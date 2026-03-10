import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:solitary/providers/auth_provider.dart';
import 'package:solitary/services/database_helper.dart';
import '../messages/chat_page.dart';

class HistoryMessagesPage extends StatefulWidget {
  final int hikeId;
  const HistoryMessagesPage({super.key, required this.hikeId});

  @override
  State<HistoryMessagesPage> createState() => _HistoryMessagesPageState();
}

class _HistoryMessagesPageState extends State<HistoryMessagesPage> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?.id ?? 0;

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
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadHistoryParticipants(currentUserId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final participants = snapshot.data!;
                if (participants.isEmpty) {
                  return const Center(child: Text('本次徒步没有临时会话'));
                }

                return ListView.builder(
                  itemCount: participants.length,
                  itemBuilder: (context, index) {
                    final p = participants[index];
                    return ListTile(
                      leading: CircleAvatar(child: Text((p['name'] as String).substring(0, 1))),
                      title: Text(p['name'] as String),
                      subtitle: Text('${p['msgCount']} 条对话'),
                      onTap: () {
                        // Navigate to ChatPage to view messages
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatPage(
                              title: p['name'] as String,
                              avatar: p['avatar'] as String?,
                              partnerId: p['id'] as int,
                              hikeId: widget.hikeId, // Pass hikeId to show only hike messages
                            ),
                          ),
                        );
                      },
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

  Future<List<Map<String, dynamic>>> _loadHistoryParticipants(int currentUserId) async {
    final messages = await DatabaseHelper().getMessagesByHikeId(widget.hikeId);
    final Map<int, int> msgCounts = {};
    
    // Group by partner
    for (var msg in messages) {
      final senderId = msg['sender_id'] as int;
      final receiverId = msg['receiver_id'] as int;
      final partnerId = (senderId == currentUserId) ? receiverId : senderId;
      
      msgCounts[partnerId] = (msgCounts[partnerId] ?? 0) + 1;
    }
    
    // Fetch partner info
    final List<Map<String, dynamic>> participants = [];
    for (var partnerId in msgCounts.keys) {
      final contact = await DatabaseHelper().getContact(partnerId);
      participants.add({
        'id': partnerId,
        'name': contact?['nickname'] ?? '用户 $partnerId',
        'avatar': contact?['avatar'],
        'msgCount': msgCounts[partnerId],
        'snapStatus': 'NONE' // Could be fetched if needed
      });
    }
    
    return participants;
  }
}
