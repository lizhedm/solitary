import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../services/database_helper.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';

class RouteFeedbackPage extends StatefulWidget {
  final double? latitude;
  final double? longitude;

  const RouteFeedbackPage({super.key, this.latitude, this.longitude});

  @override
  State<RouteFeedbackPage> createState() => _RouteFeedbackPageState();
}

class _RouteFeedbackPageState extends State<RouteFeedbackPage> {
  String? _selectedType;
  final TextEditingController _descriptionController = TextEditingController();
  final List<XFile> _photos = [];
  final ImagePicker _picker = ImagePicker();
  String _validity = '3600'; // seconds

  final List<Map<String, dynamic>> _feedbackTypes = [
    {
      'id': 'blocked',
      'icon': Icons.block,
      'label': '道路阻断',
      'color': Colors.red,
    },
    {
      'id': 'detour',
      'icon': Icons.alt_route,
      'label': '建议绕行',
      'color': Colors.orange,
    },
    {
      'id': 'weather',
      'icon': Icons.cloud,
      'label': '天气变化',
      'color': Colors.blue,
    },
    {
      'id': 'water',
      'icon': Icons.water_drop,
      'label': '水源位置',
      'color': Colors.cyan,
    },
    {
      'id': 'campsite',
      'icon': Icons.nights_stay,
      'label': '推荐营地',
      'color': Colors.green,
    },
    {
      'id': 'danger',
      'icon': Icons.warning,
      'label': '危险区域',
      'color': Colors.deepOrange,
    },
    {
      'id': 'supply',
      'icon': Icons.store,
      'label': '有补给点',
      'color': Colors.purple,
    },
    {
      'id': 'other',
      'icon': Icons.more_horiz,
      'label': '其他信息',
      'color': Colors.grey,
    },
  ];

