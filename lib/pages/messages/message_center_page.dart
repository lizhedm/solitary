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
    
    // Start polling when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final msgProvider = Provider.of<MessageProvider>(context, listen: false);
      if (authProvider.user != null) {
        msgProvider.startPolling(authProvider.user!.id);
      }
    });
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

  Widget _buildFriendsList() {
    return Consumer<MessageProvider>(
      builder: (context, provider, child) {
        if (provider.contacts.isEmpty) {
           return const Center(child: Text('暂无好友消息'));
        }
        
        return ListView.builder(
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
                            : 'http://114.55.148.245:8000$avatarUrl',
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
        );
      },
    );
  }
  
  String _formatTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return '${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}';
    }
    return '${date.month}/${date.day}';
  }

  Widget _buildTemporaryList() {
    return const Center(child: Text('暂无临时会话'));
  }

  Widget _buildMyFeedbacksList() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.id;
    
    if (userId == null) {
      return const Center(child: Text('请先登录'));
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper().getFeedbacks(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('加载失败: ${snapshot.error}'));
        }
        
        final feedbacks = snapshot.data ?? [];
        if (feedbacks.isEmpty) {
          return const Center(child: Text('暂无路况反馈'));
        }
        
        return ListView.builder(
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

            return Card(
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
                              url = 'http://114.55.148.245:8000$url';
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
            );
          },
        );
      },
    );
  }
}
