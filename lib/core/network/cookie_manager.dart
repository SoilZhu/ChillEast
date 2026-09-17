import 'dart:io' as io;
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as webview;
import 'package:path_provider/path_provider.dart';
import '../constants/app_constants.dart';
import '../exceptions/app_exceptions.dart';
import 'package:logger/logger.dart';

/// 全局 Cookie 管理器
/// 负责在 Dio 和 InAppWebView 之间同步和持久化 Cookie
class AppCookieManager {
  static final AppCookieManager _instance = AppCookieManager._internal();
  factory AppCookieManager() => _instance;
  
  AppCookieManager._internal();
  
  final Logger _logger = Logger();
  
  // Dio 的 CookieJar
  late final PersistCookieJar _dioCookieJar;
  
  // InAppWebView 的 CookieManager
  late final webview.CookieManager _webViewCookieManager;
  
  bool _initialized = false;
  
  /// 初始化 CookieManager
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // 获取应用文档目录 (可写)
      final appDocDir = await getApplicationDocumentsDirectory();
      final cookiePath = '${appDocDir.path}/.cookies';
      
      // 初始化 Dio CookieJar
      _dioCookieJar = PersistCookieJar(
        ignoreExpires: false,
        storage: FileStorage(cookiePath),
      );
      
      // 初始化 WebView CookieManager
      _webViewCookieManager = webview.CookieManager.instance();
      
