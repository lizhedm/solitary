import 'package:flutter/material.dart';
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
  }

  @override
  void dispose() {
    _tabController.dispose();
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
    // Mock Data
    final friends = [
      {'name': '山野行者', 'msg': '下次一起去香山吗？', 'time': '10:30', 'avatar': 'S'},
      {'name': 'Lisa', 'msg': '照片发给你了', 'time': '昨天', 'avatar': 'L'},
    ];

    return ListView.builder(
      itemCount: friends.length,
      itemBuilder: (context, index) {
        final friend = friends[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.grey[200],
            child: Text(friend['avatar']!),
          ),
          title: Text(friend['name']!),
          subtitle: Text(friend['msg']!),
          trailing: Text(friend['time']!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatPage(
                  title: friend['name']!,
                  avatar: friend['avatar'],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTemporaryList() {
    // Mock Data for mixed list
    // Type 1: Direct Message (dm)
    // Type 2: Question Broadcast (question)
    final items = [
      {
        'type': 'dm',
        'name': '路人A', 
        'msg': '前面路况怎么样？', 
        'time': '刚刚', 
        'avatar': 'A', 
        'distance': '500m'
      },
      {
        'type': 'question',
        'content': '请问前方有水源吗？', 
        'recipientCount': 8,
        'replyCount': 3,
        'time': '10分钟前',
      },
      {
        'type': 'dm',
        'name': '路人B', 
        'msg': '我也在往山顶走。', 
        'time': '15分钟前', 
        'avatar': 'B', 
        'distance': '200m'
      },
    ];

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final item = items[index];
        final type = item['type'];

        if (type == 'dm') {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange.shade100,
              child: Text(item['avatar'] as String, style: TextStyle(color: Colors.orange.shade800)),
            ),
            title: Row(
              children: [
                Expanded(child: Text(item['name'] as String, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(4)),
                  child: Text(item['distance'] as String, style: const TextStyle(fontSize: 10, color: Colors.deepOrange)),
                ),
              ],
            ),
            subtitle: Text(item['msg'] as String, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Text(item['time'] as String, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            onTap: () {
               // Type 1 -> ChatPage
               Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatPage(
                    title: item['name'] as String,
                    avatar: item['avatar'] as String,
                  ),
                ),
              );
            },
          );
        } else {
          // Type 2: Question Broadcast
          return ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.help_outline, color: Colors.blue.shade700, size: 20),
            ),
            title: Text(
              '我的提问: ${item['content']}', 
              style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '发送给 ${item['recipientCount']} 人 · ${item['replyCount']} 条回复',
              style: const TextStyle(color: Colors.grey),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () {
              // Type 2 -> QuestionRepliesPage
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => QuestionRepliesPage(
                    question: item['content'] as String,
                    recipientCount: item['recipientCount'] as int,
                  ),
                ),
              );
            },
          );
        }
      },
    );
  }

  Widget _buildMyFeedbacksList() {
    final feedbacks = [
      {'type': 'blocked', 'content': '前方道路塌方，无法通行', 'time': '1小时前', 'status': '生效中', 'view': 120, 'confirm': 15},
      {'type': 'weather', 'content': '山顶开始下雨了', 'time': '2小时前', 'status': '已过期', 'view': 45, 'confirm': 2},
    ];

    return ListView.builder(
      itemCount: feedbacks.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final item = feedbacks[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
               // Navigate to Detail Page instead of Chat
               Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RouteFeedbackDetailPage(feedback: item),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (item['type'] == 'blocked' ? Colors.red : Colors.blue).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item['type'] == 'blocked' ? '道路阻断' : '天气提醒',
                          style: TextStyle(
                            color: item['type'] == 'blocked' ? Colors.red : Colors.blue,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(item['time'] as String, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(item['content'] as String, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.remove_red_eye, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('${item['view']}', style: const TextStyle(color: Colors.grey)),
                      const SizedBox(width: 16),
                      const Icon(Icons.thumb_up, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('${item['confirm']}', style: const TextStyle(color: Colors.grey)),
                      const Spacer(),
                      if (item['status'] == '生效中')
                        TextButton(
                          onPressed: () {
                            // Revoke logic
                          },
                          child: const Text('撤销', style: TextStyle(color: Colors.red)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
