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
          _buildTemporaryList(),
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
                        partnerId: contact.id, // Need to update ChatPage to accept ID
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
              final Map<int, Map<String, dynamic>> incomingMap = {}; // Grouped by partnerId
              
              for (var msg in allMessages) {
                final type = msg['type'] as String? ?? 'text';
                final senderId = msg['sender_id'] as int;
                final receiverId = msg['receiver_id'] as int;
                final hikeId = msg['hike_id'] as int?;
                
                // 1. My Questions (Sent by me, type=question, not in hike)
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
                   // Logic: Keep latest message per partner
                   if (incomingMap.containsKey(partnerId)) {
                      final existingTime = (incomingMap[partnerId]!['msg'] as Map)['timestamp'] as int;
                      if ((msg['timestamp'] as int) < existingTime) continue;
                   }
                   incomingMap[partnerId] = {
                     'msg': msg,
                     'type': 'question',
                     'partner_id': partnerId
                   };
                   continue;
                }
                
                // 3. SOS Messages (Sent OR Received, type=sos, IGNORE hike_id)
                if (type == 'sos') {
                   final partnerId = (senderId == currentUserId) ? receiverId : senderId;
                   
                   // Logic: Keep latest message per partner (SOS overrides others if newer)
                   if (incomingMap.containsKey(partnerId)) {
                      final existingTime = (incomingMap[partnerId]!['msg'] as Map)['timestamp'] as int;
                      if ((msg['timestamp'] as int) < existingTime) continue;
                   }
                   incomingMap[partnerId] = {
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
