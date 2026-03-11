import 'package:flutter/material.dart';
import '../../models/hiking_record.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'history_messages_page.dart';
import 'dart:convert';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/device_utils.dart';

import '../../services/database_helper.dart';

class HikingHistoryPage extends StatefulWidget {
  const HikingHistoryPage({super.key});

  @override
  State<HikingHistoryPage> createState() => _HikingHistoryPageState();
}

class _HikingHistoryPageState extends State<HikingHistoryPage> {
  List<HikingRecord> _records = [];
  bool _isLoading = true;
  int _totalCount = 0;
  double _totalDistance = 0.0;
  int _totalElevationGain = 0;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.id ?? 0;

    // 1. Load from Local DB first
    try {
      final localRecords = await DatabaseHelper().getHikingRecords(userId);
      if (localRecords.isNotEmpty) {
         if (mounted) {
           setState(() {
              _records = localRecords.map((json) {
                 final Map<String, dynamic> map = Map.from(json);
                 // Prefer remote_id, fallback to local_id
                 map['id'] = (json['remote_id'] ?? json['local_id']).toString();
                 return HikingRecord.fromJson(map);
              }).toList();
              
              _totalCount = _records.length;
              _totalDistance = _records.fold(0.0, (sum, r) => sum + r.distance);
              _totalElevationGain = _records.fold(0, (sum, r) => sum + r.elevationGain);
              _isLoading = false;
           });
         }
      }
    } catch (e) {
      debugPrint('Load local history failed: $e');
    }

