import 'package:flutter/material.dart';

class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  bool _visibleOnMap = true;
  double _visibleRange = 1.0;
  bool _receiveSOS = true;
  bool _receiveQuestions = true;
  bool _receiveFeedback = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('隐私设置')),
      body: ListView(
        children: [
          _buildSectionHeader('位置可见性'),
          SwitchListTile(
            title: const Text('在地图上显示我的位置'),
            subtitle: const Text('关闭后其他人无法在地图上看到您'),
            value: _visibleOnMap,
            onChanged: (val) => setState(() => _visibleOnMap = val),
          ),
          if (_visibleOnMap)
            Column(
              children: [
                ListTile(
                  title: const Text('可见范围'),
                  subtitle: Text('当前设置：${_visibleRange.toInt()}公里'),
                ),
                Slider(
                  value: _visibleRange,
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: '${_visibleRange.toInt()}km',
                  onChanged: (val) => setState(() => _visibleRange = val),
                ),
              ],
            ),
          _buildSectionHeader('接收设置'),
          SwitchListTile(
            title: const Text('接收求救信息'),
            subtitle: const Text('附近有用户求救时通知我'),
            value: _receiveSOS,
            onChanged: (val) => setState(() => _receiveSOS = val),
          ),
          SwitchListTile(
            title: const Text('接收周围提问'),
            value: _receiveQuestions,
            onChanged: (val) => setState(() => _receiveQuestions = val),
          ),
          SwitchListTile(
            title: const Text('接收路况反馈'),
            value: _receiveFeedback,
            onChanged: (val) => setState(() => _receiveFeedback = val),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(title, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
    );
  }
}
