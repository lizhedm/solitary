import 'package:flutter/material.dart';

class LanguageSettingsPage extends StatefulWidget {
  const LanguageSettingsPage({super.key});

  @override
  State<LanguageSettingsPage> createState() => _LanguageSettingsPageState();
}

class _LanguageSettingsPageState extends State<LanguageSettingsPage> {
  String _language = 'zh-CN';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('语言设置')),
      body: ListView(
        children: [
          RadioListTile(
            title: const Text('简体中文'),
            value: 'zh-CN',
            groupValue: _language,
            onChanged: (val) => setState(() => _language = val!),
          ),
          RadioListTile(
            title: const Text('English'),
            value: 'en',
            groupValue: _language,
            onChanged: (val) => setState(() => _language = val!),
          ),
        ],
      ),
    );
  }
}
