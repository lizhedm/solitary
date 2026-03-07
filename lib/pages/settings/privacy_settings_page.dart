import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  bool _isLoading = true;
  bool _visibleOnMap = true;
  double _visibleRange = 5.0;
  bool _receiveSOS = true;
  bool _receiveQuestions = true;
  bool _receiveFeedback = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user != null) {
        final user = authProvider.user!;
        setState(() {
          _visibleOnMap = user.visibleOnMap;
          _visibleRange = user.visibleRange.toDouble();
          _receiveSOS = user.receiveSOS;
          _receiveQuestions = user.receiveQuestions;
          _receiveFeedback = user.receiveFeedback;
          _isLoading = false;
        });
      } else {
        // Fallback or re-fetch
        await authProvider.fetchUserProfile();
        final user = authProvider.user;
        if (user != null) {
          setState(() {
            _visibleOnMap = user.visibleOnMap;
            _visibleRange = user.visibleRange.toDouble();
            _receiveSOS = user.receiveSOS;
            _receiveQuestions = user.receiveQuestions;
            _receiveFeedback = user.receiveFeedback;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Load privacy settings failed: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    // Optimistic update
    setState(() {
      if (key == 'visible_on_map') _visibleOnMap = value;
      if (key == 'visible_range') _visibleRange = value.toDouble();
      if (key == 'receive_sos') _receiveSOS = value;
      if (key == 'receive_questions') _receiveQuestions = value;
      if (key == 'receive_feedback') _receiveFeedback = value;
    });

    try {
      await ApiService().put('/users/privacy-settings', data: {key: value});
      // Refresh user profile to keep local state in sync
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.fetchUserProfile();
    } catch (e) {
      debugPrint('Update setting failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设置保存失败，请重试')),
        );
        // Revert could be implemented here
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('隐私设置')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('隐私设置')),
      body: ListView(
        children: [
          _buildSectionHeader('位置可见性'),
          SwitchListTile(
            title: const Text('在地图上显示我的位置'),
            subtitle: const Text('关闭后其他人无法在地图上看到您'),
            value: _visibleOnMap,
            onChanged: (val) => _updateSetting('visible_on_map', val),
            activeColor: const Color(0xFF2E7D32),
          ),
          if (_visibleOnMap)
            Column(
              children: [
                ListTile(
                  title: const Text('可见范围'),
                  subtitle: Text('当前设置：${_visibleRange.toInt()}公里'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Text('1km'),
                      Expanded(
                        child: Slider(
                          value: [1.0, 3.0, 5.0, 10.0].indexOf(_visibleRange).toDouble().clamp(0.0, 3.0),
                          min: 0,
                          max: 3,
                          divisions: 3,
                          label: '${_visibleRange.toInt()}km',
                          onChanged: (val) {
                            setState(() => _visibleRange = [1.0, 3.0, 5.0, 10.0][val.toInt()]);
                          },
                          onChangeEnd: (val) => _updateSetting(
                              'visible_range', [1.0, 3.0, 5.0, 10.0][val.toInt()].toInt()),
                          activeColor: const Color(0xFF2E7D32),
                        ),
                      ),
                      const Text('10km'),
                    ],
                  ),
                ),
              ],
            ),
          _buildSectionHeader('接收设置'),
          SwitchListTile(
            title: const Text('接收求救信息'),
            subtitle: const Text('附近有用户求救时通知我'),
            value: _receiveSOS,
            onChanged: (val) => _updateSetting('receive_sos', val),
            activeColor: const Color(0xFF2E7D32),
          ),
          SwitchListTile(
            title: const Text('接收周围提问'),
            value: _receiveQuestions,
            onChanged: (val) => _updateSetting('receive_questions', val),
            activeColor: const Color(0xFF2E7D32),
          ),
          SwitchListTile(
            title: const Text('接收路况反馈'),
            value: _receiveFeedback,
            onChanged: (val) => _updateSetting('receive_feedback', val),
            activeColor: const Color(0xFF2E7D32),
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
