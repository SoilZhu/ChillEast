import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/cookie_manager.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/secure_storage_helper.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/utils/app_logger.dart';
import '../services/http_login_service.dart';
import '../services/portal_identity.dart';

final authServiceProvider = Provider((ref) => AuthService());

class AuthService {
  final _logger = AppLogger.instance;

  final HttpLoginService _httpLoginService;

  AuthService({HttpLoginService? httpLoginService})
      : _httpLoginService = httpLoginService ??
            HttpLoginService(
                onProgress: (message) => _logLoginProgress(message));

  PortalIdentity? _lastLoginProfile;
  int _sessionGeneration = 0;

  /// Reuse the authenticated HTML parsed in this login attempt. Campus-card
  /// OAuth is started once by AuthNotifier and must not block profile rendering.
  Future<Map<String, String?>> fetchFullUserInfo() async {
    if (_loginInProgress) return {};
    final generation = _sessionGeneration;
    try {
      final dio = DioClient().dio;
      String? uid = await AppCookieManager()
          .getCookieValue('https://passport2.chaoxing.com', 'UID');
      uid ??= await AppCookieManager()
          .getCookieValue('https://passport2.chaoxing.com', '_uid');
      if (uid == null || uid.isEmpty) return {};

      var profile = _lastLoginProfile;
      if (profile == null) {
        // Compatibility fallback for an unrecognized portal layout or a
        // profile refresh not preceded by this service's login in this process.
        final response = await dio.get(AppConstants.portalIndexUrl);
        if (response.statusCode == 200 && response.data != null) {
          profile = PortalIdentity.parse(response.data.toString());
        }
      }
      final avatar = await _fetchAvatar(uid, dio);
      if (generation != _sessionGeneration || _loginInProgress) return {};
      return {
        'realName': profile?.realName,
        'username': profile?.username,
        'uid': uid,
        'avatarUrl': avatar,
      };
    } catch (_) {
      _logger.w('用户资料刷新失败，保留现有资料');
      return {};
    }
  }

