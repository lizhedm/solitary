import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:solitary/providers/auth_provider.dart';
import 'package:solitary/providers/message_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'dart:async';
import '../../services/database_helper.dart';
import 'chat_page.dart';
import '../hiking/route_feedback_detail_page.dart';
import '../hiking/feedback_list_widget.dart';
import 'sos_event_detail_page.dart';

import 'package:solitary/services/api_service.dart';

class MessageCenterPage extends StatefulWidget {
  const MessageCenterPage({super.key});

  @override
  State<MessageCenterPage> createState() => _MessageCenterPageState();
}

class _MessageCenterPageState extends State<MessageCenterPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _tempListVersion = 0;
  Timer? _tempRefreshDebounce;
  Map<String, List<Map<String, dynamic>>>? _tempCache;
  Future<Map<String, List<Map<String, dynamic>>>>? _tempFuture;
  int _tempFutureVersion = -1;
  VoidCallback? _providerListener;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Add listener to refresh data when switching tabs
    _tabController.addListener(() {
      if (_tabController.index == 2 && !_tabController.indexIsChanging) {
        _fetchMyFeedbacks();
      }
    });
    
    // Start polling when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final msgProvider = Provider.of<MessageProvider>(context, listen: false);
      if (authProvider.user != null) {
        msgProvider.startPolling(authProvider.user!.id);
        // Also fetch feedbacks initially
        msgProvider.fetchMyFeedbacks(authProvider.user!.id);
      }

      // 监听轮询更新：让“临时会话”在几秒内自动刷新（不需要退出重登）
      _providerListener = () {
        // 只在“临时会话”tab时刷新，避免不必要的重建
        if (!mounted) return;
        if (_tabController.index != 1) return;
        _tempRefreshDebounce?.cancel();
        _tempRefreshDebounce = Timer(const Duration(milliseconds: 350), () {
          if (!mounted) return;
          setState(() {
            _tempListVersion++;
          });
        });
      };
      msgProvider.addListener(_providerListener!);
    });
  }

  void _fetchMyFeedbacks() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final msgProvider = Provider.of<MessageProvider>(context, listen: false);
    if (authProvider.user != null) {
      msgProvider.fetchMyFeedbacks(authProvider.user!.id);
    }
  }

  @override
  void dispose() {
    final msgProvider = Provider.of<MessageProvider>(context, listen: false);
    if (_providerListener != null) {
      msgProvider.removeListener(_providerListener!);
    }
    _tempRefreshDebounce?.cancel();
    _tabController.dispose();
    // Don't stop polling here if we want background updates, 
    // but for now, let's keep it bound to the provider's lifecycle or page
    // Actually MessageProvider is global, so maybe don't stop?
    // But to save resources when leaving tab... let's keep polling active for now.
    super.dispose();
  }

  Future<Map<String, List<Map<String, dynamic>>>> _getTempFuture(int currentUserId) {
    if (_tempFuture != null && _tempFutureVersion == _tempListVersion) {
      return _tempFuture!;
    }
    _tempFutureVersion = _tempListVersion;
    _tempFuture = _loadTemporaryDataV2(currentUserId);
    return _tempFuture!;
  }

  Future<Map<String, List<Map<String, dynamic>>>> _loadTemporaryDataV2(int currentUserId) async {
    final db = await DatabaseHelper().database;
    debugPrint('Fetching all messages for temporary session list (v2)...');

    // 只展示“当前进行中的徒步”时间段内产生的临时会话。
    // 如果当前没有进行中的徒步（end_time 为空的记录），则临时会话列表为空。
    final activeHike = await db.query(
      'hiking_records',
      where: 'user_id = ? AND end_time IS NULL',
      whereArgs: [currentUserId],
      orderBy: 'start_time DESC',
      limit: 1,
    );
    if (activeHike.isEmpty) {
      return {
        'my_questions': <Map<String, dynamic>>[],
        'incoming_questions': <Map<String, dynamic>>[],
        'my_sos': <Map<String, dynamic>>[],
        'incoming_sos': <Map<String, dynamic>>[],
      };
    }

    final startSeconds = activeHike.first['start_time'] as int? ?? 0;
    final startMs = startSeconds * 1000;
    final endMs = DateTime.now().millisecondsSinceEpoch;

    var allMessages = await db.query(
      'messages',
      where:
          '(sender_id = ? OR receiver_id = ?) AND timestamp >= ? AND timestamp <= ?',
      whereArgs: [currentUserId, currentUserId, startMs, endMs],
      orderBy: 'timestamp DESC',
    );

    // 本地无数据时兜底同步一次（避免必须退出重登才看到）
    if (allMessages.isEmpty) {
      try {
        final resp = await ApiService().get('/messages');
        if (resp.statusCode == 200 && resp.data is List) {
          for (final item in (resp.data as List)) {
            if (item is! Map) continue;
            final m = Map<String, dynamic>.from(item);
            m['remote_id'] = m['id'];
            m.remove('id');
            m['sync_status'] = 0;
            if (m['is_read'] is bool) {
              m['is_read'] = (m['is_read'] == true) ? 1 : 0;
            }
            await DatabaseHelper().saveMessage(m);
          }
        }
      } catch (e) {
        debugPrint('Temp list fallback sync /messages failed: $e');
      }

      allMessages = await db.query(
        'messages',
        where:
            '(sender_id = ? OR receiver_id = ?) AND timestamp >= ? AND timestamp <= ?',
        whereArgs: [currentUserId, currentUserId, startMs, endMs],
        orderBy: 'timestamp DESC',
      );
    }

    final Map<String, Map<String, dynamic>> myQuestionsMap = {};
    final Map<String, Map<String, dynamic>> incomingQuestionsMap = {};
    final Map<String, Map<String, dynamic>> incomingSosMap = {};

    for (var msg in allMessages) {
      final type = msg['type'] as String? ?? 'text';
      final senderId = msg['sender_id'] as int;
      final receiverId = msg['receiver_id'] as int;
      final hikeId = msg['hike_id'] as int?;
      final timestamp = msg['timestamp'] as int;

      if (type == 'question' && (hikeId == null || hikeId == 0)) {
        final content = msg['content'] as String;
        if (senderId == currentUserId) {
          if (!myQuestionsMap.containsKey(content)) {
            myQuestionsMap[content] = {
              'content': content,
              'timestamp': timestamp,
              'recipients': <int>[],
            };
          }
          final recipients = myQuestionsMap[content]!['recipients'] as List<int>;
          if (!recipients.contains(receiverId)) recipients.add(receiverId);
        } else if (receiverId == currentUserId) {
          final partnerId = senderId;
          final key = 'question_incoming_${partnerId}_$content';
          if (incomingQuestionsMap.containsKey(key)) {
            final existingTime =
                (incomingQuestionsMap[key]!['msg'] as Map)['timestamp'] as int;
            if (timestamp <= existingTime) continue;
          }
          incomingQuestionsMap[key] = {'msg': msg, 'partner_id': partnerId};
        }
        continue;
      }

      if (type == 'sos' && receiverId == currentUserId) {
        final partnerId = senderId;
        final remoteId = msg['remote_id'];
        final baseKey =
            remoteId != null ? remoteId.toString() : '${partnerId}_$timestamp';
        final key = 'sos_incoming_$baseKey';
        if (incomingSosMap.containsKey(key)) {
          final existingTime =
              (incomingSosMap[key]!['msg'] as Map)['timestamp'] as int;
          if (timestamp <= existingTime) continue;
        }
        incomingSosMap[key] = {'msg': msg, 'partner_id': partnerId};
        continue;
      }
    }

    final myQuestionList = myQuestionsMap.values.toList();
    myQuestionList.sort(
        (a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));

    final List<Map<String, dynamic>> incomingQuestionList = [];
    for (var item in incomingQuestionsMap.values) {
      final msg = item['msg'] as Map<String, dynamic>;
      final partnerId = item['partner_id'] as int;
      String name = '用户 $partnerId';
      String avatar = '';

      var contact = await DatabaseHelper().getContact(partnerId, ownerId: currentUserId);
      if (contact != null) {
        name = contact['nickname'] ?? name;
        avatar = contact['avatar'] ?? avatar;
      } else {
        // 兜底从服务端拉一次用户信息，用于展示头像（与详情页逻辑保持一致）
        try {
          final resp = await ApiService().get('/users/$partnerId');
          if (resp.statusCode == 200 && resp.data != null) {
            final user = resp.data;
            name = user['nickname'] ?? name;
            avatar = user['avatar'] ?? avatar;
          }
        } catch (e) {
          debugPrint('Error fetching user info for $partnerId: $e');
        }
      }

      incomingQuestionList.add({
        'partner_id': partnerId,
        'partner_name': name,
        'partner_avatar': avatar,
        'content': '收到提问: ${msg['content']}',
        'timestamp': msg['timestamp'],
      });
    }
    incomingQuestionList.sort(
        (a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));

    final mySosEvents = await db.query(
      'sos_events',
      where: 'user_id = ? AND created_at >= ? AND created_at <= ?',
      whereArgs: [currentUserId, startMs, endMs],
      orderBy: 'created_at DESC',
    );

    final List<Map<String, dynamic>> incomingSosList = [];
    for (var item in incomingSosMap.values) {
      final msg = item['msg'] as Map<String, dynamic>;
      final partnerId = item['partner_id'] as int;
      String name = partnerId == 0 ? '所有人 (SOS广播)' : '用户 $partnerId';
      String avatar = '';
      if (partnerId != 0) {
        var contact = await DatabaseHelper().getContact(partnerId, ownerId: currentUserId);
        if (contact != null) {
          name = contact['nickname'] ?? name;
          avatar = contact['avatar'] ?? avatar;
        } else {
          try {
            final resp = await ApiService().get('/users/$partnerId');
            if (resp.statusCode == 200 && resp.data != null) {
              final user = resp.data;
              name = user['nickname'] ?? name;
              avatar = user['avatar'] ?? avatar;
            }
          } catch (e) {
            debugPrint('Error fetching user info for $partnerId: $e');
          }
        }
      }
      String dangerLabel = '未知危险';
      int safetyStatus = 0;
      List urgentLabels = [];
      try {
        final data = jsonDecode(msg['content'] as String? ?? '{}');
        dangerLabel = data['danger_label'] ?? dangerLabel;
        safetyStatus = data['safety_status'] ?? safetyStatus;
        urgentLabels = (data['urgent_labels'] as List?) ?? [];
      } catch (_) {}

      incomingSosList.add({
        'partner_id': partnerId,
        'partner_name': name,
        'partner_avatar': avatar,
        'content': '收到他的求救信号',
        'timestamp': msg['timestamp'],
        'danger_label': dangerLabel,
        'safety_status': safetyStatus,
        'urgent_labels': urgentLabels,
      });
    }
    incomingSosList.sort(
        (a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));

    return {
      'my_questions': myQuestionList,
      'incoming_questions': incomingQuestionList,
      'my_sos': mySosEvents,
      'incoming_sos': incomingSosList,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('消息中心'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2E7D32),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF2E7D32),
          tabs: const [
            Tab(text: '好友消息'),
            Tab(text: '临时会话'),
            Tab(text: '我的路况'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsList(),
          _buildTemporaryListV2(),
          _buildMyFeedbacksList(),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String description, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniTag(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _previewTag(String? content, {String? type}) {
    final t = (type ?? '').toLowerCase();
    if (t == 'feedback_card') {
      return {'text': '路况卡片', 'color': Colors.blue, 'icon': Icons.description};
    }
    if (t == 'sos') {
      return {'text': 'SOS卡片', 'color': Colors.red, 'icon': Icons.warning_amber_rounded};
    }
    if (t == 'question') {
      return {'text': '提问卡片', 'color': Colors.deepPurple, 'icon': Icons.help_outline};
    }
    if (content != null && content.isNotEmpty && content.trim().startsWith('{')) {
      try {
        final obj = jsonDecode(content);
        if (obj is Map) {
          final innerType = (obj['type'] ?? '').toString().toLowerCase();
          if (innerType == 'feedback_card') {
            return {'text': '路况卡片', 'color': Colors.blue, 'icon': Icons.description};
          }
          if (innerType == 'sos_card') {
            return {'text': 'SOS卡片', 'color': Colors.red, 'icon': Icons.warning_amber_rounded};
          }
        }
      } catch (_) {}
    }
    return null;
  }

  Widget _buildRecentPreview(String? content, {String? type}) {
    final tag = _previewTag(content, type: type);
    if (tag != null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: IntrinsicWidth(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (tag['color'] as Color).withOpacity(0.12),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: (tag['color'] as Color).withOpacity(0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(tag['icon'] as IconData, size: 12, color: tag['color'] as Color),
                const SizedBox(width: 4),
                Text(
                  tag['text'] as String,
                  style: TextStyle(fontSize: 11, color: tag['color'] as Color, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Text(
      content ?? '暂无消息',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Future<void> _refreshFriendsList() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final msgProvider = Provider.of<MessageProvider>(context, listen: false);
    if (authProvider.user != null) {
      msgProvider.startPolling(authProvider.user!.id);
      await msgProvider.fetchContacts(authProvider.user!.id);
      await msgProvider.fetchNewMessages(authProvider.user!.id);
    }
  }

  Widget _buildFriendsList() {
    return Consumer<MessageProvider>(
      builder: (context, provider, child) {
        if (provider.contacts.isEmpty) {
           return RefreshIndicator(
             onRefresh: _refreshFriendsList,
             child: ListView(
               physics: const AlwaysScrollableScrollPhysics(),
               children: [
                 SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                 _buildEmptyState(
                   '暂无好友消息',
                   '这里会显示你和队友的聊天记录。\n在地图上点击队友头像即可发起聊天。',
                   Icons.chat_bubble_outline,
                 ),
               ],
             ),
           );
        }
        
        return RefreshIndicator(
          onRefresh: _refreshFriendsList,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: provider.contacts.length,
            itemBuilder: (context, index) {
              final contact = provider.contacts[index];
              final avatarUrl = contact.avatar;
              
              return ListTile(
                leading: GestureDetector(
                  child: (avatarUrl != null && avatarUrl.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: avatarUrl.startsWith('http') 
                              ? avatarUrl 
                              : 'http://8.136.205.255:8000$avatarUrl',
                          imageBuilder: (context, imageProvider) => CircleAvatar(
                            backgroundImage: imageProvider,
                          ),
                          placeholder: (context, url) => const CircleAvatar(child: Icon(Icons.person)),
                          errorWidget: (context, url, error) => const CircleAvatar(child: Icon(Icons.error)),
                        )
                      : CircleAvatar(
                          backgroundColor: Colors.grey[200],
                          child: Text(contact.nickname.substring(0, 1).toUpperCase()),
                        ),
                ),
                title: Text(contact.nickname),
                subtitle: _buildRecentPreview(
                  contact.lastMessage,
                  type: contact.lastMessageType,
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (contact.lastMessageTime != null)
                      Text(
                        _formatTime(contact.lastMessageTime!), 
                        style: const TextStyle(fontSize: 12, color: Colors.grey)
                      ),
                    const SizedBox(height: 4),
                    if (contact.unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${contact.unreadCount}',
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatPage(
                        title: contact.nickname,
                        avatar: contact.avatar,
                        partnerId: contact.id,
                        isFriendConversation: true,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thatDay = DateTime(date.year, date.month, date.day);
    
    final diff = today.difference(thatDay).inDays;
    final timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    
    if (diff == 0) {
      return '今天 $timeStr';
    } else if (diff == 1) {
      return '昨天 $timeStr';
    } else if (diff == 2) {
      return '前天 $timeStr';
    } else {
      return '${date.month}月${date.day}日 $timeStr';
    }
  }

  Widget _buildTemporaryList() {
    return Consumer<MessageProvider>(
      builder: (context, provider, child) {
        // Group messages by type='question' and senderId=me to find "My Questions"
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final currentUserId = authProvider.user?.id;
        
        if (currentUserId == null) return const Center(child: Text('请先登录'));
        
        // Use FutureBuilder because we need to query DB for specific message types
        return RefreshIndicator(
          onRefresh: () async {
            // Force polling to fetch new messages
            provider.startPolling(currentUserId);
            await provider.fetchNewMessages(currentUserId);
            setState(() {});
          },
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: DatabaseHelper().database.then((db) async {
              debugPrint('Fetching all messages for temporary list checking...');
              
              // Fetch ALL messages related to current user to avoid any SQL filtering issues
              final allMessages = await db.query(
                'messages',
                where: 'sender_id = ? OR receiver_id = ?',
                whereArgs: [currentUserId, currentUserId],
                orderBy: 'timestamp DESC'
              );
              
              debugPrint('Total raw messages found: ${allMessages.length}');
              
              // Containers for final result
              final Map<String, Map<String, dynamic>> myQuestionsMap = {}; // Grouped by content
              final Map<String, Map<String, dynamic>> incomingMap = {}; // Key: "type_direction_partnerId_content"
              
              for (var msg in allMessages) {
                final type = msg['type'] as String? ?? 'text';
                final senderId = msg['sender_id'] as int;
                final receiverId = msg['receiver_id'] as int;
                final hikeId = msg['hike_id'] as int?;
                
                // 1. My Questions (Sent by me, type=question, not in hike)
                // We keep grouping by content for broadcasts to avoid list explosion,
                // but these are already separate from other types with the same partner.
                if (senderId == currentUserId && type == 'question' && (hikeId == null || hikeId == 0)) {
                  final content = msg['content'] as String;
                  if (!myQuestionsMap.containsKey(content)) {
                    myQuestionsMap[content] = {
                      'content': content,
                      'timestamp': msg['timestamp'],
                      'recipients': <int>[],
                      'reply_count': 0,
                      'is_incoming': false // Explicitly mark as my question group
                    };
                  }
                  // Add recipient if not already added
                  final recipients = myQuestionsMap[content]!['recipients'] as List<int>;
                  if (!recipients.contains(receiverId)) {
                    recipients.add(receiverId);
                  }
                  continue;
                }
                
                // 2. Incoming Questions (Received by me, type=question, not in hike)
                if (receiverId == currentUserId && type == 'question' && (hikeId == null || hikeId == 0)) {
                   final partnerId = senderId;
                   final content = msg['content'] as String;
                   // Use content in key to show different questions from same partner as separate entries
                   final key = "question_incoming_${partnerId}_$content";
                   
                   if (incomingMap.containsKey(key)) {
                      final existingTime = (incomingMap[key]!['msg'] as Map)['timestamp'] as int;
                      if ((msg['timestamp'] as int) < existingTime) continue;
                   }
                   incomingMap[key] = {
                     'msg': msg,
                     'type': 'question',
                     'partner_id': partnerId
                   };
                   continue;
                }
                
                // 3. SOS Messages (Sent OR Received, type=sos, IGNORE hike_id)
                if (type == 'sos') {
                   final isOutgoing = senderId == currentUserId;
                   final partnerId = isOutgoing ? receiverId : senderId;
                   // Separate by direction and partner. 
                   // Different SOS events with same partner are usually updates, so we keep latest.
                   final key = "sos_${isOutgoing ? 'outgoing' : 'incoming'}_$partnerId";
                   
                   if (incomingMap.containsKey(key)) {
                      final existingTime = (incomingMap[key]!['msg'] as Map)['timestamp'] as int;
                      if ((msg['timestamp'] as int) < existingTime) continue;
                   }
                   incomingMap[key] = {
                     'msg': msg,
                     'type': 'sos',
                     'partner_id': partnerId
                   };
                   continue;
                }
              }
              
              debugPrint('Processed: ${myQuestionsMap.length} my questions, ${incomingMap.length} other chats');
              
              // Resolve Contact Info for incomingMap
              for (var key in incomingMap.keys) {
                 final item = incomingMap[key]!;
                 final msg = item['msg'] as Map<String, dynamic>;
                 final partnerId = item['partner_id'] as int;
                 final type = item['type'] as String;
                 final senderId = msg['sender_id'] as int;
                 
                 // Get partner info
                 String name = partnerId == 0 ? '所有人 (SOS广播)' : '用户 $partnerId';
                 String avatar = '';
                 
                 if (partnerId != 0) {
                   var contact = await DatabaseHelper().getContact(partnerId, ownerId: currentUserId);
                   if (contact != null) {
                      name = contact['nickname'] ?? name;
                      avatar = contact['avatar'] ?? avatar;
                   } else {
                      try {
                        final response = await ApiService().get('/users/$partnerId');
                        if (response.statusCode == 200 && response.data != null) {
                          final user = response.data;
                          name = user['nickname'] ?? name;
                          avatar = user['avatar'] ?? avatar;
                        }
                      } catch (e) {
                        debugPrint('Error fetching user info for $partnerId: $e');
                      }
                   }
                 }
                 
                 String content = msg['content'] as String;
                 
                 // Format content for display
                 if (type == 'sos') {
                    if (senderId == currentUserId) {
                      content = partnerId == 0 ? '我已发出求救广播' : '我向他发出了求救';
                    } else {
                      content = '收到他的求救信号';
                    }
                 } else if (type == 'question') {
                    content = '收到提问: $content';
                 }
                 
                 // Finalize item
                 incomingMap[key] = {
                    'partner_id': partnerId,
                    'partner_name': name,
                    'partner_avatar': avatar,
                    'content': content,
                    'timestamp': msg['timestamp'],
                    'type': type,
                    'is_incoming': true // This marks it for single-chat card style
                 };
              }
            
              final List<Map<String, dynamic>> combined = [];
              combined.addAll(myQuestionsMap.values);
              combined.addAll(incomingMap.values);
            
              // Sort by timestamp
              combined.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));
            
              return combined;
          }),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
               return Center(child: Text('加载失败: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyState(
                '暂无临时会话',
                '这里显示附近的临时消息。\n当你在地图上向陌生人打招呼时，会话会出现在这里。',
                Icons.people_outline,
              );
            }
            
            final items = snapshot.data!;
            
            return ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                
                // 1. My Question (Group)
                if (item['is_incoming'] != true) {
                   final recipientCount = (item['recipients'] as List).length;
                   return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.blue.shade50,
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Icon(Icons.help, color: Colors.white),
                      ),
                      title: Text('我的提问: ${item['content']}', maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '发送给 $recipientCount 位用户 • ${_formatTime(item['timestamp'])}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // Old code replaced
                      },
                    ),
                  );
                } 
                
                // 2. Incoming/Outgoing Single Chat (SOS or Question or Others)
                else {
                   final partnerId = item['partner_id'] as int;
                   final partnerName = item['partner_name'] as String;
                   final partnerAvatar = item['partner_avatar'] as String;
                   final type = item['type'] as String;
                   final isSOS = type == 'sos';

                   return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: isSOS ? Colors.red.shade50 : null, // Red background for SOS
                    shape: isSOS ? RoundedRectangleBorder(
                      side: BorderSide(color: Colors.red.shade200, width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ) : null,
                    child: ListTile(
                      leading: (partnerAvatar.isNotEmpty)
                          ? CircleAvatar(
                              backgroundImage: CachedNetworkImageProvider(
                                partnerAvatar.startsWith('http') 
                                  ? partnerAvatar 
                                  : 'http://8.136.205.255:8000$partnerAvatar'
                              ),
                            )
                          : CircleAvatar(
                              backgroundColor: isSOS ? Colors.red.shade100 : Colors.orange.shade100,
                              child: isSOS 
                                ? const Icon(Icons.warning_amber_rounded, color: Colors.red)
                                : Text(partnerName.substring(0, 1), style: const TextStyle(color: Colors.orange)),
                            ),
                      title: Text(
                        item['content'], 
                        maxLines: 1, 
                        overflow: TextOverflow.ellipsis,
                        style: isSOS ? const TextStyle(color: Colors.red, fontWeight: FontWeight.bold) : null,
                      ),
                      subtitle: Text(
                        '与 $partnerName • ${_formatTime(item['timestamp'])}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chat),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatPage(
                              title: partnerName,
                              avatar: partnerAvatar,
                              partnerId: partnerId,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }
              },
            );
          },
        ),
      );
    },
  );
}

  /// 新版本的临时会话列表：明确拆分为「我的提问 / 向我提问 / 我的求救 / 向我求救」四大类
  Widget _buildTemporaryListV2() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.id;

    if (currentUserId == null) {
      return const Center(child: Text('请先登录'));
    }

    return RefreshIndicator(
      onRefresh: () async {
        final provider = Provider.of<MessageProvider>(context, listen: false);
        provider.startPolling(currentUserId);
        await provider.fetchNewMessages(currentUserId);
        if (mounted) {
          setState(() {
            _tempListVersion++;
          });
        }
        setState(() {});
      },
      child: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
        future: _getTempFuture(currentUserId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('加载失败: ${snapshot.error}'));
              }
          final data = snapshot.data ?? _tempCache;
          if (snapshot.hasData) {
            _tempCache = snapshot.data;
          }
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }
              final myQuestions = data['my_questions'] ?? [];
              final incomingQuestions = data['incoming_questions'] ?? [];
              final mySos = data['my_sos'] ?? [];
              final incomingSos = data['incoming_sos'] ?? [];

              if (myQuestions.isEmpty &&
                  incomingQuestions.isEmpty &&
                  mySos.isEmpty &&
                  incomingSos.isEmpty) {
                return _buildEmptyState(
                  '暂无临时会话',
                  '这里会显示你的提问、收到的提问以及求救信息。\n在地图页面发起求助或求救后，会话会出现在这里。',
                  Icons.people_outline,
                );
              }

              return ListView(
                children: [
                  if (myQuestions.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(
                        '我的提问',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ),
                    ...myQuestions.map((item) {
                      return _MyQuestionCard(
                        item: item,
                        formatTime: _formatTime,
                      );
                    }),
                  ],

                  if (incomingQuestions.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(
                        '向我提问',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ),
                    ...incomingQuestions.map((item) {
                      final partnerId = item['partner_id'] as int;
                      final partnerName = item['partner_name'] as String;
                      final partnerAvatar = item['partner_avatar'] as String;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: (partnerAvatar.isNotEmpty)
                              ? CircleAvatar(
                                  backgroundImage: CachedNetworkImageProvider(
                                    partnerAvatar.startsWith('http')
                                        ? partnerAvatar
                                        : 'http://8.136.205.255:8000$partnerAvatar',
                                  ),
                                )
                              : CircleAvatar(
                                  backgroundColor: Colors.orange.shade100,
                                  child: Text(
                                    partnerName.substring(0, 1),
                                    style: const TextStyle(color: Colors.orange),
                                  ),
                                ),
                          title: Text(
                            item['content'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '来自 $partnerName • ${_formatTime(item['timestamp'])}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chat),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatPage(
                                  title: partnerName,
                                  avatar: partnerAvatar,
                                  partnerId: partnerId,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }),
                  ],

                  if (mySos.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(
                        '我的求救',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                    ...mySos.map((event) {
                      return _MySosCard(
                        event: event,
                        formatTime: _formatTime,
                      );
                    }),
                  ],

                  if (incomingSos.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(
                        '向我求救',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                    ...incomingSos.map((item) {
                      final partnerId = item['partner_id'] as int;
                      final partnerName = item['partner_name'] as String;
                      final partnerAvatar = item['partner_avatar'] as String;
                      final dangerLabel = item['danger_label'] as String? ?? '未知危险';
                      final safetyStatus = item['safety_status'] as int? ?? 0;
                      final urgentLabels = (item['urgent_labels'] as List?) ?? [];
                      final statusText = safetyStatus == 2
                          ? '已脱险'
                          : (safetyStatus == 1 ? '暂时安全' : '仍危险');
                      final statusColor = safetyStatus == 2
                          ? Colors.green
                          : (safetyStatus == 1 ? Colors.orange : Colors.red);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        color: Colors.red.shade50,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: Colors.red.shade200,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: (partnerAvatar.isNotEmpty)
                              ? CircleAvatar(
                                  backgroundImage: CachedNetworkImageProvider(
                                    partnerAvatar.startsWith('http')
                                        ? partnerAvatar
                                        : 'http://8.136.205.255:8000$partnerAvatar',
                                  ),
                                )
                              : CircleAvatar(
                                  backgroundColor: Colors.red.shade100,
                                  child: const Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.red,
                                  ),
                                ),
                          title: Text(
                            item['content'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    _miniTag(Icons.report, dangerLabel, Colors.red.shade700),
                                    _miniTag(Icons.shield, statusText, statusColor),
                                    if (urgentLabels.isNotEmpty)
                                      _miniTag(Icons.inventory_2, urgentLabels.join('、'), Colors.deepOrange),
                                    _miniTag(Icons.access_time, _formatTime(item['timestamp']), Colors.grey),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '来自 $partnerName',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          trailing: const Icon(Icons.chat),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatPage(
                                  title: partnerName,
                                  avatar: partnerAvatar,
                                  partnerId: partnerId,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }),
                  ],
                ],
              );
            },
          ),
        );
  }

  Widget _buildMyFeedbacksList() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.id;
    
    if (userId == null) {
      return const Center(child: Text('请先登录'));
    }

    return Consumer<MessageProvider>(
      builder: (context, provider, child) {
        final feedbacks = provider.myFeedbacks;
        return FeedbackListWidget(
          feedbacks: feedbacks,
          onRefresh: () => provider.fetchMyFeedbacks(userId, forceRefresh: true),
        );
      },
    );
  }
}

class _MySosCard extends StatefulWidget {
  final Map<String, dynamic> event;
  final String Function(int) formatTime;

  const _MySosCard({Key? key, required this.event, required this.formatTime}) : super(key: key);

  @override
  State<_MySosCard> createState() => _MySosCardState();
}

class _MySosCardState extends State<_MySosCard> {
  bool _isExpanded = false;

  Future<Map<String, dynamic>> _getUserInfo(int partnerId, int currentUserId) async {
    var contact = await DatabaseHelper().getContact(partnerId, ownerId: currentUserId);
    if (contact != null) {
      return contact;
    }
    try {
      final response = await ApiService().get('/users/$partnerId');
      if (response.statusCode == 200 && response.data != null) {
        return {
          'nickname': response.data['nickname'] ?? '用户 $partnerId',
          'avatar': response.data['avatar'] ?? '',
        };
      }
    } catch (e) {
      // Ignore
    }
    return {
      'nickname': '用户 $partnerId',
      'avatar': '',
    };
  }

  Widget _miniTag(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String dangerLabel = '未知危险';
    int safetyStatus = 0;
    List urgentLabels = [];
    int createdAt = widget.event['created_at'] as int? ?? 0;
    List recipients = [];
    int recipientCount = 0;

    try {
      final msg = jsonDecode(widget.event['message_json'] ?? '{}');
      dangerLabel = msg['danger_label'] ?? dangerLabel;
      safetyStatus = msg['safety_status'] ?? safetyStatus;
      urgentLabels = (msg['urgent_labels'] as List?) ?? [];
    } catch (_) {}

    try {
      recipients = jsonDecode(widget.event['recipients_json'] ?? '[]') as List;
      recipientCount = recipients.length;
    } catch (_) {}

    final statusText = safetyStatus == 2
        ? '已脱险'
        : (safetyStatus == 1 ? '暂时安全' : '仍危险');
    final statusColor = safetyStatus == 2
        ? Colors.green
        : (safetyStatus == 1 ? Colors.orange : Colors.red);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.red.shade50,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.red.shade200, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.red.shade100,
              child: const Icon(Icons.warning_amber_rounded, color: Colors.red),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '已发送给 $recipientCount 位用户',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isExpanded ? '收起会话' : '展开会话',
                        style: const TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                      Icon(
                        _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 16,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _miniTag(Icons.report, dangerLabel, Colors.red.shade700),
                  _miniTag(Icons.shield, statusText, statusColor),
                  if (urgentLabels.isNotEmpty)
                    _miniTag(Icons.inventory_2, urgentLabels.join('、'), Colors.deepOrange),
                  _miniTag(Icons.access_time, widget.formatTime(createdAt), Colors.grey),
                ],
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SOSEventDetailPage(event: Map<String, dynamic>.from(widget.event)),
                ),
              );
            },
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.red.shade100)),
              ),
              child: Column(
                children: recipients.map((partnerItem) {
                  int partnerId;
                  if (partnerItem is int) {
                    partnerId = partnerItem;
                  } else if (partnerItem is Map) {
                    partnerId = partnerItem['id'] as int? ?? 0;
                  } else {
                    partnerId = int.tryParse(partnerItem.toString()) ?? 0;
                  }
                  
                  if (partnerId == 0) return const SizedBox.shrink();

                  return FutureBuilder<Map<String, dynamic>?>(
                    future: _getUserInfo(partnerId, Provider.of<AuthProvider>(context, listen: false).user?.id ?? 0),
                    builder: (context, snapshot) {
                      String name = '用户 $partnerId';
                      String avatar = '';
                      if (snapshot.hasData && snapshot.data != null) {
                        name = snapshot.data!['nickname'] ?? name;
                        avatar = snapshot.data!['avatar'] ?? '';
                      }
                      return ListTile(
                        dense: true,
                        leading: (avatar.isNotEmpty)
                            ? CircleAvatar(
                                radius: 16,
                                backgroundImage: CachedNetworkImageProvider(
                                  avatar.startsWith('http')
                                      ? avatar
                                      : 'http://8.136.205.255:8000$avatar',
                                ),
                              )
                            : CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.orange.shade100,
                                child: Text(
                                  name.substring(0, 1),
                                  style: const TextStyle(color: Colors.orange, fontSize: 12),
                                ),
                              ),
                        title: Text(name, style: const TextStyle(fontSize: 14)),
                        trailing: const Icon(Icons.chat, size: 16, color: Colors.grey),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatPage(
                                title: name,
                                avatar: avatar,
                                partnerId: partnerId,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                }).toList(),
              ),
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }
}

class _MyQuestionCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final String Function(int) formatTime;

  const _MyQuestionCard({Key? key, required this.item, required this.formatTime}) : super(key: key);

  @override
  State<_MyQuestionCard> createState() => _MyQuestionCardState();
}

class _MyQuestionCardState extends State<_MyQuestionCard> {
  bool _isExpanded = false;

  Future<Map<String, dynamic>> _getUserInfo(int partnerId, int currentUserId) async {
    var contact = await DatabaseHelper().getContact(partnerId, ownerId: currentUserId);
    if (contact != null) {
      return contact;
    }
    try {
      final response = await ApiService().get('/users/$partnerId');
      if (response.statusCode == 200 && response.data != null) {
        return {
          'nickname': response.data['nickname'] ?? '用户 $partnerId',
          'avatar': response.data['avatar'] ?? '',
        };
      }
    } catch (e) {
      // Ignore
    }
    return {
      'nickname': '用户 $partnerId',
      'avatar': '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final recipients = widget.item['recipients'] as List? ?? [];
    final recipientCount = recipients.length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blue.shade50,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.blue.shade200, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.blue,
              child: Icon(Icons.help, color: Colors.white),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.item['content'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                    onPressed: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isExpanded ? '收起会话' : '展开会话',
                          style: const TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                        Icon(
                          _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          size: 16,
                          color: Colors.blue,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            subtitle: Text(
              '发送给 $recipientCount 位用户 • ${widget.formatTime(widget.item['timestamp'])}',
              style: const TextStyle(fontSize: 12),
            ),
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.blue.shade100)),
              ),
              child: Column(
                children: recipients.map((partnerItem) {
                  int partnerId;
                  if (partnerItem is int) {
                    partnerId = partnerItem;
                  } else if (partnerItem is Map) {
                    partnerId = partnerItem['id'] as int? ?? 0;
                  } else {
                    partnerId = int.tryParse(partnerItem.toString()) ?? 0;
                  }
                  
                  if (partnerId == 0) return const SizedBox.shrink();

                  return FutureBuilder<Map<String, dynamic>?>(
                    future: _getUserInfo(partnerId, Provider.of<AuthProvider>(context, listen: false).user?.id ?? 0),
                    builder: (context, snapshot) {
                      String name = '用户 $partnerId';
                      String avatar = '';
                      if (snapshot.hasData && snapshot.data != null) {
                        name = snapshot.data!['nickname'] ?? name;
                        avatar = snapshot.data!['avatar'] ?? '';
                      }
                      return ListTile(
                        dense: true,
                        leading: (avatar.isNotEmpty)
                            ? CircleAvatar(
                                radius: 16,
                                backgroundImage: CachedNetworkImageProvider(
                                  avatar.startsWith('http')
                                      ? avatar
                                      : 'http://8.136.205.255:8000$avatar',
                                ),
                              )
                            : CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.blue.shade100,
                                child: Text(
                                  name.substring(0, 1),
                                  style: const TextStyle(color: Colors.blue, fontSize: 12),
                                ),
                              ),
                        title: Text(name, style: const TextStyle(fontSize: 14)),
                        trailing: const Icon(Icons.chat, size: 16, color: Colors.blueGrey),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatPage(
                                title: name,
                                avatar: avatar,
                                partnerId: partnerId,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                }).toList(),
              ),
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }
}
