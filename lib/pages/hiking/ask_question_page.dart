import 'package:flutter/material.dart';

class AskQuestionPage extends StatefulWidget {
  const AskQuestionPage({super.key});

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
                        '将发送给周围 8 位开启接收问题的用户',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '仅路线相似度大于60%的用户可见',
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
                onPressed: _questionController.text.trim().isEmpty
                    ? null
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('问题已发送')),
                        );
                        Navigator.pop(context);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('发送'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
