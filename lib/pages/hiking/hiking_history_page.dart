import 'package:flutter/material.dart';
import 'history_messages_page.dart';

class HikingHistoryPage extends StatelessWidget {
  const HikingHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock Data with month grouping
    final history = [
      {
        'month': '2023年10月',
        'items': [
          {
            'id': '1',
            'date': '2023-10-01',
            'duration': '4h 30m',
            'distance': '12.5 km',
            'location': '香山公园',
            'status': 'completed',
          },
        ]
      },
      {
        'month': '2023年9月',
        'items': [
          {
            'id': '2',
            'date': '2023-09-24',
            'duration': '2h 15m',
            'distance': '5.2 km',
            'location': '奥林匹克森林公园',
            'status': 'completed',
          },
          {
            'id': '3',
            'date': '2023-09-10',
            'duration': '0h 45m',
            'distance': '2.0 km',
            'location': '朝阳公园',
            'status': 'aborted',
          },
        ]
      }
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('徒步历史'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Summary Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SummaryItem(label: '本月徒步', value: '1次', color: Colors.white),
                _SummaryItem(label: '本月距离', value: '12.5km', color: Colors.white),
                _SummaryItem(label: '累计次数', value: '3次', color: Colors.white),
              ],
            ),
          ),
          
          Expanded(
            child: ListView.builder(
              itemCount: history.length,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemBuilder: (context, index) {
                final group = history[index];
                final month = group['month'] as String;
                final items = group['items'] as List<Map<String, Object>>;
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(month, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    ),
                    ...items.map((item) {
                      final isCompleted = item['status'] == 'completed';
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => HistoryDetailPage(historyId: item['id'] as String),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      item['date'] as String,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isCompleted ? Colors.green.shade100 : Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isCompleted ? '已完成' : '未完成',
                                        style: TextStyle(
                                          color: isCompleted ? Colors.green.shade800 : Colors.orange.shade800,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(item['location'] as String, style: const TextStyle(color: Colors.grey)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildStatItem(Icons.timer, item['duration'] as String, '时长'),
                                    _buildStatItem(Icons.directions_walk, item['distance'] as String, '距离'),
                                    _buildStatItem(Icons.local_fire_department, '350 kcal', '消耗'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF2E7D32)),
            const SizedBox(width: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8))),
      ],
    );
  }
}

class HistoryDetailPage extends StatelessWidget {
  final String historyId;

  const HistoryDetailPage({super.key, required this.historyId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('徒步详情'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.grey[200],
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('轨迹地图回放', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '徒步详情',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '已完成',
                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildDetailRow(Icons.calendar_today, '日期', '2023-10-01'),
                    const SizedBox(height: 16),
                    _buildDetailRow(Icons.timer, '总时长', '4h 30m'),
                    const SizedBox(height: 16),
                    _buildDetailRow(Icons.directions_walk, '总距离', '12.5 km'),
                    const SizedBox(height: 16),
                    _buildDetailRow(Icons.terrain, '海拔爬升', '450 m'),
                    const SizedBox(height: 16),
                    _buildDetailRow(Icons.local_fire_department, '消耗热量', '350 kcal'),
                    
                    const SizedBox(height: 24),
                    const Divider(),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.forum, color: Colors.blue),
                      ),
                      title: const Text('查看临时会话'),
                      subtitle: const Text('5 条消息 · 3 人参与'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const HistoryMessagesPage()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF2E7D32), size: 24),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ],
    );
  }
}
