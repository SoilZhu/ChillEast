import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart' as dio_cookie;
import '../constants/app_constants.dart';
import '../exceptions/app_exceptions.dart';
import 'cookie_manager.dart';
import '../utils/app_logger.dart';
import 'package:logger/logger.dart';

/// Dio 网络请求单例封装
class DioClient {
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;
  
  DioClient._internal();
  
  late final Dio _dio;
  final Logger _logger = AppLogger.instance;
  bool _initialized = false;
  
  /// 初始化 Dio
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // 初始化 CookieManager
      await AppCookieManager().initialize();
      
      // 创建 Dio 实例
      _dio = Dio(BaseOptions(
        baseUrl: AppConstants.portalBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/147.0.0.0 Safari/537.36 Edg/147.0.0.0',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        },
        followRedirects: true, // 启用自动重定向，CAS 登录需要跟随 302
        maxRedirects: 10, // 最大重定向次数
        validateStatus: (status) => status != null && status < 500, // 接受所有非 5xx 状态码
      ));
      
      // 添加 Cookie 管理器拦截器
      _dio.interceptors.add(dio_cookie.CookieManager(AppCookieManager().dioCookieJar));
      
      // 添加日志拦截器 (精简版：仅记录请求行和错误，并强制使用 UTF-8 输出)
      _dio.interceptors.add(LogInterceptor(
        request: true,
        requestHeader: false,
        requestBody: false,
        responseHeader: false,
        responseBody: false,
        error: true,
        logPrint: (obj) => _logger.d(obj.toString()),
      ));
      
      _initialized = true;
      _logger.i('DioClient initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize DioClient: $e');
      throw NetworkException('DioClient 初始化失败: $e');
    }
  }
  
  /// 获取 Dio 实例
  Dio get dio {
    if (!_initialized) {
      throw NetworkException('DioClient 未初始化,请先调用 initialize()');
    }
    return _dio;
  }
  
  /// GET 请求
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      _logger.e('GET request failed: $e');
      throw NetworkException('网络请求失败: ${e.message}', code: e.response?.statusCode.toString());
    } catch (e) {
      _logger.e('Unexpected error in GET request: $e');
      throw NetworkException('未知错误: $e');
    }
  }
  
  /// POST 请求
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      _logger.e('POST request failed: $e');
      throw NetworkException('网络请求失败: ${e.message}', code: e.response?.statusCode.toString());
    } catch (e) {
      _logger.e('Unexpected error in POST request: $e');
      throw NetworkException('未知错误: $e');
    }
  }
  
  /// 静态辅助方法：获取标准请求配置
  static Options getOptions({String? referer, bool isXmlHttpRequest = false}) {
    final headers = <String, dynamic>{};
    if (referer != null) {
      headers['Referer'] = referer;
    }
    if (isXmlHttpRequest) {
      headers['X-Requested-With'] = 'XMLHttpRequest';
    }
    return Options(headers: headers);
  }

  /// 销毁 DioClient
  Future<void> dispose() async {
    try {
      _dio.close(force: true);
      await AppCookieManager().dispose();
      _initialized = false;
      _logger.i('DioClient disposed');
    } catch (e) {
      _logger.e('Failed to dispose DioClient: $e');
    }
  }
}
