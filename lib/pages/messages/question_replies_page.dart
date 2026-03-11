import 'package:flutter/material.dart';
import 'package:solitary/services/database_helper.dart';
import 'package:solitary/services/api_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'chat_page.dart';

class QuestionRepliesPage extends StatefulWidget {
  final String question;
  final int recipientCount;
  final List<int> recipientIds;

  const QuestionRepliesPage({
    super.key, 
    required this.question,
    required this.recipientCount,
    required this.recipientIds,
  });

  @override
  State<QuestionRepliesPage> createState() => _QuestionRepliesPageState();
}

class _QuestionRepliesPageState extends State<QuestionRepliesPage> {
  List<Map<String, dynamic>> _recipients = [];

  @override
  void initState() {
    super.initState();
    _loadRecipients();
  }

  Future<void> _loadRecipients() async {
    // For each recipient, check if we have contact info and last message
    final List<Map<String, dynamic>> loaded = [];
    
    for (var userId in widget.recipientIds) {
      // 1. Get User Info (Try contact first, or placeholder)
      var user = await DatabaseHelper().getContact(userId);
      String name = user?['nickname'] ?? '用户 $userId';
      String avatar = user?['avatar'] ?? '';
      
      // If not found locally, fetch from API
      if (user == null) {
        try {
          final response = await ApiService().get('/users/$userId');
          if (response.statusCode == 200 && response.data != null) {
            final u = response.data;
            name = u['nickname'] ?? '用户 $userId';
            avatar = u['avatar'] ?? '';
          }
        } catch (e) {
          // Ignore
        }
      }
      
      loaded.add({
        'id': userId,
        'name': name,
        'avatar': avatar,
        'status': '已发送', // Default
        'lastMsg': '',
        'time': '',
      });
    }
    
    if (mounted) {
      setState(() {
        _recipients = loaded;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                Text(widget.question, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('已发送给 ${widget.recipientCount} 位附近用户', style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          
          Expanded(
            child: ListView.builder(
              itemCount: _recipients.length,
              itemBuilder: (context, index) {
                final user = _recipients[index];
                final hasReply = user['lastMsg'].toString().isNotEmpty;
                final avatar = user['avatar'] as String;
                final name = user['name'] as String;
                
                return ListTile(
                  leading: (avatar.isNotEmpty)
                      ? CircleAvatar(
                          backgroundImage: CachedNetworkImageProvider(
                            avatar.startsWith('http') 
                              ? avatar 
                              : 'http://8.136.205.255:8000$avatar'
                          ),
                        )
                      : CircleAvatar(
                          backgroundColor: hasReply ? Colors.green.shade100 : Colors.grey.shade200,
                          child: Text(name.substring(0, 1), 
                            style: TextStyle(color: hasReply ? Colors.green : Colors.grey)
                          ),
                        ),
                  title: Text(name),
                  subtitle: Text(
                    hasReply ? user['lastMsg'] as String : '等待回复...',
                    style: TextStyle(
                      color: hasReply ? Colors.black87 : Colors.grey,
                      fontStyle: hasReply ? FontStyle.normal : FontStyle.italic,
                    ),
                  ),
                  trailing: const Icon(Icons.chat_bubble_outline, color: Colors.blue),
                  onTap: () {
                    // Go to chat with this specific user
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatPage(
                          title: name,
                          avatar: avatar,
                          partnerId: user['id'] as int,
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
