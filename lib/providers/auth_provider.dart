import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../models/user.dart';
import '../services/api_service.dart';

/// AuthProvider - 认证状态管理类
/// 使用ChangeNotifier管理用户登录状态和用户信息
class AuthProvider with ChangeNotifier {
  // 当前登录用户信息
  User? _user;
  // 用户认证令牌
  String? _token;
  // 是否正在加载中
  bool _isLoading = false;
  // API服务实例
  final ApiService _apiService = ApiService();

  // 是否已认证（token不为空）
  bool get isAuthenticated => _token != null;
  // 获取当前用户
  User? get user => _user;
  // 获取加载状态
  bool get isLoading => _isLoading;

  /// login - 用户登录方法
  /// 参数：username 用户名, password 密码
  /// 流程：1.获取令牌 2.保存令牌到本地 3.获取用户信息
  Future<void> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 检查是否为测试账号
      if (username == 'user' && password == '12345678') {
        // 测试账号 - 模拟登录
        _token = 'test_token_12345678';
        _user = User(
          id: 1,
          username: 'user',
          nickname: '测试用户',
          email: 'user@example.com',
          avatar: null,
          isActive: true,
        );

        // 保存token到本地存储
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);

        notifyListeners();
      } else {
        // 1. 获取令牌 - 发送用户名密码到服务器
        final formData = FormData.fromMap({
          'username': username,
          'password': password,
        });

        final response = await _apiService.post('/token', data: formData);
        _token = response.data['access_token'];

        // 保存token到本地存储
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);

        // 2. 获取用户信息
        await fetchUserProfile();
      }
    } catch (e) {
      print('Login error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// fetchUserProfile - 获取用户信息
  /// 从服务器获取当前登录用户的详细信息
  Future<void> fetchUserProfile() async {
    try {
      final response = await _apiService.get('/users/me');
      _user = User.fromJson(response.data);
      notifyListeners();
    } catch (e) {
      print('Fetch user error: $e');
      // Token可能已失效，执行登出
      logout();
    }
  }

  /// register - 用户注册方法
  /// 参数：username 用户名, password 密码, email 邮箱(可选), nickname 昵称(可选)
  Future<void> register(
    String username,
    String password, {
    String? email,
    String? nickname,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      // 发送注册请求到服务器
      await _apiService.post(
        '/register',
        data: {
          'username': username,
          'password': password,
          'email': email,
          'nickname': nickname,
        },
      );
      // 注册成功后可以选择自动登录或返回成功
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// logout - 用户登出方法
  /// 清除本地存储的token和用户信息
  Future<void> logout() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    notifyListeners();
  }

  /// checkAuth - 检查认证状态
  /// 应用启动时调用，检查本地存储的token是否有效
  Future<void> checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    if (_token != null) {
      // 如果有token，验证并获取用户信息
      await fetchUserProfile();
    }
  }
}
