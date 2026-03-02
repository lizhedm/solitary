import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../hiking/hiking_history_page.dart';
import 'privacy_settings_page.dart';
import 'account_security_page.dart';
import 'language_settings_page.dart';
import 'map_settings_page.dart';
import 'notification_settings_page.dart';
import 'user_guide_page.dart';
import 'about_us_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          // User Profile Card
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: const Color(0xFF2E7D32),
                  child: Text(
                    user?.nickname?.substring(0, 1).toUpperCase() ?? 'U',
                    style: const TextStyle(fontSize: 24, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.nickname ?? '用户',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      user?.username ?? '',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Settings Sections
          _buildSectionHeader('隐私与安全'),
          _buildSettingsTile(
            icon: Icons.visibility,
            title: '隐私设置',
            color: Colors.blue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PrivacySettingsPage()),
              );
            },
          ),
          _buildSettingsTile(
            icon: Icons.security,
            title: '账号与安全',
            color: Colors.green,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AccountSecurityPage()),
              );
            },
          ),

          const SizedBox(height: 16),
          _buildSectionHeader('偏好设置'),
          _buildSettingsTile(
            icon: Icons.history,
            title: '徒步历史',
            color: Colors.brown,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HikingHistoryPage()),
              );
            },
          ),
          _buildSettingsTile(
            icon: Icons.language,
            title: '语言',
            color: Colors.purple,
            value: '简体中文',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LanguageSettingsPage()),
              );
            },
          ),
          _buildSettingsTile(
            icon: Icons.map,
            title: '地图设置',
            color: Colors.orange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MapSettingsPage()),
              );
            },
          ),
          _buildSettingsTile(
            icon: Icons.notifications,
            title: '通知设置',
            color: Colors.red,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationSettingsPage()),
              );
            },
          ),

          const SizedBox(height: 16),
          _buildSectionHeader('关于'),
          _buildSettingsTile(
            icon: Icons.help,
            title: '使用指南',
            color: Colors.teal,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UserGuidePage()),
              );
            },
          ),
          _buildSettingsTile(
            icon: Icons.info,
            title: '关于我们',
            color: Colors.grey,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutUsPage()),
              );
            },
          ),

          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton(
              onPressed: () {
                Provider.of<AuthProvider>(context, listen: false).logout();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('退出登录'),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required Color color,
    String? value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            Text(value, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        ],
      ),
      onTap: onTap,
    );
  }
}
