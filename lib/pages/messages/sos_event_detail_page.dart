import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../hiking/route_feedback_detail_page.dart';

class SOSEventDetailPage extends StatefulWidget {
  final Map<String, dynamic> event;

  const SOSEventDetailPage({super.key, required this.event});

  @override
  State<SOSEventDetailPage> createState() => _SOSEventDetailPageState();
}

class _SOSEventDetailPageState extends State<SOSEventDetailPage> {
  late final Map<String, dynamic> _messageData;
  late final List<String> _photoUrls;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _messageData = _safeJson(widget.event['message_json']) ?? {};
    
    // 尝试从外层 photos_json 或者内层 message_json.photos 获取图片
    dynamic photosJson = _safeJson(widget.event['photos_json']);
    if (photosJson == null || (photosJson is List && photosJson.isEmpty)) {
      photosJson = _messageData['photos'];
    }
    
    _photoUrls = (photosJson is List)
        ? photosJson.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : <String>[];
  }

  dynamic _safeJson(dynamic value) {
    try {
      if (value == null) return null;
      if (value is String) return jsonDecode(value);
      return value;
    } catch (_) {
      return null;
    }
  }

  Widget _chip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dangerLabel = _messageData['danger_label']?.toString() ?? '未知危险';
    final safetyStatus = int.tryParse('${_messageData['safety_status'] ?? 0}') ?? 0;
    final urgentLabels = (_messageData['urgent_labels'] is List)
        ? (_messageData['urgent_labels'] as List).map((e) => e.toString()).toList()
        : <String>[];
    final description = _messageData['description']?.toString() ?? '';
    final timeText = _messageData['time']?.toString() ?? '';

    final statusText = safetyStatus == 2 ? '已脱险' : (safetyStatus == 1 ? '暂时安全' : '仍危险');
    final statusColor = safetyStatus == 2 ? Colors.green : (safetyStatus == 1 ? Colors.orange : Colors.red);

    return Scaffold(
      appBar: AppBar(
        title: const Text('求救详情'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(Icons.report, dangerLabel, Colors.red.shade700),
              _chip(Icons.shield, statusText, statusColor),
              if (urgentLabels.isNotEmpty)
                _chip(Icons.inventory_2, urgentLabels.join('、'), Colors.deepOrange),
              if (timeText.isNotEmpty)
                _chip(Icons.access_time, timeText, Colors.grey),
            ],
          ),
          const SizedBox(height: 16),

          // 现场照片：布局、交互完全复用 route_feedback_detail_page 的风格
          if (_photoUrls.isNotEmpty)
            Stack(
              children: [
                SizedBox(
                  height: 250,
                  child: PageView.builder(
                    itemCount: _photoUrls.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      String url = _photoUrls[index];
                      if (!url.startsWith('http')) {
                        url = 'http://8.136.205.255:8000$url';
                      }
                      return GestureDetector(
                        onTap: () {
                          final fullUrls = _photoUrls.map((p) {
                            if (!p.startsWith('http')) {
                              return 'http://8.136.205.255:8000$p';
                            }
                            return p;
                          }).toList();

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ImageViewerPage(
                                imageUrls: fullUrls,
                                initialIndex: index,
                              ),
                            ),
                          );
                        },
                        child: CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: Colors.grey[200]),
                          errorWidget: (context, url, error) => const Icon(Icons.error),
                        ),
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
                      '${_currentIndex + 1}/${_photoUrls.length}',
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
              child: const Center(
                child: Text('暂无现场照片', style: TextStyle(color: Colors.grey)),
              ),
            ),
          const SizedBox(height: 16),

          if (description.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '具体描述',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ],
              ),
            ),

        ],
      ),
    );
  }
}

