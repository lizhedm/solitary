import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:solitary/providers/auth_provider.dart';
import 'package:solitary/services/api_service.dart';
import 'package:solitary/services/database_helper.dart';

class AskQuestionPage extends StatefulWidget {
  final double? latitude;
  final double? longitude;

  const AskQuestionPage({super.key, this.latitude, this.longitude});

  @override
  State<AskQuestionPage> createState() => _AskQuestionPageState();
}

class _AskQuestionPageState extends State<AskQuestionPage> {
  final TextEditingController _questionController = TextEditingController();
  final List<String> _quickQuestions = [
    '前方路况如何？',
    '还有多久到山顶？',
    '前方有水源吗？',
    '推荐在哪里露营？',
    '下山的路好走吗？',
  ];
  bool _hasReward = false;
  bool _isSending = false;

  Future<void> _sendQuestion() async {
    final content = _questionController.text.trim();
    if (content.isEmpty) return;
    
    // Check location
    if (widget.latitude == null || widget.longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法获取当前位置，无法发送提问')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.id;
      if (userId == null) throw Exception('User not logged in');

      // 1. Call Backend API
      final response = await ApiService().post('/messages/ask', data: {
        'content': content,
        'latitude': widget.latitude,
        'longitude': widget.longitude,
      });

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final messages = data['question_messages'] as List;
        final count = data['recipient_count'] as int;

        // 2. Save Messages to Local DB
        for (var msg in messages) {
           final messageMap = {
             'remote_id': msg['id'],
             'sender_id': userId,
             'receiver_id': msg['receiver_id'],
             'content': content,
             'type': 'question',
             'timestamp': msg['timestamp'],
             'is_read': 1, // Read by self
             'sync_status': 0 // Synced
           };
           await DatabaseHelper().saveMessage(messageMap);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('问题已发送给 $count 位徒步者')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('Send question failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('向周围人提问'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Recipients Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.people_outline, color: Colors.blue, size: 32),
                      const SizedBox(height: 8),
                      const Text(
                        '将发送给周围 3~8 位相关用户',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '优先发送给10公里内最近的活跃用户',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Quick Questions
                const Text('快捷问题', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ..._quickQuestions.map((q) => ListTile(
                  title: Text(q),
                  trailing: const Icon(Icons.chevron_right),
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    setState(() {
                      _questionController.text = q;
                    });
                  },
                )),
                const Divider(),
                const SizedBox(height: 16),

                // Custom Input
                const Text('自定义问题', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: _questionController,
                  maxLength: 50,
                  decoration: const InputDecoration(
                    hintText: '输入您的问题...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Reward Toggle
                Row(
                  children: [
                    Switch(
                      value: _hasReward,
                      onChanged: (value) => setState(() => _hasReward = value),
                      activeColor: const Color(0xFF2E7D32),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('添加感谢标记（对方回复后可发送感谢）'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Send Button
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_questionController.text.trim().isEmpty || _isSending)
                    ? null
                    : _sendQuestion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSending
                    ? const SizedBox(
                        width: 20, 
                        height: 20, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      )
                    : const Text('发送'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