      _initialized = true;
      _logger.i('AppCookieManager initialized successfully at: $cookiePath');
    } catch (e) {
      _logger.e('Failed to initialize AppCookieManager: $e');
      throw CookieException('CookieManager 初始化失败: $e');
    }
  }
  
  /// 获取 Dio CookieJar
  PersistCookieJar get dioCookieJar {
    if (!_initialized) {
      throw const CookieException('CookieManager 未初始化,请先调用 initialize()');
    }
    return _dioCookieJar;
  }
  
  /// 清除所有 SSO 和 Portal 相关的 Cookie
  Future<void> clearSsoCookies() async {
    if (!_initialized) await initialize();

    try {
      // 清除 Dio 中的 SSO 和 Portal Cookie
      final domains = [
        AppConstants.ssoBaseUrl,
        AppConstants.portalBaseUrl,
        'https://passport2.chaoxing.com',
        'https://passport2-api.chaoxing.com',
      ];

      // Delete the entire host, including /cas, /authn and /portal paths.
      // Expiring only cookies visible at "/" leaves path-scoped TGC/session
      // cookies behind. Sequential deletes also avoid persistence write races.
      for (final domain in domains) {
        await _dioCookieJar.delete(Uri.parse(domain), true);
      }

      // 清除 WebView 中的所有 Cookie
      await _webViewCookieManager.deleteAllCookies();

      _logger.i('✅ SSO and Portal cookies cleared successfully');
    } catch (e) {
      _logger.e('Failed to clear SSO cookies: $e');
      throw CookieException('清除 SSO Cookie 失败: $e');
    }
  }

  /// Publish a successful, fresh HTTP session to Dio and WebView.
  /// Preserve host-only scope, path, expiry, Secure and HttpOnly attributes.
  Future<void> saveHttpLoginCookies(Map<Uri, List<io.Cookie>> cookies, {void Function(String)? onProgress}) async {
    if (!_initialized) await initialize();
    try {
      final storageBatches = <Uri, List<io.Cookie>>{};
      final webViewGroups = <String, List<MapEntry<Uri, io.Cookie>>>{};
      var cookieCount = 0;
      for (final entry in cookies.entries) {
        final origin = Uri(scheme: entry.key.scheme, host: entry.key.host,
            port: entry.key.hasPort ? entry.key.port : null, path: '/');
        for (final cookie in entry.value) {
          // Batch by origin only after making the original default path explicit.
          if (cookie.path == null || !cookie.path!.startsWith('/')) {
            final slash = entry.key.path.lastIndexOf('/');
            cookie.path = slash <= 0 ? '/' : entry.key.path.substring(0, slash);
          }
          storageBatches.putIfAbsent(origin, () => []).add(cookie);
          final scope = (cookie.domain ?? entry.key.host)
              .replaceFirst(RegExp(r'^\.'), '').toLowerCase();
          webViewGroups.putIfAbsent(scope, () => []).add(MapEntry(entry.key, cookie));
          cookieCount++;
        }
      }
      final clock = Stopwatch()..start();
      // PersistCookieJar shares its host index and domain file. Keep disk writes
      // sequential, while reducing repeated writes for different paths of a host.
      for (final entry in storageBatches.entries) {
        await _dioCookieJar.saveFromResponse(entry.key, entry.value);
      }
      final storageMs = clock.elapsedMilliseconds;
      clock.reset();
      final groups = webViewGroups.values.toList();
      for (var start = 0; start < groups.length; start += 4) {
        final end = start + 4 < groups.length ? start + 4 : groups.length;
        // A cookie domain is serialized; at most four independent domains run
        // together. Wait for ALL active writers before rolling back on failure,
        // otherwise a late write could resurrect a logged-out session.
        await Future.wait(groups.sublist(start, end).map((group) async {
          for (final entry in group) {
            await _saveWebViewLoginCookie(entry.key, entry.value);
          }
        }), eagerError: false);
      }
      final message = 'HTTP Cookie 同步：cookies=$cookieCount, origins=${storageBatches.length}, '
          'persistMs=$storageMs, webViewMs=${clock.elapsedMilliseconds}';
      if (onProgress != null) {
        onProgress(message);
      } else {
        _logger.i(message);
      }
    } catch (_) {
      await clearSsoCookies();
      throw const CookieException('同步登录 Cookie 失败，请重新登录');
    }
  }

  Future<void> _saveWebViewLoginCookie(Uri uri, io.Cookie cookie) async {
    final saved = await _webViewCookieManager.setCookie(
      url: webview.WebUri(uri.toString()),
      name: cookie.name,
      value: cookie.value,
      domain: cookie.domain,
      path: cookie.path ?? '/',
      expiresDate: cookie.expires?.millisecondsSinceEpoch,
      isSecure: cookie.secure,
      isHttpOnly: cookie.httpOnly,
      sameSite: const {
        io.SameSite.lax: webview.HTTPCookieSameSitePolicy.LAX,
        io.SameSite.strict: webview.HTTPCookieSameSitePolicy.STRICT,
        io.SameSite.none: webview.HTTPCookieSameSitePolicy.NONE,
      }[cookie.sameSite],
    );
    if (!saved) throw const CookieException('同步登录 Cookie 失败');
  }

  /// 清除所有 Cookie（包括 WebVPN、CAS、教务系统等）
  Future<void> clearAllCookies() async {
    if (!_initialized) await initialize();
    
    try {
      // 清除 Dio 中的所有 Cookie
      await _dioCookieJar.deleteAll();
      _logger.d('Dio cookies cleared');
      
      // 清除 WebView 中的所有 Cookie
      await _webViewCookieManager.deleteAllCookies();
      _logger.d('WebView cookies cleared');
      
      _logger.i('✅ All cookies cleared successfully');
    } catch (e) {
      _logger.e('Failed to clear all cookies: $e');
      throw CookieException('清除所有 Cookie 失败: $e');
    }
  }
  
  /// 从 WebView 同步多个域名的 Cookie 到 Dio
  /// [currentUrl] 可选，传入当前正在访问的 URL 以确保捕获特定路径下的 Cookie (如 /relax/)
  Future<void> syncMultiDomainCookiesFromWebView([String? currentUrl]) async {
    if (!_initialized) await initialize();
    
    try {
      // 1. 扩充需要同步的域名列表
      final domains = [
        AppConstants.ssoBaseUrl,
        AppConstants.portalBaseUrl,
        'https://hunau.edu.cn',
        'https://bxpt.hunau.edu.cn',
        'https://bxpt.hunau.edu.cn/relax/', // 👈 增加带路径的探测
        'https://webvpn.hunau.edu.cn',
        'https://passport2.chaoxing.com',
        'https://passport2-api.chaoxing.com',
        'https://notice.chaoxing.com',
        'https://mooc1.chaoxing.com',
        'https://mooc1-api.chaoxing.com',
        'https://mooc-res2.chaoxing.com',
        'https://reserve.chaoxing.com',
        'https://office.chaoxing.com',
        'https://v1.chaoxing.com',
        'https://photo.chaoxing.com',
        'https://p.cldisk.com',
        'https://ananas.chaoxing.com',
        'https://hub.17wanxiao.com',
        'https://17wanxiao.com',
        'https://fin-serv.hunau.edu.cn',
      ];

      // 如果提供了当前 URL，也加入探测列表
      if (currentUrl != null && !domains.contains(currentUrl)) {
        domains.add(currentUrl);
      }
      
      int totalSynced = 0;
      
      for (final domain in domains) {
        try {
          final cookies = await _webViewCookieManager.getCookies(
            url: webview.WebUri(domain),
          );
          
          for (final cookie in cookies) {
            // 调试日志：打印具体抓到的 Cookie (只看关键信息)
            _logger.d('🔍 WebView Cookie: [${cookie.name}] domain=${cookie.domain} path=${cookie.path}');

            // 创建 Dio Cookie
            final dioCookie = io.Cookie(cookie.name, cookie.value);
            
            // 修正 Domain：如果 WebView 返回的 domain 带点 (如 .hunau.edu.cn)
            // 确保保存到 Dio 时也保留这个特性，以便子域名能共享
            if (cookie.domain != null) {
              dioCookie.domain = cookie.domain;
            } else {
              dioCookie.domain = Uri.parse(domain).host;
            }

            dioCookie.path = cookie.path ?? '/';
            
            await _dioCookieJar.saveFromResponse(
              Uri.parse(domain),
              [dioCookie],
            );

            // ✨ Cookie 镜像逻辑：
            // 如果是在 WebVPN 域名下发现的密钥，强行拷贝一份给 Portal 域名
            // 这样当代码请求不带前缀的 portal.hunau.edu.cn 时，Dio 也会带上 WebVPN 的身份凭证
            if (domain.contains('webvpn.hunau.edu.cn') && 
                (cookie.name.contains('vpn_ticket') || cookie.name.contains('webvpn_key'))) {
              final mirroredCookie = io.Cookie(cookie.name, cookie.value)
                ..domain = 'portal.hunau.edu.cn'
                ..path = '/'
                ..httpOnly = true;
              
              await _dioCookieJar.saveFromResponse(
                Uri.parse(AppConstants.portalBaseUrl),
                [mirroredCookie],
              );
              _logger.d('🎭 Mirrored WebVPN cookie ${cookie.name} to portal domain');
            }

            totalSynced++;
          }
          
          _logger.d('🍪 Synced ${cookies.length} cookies from $domain');
        } catch (e) {
          _logger.w('⚠️ Failed to sync cookies from $domain: $e');
        }
      }
      
      _logger.i('✅ Total synced $totalSynced cookies from all domains');
    } catch (e) {
      _logger.e('Failed to sync multi-domain cookies from WebView: $e');
      throw CookieException('从 WebView 同步多域名 Cookie 失败: $e');
    }
  }
  
  /// ✨ 新增：从 Dio 同步 Cookie 到 WebView (回流)
  Future<void> syncCookiesToWebView(String url) async {
    if (!_initialized) await initialize();
    try {
      final uri = Uri.parse(url);
      final cookies = await _dioCookieJar.loadForRequest(uri);
      
      for (final cookie in cookies) {
        // 根据 cookie 自身的 domain 或请求的 host 来决定注入的域名作用域
        String targetDomain = cookie.domain ?? uri.host;
        
        await _webViewCookieManager.setCookie(
          url: webview.WebUri(url),
          name: cookie.name,
          value: cookie.value,
          domain: targetDomain,
          path: cookie.path ?? '/',
          isSecure: false, // 🛠️ 关键修复：兼容 http 跳转
          isHttpOnly: cookie.httpOnly,
        );
      }
      _logger.d('💉 Injected ${cookies.length} cookies back to WebView for $url');
    } catch (e) {
      _logger.w('⚠️ Failed to inject cookies back to WebView: $e');
    }
  }

  /// ✨ 新增：全域注入超星系 Cookie
  /// 解决详情页内部 JS 跨域请求（如请求 mooc1 或 passport2）时的权限问题
  Future<void> injectAllChaoxingCookies() async {
    if (!_initialized) await initialize();
    final domains = [
      'http://chaoxing.com',
      'https://chaoxing.com',
      'https://passport2.chaoxing.com',
      'https://passport2-api.chaoxing.com',
      'https://notice.chaoxing.com',
      'http://notice.chaoxing.com',
      'https://mooc1.chaoxing.com',
      'http://mooc1.chaoxing.com',
      'https://mooc1-api.chaoxing.com',
      'https://mooc-res2.chaoxing.com',
      'https://reserve.chaoxing.com',
      'http://reserve.chaoxing.com',
      'https://office.chaoxing.com',
      'http://office.chaoxing.com',
      'https://photo.chaoxing.com',
      'https://p.cldisk.com',
      'https://ananas.chaoxing.com',
      'https://fin-serv.hunau.edu.cn',
    ];

    for (final domain in domains) {
      await syncCookiesToWebView(domain);
    }
    _logger.i('🚀 Global Chaoxing cookies injected to WebView');
  }
  
  /// 设置 Cookie 到 WebView (默认设置为 portal 域名)
  Future<void> setCookieToWebView(String name, String value, {String? domain, String? path}) async {
    if (!_initialized) await initialize();
    
    try {
      final targetDomain = domain ?? 'portal.hunau.edu.cn';
      final targetUrl = 'https://$targetDomain';
      
      await _webViewCookieManager.setCookie(
        url: webview.WebUri(targetUrl),
        name: name,
        value: value,
        domain: domain ?? targetDomain,
        path: path ?? '/',
      );
      
      _logger.d('Set cookie $name to WebView ($targetDomain)');
    } catch (e) {
      _logger.e('Failed to set cookie to WebView: $e');
      throw CookieException('设置 WebView Cookie 失败: $e');
    }
  }

  /// 同时设置 Cookie 到 Dio 和 WebView
  Future<void> setCookie({
    required String url,
    required String name,
    required String value,
    String? domain,
    String? path,
  }) async {
    if (!_initialized) await initialize();

    try {
      // 1. 设置到 Dio
      final dioUri = Uri.parse(url);
      final ioCookie = io.Cookie(name, value);
      ioCookie.domain = domain ?? dioUri.host;
      ioCookie.path = path ?? '/';
      await _dioCookieJar.saveFromResponse(dioUri, [ioCookie]);

      // 2. 设置到 WebView
      await _webViewCookieManager.setCookie(
        url: webview.WebUri(url),
        name: name,
        value: value,
        domain: domain ?? ioCookie.domain,
        path: path ?? '/',
      );

      _logger.d('✅ Cookie $name synced to both Dio and WebView');
    } catch (e) {
      _logger.e('Failed to set cookie: $e');
    }
  }
  
  

  /// 从 Dio CookieJar 中获取特定域名的 Cookie 值
  Future<String?> getCookieValue(String url, String name) async {
    if (!_initialized) await initialize();
    try {
      final cookies = await _dioCookieJar.loadForRequest(Uri.parse(url));
      for (final cookie in cookies) {
        if (cookie.name == name) {
          return cookie.value;
        }
      }
    } catch (e) {
      _logger.w('⚠️ Failed to get cookie $name for $url: $e');
    }
    return null;
  }
  
  /// 销毁 CookieManager
  Future<void> dispose() async {
    try {
      await _dioCookieJar.deleteAll();
      await _webViewCookieManager.deleteAllCookies();
      _initialized = false;
      _logger.i('AppCookieManager disposed');
    } catch (e) {
      _logger.e('Failed to dispose AppCookieManager: $e');
    }
  }
}
