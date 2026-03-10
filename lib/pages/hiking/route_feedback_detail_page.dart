import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import '../../utils/device_utils.dart';

class RouteFeedbackDetailPage extends StatefulWidget {
  final Map<String, dynamic> feedback;

  const RouteFeedbackDetailPage({super.key, required this.feedback});

  @override
  State<RouteFeedbackDetailPage> createState() => _RouteFeedbackDetailPageState();
}

class _RouteFeedbackDetailPageState extends State<RouteFeedbackDetailPage> {
  bool _isSimulator = false;
  int _currentPhotoIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkDevice();
  }

  Future<void> _checkDevice() async {
    final isSim = await DeviceUtils.isSimulator();
    if (mounted) {
      setState(() {
        _isSimulator = isSim;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedback = widget.feedback;
    final typeMap = {
      'blocked': {'label': '道路阻断', 'color': Colors.red, 'icon': Icons.block},
      'detour': {'label': '建议绕行', 'color': Colors.orange, 'icon': Icons.alt_route},
      'weather': {'label': '天气变化', 'color': Colors.blue, 'icon': Icons.cloud},
      'water': {'label': '水源位置', 'color': Colors.cyan, 'icon': Icons.water_drop},
      'campsite': {'label': '推荐营地', 'color': Colors.green, 'icon': Icons.nights_stay},
      'danger': {'label': '危险区域', 'color': Colors.deepOrange, 'icon': Icons.warning},
      'supply': {'label': '有补给点', 'color': Colors.purple, 'icon': Icons.store},
      'sos': {'label': '紧急求助', 'color': Colors.red, 'icon': Icons.warning},
      'other': {'label': '其他信息', 'color': Colors.grey, 'icon': Icons.more_horiz},
    };
    
    // Handle different field names for SOS vs Feedback
    String typeStr = feedback['type'] as String? ?? 'other';
    // If it's an SOS alert (might not have type field or type is different)
    if (feedback.containsKey('status') && feedback.containsKey('message')) {
       typeStr = 'sos';
    }

    final typeKey = typeStr;
    final typeInfo = typeMap[typeKey] ?? typeMap['other']!;
    final color = typeInfo['color'] as Color;
    
    // Parse time
    final createdTime = DateTime.fromMillisecondsSinceEpoch(feedback['created_at']);
    final dateStr = '${createdTime.year}-${createdTime.month}-${createdTime.day} ${createdTime.hour}:${createdTime.minute}';

    // Parse photos
    List<String> photos = [];
    if (feedback['photos'] != null && feedback['photos'].toString().isNotEmpty) {
      try {
        photos = List<String>.from(jsonDecode(feedback['photos']));
      } catch (e) {
        // ignore error
      }
    }

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
            // Map Placeholder or Photos
            if (photos.isNotEmpty)
              Stack(
                children: [
                  SizedBox(
                    height: 250,
                    child: PageView.builder(
                      itemCount: photos.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPhotoIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        String url = photos[index];
                        if (!url.startsWith('http')) {
                          url = 'http://114.55.148.245:8000$url';
                        }
                        return CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: Colors.grey[200]),
                          errorWidget: (context, url, error) => const Icon(Icons.error),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_currentPhotoIndex + 1}/${photos.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              )
            else
              Container(
                height: 200,
                color: Colors.grey[200],
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map, size: 48, color: color),
                      const SizedBox(height: 8),
                      Text(
                        _isSimulator ? '模拟器不支持地图显示' : '暂无照片/地图数据',
                         style: TextStyle(color: color)
                      ),
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
                        child: Row(
                          children: [
                            Icon(typeInfo['icon'] as IconData, size: 16, color: color),
                            const SizedBox(width: 4),
                            Text(
                              typeInfo['label'] as String,
                              style: TextStyle(color: color, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        dateStr,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Content
                  Text(
                    feedback['content'] ?? feedback['message'] ?? '无内容',
                    style: const TextStyle(fontSize: 18, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  
                  // Address
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          feedback['address'] ?? '未知位置',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStat(Icons.remove_red_eye, '${feedback['view_count'] ?? 0}', '浏览'),
                      _buildStat(Icons.thumb_up, '${feedback['confirm_count'] ?? 0}', '确认'),
                      _buildStat(Icons.comment, '0', '评论'), // Mock comment count
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  // Comments Section (Mock for now as backend doesn't support comments yet)
                  const Text('评论 (0)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('暂无评论', style: TextStyle(color: Colors.grey)),
                    ),
                  ),
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
}
