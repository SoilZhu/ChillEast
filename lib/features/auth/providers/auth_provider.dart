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
import '../../workspace/services/campus_card_service.dart';
import '../services/http_login_service.dart';

final authServiceProvider = Provider((ref) {
  final campusCardService = ref.read(campusCardServiceProvider);
  return AuthService(campusCardService);
});

class AuthService {
  final _logger = AppLogger.instance;
  final CampusCardService _campusCardService;

  final HttpLoginService _httpLoginService;

  AuthService(this._campusCardService, {HttpLoginService? httpLoginService})
      : _httpLoginService = httpLoginService ??
            HttpLoginService(onProgress: (message) => AppLogger.instance.i(message));

  /// 获取详细的用户资料（姓名、学号、头像）
  Future<Map<String, String?>> fetchFullUserInfo() async {
    try {
      final dio = DioClient().dio;
      
      // 1. 优先从 Cookie 中提取 UID
      String? cookieUid = await AppCookieManager().getCookieValue('https://passport2.chaoxing.com', 'UID');
      cookieUid ??= await AppCookieManager().getCookieValue('https://passport2.chaoxing.com', '_uid');
      
      // 🚀 优化：立即启动校园卡授权，与资料获取并行
      final authFuture = _campusCardService.authenticate();
      
      String? realName;
      String? uname;

      // 2. 尝试从门户首页 HTML 解析资料
      try {
        final response = await dio.get(AppConstants.portalIndexUrl);
        if (response.statusCode == 200 && response.data != null) {
          final String html = response.data.toString();
          final infoTxtMatch = RegExp(r'<div class="infoTxt">([\s\S]*?)<\/div>').firstMatch(html);
          
          if (infoTxtMatch != null) {
            final infoHtml = infoTxtMatch.group(1)!;
            final nameMatch = RegExp(r'<em>(.*?)<\/em>').firstMatch(infoHtml);
            if (nameMatch != null) realName = nameMatch.group(1);
            
            final unameMatch = RegExp(r'学号：(\d+)').firstMatch(infoHtml);
            if (unameMatch != null) uname = unameMatch.group(1);
          }
        }
      } catch (e) {
        _logger.w('⚠️ User profile parsing failed: $e');
      }

      // 3. 确定最终 UID
      final finalUid = cookieUid;
      if (finalUid == null) {
        _logger.e('❌ No UID found');
        return {};
      }

      _logger.i('👤 Profile: $realName ($uname)');

      // 4. 等待头像下载和授权结果完成
      String? localAvatarPath;
      String? openid;

      try {
        final results = await Future.wait([
          _fetchAvatar(finalUid, dio),
          authFuture,
        ]);
        
        localAvatarPath = results[0];
        openid = results[1];
      } catch (e) {
        _logger.w('⚠️ Parallel task error: $e');
      }
      
      return {
        'realName': realName,
        'username': uname,
        'uid': finalUid,
        'avatarUrl': localAvatarPath,
        'openid': openid,
      };
    } catch (e) {
      _logger.e('❌ Profile retrieval error: $e');
      return {};
    }
  }

  /// 私有辅助方法：获取头像
  Future<String?> _fetchAvatar(String uid, Dio dio) async {
    try {
      final avatarApiUrl = AppConstants.fusionAvatarUrl(uid);
      final tempDir = await getApplicationDocumentsDirectory();
      final savePath = p.join(tempDir.path, 'avatar_$uid.png');
      
      String finalUrl = avatarApiUrl;
      int redirectCount = 0;
      
      while (redirectCount < 5) {
        final headRes = await dio.get(
          finalUrl,
          options: Options(
            followRedirects: false, 
            validateStatus: (status) => status! < 500,
          ),
        );

        if (headRes.statusCode == 302 || headRes.statusCode == 301) {
          String? location = headRes.headers.value('location');
          if (location == null) break;
          if (location.startsWith('/')) {
            final uri = Uri.parse(finalUrl);
            location = '${uri.scheme}://${uri.host}$location';
          }
          if (location.contains('cas/login') || location.contains('passport2.chaoxing.com/login')) {
            finalUrl = '';
            break;
          }
          finalUrl = location;
          redirectCount++;
        } else {
          break;
        }
      }

      if (finalUrl.isNotEmpty) {
        final downloadRes = await dio.download(finalUrl, savePath);
        final contentType = downloadRes.headers.value('content-type') ?? '';
        if (!contentType.contains('text/html') && !contentType.contains('application/json')) {
          _logger.d('🖼️ Avatar updated');
          return savePath;
        }
      }
    } catch (e) {
      _logger.d('⚠️ Avatar sync skipped: $e');
    }
    return null;
  }

  /// 核心登录入口
  Future<void> login(String username, String password) async {
    _logger.i('🔐 Starting HTTP login...');
    await _loginWithHttp(username, password);

    // 登录成功后保存凭据
    await SecureStorageHelper().saveUsername(username);
    await SecureStorageHelper().savePassword(password);
  }

  /// 静默登录入口 (后台自动登录)
  Future<void> silentLogin() async {
    final username = await SecureStorageHelper().getUsername();
    final password = await SecureStorageHelper().getPassword();

    if (username == null || password == null) {
      throw const AppException('无保存的凭据');
    }

    _logger.i('🔄 Starting silent HTTP login...');
    await _loginWithHttp(username, password);
  }

  /// 退出登录
  Future<void> logout() async {
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
    final cookieManager = AppCookieManager();
    try {
      // Both manual and silent login discard old SSO/portal cookies. The HTTP
      // service also uses its own empty jar, never importing persisted cookies.
      await cookieManager.clearSsoCookies();
      final cookies = await _httpLoginService.login(username, password);
      await cookieManager.saveHttpLoginCookies(cookies);
      _logger.i('✅ HTTP login successful; fresh cookies synchronized');
    } on AppException catch (error) {
      _logger.w('HTTP 登录未完成：${error.message}');
      rethrow;
    } finally {
      _loginInProgress = false;
    }
  }
}
