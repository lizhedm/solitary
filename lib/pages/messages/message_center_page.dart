import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:solitary/providers/auth_provider.dart';
import 'package:solitary/providers/message_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
     // Placeholder for now, could integrate with Feedback API later
     return const Center(child: Text('暂无路况反馈'));
  }
}