    // 2. Fetch from API
    try {
      final response = await ApiService().get('/hiking-records', queryParameters: {'user_id': userId});
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> data = response.data['records'] ?? [];
        
        // Sync to Local DB
        for (var json in data) {
           try {
             final record = HikingRecord.fromJson(json);
             final localMap = record.toJson();
             localMap['remote_id'] = int.tryParse(record.id);
             localMap.remove('id');
             localMap['sync_status'] = 0;
             localMap['user_id'] = userId;
             
             await DatabaseHelper().saveHikingRecord(localMap);
           } catch (e) {
             debugPrint('Error syncing record: $e');
           }
        }
        
        if (mounted) {
          setState(() {
            _records = data.map((json) => HikingRecord.fromJson(json)).toList();
            _totalCount = response.data['total_count'] ?? _records.length;
            _totalDistance = (response.data['total_distance'] as num?)?.toDouble() ?? 
                _records.fold(0.0, (sum, r) => sum + r.distance);
            _totalElevationGain = response.data['total_elevation_gain'] ?? 
                _records.fold(0, (sum, r) => sum + r.elevationGain);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Fetch hiking history failed: $e');
      // Only set loading to false if we haven't loaded local data yet or local data is empty
      // If we have local data, we keep showing it
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, List<HikingRecord>> _groupByMonth(List<HikingRecord> records) {
    Map<String, List<HikingRecord>> groups = {};
    for (var record in records) {
      String month = '${record.startTime.year}年${record.startTime.month}月';
      if (!groups.containsKey(month)) {
        groups[month] = [];
      }
      groups[month]!.add(record);
    }
    return groups;
  }

  String _getCorrectedImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return 'http://8.136.205.255:8000$url';
  }

  @override
  Widget build(BuildContext context) {
    final groupedRecords = _groupByMonth(_records);
    final months = groupedRecords.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('徒步历史'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _SummaryItem(label: '累计次数', value: '$_totalCount次', color: Colors.white),
                      _SummaryItem(label: '总距离', value: '${_totalDistance.toStringAsFixed(1)}km', color: Colors.white),
                      _SummaryItem(label: '累计海拔爬升', value: '${_totalElevationGain}m', color: Colors.white),
                    ],
                  ),
                ),
                
                Expanded(
                  child: ListView.builder(
                    itemCount: months.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final month = months[index];
                      final items = groupedRecords[month]!;
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(month, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                          ),
                          ...items.map((item) {
                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => HistoryDetailPage(record: item),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Column(
                                  children: [
                                    if (item.mapSnapshotUrl != null)
                                      ClipRRect(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                        child: CachedNetworkImage(
                                          imageUrl: _getCorrectedImageUrl(item.mapSnapshotUrl),
                                          height: 150,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(
                                            height: 150,
                                            color: Colors.grey[200],
                                            child: const Center(child: CircularProgressIndicator()),
                                          ),
                                          errorWidget: (context, url, error) => Container(
                                            height: 150,
                                            color: Colors.grey[200],
                                            child: const Icon(Icons.map, color: Colors.grey),
                                          ),
                                        ),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '${item.startTime.year}-${item.startTime.month.toString().padLeft(2, '0')}-${item.startTime.day.toString().padLeft(2, '0')}',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade100,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '已完成',
                                                  style: TextStyle(
                                                    color: Colors.green.shade800,
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
                                              Expanded(
                                                child: Text(
                                                  '${item.startLocation ?? "未知"} → ${item.endLocation ?? "未知"}',
                                                  style: const TextStyle(color: Colors.grey),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              _buildStatItem(Icons.timer, '${(item.duration / 60).floor()}m', '时长'),
                                              _buildStatItem(Icons.directions_walk, '${item.distance.toStringAsFixed(1)}km', '距离'),
                                              _buildStatItem(Icons.terrain, '${item.elevationGain}m', '爬升'),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
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
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8))),
      ],
    );
  }
}

class HistoryDetailPage extends StatefulWidget {
  final HikingRecord record;

  const HistoryDetailPage({super.key, required this.record});

  @override
  State<HistoryDetailPage> createState() => _HistoryDetailPageState();
}

class _HistoryDetailPageState extends State<HistoryDetailPage> {
  bool _showReplay = false;
  bool _isSimulator = false;

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

  String _getCorrectedImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return 'http://8.136.205.255:8000$url';
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    
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
            child: Stack(
              children: [
                Positioned.fill(
                  child: _showReplay 
                    ? _buildReplayMap()
                    : (record.mapSnapshotUrl != null 
                        ? CachedNetworkImage(
                            imageUrl: _getCorrectedImageUrl(record.mapSnapshotUrl),
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                            errorWidget: (context, url, error) => const Center(child: Icon(Icons.error)),
                          )
                        : Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.map, size: 64, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text('轨迹地图', style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                          )),
                ),
                if (record.coordinatesJson != null)
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton.small(
                      onPressed: () => setState(() => _showReplay = !_showReplay),
                      backgroundColor: Colors.white,
                      child: Icon(_showReplay ? Icons.image : Icons.play_arrow, color: const Color(0xFF2E7D32)),
                    ),
                  ),
              ],
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
                    _buildDetailRow(Icons.calendar_today, '日期', '${record.startTime.year}-${record.startTime.month}-${record.startTime.day}'),
                    const SizedBox(height: 16),
                    _buildDetailRow(Icons.timer, '总时长', '${(record.duration / 3600).floor()}h ${(record.duration % 3600 / 60).floor()}m'),
                    const SizedBox(height: 16),
                    _buildDetailRow(Icons.directions_walk, '总距离', '${record.distance.toStringAsFixed(1)} km'),
                    const SizedBox(height: 16),
                    _buildDetailRow(Icons.terrain, '海拔爬升', '${record.elevationGain} m'),
                    const SizedBox(height: 16),
                    _buildDetailRow(Icons.local_fire_department, '消耗热量', '${record.calories} kcal'),
                    
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
                      subtitle: Text('${record.messageCount} 条消息'),
                      trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                        // Pass record id and time range
                        final recordId = int.tryParse(record.id) ?? 0;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HistoryMessagesPage(
                              hikeId: recordId,
                              startTime: record.startTime,
                              endTime: record.endTime,
                            ),
                          ),
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

  Widget _buildReplayMap() {
    if (_isSimulator) {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text('模拟器不支持地图回放', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    final record = widget.record;
    if (record.coordinatesJson == null) return const SizedBox.shrink();

    final List<dynamic> coordsData = jsonDecode(record.coordinatesJson!);
    final List<LatLng> points = coordsData.map((c) => LatLng(c['lat'], c['lng'])).toList();
    
    if (points.isEmpty) return const Center(child: Text('无轨迹数据'));

    return AMapWidget(
      apiKey: const AMapApiKey(
        androidKey: '4bf8b27c0d66ef2fce72e133db777349',
        iosKey: '173b139f4b0710330132c496bf45ece1',
        webKey: '1f67dc45ef1c30121049a15d27edf12e',
      ),
      initialCameraPosition: CameraPosition(target: points.first, zoom: 15),
      polylines: {
        Polyline(
          points: points,
          width: 3,
          color: const Color(0xFF2E7D32),
        ),
      },
      markers: {
        Marker(
          position: points.first,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          anchor: const Offset(0.5, 0.5),
        ),
        Marker(
          position: points.last,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          anchor: const Offset(0.5, 0.5),
        ),
      },
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

