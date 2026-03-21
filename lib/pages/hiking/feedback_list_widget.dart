import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'route_feedback_detail_page.dart';

class FeedbackListWidget extends StatelessWidget {
  final List<Map<String, dynamic>> feedbacks;
  final Future<void> Function()? onRefresh;

  const FeedbackListWidget({
    super.key,
    required this.feedbacks,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (feedbacks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              '暂无路况反馈',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '这里还没有路况信息。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
            if (onRefresh != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onRefresh,
                child: const Text('刷新'),
              ),
            ],
          ],
        ),
      );
    }

    Widget list = ListView.builder(
      itemCount: feedbacks.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final feedback = feedbacks[index];
        final typeMap = {
          'blocked': {'label': '道路阻断', 'color': Colors.red, 'icon': Icons.block},
          'detour': {'label': '建议绕行', 'color': Colors.orange, 'icon': Icons.alt_route},
          'weather': {'label': '天气变化', 'color': Colors.blue, 'icon': Icons.cloud},
          'water': {'label': '水源位置', 'color': Colors.cyan, 'icon': Icons.water_drop},
          'campsite': {'label': '推荐营地', 'color': Colors.green, 'icon': Icons.nights_stay},
          'danger': {'label': '危险区域', 'color': Colors.deepOrange, 'icon': Icons.warning},
          'supply': {'label': '有补给点', 'color': Colors.purple, 'icon': Icons.store},
          'other': {'label': '其他信息', 'color': Colors.grey, 'icon': Icons.more_horiz},
        };

        final typeKey = feedback['type'] as String? ?? 'other';
        final typeInfo = typeMap[typeKey] ?? typeMap['other']!;
        final createdTime = DateTime.fromMillisecondsSinceEpoch(feedback['created_at']);
        final dateStr = '${createdTime.year}-${createdTime.month.toString().padLeft(2, '0')}-${createdTime.day.toString().padLeft(2, '0')} ${createdTime.hour.toString().padLeft(2, '0')}:${createdTime.minute.toString().padLeft(2, '0')}';

        List<String> photos = [];
        if (feedback['photos'] != null && feedback['photos'].toString().isNotEmpty) {
          try {
            photos = List<String>.from(jsonDecode(feedback['photos']));
          } catch (e) {
            // ignore error
          }
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RouteFeedbackDetailPage(feedback: feedback),
              ),
            );
          },
          child: Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        typeInfo['icon'] as IconData,
                        color: typeInfo['color'] as Color,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        typeInfo['label'] as String,
                        style: TextStyle(
                          color: typeInfo['color'] as Color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (feedback['sync_status'] == 1)
                        const Row(
                          children: [
                            SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 4),
                            Text('同步中', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        )
                      else
                        const Icon(Icons.cloud_done, size: 16, color: Colors.green),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    feedback['content'] ?? '',
                    style: const TextStyle(fontSize: 16),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (photos.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 80,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: photos.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, pIndex) {
                          String url = photos[pIndex];
                          if (!url.startsWith('http')) {
                            url = 'http://8.136.205.255:8000$url';
                          }
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: url,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(color: Colors.grey[200]),
                              errorWidget: (context, url, error) => const Icon(Icons.error),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dateStr,
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.remove_red_eye, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text('${feedback['view_count'] ?? 0}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(width: 12),
                          const Icon(Icons.thumb_up, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text('${feedback['confirm_count'] ?? 0}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (onRefresh != null) {
      return RefreshIndicator(
        onRefresh: onRefresh!,
        child: list,
      );
    }
    
    return list;
  }
}
