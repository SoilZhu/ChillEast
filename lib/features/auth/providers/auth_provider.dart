import 'dart:io';
import 'package:dio/dio.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/cookie_manager.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/secure_storage_helper.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../workspace/services/campus_card_service.dart';

final authServiceProvider = Provider((ref) {
  final campusCardService = ref.read(campusCardServiceProvider);
  return AuthService(campusCardService);
});

class AuthService {
  final _logger = AppLogger.instance;
  final CampusCardService _campusCardService;

  AuthService(this._campusCardService);
  
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
        
        localAvatarPath = results[0] as String?;
        openid = results[1] as String?;
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
    _logger.i('🔐 Manual login attempt for $username...');
    await _loginWithWebView(username, password);
    
    // 登录成功后保存凭据
    await SecureStorageHelper().saveUsername(username);
    await SecureStorageHelper().savePassword(password);
  }

  /// 静默登录入口 (后台自动登录)
  Future<void> silentLogin() async {
    final username = await SecureStorageHelper().getUsername();
    final password = await SecureStorageHelper().getPassword();

    if (username == null || password == null) {
      throw AppException('无保存的凭据');
    }

    _logger.i('🔄 Auto-login attempt for $username...');
    // 💡 优化：清除 SSO 和 Portal Cookie 让其重新登录
    await AppCookieManager().clearSsoCookies();
    await _loginWithWebView(username, password);
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

  Future<void> _loginWithWebView(String username, String password) async {
    _logger.d('🚀 Starting HeadlessInAppWebView for SSO login...');

    final completer = Completer<void>();
    bool isLoginSubmitted = false;
    bool isLoginSuccess = false;
    HeadlessInAppWebView? webView;

    try {
      // 使用带service参数的CAS登录URL,登录后自动跳转到portal
      const ssoLoginUrl = 'https://sso.hunau.edu.cn/cas/login?service=https%3A%2F%2Fportal.hunau.edu.cn%2Flogin';

      webView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(ssoLoginUrl)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          useShouldOverrideUrlLoading: false,
          supportMultipleWindows: true,
          javaScriptCanOpenWindowsAutomatically: true,
          userAgent: 'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/147.0.0.0 Mobile Safari/537.36',
          mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
          loadsImagesAutomatically: false, // 🚀 Speed up: Don't load images in headless mode
          disableDefaultErrorPage: true,
        ),
        onLoadStart: (controller, url) async {
          final urlString = url?.toString() ?? '';
          _logger.d('🚀 onLoadStart: $urlString');

          // 1. 登录页面检测与自动注入
          final isLoginPage = urlString.contains('/cas/login') || 
                              urlString.contains('/authn/login.html') ||
                              urlString.contains('sso.hunau.edu.cn');
                              
          if (isLoginPage && !isLoginSubmitted && !isLoginSuccess) {
            _logger.d('🔐 Detected SSO login page, preparing injection...');
            
            // 使用 evaluateJavascript 的异步特性，并在脚本内部处理重试逻辑
            final result = await controller.evaluateJavascript(source: '''
              (async function() {
                const sleep = (ms) => new Promise(r => setTimeout(r, ms));
                
                for (let i = 0; i < 20; i++) {
                  // console.log('=== JS Login Injection Attempt ' + (i+1) + ' ===');
                  
                  // A. 安全检查 body 是否存在
                  if (!document.body) {
                    await sleep(500);
                    continue;
                  }

                  // B. 检查页面报错文本
                  const findError = () => {
                    const texts = ['密码错误', '账号或密码不正确', '验证码错误', '失败', '非法'];
                    const bodyText = document.body.innerText || '';
                    for (let t of texts) {
                      if (bodyText.includes(t)) return t;
                    }
                    return null;
                  };

                  const err = findError();
                  if (err) return 'LOGIN_ERROR: ' + err;

                  // C. 定义深度探测函数 (支持 iframe)
                  const queryInside = (selector) => {
                    let el = document.querySelector(selector);
                    if (el) return el;
                    const frames = document.querySelectorAll('iframe');
                    for (const f of frames) {
                      try {
                        let doc = f.contentDocument || f.contentWindow.document;
                        let e = doc.querySelector(selector);
                        if (e) return e;
                      } catch (e) {}
                    }
                    return null;
                  };

                  // D. 账号密码匹配
                  const userIn = queryInside('input.email-username') || queryInside('input[name="username"]');
                  const passIn = queryInside('input[name="authcode"]') || queryInside('input[type="password"]');
                  
                  if (userIn && passIn) {
                    userIn.value = '$username';
                    passIn.value = '$password';
                    console.log('JS: Fields filled');

                    let btn = queryInside('button.exeActionBtn') || 
                              queryInside('input[type="submit"]') ||
                              queryInside('button[type="submit"]') ||
                              queryInside('.login-btn');
                    
                    if (btn) {
                      console.log('JS: Clicking button');
                      btn.click();
                      return 'SUBMITTED_VIA_CLICK';
                    } else if (userIn.form) {
                      console.log('JS: Submitting form');
                      userIn.form.submit();
                      return 'SUBMITTED_VIA_FORM';
                    }
                  }

                  await sleep(500); // 🚀 Faster polling (1000ms -> 500ms)
                }
                return 'NOT_FOUND';
              })();
            ''');

            _logger.d('💉 Injection result: $result');
            if (result != null) {
              final resStr = result.toString();
              if (resStr.contains('SUBMITTED')) {
                isLoginSubmitted = true;
              } else if (resStr.contains('LOGIN_ERROR')) {
                if (!completer.isCompleted) completer.completeError(AppException(resStr));
              }
            }
          }
        },
        onLoadStop: (controller, url) async {
          final urlString = url?.toString() ?? '';
          _logger.d('🏁 onLoadStop: $urlString');
          
          // 2. 成功判定：到达 portal.hunau.edu.cn (登录后自动跳转)
          final isPortalSuccess = urlString.contains('portal.hunau.edu.cn') && !urlString.contains('/cas/login');
          
          if (isPortalSuccess && !isLoginSuccess) {
            isLoginSuccess = true;
            _logger.i('✅ Login successful, reached portal: $urlString');

            // 🚀 优化：删除了冗余的 WebVPN 授权激活和会话轮询逻辑
            // 课表同步已拥有独立的 WebView 登录链，此处直接同步 Cookie 以提速。
            
            // 4. 同步所有域名的 Cookie 到 Dio
            _logger.i('🍪 Syncing multi-domain cookies...');
            await AppCookieManager().syncMultiDomainCookiesFromWebView();
            
            // 5. 🚀 优化：此处原本有一个复杂的融合门户 Token 获取逻辑 (Token sync)
            // 但根据日志和目前的架构，该逻辑不再必要（返回登录页且已迁移至新 API），故移除以提速。
            if (!completer.isCompleted) completer.complete();
          }
        },
        onConsoleMessage: (controller, consoleMessage) {
          _logger.d('🌐 [WebView] ${consoleMessage.message}');
        },
      );

      await webView.run();
      await completer.future.timeout(const Duration(seconds: 60));
    } catch (e) {
      _logger.e('⛔ WebView Login Failed: $e');
      rethrow;
    } finally {
      webView?.dispose();
    }
  }
}
