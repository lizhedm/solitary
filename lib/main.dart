import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'package:solitary/providers/message_provider.dart';
import 'pages/auth/login_page.dart';
import 'main_screen.dart';
import 'package:solitary/services/api_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';

/// 应用程序入口函数
/// 启动整个Flutter应用
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 统一的云端后端地址
  final String baseUrl = 'http://114.55.148.245:8000';

  // 应用启动时设置全局 API 基地址
  ApiService().updateBaseUrl(baseUrl);

  // 全局错误兜底
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };

  runZonedGuarded(
    () {
      runApp(const SolitaryApp());
    },
    (error, stack) {
      print('Uncaught Flutter error: $error');
      print(stack);
    },
  );
}

/// SolitaryApp - 应用程序根全局组件
/// 配置的主题样式和状态管理
class SolitaryApp extends StatelessWidget {
  const SolitaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 使用MultiProvider提供全局状态管理
    return MultiProvider(
      providers: [
        // 创建AuthProvider用于管理用户认证状态
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MessageProvider()),
      ],
      child: MaterialApp(
        title: 'Solitary',
        // 配置Material 3主题
        theme: ThemeData(
          useMaterial3: true,
          // 从种子颜色生成配色方案，使用绿色作为主色调
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2E7D32),
            primary: const Color(0xFF2E7D32),
            secondary: const Color(0xFFD32F2F),
          ),
          // 设置脚手架背景色为白色
          scaffoldBackgroundColor: Colors.white,
          // 配置应用栏样式
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
          ),
        ),
        // 应用首页为AuthWrapper
        home: const AuthWrapper(),
      ),
    );
  }
}

/// AuthWrapper - 认证包装组件
/// 在应用启动时检查用户认证状态，并根据认证状态显示不同页面
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // 在组件初始化后检查用户认证状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).checkAuth();
    });
  }

  @override
  Widget build(BuildContext context) {
    // 监听认证状态变化
    final authProvider = Provider.of<AuthProvider>(context);

    // 如果用户已认证，显示主屏幕；否则显示登录页面
    if (authProvider.isAuthenticated) {
      return const MainScreen();
    } else {
      return const LoginPage();
    }
  }
}
