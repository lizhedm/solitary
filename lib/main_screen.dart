import 'package:flutter/material.dart';
import 'pages/hiking/hiking_map_page.dart';
import 'pages/messages/message_center_page.dart';
import 'pages/settings/settings_page.dart';

/// MainScreen - 主屏幕组件
/// 应用的底部导航页面，包含徒步地图、消息中心和设置三个Tab
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // 当前选中的Tab索引，默认为0（徒步地图页面）
  int _currentIndex = 0;

  // 页面列表，包含三个主要页面
  final List<Widget> _pages = [
    const HikingMapPage(), // 徒步地图页面
    const MessageCenterPage(), // 消息中心页面
    const SettingsPage(), // 设置页面
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 使用IndexedStack保持页面状态，只显示当前选中的页面
      body: IndexedStack(index: _currentIndex, children: _pages),
      // 底部导航栏
      bottomNavigationBar: BottomNavigationBar(
        // 当前选中的索引
        currentIndex: _currentIndex,
        // 点击Tab时的回调，更新当前索引
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        // 选中项颜色 - 绿色主题色
        selectedItemColor: const Color(0xFF2E7D32),
        // 未选中项颜色 - 灰色
        unselectedItemColor: Colors.grey,
        // 导航栏类型为固定类型，所有项都会显示
        type: BottomNavigationBarType.fixed,
        // 导航项配置
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: '开始徒步'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: '消息'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}
