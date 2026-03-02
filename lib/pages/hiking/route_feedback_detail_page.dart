import 'package:flutter/material.dart';

class RouteFeedbackDetailPage extends StatelessWidget {
  final Map<String, dynamic> feedback;

  const RouteFeedbackDetailPage({super.key, required this.feedback});

  @override
  Widget build(BuildContext context) {
    final isBlocked = feedback['type'] == 'blocked';
    final color = isBlocked ? Colors.red : Colors.blue;

    return Scaffold(
      appBar: AppBar(
        title: const Text('路况详情'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map Placeholder
            Container(
              height: 200,
              color: Colors.grey[200],
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_on, size: 48, color: color),
                    const SizedBox(height: 8),
                    Text('位置地图', style: TextStyle(color: color)),
                  ],
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Tag
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isBlocked ? '道路阻断' : '天气提醒',
                          style: TextStyle(color: color, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        feedback['time'] as String,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Content
                  Text(
                    feedback['content'] as String,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  
                  // Stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStat(Icons.remove_red_eye, '${feedback['view']}', '浏览'),
                      _buildStat(Icons.thumb_up, '${feedback['confirm']}', '确认'),
                      _buildStat(Icons.comment, '5', '评论'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  // Comments Section (Mock)
                  const Text('评论 (5)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildComment('山野行者', '确实很难走，建议绕行。', '10分钟前'),
                  _buildComment('Lisa', '收到，谢谢提醒！', '30分钟前'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildComment(String user, String content, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Colors.grey[200],
            child: Text(user[0]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(user, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(content),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
