import 'package:flutter/material.dart';

class UserGuidePage extends StatelessWidget {
  const UserGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('使用指南')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _GuideCard(
            title: '开始徒步',
            content: '点击主页底部的“开始徒步”按钮，系统将自动记录您的轨迹。长按暂停按钮可以暂停记录。',
            icon: Icons.directions_walk,
          ),
          SizedBox(height: 16),
          _GuideCard(
            title: '一键求救',
            content: '遇到危险时，长按地图页面的SOS红色按钮3秒，即可向周围发送求救信号。',
            icon: Icons.sos,
            color: Colors.red,
          ),
        ],
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  final String title;
  final String content;
  final IconData icon;
  final Color color;

  const _GuideCard({
    required this.title,
    required this.content,
    required this.icon,
    this.color = Colors.green,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(content),
          ],
        ),
      ),
    );
  }
}
