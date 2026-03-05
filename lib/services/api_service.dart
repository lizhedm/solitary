import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ApiService - API服务类
/// 封装Dio HTTP客户端，用于与后端服务器通信
class ApiService {
  // 单例实例
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  late final Dio _dio;

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: 'http://114.55.148.245:8000', // 云端后端地址，默认统一访问云服务器
        connectTimeout: const Duration(seconds: 30), // 连接超时时间
        receiveTimeout: const Duration(seconds: 60), // 接收超时时间
      ),
    );
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
        onResponse: (Response response, ResponseInterceptorHandler handler) {
          // 简单日志，帮助排错
          // ignore: avoid_print
          print(
            '[ApiService] ${response.requestOptions.method} ${response.requestOptions.uri} -> ${response.statusCode}',
          );
          print('[ApiService] Response data: ${response.data}');
          return handler.next(response);
        },
        onError: (DioError error, ErrorInterceptorHandler handler) {
          // 打印错误信息，便于排错
          // ignore: avoid_print
          print('[ApiService] Error: ${error.type} ${error.message}');
          if (error.response != null) {
            print('[ApiService] Error response: ${error.response?.data}');
          }
          return handler.next(error);
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
  Future<Response> post(String path, {dynamic data, Options? options}) async {
    return await _dio.post(path, data: data, options: options);
  }
}
