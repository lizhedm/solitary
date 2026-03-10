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
    final localContacts = await DatabaseHelper().getContacts();
    
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
           await DatabaseHelper().saveContact(contact.toJson());
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
    final localContacts = await DatabaseHelper().getContacts();
    final List<Contact> updatedContacts = [];
    
    for (var c in localContacts) {
       var contact = Contact.fromJson(c);
       final lastMsg = await DatabaseHelper().getLastMessage(contact.id, currentUserId);
       final unread = await DatabaseHelper().getUnreadCount(contact.id, currentUserId);
       
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

  Future<void> fetchMyFeedbacks(int currentUserId) async {
    // 1. Load from local
    final localFeedbacks = await DatabaseHelper().getFeedbacks(currentUserId);
    _myFeedbacks = localFeedbacks;
    notifyListeners();

    // 2. Load from API
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
        }
        
        // Refresh local list
        _myFeedbacks = await DatabaseHelper().getFeedbacks(currentUserId);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Fetch my feedbacks failed: $e');
    }
  }

  Future<void> fetchNewMessages(int currentUserId) async {
    try {
      final response = await _apiService.get('/messages'); 
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        bool hasNew = false;
        
        for (var item in data) {
           final msg = Message.fromJson(item);
           // Save to DB
           final map = msg.toJson();
           map['remote_id'] = msg.id;
           map.remove('id');
           map['sync_status'] = 0;
           
           // Check if exists (optimization needed)
           await DatabaseHelper().saveMessage(map);
           hasNew = true;
        }
        
        if (hasNew) {
           await _refreshContactDetails(currentUserId);
           notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Fetch messages failed: $e');
    }
  }
  
  Future<void> sendMessage(int currentUserId, int receiverId, String content, {String type = 'text'}) async {
    final tempMsg = Message(
      id: 0, // Placeholder
      senderId: currentUserId,
      receiverId: receiverId,
      content: content,
      type: type,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      isRead: false
    );
    
    // Save locally first
    final map = tempMsg.toJson();
    map.remove('id');
    map['sync_status'] = 1; // Pending
    final localId = await DatabaseHelper().saveMessage(map);
    
    // Refresh UI immediately
    await _refreshContactDetails(currentUserId);
    notifyListeners();
    
    try {
      final response = await _apiService.post('/messages', data: {
        'receiver_id': receiverId,
        'content': content,
        'type': type
      });
      
      if (response.statusCode == 200) {
         final remoteMsg = Message.fromJson(response.data);
         // Update local
         map['remote_id'] = remoteMsg.id;
         map['timestamp'] = remoteMsg.timestamp;
         map['sync_status'] = 0;
         map['local_id'] = localId; // Important: update the existing record
         await DatabaseHelper().saveMessage(map);
         notifyListeners();
      }
    } catch (e) {
      debugPrint('Send message failed: $e');
    }
  }
  
  Future<List<Message>> getMessagesForContact(int currentUserId, int partnerId, {int? hikeId}) async {
    // 1. Get unread remote IDs to sync with server
    final unreadIds = await DatabaseHelper().getUnreadMessageIds(partnerId, currentUserId);
    
    // 2. Mark local messages as read
    await DatabaseHelper().markMessagesAsRead(partnerId, currentUserId);
    
    // 3. Refresh contact list to update unread count immediately
    await _refreshContactDetails(currentUserId);
    
    // 4. Sync read status with server (fire and forget)
    if (unreadIds.isNotEmpty) {
      _apiService.post('/messages/mark-read', data: {
        'message_ids': unreadIds
      }).then((_) {
        debugPrint('Marked ${unreadIds.length} messages as read on server');
      }).catchError((e) {
        debugPrint('Failed to mark messages as read: $e');
      });
    }
    
    List<Map<String, dynamic>> list;
    if (hikeId != null) {
      // Fetch messages for a specific hike with this partner
      final allHikeMessages = await DatabaseHelper().getMessagesByHikeId(hikeId);
      list = allHikeMessages.where((msg) {
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

