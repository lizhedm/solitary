import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ApiService - API服务类
/// 封装Dio HTTP客户端，用于与后端服务器通信
class ApiService {
  // Dio HTTP客户端实例
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'http://localhost:8000', // 默认localhost，运行时可通过updateBaseUrl更新
      connectTimeout: const Duration(seconds: 10), // 连接超时时间10秒
      receiveTimeout: const Duration(seconds: 10), // 接收超时时间10秒
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
