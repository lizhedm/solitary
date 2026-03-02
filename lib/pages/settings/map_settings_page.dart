import 'package:flutter/material.dart';

class MapSettingsPage extends StatefulWidget {
  const MapSettingsPage({super.key});

  @override
  State<MapSettingsPage> createState() => _MapSettingsPageState();
}

class _MapSettingsPageState extends State<MapSettingsPage> {
  bool _autoRotate = false;
  bool _keepScreenOn = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('地图设置')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('地图类型'),
            trailing: const Text('标准'),
            onTap: () {},
          ),
          SwitchListTile(
            title: const Text('自动旋转'),
            subtitle: const Text('根据行进方向自动旋转地图'),
            value: _autoRotate,
            onChanged: (val) => setState(() => _autoRotate = val),
          ),
          SwitchListTile(
            title: const Text('保持屏幕常亮'),
            value: _keepScreenOn,
            onChanged: (val) => setState(() => _keepScreenOn = val),
          ),
          const Divider(),
          ListTile(
            title: const Text('下载离线地图'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
