import 'package:flutter/material.dart';
import '../messages/chat_page.dart';

class HistoryMessagesPage extends StatelessWidget {
  const HistoryMessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock Data
    final participants = [
      {'id': '1', 'name': '山野行者', 'msgCount': 3, 'avatar': 'S', 'snapStatus': 'NONE'},
      {'id': '2', 'name': '路人A', 'msgCount': 2, 'avatar': 'A', 'snapStatus': 'PENDING'},
      {'id': '3', 'name': 'Lisa', 'msgCount': 5, 'avatar': 'L', 'snapStatus': 'MUTUAL'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('历史消息'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.orange.withOpacity(0.1),
            child: const Row(
              children: [
                Icon(Icons.history, color: Colors.orange),
                SizedBox(width: 8),
                Text('历史消息，无法继续发送', style: TextStyle(color: Colors.orange)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: participants.length,
              itemBuilder: (context, index) {
                final p = participants[index];
                return ListTile(
                  leading: CircleAvatar(child: Text(p['avatar'] as String)),
                  title: Text(p['name'] as String),
                  subtitle: Text('${p['msgCount']} 条对话'),
                  trailing: _buildSnapButton(context, p),
                  onTap: () {
                    // Navigate to ChatPage to view messages
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatPage(
                          title: p['name'] as String,
                          avatar: p['avatar'] as String,
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

  Widget _buildSnapButton(BuildContext context, Map<String, Object> participant) {
    final status = participant['snapStatus'] as String;
    
    if (status == 'MUTUAL') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 16, color: Colors.green),
            SizedBox(width: 4),
            Text('好友', style: TextStyle(color: Colors.green, fontSize: 12)),
          ],
        ),
      );
    } else if (status == 'PENDING') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.access_time, size: 16, color: Colors.orange),
            SizedBox(width: 4),
            Text('等待', style: TextStyle(color: Colors.orange, fontSize: 12)),
          ],
        ),
      );
    } else {
      return ElevatedButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已发送合拍请求')),
          );
        },
        icon: const Icon(Icons.thumb_up, size: 16),
        label: const Text('合拍'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }
  }
}
