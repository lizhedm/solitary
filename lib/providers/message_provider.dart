import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/database_helper.dart';
import 'auth_provider.dart';

class MessageProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  Timer? _pollingTimer;
  List<Contact> _contacts = [];
  Map<int, List<Message>> _messages = {}; // partnerId -> messages
  bool _isLoading = false;
  
  List<Contact> get contacts => _contacts;
  bool get isLoading => _isLoading;

  void startPolling(int currentUserId) {
    stopPolling();
    // Poll every 5 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      fetchNewMessages(currentUserId);
      fetchContacts(currentUserId);
    });
    // Initial fetch
    fetchNewMessages(currentUserId);
    fetchContacts(currentUserId);
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }
  
  Future<void> fetchContacts(int currentUserId) async {
    // 1. Load from local
    final localContacts = await DatabaseHelper().getContacts(currentUserId);
    
    // Only notify if contacts list was empty (first load)
    if (_contacts.isEmpty) {
       _contacts = localContacts.map((e) => Contact.fromJson(e)).toList();
       // Hydrate with last messages
       await _refreshContactDetails(currentUserId);
    }
    
    // 2. Load from API
    try {
      final response = await _apiService.get('/friends');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        bool hasChanges = false;
        
        for (var item in data) {
           final contact = Contact.fromJson(item);
           // Check if this contact is new or updated
           // For now, just save blindly, but we could optimize
           await DatabaseHelper().saveContact(contact.toJson(), ownerId: currentUserId);
        }
        
        // Update unread counts and last messages
        // This will trigger notifyListeners()
        await _refreshContactDetails(currentUserId);
      }
    } catch (e) {
      debugPrint('Fetch contacts failed: $e');
    }
  }
  
  Future<void> _refreshContactDetails(int currentUserId) async {
    final localContacts = await DatabaseHelper().getContacts(currentUserId);
    final List<Contact> updatedContacts = [];
    // 好友列表中的联系人：取 lastMessage / unread 来自 friend_messages
    for (var c in localContacts) {
       var contact = Contact.fromJson(c);
       final lastMsg = await DatabaseHelper().getLastFriendMessage(contact.id, currentUserId);
       final unread = await DatabaseHelper().getUnreadFriendCount(contact.id, currentUserId);
       if (lastMsg != null) {
         contact = contact.copyWith(
           lastMessage: lastMsg['content'],
           lastMessageTime: lastMsg['timestamp'],
         );
       }
       contact = contact.copyWith(unreadCount: unread);
       updatedContacts.add(contact);
    }
    updatedContacts.sort((a, b) => (b.lastMessageTime ?? 0).compareTo(a.lastMessageTime ?? 0));
    _contacts = updatedContacts;
    notifyListeners();
  }

  // Feedback related
  List<Map<String, dynamic>> _myFeedbacks = [];
  List<Map<String, dynamic>> get myFeedbacks => _myFeedbacks;
  int? _lastMyFeedbacksSyncMs;

  bool _shouldSyncMyFeedbacks() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastMyFeedbacksSyncMs == null) {
      _lastMyFeedbacksSyncMs = now;
      return true;
    }
    // 超过60秒才自动重新拉取服务器数据
    if (now - _lastMyFeedbacksSyncMs! > 60000) {
      _lastMyFeedbacksSyncMs = now;
      return true;
    }
    return false;
  }

  Future<void> fetchMyFeedbacks(int currentUserId, {bool forceRefresh = false}) async {
    // 1. 优先加载本地，保证快速显示
    final localFeedbacks = await DatabaseHelper().getFeedbacks(currentUserId);
    _myFeedbacks = localFeedbacks;
    notifyListeners();

    // 2. 根据节流策略决定是否从服务器同步最新数据
    if (!forceRefresh && !_shouldSyncMyFeedbacks()) {
      return;
    }

    try {
      final response = await _apiService.get('/messages/feedback/my');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;

        for (var item in data) {
          final feedbackData = Map<String, dynamic>.from(item);
          // Map API response to local DB schema
          feedbackData['remote_id'] = feedbackData['id'];
          feedbackData.remove('id');
          feedbackData['user_id'] = currentUserId;
          feedbackData['sync_status'] = 0;

          // Handle photos list -> json string
          if (feedbackData['photos'] is List) {
            feedbackData['photos'] = jsonEncode(feedbackData['photos']);
          }

          await DatabaseHelper().saveFeedback(feedbackData);

          // 同步该路况的评论到本地，保证“详情评论”可离线回显
          final feedbackId = item['id'];
          if (feedbackId != null) {
            try {
              final commentsResp = await _apiService.get('/messages/feedback/$feedbackId/comments');
              if (commentsResp.statusCode == 200 && commentsResp.data is List) {
                for (final c in commentsResp.data) {
                  final comment = Map<String, dynamic>.from(c);
                  comment['feedback_id'] = feedbackId;
                  comment['remote_id'] = comment['id'];
                  comment.remove('id');
                  await DatabaseHelper().saveFeedbackComment(comment);
                }
              }
            } catch (_) {}
          }
        }

        // Refresh local list with latest counts from server
        _myFeedbacks = await DatabaseHelper().getFeedbacks(currentUserId);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Fetch my feedbacks failed: $e');
    }
  }

  Future<void> syncTempFriendships(int currentUserId) async {
    try {
      final resp = await _apiService.get('/messages/temp-friendships');
      if (resp.statusCode == 200 && resp.data is List) {
        for (final item in resp.data) {
          final row = Map<String, dynamic>.from(item);
          await DatabaseHelper().saveTempFriendship({
            'owner_id': currentUserId,
            'partner_id': row['partner_id'],
            'partner_name': row['partner_name'],
            'partner_avatar': row['partner_avatar'],
            'last_message': row['last_message'],
            'last_message_type': row['last_message_type'] ?? 'text',
            'last_timestamp': row['last_timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }
    } catch (e) {
      debugPrint('Sync temp friendships failed: $e');
    }
  }

  Future<void> fetchNewMessages(int currentUserId) async {
    bool hasNew = false;
    try {
      final response = await _apiService.get('/messages');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        for (var item in data) {
          final msg = Message.fromJson(item);
          final map = msg.toJson();
          map['remote_id'] = msg.id;
          map.remove('id');
          map['sync_status'] = 0;
          await DatabaseHelper().saveMessage(map);
          hasNew = true;
        }
      }
    } catch (e) {
      debugPrint('Fetch messages failed: $e');
    }
    try {
      final fmResponse = await _apiService.get('/friend-messages');
      if (fmResponse.statusCode == 200) {
        final List<dynamic> data = fmResponse.data;
        for (var item in data) {
          final msg = Message.fromJson(Map<String, dynamic>.from(item));
          final map = msg.toJson();
          map['remote_id'] = msg.id;
          map.remove('id');
          map['sync_status'] = 0;
          if (item is Map && item.containsKey('attachment_url')) {
            map['attachment_url'] = item['attachment_url'];
          }
          await DatabaseHelper().saveFriendMessage(map);
          hasNew = true;
        }
      }
    } catch (e) {
      debugPrint('Fetch friend messages failed: $e');
    }
    if (hasNew) {
      await syncTempFriendships(currentUserId);
      await _refreshContactDetails(currentUserId);
      notifyListeners();
    }
  }
  
  /// [isFriendConversation] 为 true 时走好友消息（friend_messages 表与 /friend-messages 接口），否则走临时会话（messages 表与 /messages）。
  Future<void> sendMessage(int currentUserId, int receiverId, String content, {String type = 'text', bool isFriendConversation = false}) async {
    final tempMsg = Message(
      id: 0,
      senderId: currentUserId,
      receiverId: receiverId,
      content: content,
      type: type,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      isRead: false,
    );
    final map = tempMsg.toJson();
    map.remove('id');
    map['sync_status'] = 1;

    if (isFriendConversation) {
      final localId = await DatabaseHelper().saveFriendMessage(map);
      await _refreshContactDetails(currentUserId);
      notifyListeners();
      try {
        final response = await _apiService.post('/friend-messages', data: {
          'receiver_id': receiverId,
          'content': content,
          'type': type,
        });
      if (response.statusCode == 200) {
        final remoteMsg = Message.fromJson(Map<String, dynamic>.from(response.data));
        await DatabaseHelper().updateFriendMessageByLocalId(localId, {
          'remote_id': remoteMsg.id,
          'timestamp': remoteMsg.timestamp,
          'sync_status': 0,
          if (response.data is Map && (response.data as Map).containsKey('attachment_url'))
            'attachment_url': (response.data as Map)['attachment_url'],
        });
        await _refreshContactDetails(currentUserId);
        notifyListeners();
        }
      } catch (e) {
        debugPrint('Send friend message failed: $e');
      }
      return;
    }

    final localId = await DatabaseHelper().saveMessage(map);
    await _refreshContactDetails(currentUserId);
    notifyListeners();
    try {
      final response = await _apiService.post('/messages', data: {
        'receiver_id': receiverId,
        'content': content,
        'type': type,
      });
      if (response.statusCode == 200) {
        final remoteMsg = Message.fromJson(response.data);
        await DatabaseHelper().updateMessageByLocalId(localId, {
          'remote_id': remoteMsg.id,
          'timestamp': remoteMsg.timestamp,
          'sync_status': 0,
        });
        await _refreshContactDetails(currentUserId);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Send message failed: $e');
    }
  }
  
  /// [isFriendConversation] 为 true 时从 friend_messages 读并同步已读到 /friend-messages/mark-read；否则从 messages 读并走 /messages/mark-read。
  Future<List<Message>> getMessagesForContact(int currentUserId, int partnerId, {int? hikeId, DateTime? startTime, DateTime? endTime, bool isFriendConversation = false}) async {
    if (isFriendConversation) {
      final unreadIds = await DatabaseHelper().getUnreadFriendMessageIds(partnerId, currentUserId);
      await DatabaseHelper().markFriendMessagesAsRead(partnerId, currentUserId);
      await _refreshContactDetails(currentUserId);
      if (unreadIds.isNotEmpty) {
        _apiService.post('/friend-messages/mark-read', data: {'message_ids': unreadIds}).then((_) {
          debugPrint('Marked ${unreadIds.length} friend messages as read on server');
        }).catchError((e) {
          debugPrint('Failed to mark friend messages as read: $e');
        });
      }
      final list = await DatabaseHelper().getFriendMessages(partnerId, currentUserId);
      return list.map((e) => Message.fromJson(e)).toList();
    }

    final unreadIds = await DatabaseHelper().getUnreadMessageIds(partnerId, currentUserId);
    await DatabaseHelper().markMessagesAsRead(partnerId, currentUserId);
    await _refreshContactDetails(currentUserId);
    if (unreadIds.isNotEmpty) {
      _apiService.post('/messages/mark-read', data: {'message_ids': unreadIds}).then((_) {
        debugPrint('Marked ${unreadIds.length} messages as read on server');
      }).catchError((e) {
        debugPrint('Failed to mark messages as read: $e');
      });
    }

    List<Map<String, dynamic>> list;
    
    // Convert DateTime to integer timestamp (milliseconds) for comparison if needed
    final int? startTs = startTime?.millisecondsSinceEpoch;
    final int? endTs = endTime?.millisecondsSinceEpoch;

    if (hikeId != null && hikeId > 0) {
      final allHikeMessages = await DatabaseHelper().getMessagesByHikeId(hikeId, currentUserId);
      list = allHikeMessages.where((msg) {
        final senderId = msg['sender_id'] as int;
        final receiverId = msg['receiver_id'] as int;
        return (senderId == currentUserId && receiverId == partnerId) ||
            (senderId == partnerId && receiverId == currentUserId);
      }).toList();
      
      // If we got no messages by hikeId, try fallback to time range if available
      if (list.isEmpty && startTs != null && endTs != null) {
        final allRangeMessages = await DatabaseHelper().getMessagesByTimeRange(startTs, endTs);
        list = allRangeMessages.where((msg) {
          final senderId = msg['sender_id'] as int;
          final receiverId = msg['receiver_id'] as int;
          return (senderId == currentUserId && receiverId == partnerId) ||
              (senderId == partnerId && receiverId == currentUserId);
        }).toList();
      }
    } else if (startTs != null && endTs != null) {
      final allRangeMessages = await DatabaseHelper().getMessagesByTimeRange(startTs, endTs);
      list = allRangeMessages.where((msg) {
        final senderId = msg['sender_id'] as int;
        final receiverId = msg['receiver_id'] as int;
        return (senderId == currentUserId && receiverId == partnerId) ||
            (senderId == partnerId && receiverId == currentUserId);
      }).toList();
    } else {
      list = await DatabaseHelper().getMessages(partnerId, currentUserId);
    }
    
    return list.map((e) => Message.fromJson(e)).toList();
  }
  
  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}

class Contact {
  final int id;
  final String nickname;
  final String? avatar;
  final String? lastMessage;
  final int? lastMessageTime;
  final int unreadCount;
  
  Contact({
    required this.id, 
    required this.nickname, 
    this.avatar,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0
  });
  
  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'],
      nickname: json['nickname'],
      avatar: json['avatar'],
      lastMessage: json['last_msg_content'], // from local DB join or manual
      lastMessageTime: json['last_msg_time'],
      unreadCount: json['unread_count'] ?? 0
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'avatar': avatar
    };
  }
  
  Contact copyWith({String? lastMessage, int? lastMessageTime, int? unreadCount}) {
    return Contact(
      id: id,
      nickname: nickname,
      avatar: avatar,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount
    );
  }
}

