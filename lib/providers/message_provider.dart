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
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => fetchNewMessages(currentUserId));
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
    _contacts = localContacts.map((e) => Contact.fromJson(e)).toList();
    notifyListeners();
    
    // 2. Load from API
    try {
      final response = await _apiService.get('/friends');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        for (var item in data) {
           final contact = Contact.fromJson(item);
           await DatabaseHelper().saveContact(contact.toJson());
        }
        
        // Update unread counts and last messages
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
  
  Future<List<Message>> getMessagesForContact(int currentUserId, int partnerId) async {
    final list = await DatabaseHelper().getMessages(partnerId, currentUserId);
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

