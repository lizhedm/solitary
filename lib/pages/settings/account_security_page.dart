import 'package:flutter/material.dart';

class AccountSecurityPage extends StatelessWidget {
  const AccountSecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('账号与安全')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('手机号'),
            trailing: const Text('138****8888'),
            onTap: () {},
          ),
          ListTile(
            title: const Text('微信账号'),
            trailing: const Text('已绑定'),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            title: const Text('修改密码'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            title: const Text('注销账号'),
            textColor: Colors.red,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