  /// Follow redirects manually, then save the response already downloaded.
  /// Avoid GETting the image once to inspect it and downloading it a second time.
  Future<String?> _fetchAvatar(String uid, Dio dio) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final savePath = p.join(directory.path, 'avatar_$uid.png');
      var uri = Uri.parse(AppConstants.fusionAvatarUrl(uid));
      for (var redirect = 0; redirect < 5; redirect++) {
        final response = await dio.get<List<int>>(uri.toString(),
            options: Options(
              responseType: ResponseType.bytes,
              followRedirects: false,
              validateStatus: (status) => status != null && status < 500,
            ));
        if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          if (location == null) return null;
          final next = uri.resolve(location);
          if (next.scheme != 'https' ||
              next.userInfo.isNotEmpty ||
              next.path.contains('/cas/login') ||
              next.host.startsWith('passport')) {
            return null;
          }
          uri = next;
          continue;
        }
        final type =
            response.headers.value(HttpHeaders.contentTypeHeader) ?? '';
        final bytes = response.data;
        if (response.statusCode != 200 ||
            !type.toLowerCase().startsWith('image/') ||
            bytes == null ||
            bytes.isEmpty) {
          return null;
        }
        await File(savePath).writeAsBytes(bytes);
        return savePath;
      }
    } catch (_) {
      _logger.d('头像更新跳过');
    }
    return null;
  }

  /// 轻量探测持久化 Cookie 对应的会话是否仍然有效。
  /// 只读、不清理、不重登，供启动时决定直接复用还是走完整静默登录。
  /// 判定顺序：先找"已登录"的正向证明（解析门户身份），再看被踢下线的
  /// 反向信号。顺序不能反——已登录页内也可能内嵌 cas/login 字符串。
  /// 任何异常（无网络等）都视为无效，走静默登录兜底。
  Future<bool> hasValidPersistedSession() async {
    try {
      final dio = DioClient().dio;
      final response = await dio.get<String>(
        AppConstants.portalIndexUrl,
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: true,
          validateStatus: (status) => status != null && status < 500,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final body = response.data ?? '';
      final identity = PortalIdentity.parse(body);
      final kickedToLogin =
          response.realUri.path.contains('/cas/login') ||
              body.contains('/cas/login');
      _logger.i('Session probe: status=${response.statusCode} '
          'finalUri=${response.realUri} bodyLen=${body.length} '
          'identity=${identity != null} kickedToLogin=$kickedToLogin');
      return identity != null;
    } catch (_) {
      return false;
    }
  }

  /// 核心登录入口
  Future<void> login(String username, String password) async {
    final total = Stopwatch()..start();
    _logLoginProgress('Starting HTTP login...');
    await _loginWithHttp(username, password);

    // 登录成功后保存凭据
    final storageClock = Stopwatch()..start();
    await SecureStorageHelper().saveUsername(username);
    await SecureStorageHelper().savePassword(password);
    _logLoginProgress(
        'HTTP 登录[凭据保存] elapsedMs=${storageClock.elapsedMilliseconds}, loginTotalMs=${total.elapsedMilliseconds}');
  }

  /// 静默登录入口 (后台自动登录)
  Future<void> silentLogin({String? username, String? password}) async {
    if (username == null || password == null) {
      final snapshot = await SecureStorageHelper().readAuthSnapshot();
      username = snapshot.username;
      password = snapshot.password;
    }

    if (username == null || password == null) {
      throw const AppException('无保存的凭据');
    }

    _logLoginProgress('Starting silent HTTP login...');
    await _loginWithHttp(username, password);
  }

  /// 退出登录
  Future<void> logout() async {
    _sessionGeneration++;
    _lastLoginProfile = null;
    _logger.i('🚪 Logging out...');
    await SecureStorageHelper().clearAll();
    await _clearCookies();
  }

  Future<void> _clearCookies() async {
    _logger.d('Clearing cookies...');
    await AppCookieManager().clearAllCookies();
  }

  bool _loginInProgress = false;

  Future<void> _loginWithHttp(String username, String password) async {
    if (_loginInProgress) {
      throw const AuthException('登录正在进行中，请稍候');
    }
    _loginInProgress = true;
    final generation = ++_sessionGeneration;
    _lastLoginProfile = null;
    final totalClock = Stopwatch()..start();
    final phaseClock = Stopwatch()..start();
    final cookieManager = AppCookieManager();
    try {
      // Both manual and silent login discard old SSO/portal cookies. The HTTP
      // service also uses its own empty jar, never importing persisted cookies.
      await cookieManager.clearSsoCookies();
      _logLoginProgress(
          'HTTP 登录[清理旧 Cookie] elapsedMs=${phaseClock.elapsedMilliseconds}');
      phaseClock.reset();
      final result = await _httpLoginService.login(username, password);
      _logLoginProgress(
          'HTTP 登录[认证网络链] elapsedMs=${phaseClock.elapsedMilliseconds}, requests=${result.requestCount}');
      phaseClock.reset();
      if (generation != _sessionGeneration) {
        throw const AuthException('登录已取消');
      }
      await cookieManager.saveHttpLoginCookies(result.cookies,
          onProgress: _logLoginProgress);
      if (generation != _sessionGeneration) {
        await cookieManager.clearSsoCookies();
        throw const AuthException('登录已取消');
      }
      _lastLoginProfile = result.profile;
      _logLoginProgress(
          'HTTP 登录[发布新 Cookie] elapsedMs=${phaseClock.elapsedMilliseconds}, readyMs=${totalClock.elapsedMilliseconds}');
      _logLoginProgress('HTTP login successful; fresh cookies synchronized');
    } on AppException catch (error) {
      _logLoginProgress('HTTP 登录未完成：${error.message}');
      rethrow;
    } finally {
      _loginInProgress = false;
    }
  }
}

// Keep this narrowly scoped to redacted authentication telemetry. Debug APKs
// launched outside flutter run may not enable assertions, which otherwise makes
// Logger's DevelopmentFilter silently discard the timing measurements.
void _logLoginProgress(String message) {
  if (kDebugMode) debugPrint(message);
}
