import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class RouteFeedbackPage extends StatefulWidget {
  const RouteFeedbackPage({super.key});

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
    {'id': 'blocked', 'icon': Icons.block, 'label': '道路阻断', 'color': Colors.red},
    {'id': 'detour', 'icon': Icons.alt_route, 'label': '建议绕行', 'color': Colors.orange},
    {'id': 'weather', 'icon': Icons.cloud, 'label': '天气变化', 'color': Colors.blue},
    {'id': 'water', 'icon': Icons.water_drop, 'label': '水源位置', 'color': Colors.cyan},
    {'id': 'campsite', 'icon': Icons.nights_stay, 'label': '推荐营地', 'color': Colors.green},
    {'id': 'danger', 'icon': Icons.warning, 'label': '危险区域', 'color': Colors.deepOrange},
    {'id': 'other', 'icon': Icons.more_horiz, 'label': '其他信息', 'color': Colors.grey},
  ];

  Future<void> _takePhoto() async {
    if (_photos.length >= 2) return;
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
                const Text('路况类型', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _feedbackTypes.map((type) {
                    final isSelected = _selectedType == type['id'];
                    return FilterChip(
                      label: Text(type['label']),
                      avatar: Icon(type['icon'], size: 18, color: isSelected ? Colors.white : type['color']),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedType = selected ? type['id'] : null;
                        });
                      },
                      selectedColor: type['color'],
                      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                      backgroundColor: Colors.white,
                      side: BorderSide(color: type['color']),
                      checkmarkColor: Colors.white,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Description
                const Text('详细描述', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                const Text('照片证据（可选）', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _photos.length + (_photos.length < 2 ? 1 : 0),
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
                const SizedBox(height: 24),

                // Validity
                const Text('有效期', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _validity,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: '3600', child: Text('1小时')),
                    DropdownMenuItem(value: '10800', child: Text('3小时')),
                    DropdownMenuItem(value: 'endOfDay', child: Text('今天')),
                    DropdownMenuItem(value: 'permanent', child: Text('永久 (如道路损毁)')),
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
                onPressed: (_selectedType == null || _descriptionController.text.isEmpty)
                    ? null
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('路况反馈已发布')),
                        );
                        Navigator.pop(context);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('发布'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
