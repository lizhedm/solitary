import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:solitary/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:solitary/providers/auth_provider.dart';
import 'package:solitary/services/database_helper.dart';
import '../messages/chat_page.dart';

class HistoryMessagesPage extends StatefulWidget {
  final int hikeId;
  final DateTime startTime;
  final DateTime endTime;
  
  const HistoryMessagesPage({
    super.key, 
    required this.hikeId, 
    required this.startTime, 
    required this.endTime
  });

  @override
  State<HistoryMessagesPage> createState() => _HistoryMessagesPageState();
}

class _HistoryMessagesPageState extends State<HistoryMessagesPage> {
  Future<List<Map<String, dynamic>>>? _participantsFuture;
  List<Map<String, dynamic>>? _participants;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUserId = authProvider.user?.id ?? 0;
      setState(() {
        _participantsFuture = _loadHistoryParticipants(currentUserId);
      });
    });
  }
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
              future: _participantsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(child: Text('加载失败: ${snapshot.error}'));
                }

                _participants = snapshot.data;
                final participants = _participants!;
                if (participants.isEmpty) {
                  return const Center(child: Text('本次徒步没有临时会话'));
                }

                return ListView.builder(
                  itemCount: participants.length,
                  itemBuilder: (context, index) {
                    final p = participants[index];
                    final avatarUrl = p['avatar'] as String?;
                    final name = p['name'] as String;
                    
                    return ListTile(
                      leading: (avatarUrl != null && avatarUrl.isNotEmpty)
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
                              child: Text(name.substring(0, 1).toUpperCase()),
                            ),
                      title: Text(name),
                      subtitle: Text('${p['msgCount']} 条对话'),
                      trailing: _buildSnapButton(p),
                      onTap: () {
                        // Navigate to ChatPage to view messages
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatPage(
                              title: p['name'] as String,
                              avatar: p['avatar'] as String?,
                              partnerId: p['id'] as int,
                              hikeId: widget.hikeId, 
                              startTime: widget.startTime,
                              endTime: widget.endTime,
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

  Widget _buildSnapButton(Map<String, dynamic> p) {
    final status = p['snapStatus'] as String;
    
    if (status == 'FRIENDS' || status == 'MATCHED') {
      return const Text('已成为好友', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold));
    }
    
    if (status == 'SNAPPED') {
      return TextButton(
        onPressed: null,
        child: Text('等待对方', style: TextStyle(color: Colors.grey.shade400)),
      );
    }

    return ElevatedButton(
      onPressed: () => _handleSnap(p),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange.shade400,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(60, 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: const Text('合拍', style: TextStyle(fontSize: 12)),
    );
  }

  Future<void> _handleSnap(Map<String, dynamic> p) async {
    try {
      final response = await ApiService().post('/friends/snap/${p['id']}');
      if (response.statusCode == 200 && response.data != null) {
        final newStatus = response.data['status'] as String;
        setState(() {
          p['snapStatus'] = newStatus;
        });
        
        if (newStatus == 'MATCHED') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已成为好友！可以在消息中心聊天。')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已发送合拍请求')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败: $e')),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _loadHistoryParticipants(int currentUserId) async {
    // Priority 1: Query by our specific hikeId using the new logic
    List<Map<String, dynamic>> messages = await DatabaseHelper().getMessagesByHikeId(widget.hikeId, currentUserId);
    
    // Priority 2: If no messages associated yet, fallback to time range
    if (messages.isEmpty) {
      final startTs = widget.startTime.millisecondsSinceEpoch;
      final endTs = widget.endTime.millisecondsSinceEpoch;
      messages = await DatabaseHelper().getMessagesByTimeRange(startTs, endTs);
    }
    
    final Map<int, int> msgCounts = {};
    
    // Group by partner（排除虚拟用户0：用于广播/SOS，不作为单独对话方展示）
    for (var msg in messages) {
      final senderId = msg['sender_id'] as int;
      final receiverId = msg['receiver_id'] as int;
      final partnerId = (senderId == currentUserId) ? receiverId : senderId;
      if (partnerId == 0) continue;
      msgCounts[partnerId] = (msgCounts[partnerId] ?? 0) + 1;
    }
    
    // Fetch partner info
    final List<Map<String, dynamic>> participants = [];
    for (var partnerId in msgCounts.keys) {
      // 1. Try local contacts
      var contact = await DatabaseHelper().getContact(partnerId, ownerId: currentUserId);
      String name = contact?['nickname'] ?? '用户 $partnerId';
      String? avatar = contact?['avatar'];
      
      // 2. If not found, try API
      if (contact == null) {
        try {
          final response = await ApiService().get('/users/$partnerId');
          if (response.statusCode == 200 && response.data != null) {
            name = response.data['nickname'] ?? '用户 $partnerId';
            avatar = response.data['avatar'];
          }
        } catch (e) {
          debugPrint('Fetch user info failed: $e');
        }
      }

      // 3. Get Snap Status
      String snapStatus = 'NONE';
      try {
        final statusResp = await ApiService().get('/friends/snap/status/$partnerId');
        if (statusResp.statusCode == 200 && statusResp.data != null) {
          snapStatus = statusResp.data['status'] as String;
        }
      } catch (e) {
        debugPrint('Fetch snap status failed: $e');
      }

      participants.add({
        'id': partnerId,
        'name': name,
        'avatar': avatar,
        'msgCount': msgCounts[partnerId],
        'snapStatus': snapStatus 
      });
    }
    
    return participants;
  }
}
