import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class SOSDetailPage extends StatefulWidget {
  const SOSDetailPage({super.key});

  @override
  State<SOSDetailPage> createState() => _SOSDetailPageState();
}

class _SOSDetailPageState extends State<SOSDetailPage> {
  String _selectedDangerType = 'injury';
  int _safetyStatus = 0; // 0: Danger, 1: Temp Safe, 2: Safe
  final List<String> _selectedItems = [];
  final TextEditingController _descriptionController = TextEditingController();
  final List<XFile> _photos = [];
  final ImagePicker _picker = ImagePicker();

  final List<Map<String, dynamic>> _dangerTypes = [
    {'id': 'injury', 'icon': Icons.local_hospital, 'label': '人员受伤', 'color': Colors.red},
    {'id': 'lost', 'icon': Icons.explore_off, 'label': '迷路失联', 'color': Colors.orange},
    {'id': 'weather', 'icon': Icons.thunderstorm, 'label': '天气突变', 'color': Colors.blueGrey},
    {'id': 'animal', 'icon': Icons.pets, 'label': '野生动物', 'color': Colors.brown},
    {'id': 'equipment', 'icon': Icons.backpack, 'label': '装备故障', 'color': Colors.grey},
    {'id': 'other', 'icon': Icons.warning, 'label': '其他危险', 'color': Colors.black},
  ];

  final List<Map<String, dynamic>> _urgentItems = [
    {'id': 'water', 'icon': Icons.water_drop, 'label': '饮用水'},
    {'id': 'food', 'icon': Icons.restaurant, 'label': '食物'},
    {'id': 'medicine', 'icon': Icons.medical_services, 'label': '药品'},
    {'id': 'warmth', 'icon': Icons.local_fire_department, 'label': '保暖'},
    {'id': 'shelter', 'icon': Icons.home, 'label': '庇护所'},
    {'id': 'rescue', 'icon': Icons.support, 'label': '专业救援'},
  ];

  Future<void> _takePhoto() async {
    if (_photos.length >= 3) return;
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() {
        _photos.add(photo);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('求救详情'),
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
                // Top Status Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '求救信号已发送给周围 3 位用户',
                          style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Danger Type
                const Text('危险类型（必选）', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _dangerTypes.length,
                  itemBuilder: (context, index) {
                    final type = _dangerTypes[index];
                    final isSelected = _selectedDangerType == type['id'];
                    return GestureDetector(
                      onTap: () => setState(() => _selectedDangerType = type['id']),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? type['color'].withOpacity(0.1) : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? type['color'] : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(type['icon'], color: isSelected ? type['color'] : Colors.grey, size: 32),
                            const SizedBox(height: 8),
                            Text(
                              type['label'],
                              style: TextStyle(
                                color: isSelected ? type['color'] : Colors.grey.shade700,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Safety Status
                const Text('当前安全状态', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      _buildStatusOption(0, '仍危险', Colors.red),
                      _buildStatusOption(1, '暂时安全', Colors.orange),
                      _buildStatusOption(2, '已脱险', Colors.green),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Urgent Items
                const Text('急需物品/帮助（多选）', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _urgentItems.map((item) {
                    final isSelected = _selectedItems.contains(item['id']);
                    return FilterChip(
                      label: Text(item['label']),
                      avatar: Icon(item['icon'], size: 18, color: isSelected ? Colors.white : Colors.grey),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedItems.add(item['id']);
                          } else {
                            _selectedItems.remove(item['id']);
                          }
                        });
                      },
                      selectedColor: const Color(0xFF2E7D32),
                      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                      checkmarkColor: Colors.white,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Description
                const Text('具体描述', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    hintText: '请描述您的具体情况...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),

                // Photos
                const Text('现场照片（可选，最多3张）', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                              border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt, color: Colors.grey),
                                Text('添加照片', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                        );
                      }
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_photos[index].path),
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => setState(() => _photos.removeAt(index)),
                              child: const CircleAvatar(
                                radius: 10,
                                backgroundColor: Colors.black54,
                                child: Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Bottom Actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Update SOS info
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('求救信息已更新并推送')),
                      );
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('更新求救信息'),
                  ),
                ),
                if (_safetyStatus == 2) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // Cancel SOS
                        Navigator.pop(context, 'cancel');
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('取消求救'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOption(int value, String label, Color color) {
    final isSelected = _safetyStatus == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _safetyStatus = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black54,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
