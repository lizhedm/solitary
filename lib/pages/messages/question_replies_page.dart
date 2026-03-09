import 'package:flutter/material.dart';
import 'chat_page.dart';

class QuestionRepliesPage extends StatelessWidget {
  final String question;
  final int recipientCount;

  const QuestionRepliesPage({
    super.key, 
    required this.question,
    required this.recipientCount,
  });

  @override
  Widget build(BuildContext context) {
    // Mock Data for recipients
    final recipients = List.generate(
      recipientCount,
      (index) => {
        'name': '用户 ${index + 1}',
        'status': index % 3 == 0 ? '已回复' : '未读',
        'lastMsg': index % 3 == 0 ? '前面大概500米有水源。' : '',
        'time': '5分钟前',
        'avatar': 'U${index + 1}',
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('提问详情'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Question Summary
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.withOpacity(0.05),
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('我的提问:', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(question, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('已发送给 $recipientCount 位附近用户', style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          
          Expanded(
            child: ListView.builder(
              itemCount: recipients.length,
              itemBuilder: (context, index) {
                final user = recipients[index];
                final hasReply = user['status'] == '已回复';
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: hasReply ? Colors.green.shade100 : Colors.grey.shade200,
                    child: Text(user['avatar'] as String, 
                      style: TextStyle(color: hasReply ? Colors.green.shade800 : Colors.grey),
                    ),
                  ),
                  title: Text(user['name'] as String),
                  subtitle: Text(
                    hasReply ? user['lastMsg'] as String : '等待回复...',
                    style: TextStyle(
                      color: hasReply ? Colors.black87 : Colors.grey,
                      fontStyle: hasReply ? FontStyle.normal : FontStyle.italic,
                    ),
                  ),
                  trailing: hasReply 
                      ? const Icon(Icons.mark_chat_unread, color: Colors.green, size: 20)
                      : const SizedBox(),
                  onTap: () {
                    // Go to chat with this specific user
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatPage(
                          title: user['name'] as String,
                          avatar: user['avatar'] as String,
                          partnerId: 0, // Placeholder
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
