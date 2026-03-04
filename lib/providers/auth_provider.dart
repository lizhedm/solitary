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

  AuthProvider() {
    // 根据平台更新API基础URL
    _updateBaseUrlForPlatform();
  }

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

  /// updateUserProfile - 更新用户信息
  /// 参数：nickname 昵称, email 邮箱, avatar 头像URL
  /// 只更新提供的字段，其他字段保持不变
  Future<void> updateUserProfile({
    String? nickname,
    String? email,
    String? avatar,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      // 构建更新数据
      final Map<String, dynamic> updateData = {};
      if (nickname != null) updateData['nickname'] = nickname;
      if (email != null) updateData['email'] = email;
      if (avatar != null) updateData['avatar'] = avatar;

      // 发送更新请求到服务器
      await _apiService.post('/users/me/update', data: updateData);

      // 更新本地用户信息
      if (_user != null) {
        _user = _user!.copyWith(
          nickname: nickname ?? _user!.nickname,
          email: email ?? _user!.email,
          avatar: avatar ?? _user!.avatar,
        );
      }

      notifyListeners();
    } catch (e) {
      print('Update profile error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// updateUsername - 更新用户名
  /// 注意：用户名可能需要在服务器端特殊处理，可能不能直接修改
  Future<void> updateUsername(String username) async {
    _isLoading = true;
    notifyListeners();
    try {
      // 发送更新用户名请求到服务器
      await _apiService.post('/users/me/update', data: {'username': username});

      // 更新本地用户信息
      if (_user != null) {
        _user = _user!.copyWith(username: username);
      }

      notifyListeners();
    } catch (e) {
      print('Update username error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// uploadAvatar - 上传头像文件
  /// 参数：fileBytes 头像文件的字节数据, fileName 文件名
  /// 返回：上传后的头像URL
  Future<String?> uploadAvatar(List<int> fileBytes, String fileName) async {
    _isLoading = true;
    notifyListeners();
    try {
      // Ensure the user is authenticated before attempting upload
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null || token.isEmpty) {
        throw Exception('未登录，请先登录');
      }
      // 创建multipart/form-data
      final formData = FormData.fromMap({
        'avatar': MultipartFile.fromBytes(fileBytes, filename: fileName),
      });

      // 发送上传请求到服务器
      final response = await _apiService.post(
        '/users/me/avatar',
        data: formData,
      );

      // 获取上传后的头像URL
      final avatarUrl = response.data['avatar_url'] as String?;

      // 更新本地用户信息
      if (_user != null && avatarUrl != null) {
        _user = _user!.copyWith(avatar: avatarUrl);
        notifyListeners();
      }

      return avatarUrl;
    } catch (e) {
      print('Upload avatar error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// _updateBaseUrlForPlatform - 根据平台更新API基础URL
  void _updateBaseUrlForPlatform() {
    // Web端使用localhost
    if (kIsWeb) {
      _apiService.updateBaseUrl('http://localhost:8000');
      return;
    }

    // 移动端平台检测
    if (defaultTargetPlatform == TargetPlatform.android) {
      _apiService.updateBaseUrl('http://10.0.2.2:8000');
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      _apiService.updateBaseUrl('http://127.0.0.1:8000');
    }
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
