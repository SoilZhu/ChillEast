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

  static const int _maxRedirects = 10;

  bool _isRedirect(int? status) =>
      status == 301 ||
      status == 302 ||
      status == 303 ||
      status == 307 ||
      status == 308;

  /// 执行学工系统CAS登录流程
  ///
  /// 流程:
  /// 1. 访问SSO获取Service Ticket (使用已登录的SSO cookie)
  /// 2. 携带Ticket访问学工CAS,手动跟随重定向链完成会话建立
  /// 3. 校验最终落点仍在学工侧且JSESSIONID已落jar
  ///
  /// Step 2 必须手动跟随重定向:Dio 的自动跟随在 adapter 层内部完成,
  /// CookieManager 拦截器看不到中间跳转,中间响应 Set-Cookie 的
  /// JSESSIONID 不会被带到下一跳,服务端会认为是全新未认证会话,
  /// 最终又弹回 SSO 登录页。每跳单独发请求,拦截器才能正常挂/存 cookie。
  Future<void> performXgxtCasLogin() async {
    try {
      _logger.i('🎓 Starting XGXT CAS login...');
      final dio = DioClient().dio;

      // Step 1: 访问SSO获取Service Ticket
      // SSO会检测到用户已登录(有TGC cookie),直接返回重定向带ticket
      _logger.d('Step 1: Requesting service ticket from SSO...');
      final ssoResponse = await dio.get(
        AppConstants.ssoLoginUrl,
        queryParameters: {
          'service': AppConstants.xgxtCasUrl,
        },
        options: Options(
          followRedirects: false, // 不自动跟随重定向,我们需要获取ticket
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      // SSO 直接返回 200 登录页,说明 TGC 已失效,需要先刷新统一认证。
      if (ssoResponse.statusCode == 200) {
        throw const NetworkException('统一认证已过期,请重新登录');
      }

      // 从Location header中提取ticket
      String? ticket;
      if (_isRedirect(ssoResponse.statusCode)) {
        final location = ssoResponse.headers.value('location');
        if (location != null && location.isNotEmpty) {
          ticket = Uri.parse(AppConstants.ssoLoginUrl)
              .resolve(location)
              .queryParameters['ticket'];
          if (ticket != null && ticket.isNotEmpty) {
            final preview = ticket.length > 20 ? ticket.substring(0, 20) : ticket;
            _logger.d('Extracted ticket: $preview...');
          }
        }
      }

      if (ticket == null || ticket.isEmpty) {
        throw const NetworkException('无法获取Service Ticket,可能未登录或登录已过期');
      }

      // Step 2: 使用Ticket验证,手动跟随重定向链,获取学工系统的JSESSIONID
      _logger.d('Step 2: Validating ticket with XGXT CAS...');
      var currentUri = Uri.parse(AppConstants.xgxtCasUrl)
          .replace(queryParameters: {'ticket': ticket});
      Response? lastResponse;
      for (var i = 0; i < _maxRedirects; i++) {
        lastResponse = await dio.getUri(
          currentUri,
          options: Options(
            followRedirects: false,
            validateStatus: (status) => status != null && status < 500,
            responseType: ResponseType.plain,
            headers: {
              'Accept':
                  'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            },
          ),
        );
        if (!_isRedirect(lastResponse.statusCode)) break;
        final location = lastResponse.headers.value('location');
        if (location == null || location.isEmpty) break;
        currentUri = currentUri.resolve(location);
        _logger.d('Redirect hop $i -> $currentUri');
      }

      // Step 3: 校验落点。Ticket 无效时学工 CAS 会把我们踢回 SSO,
      // 最终落点 host 会变回顾 SSO 侧,此时绝不能算登录成功。
      final xgxtHost = Uri.parse(AppConstants.xgxtBaseUrl).host;
      if (currentUri.host != xgxtHost) {
        throw NetworkException(
            '学工系统CAS验证失败: 最终落点不在学工系统(${currentUri.host})');
      }
      final body = lastResponse?.data;
      if (body is String &&
          body.contains('<html') &&
          body.contains('cas/login')) {
        throw const NetworkException('学工系统CAS验证失败: 会话未建立');
      }

      // Cookie已经通过Dio的CookieManager逐跳自动保存,
      // 这里只做存在性校验:JSESSIONID 缺席说明会话没建起来。
      try {
        final cookies = await AppCookieManager()
            .dioCookieJar
            .loadForRequest(Uri.parse(AppConstants.xgxtBaseUrl));

        final jsessionid = cookies.firstWhere(
          (c) => c.name == 'JSESSIONID' && c.value.isNotEmpty,
          orElse: () => io.Cookie('', ''),
        );

        if (jsessionid.value.isEmpty) {
          throw const NetworkException('学工系统会话建立失败,请重试');
        }
        _logger.i('✅ XGXT CAS login successful, JSESSIONID acquired');
      } catch (e) {
        if (e is NetworkException) rethrow;
        _logger.w('⚠️ Could not verify JSESSIONID: $e');
        throw const NetworkException('学工系统会话校验失败,请重试');
      }
    } on DioException catch (e) {
      _logger.e('❌ Dio error during XGXT CAS login: ${e.message}');
      if (e.response?.statusCode == 401) {
        throw const NetworkException('未登录或登录已过期，请重新登录');
      }
      throw NetworkException('网络请求失败: ${e.message}');
    } catch (e) {
      if (e is NetworkException) rethrow;
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
      _logger.e('❌ Failed to fetch XGXT home page: $e');
      rethrow;
    }
  }
}
