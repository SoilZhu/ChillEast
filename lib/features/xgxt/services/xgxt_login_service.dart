import 'dart:io' as io;
import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/cookie_manager.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/exceptions/app_exceptions.dart';
import 'package:logger/logger.dart';

/// 学工系统登录服务
/// 负责通过CAS SSO获取学工系统的会话
class XgxtLoginService {
  final Logger _logger = Logger();
  
  /// 执行学工系统CAS登录流程
  /// 
  /// 流程:
  /// 1. 访问SSO获取Service Ticket (使用已登录的SSO cookie)
  /// 2. 使用Ticket验证,获取学工系统的JSESSIONID
  /// 3. Cookie会自动保存到Dio的CookieJar中
  Future<void> performXgxtCasLogin() async {
    try {
      _logger.i('🎓 Starting XGXT CAS login...');
      
      // Step 1: 访问SSO获取Service Ticket
      // SSO会检测到用户已登录(有TGC cookie),直接返回重定向带ticket
      _logger.d('Step 1: Requesting service ticket from SSO...');
      final ssoResponse = await DioClient().dio.get(
        AppConstants.ssoLoginUrl,
        queryParameters: {
          'service': AppConstants.xgxtCasUrl,
        },
        options: Options(
          followRedirects: false, // 不自动跟随重定向,我们需要获取ticket
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      
      // 从Location header中提取ticket
      String? ticket;
      if (ssoResponse.statusCode == 302 || ssoResponse.statusCode == 301) {
        final location = ssoResponse.headers.value('location');
        if (location != null) {
          final uri = Uri.parse(location);
          ticket = uri.queryParameters['ticket'];
          _logger.d('Extracted ticket: ${ticket?.substring(0, ticket!.length > 20 ? 20 : ticket.length)}...');
        }
      }
      
      if (ticket == null || ticket.isEmpty) {
        throw const NetworkException('无法获取Service Ticket,可能未登录或登录已过期');
      }
      
      // Step 2: 使用Ticket验证,获取学工系统的JSESSIONID
      _logger.d('Step 2: Validating ticket with XGXT CAS...');
      final casResponse = await DioClient().dio.get(
        AppConstants.xgxtCasUrl,
        queryParameters: {
          'ticket': ticket,
        },
        options: Options(
          followRedirects: true, // 允许重定向
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      
      if (casResponse.statusCode == 200 || casResponse.statusCode == 302) {
        _logger.i('✅ XGXT CAS login successful, JSESSIONID acquired');
        
        // Cookie已经通过Dio的CookieManager自动保存
        // 可以通过检查CookieJar来验证
        try {
          final cookies = await AppCookieManager().dioCookieJar
              .loadForRequest(Uri.parse(AppConstants.xgxtBaseUrl));
          
          if (cookies.isNotEmpty) {
            final jsessionid = cookies.firstWhere(
              (c) => c.name == 'JSESSIONID',
              orElse: () => io.Cookie('', ''),
            );
            
            if (jsessionid.value.isNotEmpty) {
              _logger.d('JSESSIONID: ${jsessionid.value}');
            }
          }
        } catch (e) {
          _logger.w('⚠️ Could not verify JSESSIONID: $e');
        }
      } else {
        throw NetworkException('学工系统CAS验证失败: HTTP ${casResponse.statusCode}');
      }
      
    } on DioException catch (e) {
      _logger.e('❌ Dio error during XGXT CAS login: ${e.message}');
      if (e.response?.statusCode == 401) {
        throw const NetworkException('未登录或登录已过期，请重新登录');
      }
      throw NetworkException('网络请求失败: ${e.message}');
    } catch (e) {
      _logger.e('❌ Unexpected error during XGXT CAS login: $e');
      throw NetworkException('学工系统登录失败: ${e.toString()}');
    }
  }
  
  /// 访问学工系统主页 (需要先执行CAS登录)
  Future<Response> fetchXgxtHomePage() async {
    try {
      _logger.i('🏠 Fetching XGXT home page...');
      
      final response = await DioClient().dio.get(
        AppConstants.xgxtWapUrl,
        options: Options(
          headers: {
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          },
        ),
      );
      
      if (response.statusCode == 200) {
        _logger.i('✅ Successfully fetched XGXT home page');
        return response;
      } else {
        throw NetworkException('获取学工主页失败: HTTP ${response.statusCode}');
      }
    } on DioException catch (e) {
      _logger.e('❌ Failed to fetch XGXT home page: ${e.message}');
      rethrow;
    }
  }
}
