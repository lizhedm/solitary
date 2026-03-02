import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ApiService - API服务类
/// 封装Dio HTTP客户端，用于与后端服务器通信
class ApiService {
  // 基础URL获取方法
  // Android模拟器使用10.0.2.2访问主机localhost
  // iOS模拟器使用127.0.0.1访问主机localhost
  // Web端使用localhost
  static String get baseUrl {
    // 简单检查，实际项目中应使用环境配置
    // Android模拟器使用10.0.2.2
    return 'http://10.0.2.2:8000';
    // iOS模拟器或Web端使用 http://127.0.0.1:8000
  }

  // Dio HTTP客户端实例
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'http://127.0.0.1:8000', // 默认为localhost，用于iOS/Web。Android需要特殊处理
      connectTimeout: const Duration(seconds: 5), // 连接超时时间5秒
      receiveTimeout: const Duration(seconds: 3), // 接收超时时间3秒
    ),
  );

  /// ApiService构造函数
  /// 初始化Dio拦截器，自动添加认证令牌
  ApiService() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        // 请求拦截器 - 在发送请求前自动添加认证令牌
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('token');
          if (token != null) {
            // 添加Bearer令牌到请求头
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  /// updateBaseUrl - 动态更新基础URL
  /// 用于在不同平台运行时切换API地址
  void updateBaseUrl(String url) {
    _dio.options.baseUrl = url;
  }

  /// get - GET请求方法
  /// path: 请求路径, queryParameters: 查询参数
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return await _dio.get(path, queryParameters: queryParameters);
  }

  /// post - POST请求方法
  /// path: 请求路径, data: 请求数据
  Future<Response> post(String path, {dynamic data}) async {
    return await _dio.post(path, data: data);
  }
}
