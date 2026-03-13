import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:solitary/providers/auth_provider.dart';
import 'package:solitary/providers/message_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import '../../services/database_helper.dart';
import 'chat_page.dart';
import 'question_replies_page.dart';
import '../hiking/route_feedback_detail_page.dart';
import 'sos_event_detail_page.dart';

import 'package:solitary/services/api_service.dart';

class MessageCenterPage extends StatefulWidget {
  const MessageCenterPage({super.key});

  @override
  State<MessageCenterPage> createState() => _MessageCenterPageState();
}

class _MessageCenterPageState extends State<MessageCenterPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
    _tabController.dispose();
    // Don't stop polling here if we want background updates, 
    // but for now, let's keep it bound to the provider's lifecycle or page
    // Actually MessageProvider is global, so maybe don't stop?
    // But to save resources when leaving tab... let's keep polling active for now.
    super.dispose();
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
                subtitle: Text(
                  contact.lastMessage ?? '暂无消息', 
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis
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
                   var contact = await DatabaseHelper().getContact(partnerId);
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
                      content = partnerId == 0 ? '[SOS求救] 我已发出求救广播' : '[SOS求救] 我向他发出了求救';
                    } else {
                      content = '[SOS求救] 收到他的求救信号';
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
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => QuestionRepliesPage(
                              question: item['content'],
                              recipientCount: recipientCount,
                              recipientIds: (item['recipients'] as List).cast<int>(),
                            ),
                          ),
                        );
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
        setState(() {});
      },
      child: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
        future: DatabaseHelper().database.then((db) async {
              debugPrint('Fetching all messages for temporary session list (v2)...');

              // 这里不再强制依赖「正在进行中的徒步记录」，而是直接读取当前用户的所有相关临时消息。
              // 这样即使本次徒步已结束或本地记录异常，临时会话中的“提问 / SOS”也能正常展示。
              final startMs = 0;
              final endMs = DateTime.now().millisecondsSinceEpoch;

              var allMessages = await db.query(
                'messages',
                where: '(sender_id = ? OR receiver_id = ?) AND timestamp >= ? AND timestamp <= ?',
                whereArgs: [currentUserId, currentUserId, startMs, endMs],
                orderBy: 'timestamp DESC',
              );

              // 如果本地没有同步到 messages（常见：刚装机/刚登录/轮询未触发），这里兜底从服务端拉一次再写入本地。
              if (allMessages.isEmpty) {
                try {
                  final resp = await ApiService().get('/messages');
                  if (resp.statusCode == 200 && resp.data is List) {
                    for (final item in (resp.data as List)) {
                      if (item is! Map) continue;
                      final m = Map<String, dynamic>.from(item);
                      // 映射到本地 messages 表结构
                      m['remote_id'] = m['id'];
                      m.remove('id');
                      m['sync_status'] = 0;
                      // 兼容 is_read bool/int
                      if (m['is_read'] is bool) {
                        m['is_read'] = (m['is_read'] == true) ? 1 : 0;
                      }
                      await DatabaseHelper().saveMessage(m);
                    }
                  }
                } catch (e) {
                  debugPrint('Temp list fallback sync /messages failed: $e');
                }

                // 重新读取本地
                allMessages = await db.query(
                  'messages',
                  where: '(sender_id = ? OR receiver_id = ?) AND timestamp >= ? AND timestamp <= ?',
                  whereArgs: [currentUserId, currentUserId, startMs, endMs],
                  orderBy: 'timestamp DESC',
                );
              }

              // 四大类容器
              final Map<String, Map<String, dynamic>> myQuestionsMap = {};
              final Map<String, Map<String, dynamic>> incomingQuestionsMap = {};
              final Map<String, Map<String, dynamic>> incomingSosMap = {};

              for (var msg in allMessages) {
                final type = msg['type'] as String? ?? 'text';
                final senderId = msg['sender_id'] as int;
                final receiverId = msg['receiver_id'] as int;
                final hikeId = msg['hike_id'] as int?;
                final timestamp = msg['timestamp'] as int;

                // --- 提问类 ---
                if (type == 'question' && (hikeId == null || hikeId == 0)) {
                  final content = msg['content'] as String;

                  // 1. 我的提问：我作为发送方
                  if (senderId == currentUserId) {
                    if (!myQuestionsMap.containsKey(content)) {
                      myQuestionsMap[content] = {
                        'content': content,
                        'timestamp': timestamp,
                        'recipients': <int>[],
                      };
                    }
                    final recipients =
                        myQuestionsMap[content]!['recipients'] as List<int>;
                    if (!recipients.contains(receiverId)) {
                      recipients.add(receiverId);
                    }
                  }
                  // 2. 向我提问：我作为接收方
                  else if (receiverId == currentUserId) {
                    final partnerId = senderId;
                    final key = 'question_incoming_${partnerId}_$content';

                    if (incomingQuestionsMap.containsKey(key)) {
                      final existingTime =
                          (incomingQuestionsMap[key]!['msg'] as Map)['timestamp']
                              as int;
                      if (timestamp <= existingTime) continue;
                    }
                    incomingQuestionsMap[key] = {
                      'msg': msg,
                      'partner_id': partnerId,
                    };
                  }
                  continue;
                }

                // --- 求救类（不限定 hike）---
                // “我的求救”不再从 messages 里的广播/单条消息推导，而是从本地 sos_events 表读取（折叠成一次事件）。
                // 这里仅保留“向我求救”的聚合。
                if (type == 'sos' && receiverId == currentUserId) {
                  final partnerId = senderId;
                  final remoteId = msg['remote_id'];
                  final baseKey = remoteId != null
                      ? remoteId.toString()
                      : '${partnerId}_$timestamp';
                  final key = 'sos_incoming_$baseKey';

                  if (incomingSosMap.containsKey(key)) {
                    final existingTime =
                        (incomingSosMap[key]!['msg'] as Map)['timestamp'] as int;
                    if (timestamp <= existingTime) continue;
                  }

                  incomingSosMap[key] = {
                    'msg': msg,
                    'partner_id': partnerId,
                  };
                  continue;
                }
              }

              debugPrint(
                  'Temporary sessions grouped (v2): myQuestions=${myQuestionsMap.length}, incomingQuestions=${incomingQuestionsMap.length}, incomingSos=${incomingSosMap.length}');

              // --- 补充联系人信息 & 展示文案 ---
              final List<Map<String, dynamic>> myQuestionList =
                  myQuestionsMap.values.toList();
              myQuestionList.sort((a, b) =>
                  (b['timestamp'] as int).compareTo(a['timestamp'] as int));

              final List<Map<String, dynamic>> incomingQuestionList = [];
              for (var item in incomingQuestionsMap.values) {
                final msg = item['msg'] as Map<String, dynamic>;
                final partnerId = item['partner_id'] as int;

                String name = '用户 $partnerId';
                String avatar = '';

                var contact = await DatabaseHelper().getContact(partnerId);
                if (contact != null) {
                  name = contact['nickname'] ?? name;
                  avatar = contact['avatar'] ?? avatar;
                } else {
                  try {
                    final response =
                        await ApiService().get('/users/$partnerId');
                    if (response.statusCode == 200 &&
                        response.data != null) {
                      final user = response.data;
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
              incomingQuestionList.sort((a, b) =>
                  (b['timestamp'] as int).compareTo(a['timestamp'] as int));

              // 读取“我的求救”事件（一次SOS折叠成一条）
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

                String name =
                    partnerId == 0 ? '所有人 (SOS广播)' : '用户 $partnerId';
                String avatar = '';

                if (partnerId != 0) {
                  var contact = await DatabaseHelper().getContact(partnerId);
                  if (contact != null) {
                    name = contact['nickname'] ?? name;
                    avatar = contact['avatar'] ?? avatar;
                  } else {
                    try {
                      final response =
                          await ApiService().get('/users/$partnerId');
                      if (response.statusCode == 200 &&
                          response.data != null) {
                        final user = response.data;
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
                  'content': '[SOS求救] 收到他的求救信号',
                  'timestamp': msg['timestamp'],
                  'danger_label': dangerLabel,
                  'safety_status': safetyStatus,
                  'urgent_labels': urgentLabels,
                });
              }
              incomingSosList.sort((a, b) =>
                  (b['timestamp'] as int).compareTo(a['timestamp'] as int));

              return {
                'my_questions': myQuestionList,
                'incoming_questions': incomingQuestionList,
                'my_sos': mySosEvents,
                'incoming_sos': incomingSosList,
              };
            }),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('加载失败: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snapshot.data!;
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
                      final recipientCount =
                          (item['recipients'] as List).length;
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        color: Colors.blue.shade50,
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.blue,
                            child: Icon(Icons.help, color: Colors.white),
                          ),
                          title: Text(
                            item['content'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '发送给 $recipientCount 位用户 • ${_formatTime(item['timestamp'])}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => QuestionRepliesPage(
                                  question: item['content'],
                                  recipientCount: recipientCount,
                                  recipientIds:
                                      (item['recipients'] as List).cast<int>(),
                                ),
                              ),
                            );
                          },
                        ),
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
                      String dangerLabel = '未知危险';
                      int safetyStatus = 0;
                      List urgentLabels = [];
                      int createdAt = event['created_at'] as int? ?? 0;
                      int recipientCount = 0;

                      try {
                        final msg = jsonDecode(event['message_json'] ?? '{}');
                        dangerLabel = msg['danger_label'] ?? dangerLabel;
                        safetyStatus = msg['safety_status'] ?? safetyStatus;
                        urgentLabels = (msg['urgent_labels'] as List?) ?? [];
                      } catch (_) {}

                      try {
                        final recipients = jsonDecode(event['recipients_json'] ?? '[]') as List;
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
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: Colors.red.shade200, width: 1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.red.shade100,
                            child: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                          ),
                          title: Text(
                            '已发送给 $recipientCount 位用户',
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
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
                                _miniTag(Icons.access_time, _formatTime(createdAt), Colors.grey),
                              ],
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SOSEventDetailPage(event: Map<String, dynamic>.from(event)),
                              ),
                            );
                          },
                        ),
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
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '来自 $partnerName • ${_formatTime(item['timestamp'])}',
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
        
        if (feedbacks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text(
                  '暂无路况反馈',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '你发布的路况信息会显示在这里。\n在地图页面点击“路况”按钮即可发布。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => provider.fetchMyFeedbacks(userId),
                  child: const Text('刷新'),
                ),
              ],
            ),
          );
        }
        
        return RefreshIndicator(
          onRefresh: () => provider.fetchMyFeedbacks(userId),
          child: ListView.builder(
            itemCount: feedbacks.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final feedback = feedbacks[index];
              final typeMap = {
                'blocked': {'label': '道路阻断', 'color': Colors.red, 'icon': Icons.block},
                'detour': {'label': '建议绕行', 'color': Colors.orange, 'icon': Icons.alt_route},
                'weather': {'label': '天气变化', 'color': Colors.blue, 'icon': Icons.cloud},
                'water': {'label': '水源位置', 'color': Colors.cyan, 'icon': Icons.water_drop},
                'campsite': {'label': '推荐营地', 'color': Colors.green, 'icon': Icons.nights_stay},
                'danger': {'label': '危险区域', 'color': Colors.deepOrange, 'icon': Icons.warning},
                'supply': {'label': '有补给点', 'color': Colors.purple, 'icon': Icons.store},
                'other': {'label': '其他信息', 'color': Colors.grey, 'icon': Icons.more_horiz},
              };
              
              final typeKey = feedback['type'] as String? ?? 'other';
              final typeInfo = typeMap[typeKey] ?? typeMap['other']!;
              final createdTime = DateTime.fromMillisecondsSinceEpoch(feedback['created_at']);
              final dateStr = '${createdTime.year}-${createdTime.month}-${createdTime.day} ${createdTime.hour}:${createdTime.minute}';
              
              List<String> photos = [];
              if (feedback['photos'] != null && feedback['photos'].toString().isNotEmpty) {
                try {
                  photos = List<String>.from(jsonDecode(feedback['photos']));
                } catch (e) {
                  // ignore error
                }
              }

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RouteFeedbackDetailPage(feedback: feedback),
                    ),
                  );
                },
                child: Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              typeInfo['icon'] as IconData,
                              color: typeInfo['color'] as Color,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              typeInfo['label'] as String,
                              style: TextStyle(
                                color: typeInfo['color'] as Color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            if (feedback['sync_status'] == 1)
                              const Row(
                                children: [
                                  SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                                  SizedBox(width: 4),
                                  Text('同步中', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              )
                            else
                               const Icon(Icons.cloud_done, size: 16, color: Colors.green),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          feedback['content'] ?? '',
                          style: const TextStyle(fontSize: 16),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (photos.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 80,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: photos.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (context, pIndex) {
                                String url = photos[pIndex];
                                if (!url.startsWith('http')) {
                                  url = 'http://8.136.205.255:8000$url';
                                }
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: url,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(color: Colors.grey[200]),
                                    errorWidget: (context, url, error) => const Icon(Icons.error),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              dateStr,
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.remove_red_eye, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text('${feedback['view_count']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                const SizedBox(width: 12),
                                const Icon(Icons.thumb_up, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text('${feedback['confirm_count']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
