import 'package:flutter/material.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _friendMsg = true;
  bool _sosMsg = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('通知设置')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('好友消息通知'),
            value: _friendMsg,
            onChanged: (val) => setState(() => _friendMsg = val),
          ),
          SwitchListTile(
            title: const Text('求救信息通知'),
            subtitle: const Text('强烈建议开启'),
            value: _sosMsg,
            onChanged: (val) => setState(() => _sosMsg = val),
          ),
        ],
      ),
    );
  }
}
