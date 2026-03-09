import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/database_helper.dart';

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
  // 头像版本，用于强制刷新头像图片缓存
  int _avatarVersion = 0;
  int get avatarVersion => _avatarVersion;

  AuthProvider() {
    // 已移除按平台自动覆盖基础URL的逻辑，统一使用云端地址
  }

  // 是否已认证（token不为空）
  bool get isAuthenticated => _token != null;
  // 获取当前 token（用于跨组件访问，尤其是需要在网络请求中传递时）
  String? get token => _token;
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
      // 统一使用真实账号进行登录；移除自动化测试账号逻辑
      // 1. 获取令牌 - 发送用户名密码到服务器
      final response = await _apiService.post(
        '/token',
        data: {'username': username, 'password': password},
        options: Options(contentType: 'application/x-www-form-urlencoded'),
      );
      // 兼容后端返回的不同字段名，优先使用 access_token，其次 token 等
      final tokenFromResponse =
          response.data['access_token'] ??
          response.data['token'] ??
          response.data['jwt'];
      if (tokenFromResponse == null) {
        throw Exception('后端未返回 token，请检查接口实现');
      }
      _token = tokenFromResponse.toString();

      // 保存token到本地存储
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _token!);

      // 2. 获取用户信息
      await fetchUserProfile();
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
      _avatarVersion++;
      
      // Update Local DB
      await DatabaseHelper().saveUser(_user!.toJson());
      
      notifyListeners();
    } catch (e) {
      print('Fetch user error: $e');
      // If error is 401, logout
      if (e is DioException && e.response?.statusCode == 401) {
         logout();
      } else {
         // Other errors (network), keep local user data if available
         if (_user == null) {
            logout();
         }
      }
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
    
    // Clear Local DB
    await DatabaseHelper().clearUser();
    
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
        _avatarVersion++;
        
        // Save to Local DB
        await DatabaseHelper().saveUser(_user!.toJson());
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

  /// setServerBaseUrl - 设定服务器基地址（Android/iOS移动端特定环境下的后端地址）
  /// 便于在局域网环境下移动端直接访问本地开发服务器
  Future<void> setServerBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_base_url', url);
    // 直接切换 Dio 客户端的基础URL
    _apiService.updateBaseUrl(url);
    notifyListeners();
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
        
        // Save to Local DB
        await DatabaseHelper().saveUser(_user!.toJson());
        
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

  // 删除按平台自动覆盖基础URL 的实现，保持统一云端地址

  /// checkAuth - 检查认证状态
  /// 应用启动时调用，检查本地存储的token是否有效
  Future<void> checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    if (_token != null) {
      // 1. Load from Local DB first for immediate UI
      final localUserData = await DatabaseHelper().getCurrentUser();
      if (localUserData != null) {
        try {
          _user = User.fromJson(localUserData);
          notifyListeners();
        } catch (e) {
          print('Error loading user from local DB: $e');
        }
      }
      
      // 2. Fetch from API to update
      // 如果有token，验证并获取用户信息
      await fetchUserProfile();
    }
  }
}