  Future<void> _takePhoto() async {
    if (_photos.length >= 3) return;
    
    // Show dialog to choose source
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择图片'),
        content: const Text('请选择图片来源'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            child: const Text('相册'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            child: const Text('相机'),
          ),
        ],
      ),
    );

    if (source == null) return;

    final XFile? photo = await _picker.pickImage(source: source);
    if (photo != null) {
      setState(() {
        _photos.add(photo);
      });
    }
  }

  bool _isSubmitting = false;

  Future<List<int>> _compressImage(XFile file) async {
    final originalBytes = await file.readAsBytes();
    int sizeInBytes = originalBytes.length;
    
    // If smaller than 1MB, return original
    if (sizeInBytes <= 1000000) {
      return originalBytes;
    }

    if (kIsWeb) {
       // Web doesn't support flutter_image_compress effectively in this way usually,
       // but let's return original for web for now or implement web-specific compression.
       // For simplicity, return original on web.
       return originalBytes;
    }

    // Compress
    List<int>? compressed;
    int quality = 85;
    
    // Try compress
    while (quality > 20) {
      try {
        final res = await FlutterImageCompress.compressWithList(
          originalBytes,
          quality: quality,
          format: CompressFormat.jpeg,
        );
        
        if (res.length <= 1000000) {
          compressed = res;
          break;
        }
        compressed = res; // keep best effort
      } catch (e) {
        debugPrint('Compression error: $e');
        return originalBytes;
      }
      quality -= 15;
    }
    
    return compressed ?? originalBytes;
  }

  Future<void> _publishFeedback() async {
    if (_selectedType == null || _descriptionController.text.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      // 1. Get Location
      double lat, lng;
      if (widget.latitude != null && widget.longitude != null) {
         lat = widget.latitude!;
         lng = widget.longitude!;
      } else {
        // Fallback to get current location if not passed
        try {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 10),
          );
          lat = position.latitude;
          lng = position.longitude;
        } catch (e) {
          debugPrint('Location error: $e');
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('无法获取当前位置，请确保定位权限已开启')),
          );
          setState(() => _isSubmitting = false);
          return;
        }
      }

      // 2. Upload Photos (if any)
      List<String> photoUrls = [];
      if (_photos.isNotEmpty) {
        for (var photo in _photos) {
          try {
            final bytes = await _compressImage(photo);
            
            // Generate a filename
            final filename = 'feedback_${DateTime.now().millisecondsSinceEpoch}_${photo.name}';
            
            final formData = FormData.fromMap({
              'file': MultipartFile.fromBytes(
                bytes,
                filename: filename,
              ),
            });
            // Reuse snapshot upload endpoint for now as it handles images
            final response = await ApiService().post('/upload/snapshot', data: formData);
            if (response.statusCode == 200 && response.data != null) {
              photoUrls.add(response.data['url']);
            }
          } catch (e) {
            debugPrint('Upload photo failed: $e');
          }
        }
      }

      // 3. Prepare Data
      final feedbackData = {
        'user_id': userId,
        'type': _selectedType,
        'content': _descriptionController.text,
        'latitude': lat,
        'longitude': lng,
        'address': 'Unknown', // Could use geocoding if needed
        'photos': jsonEncode(photoUrls),
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'status': 'ACTIVE',
        'sync_status': 1, // Pending
        'user_name': authProvider.user?.nickname ?? 'Unknown', // Add username
      };

      // 4. Save to Local DB
      final localId = await DatabaseHelper().saveFeedback(feedbackData);
      
      // 5. Upload to Backend
      try {
        // Construct API payload (must match FeedbackCreate)
        final apiPayload = {
          'type': _selectedType,
          'content': _descriptionController.text,
          'latitude': lat,
          'longitude': lng,
          'address': 'Unknown',
          'photos': photoUrls,
          'created_at': feedbackData['created_at'],
        };
        
        final response = await ApiService().post('/messages/feedback', data: apiPayload);
        
        if (response.statusCode == 200) {
          // Update Local DB with remote ID
          final remoteData = response.data;
          feedbackData['local_id'] = localId;
          feedbackData['remote_id'] = remoteData['id'];
          feedbackData['sync_status'] = 0; // Synced
          await DatabaseHelper().saveFeedback(feedbackData);
        }
      } catch (e) {
        debugPrint('Upload feedback failed: $e');
        // Keep sync_status = 1, will retry later (if background sync implemented)
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('路况反馈已发布')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Publish feedback error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发布失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // Build a widget to display a photo in a web-friendly way (no dart:io).
  Widget _photoWidget(XFile photo) {
    // readAsBytes is supported on web and mobile for XFile
    return FutureBuilder<Uint8List>(
      future: photo.readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          return Image.memory(
            snapshot.data!,
            width: 100,
            height: 100,
            fit: BoxFit.cover,
          );
        }
        // placeholder while loading
        return Container(width: 100, height: 100, color: Colors.grey.shade200);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('发布路况信息'),
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
                // Impact Preview
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.people, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('该信息将影响周围 12 位相似路线用户'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Feedback Type
                const Text(
                  '路况类型',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _feedbackTypes.map((type) {
                    final isSelected = _selectedType == type['id'];
                    return FilterChip(
                      label: Text(type['label']),
                      avatar: Icon(
                        type['icon'],
                        size: 18,
                        color: isSelected ? Colors.white : type['color'],
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedType = selected ? type['id'] : null;
                        });
                      },
                      selectedColor: type['color'],
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                      ),
                      backgroundColor: Colors.white,
                      side: BorderSide(color: type['color']),
                      checkmarkColor: Colors.white,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Description
                const Text(
                  '详细描述',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    hintText: '描述具体情况，如：前方200米处有塌方，建议绕行...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),

                // Photos
                const Text(
                  '照片证据（可选）',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _photos.length + (_photos.length < 3 ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      if (index == _photos.length) {
                        return GestureDetector(
                          onTap: _takePhoto,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt, color: Colors.grey),
                                Text(
                                  '添加照片',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _photoWidget(_photos[index]),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _photos.removeAt(index)),
                              child: const CircleAvatar(
                                radius: 10,
                                backgroundColor: Colors.black54,
                                child: Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Validity
                const Text(
                  '有效期',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _validity,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: '3600', child: Text('1小时')),
                    DropdownMenuItem(value: '10800', child: Text('3小时')),
                    DropdownMenuItem(value: 'endOfDay', child: Text('今天')),
                    DropdownMenuItem(
                      value: 'permanent',
                      child: Text('永久 (如道路损毁)'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _validity = value!),
                ),
              ],
            ),
          ),

          // Submit Button
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    (_selectedType == null ||
                        _descriptionController.text.isEmpty ||
                        _isSubmitting)
                    ? null
                    : _publishFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting 
                    ? const SizedBox(
                        width: 20, 
                        height: 20, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      )
                    : const Text('发布'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
