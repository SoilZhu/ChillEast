import 'dart:async';
import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../constants/app_constants.dart';
import '../network/cookie_manager.dart';
import '../utils/app_logger.dart';

class YdjwxtAuthService {
  static final YdjwxtAuthService _instance = YdjwxtAuthService._internal();
  factory YdjwxtAuthService() => _instance;
  YdjwxtAuthService._internal();

  final _logger = AppLogger.instance;
  String? _cachedToken;
  DateTime? _tokenExpiry;
  Future<String>? _ongoingAuthFuture;

  /// 获取移动教务系统的 Token (支持缓存与自动刷新)
  Future<String> getToken({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedToken != null && _isTokenValid(_cachedToken!)) {
      _logger.d('🔑 Using cached YDJWXT token');
      return _cachedToken!;
    }

    // 防止并发重复触发认证
    if (_ongoingAuthFuture != null) {
      _logger.d('🔑 Waiting for ongoing YDJWXT authentication...');
      return await _ongoingAuthFuture!;
    }

    _ongoingAuthFuture = _performAuth(forceRefresh: forceRefresh);
    try {
      final token = await _ongoingAuthFuture!;
      return token;
    } finally {
      _ongoingAuthFuture = null;
    }
  }

  /// 清除缓存的 Token
  void clearToken() {
    _cachedToken = null;
    _tokenExpiry = null;
  }

  Future<String> _performAuth({bool forceRefresh = false}) async {
    _logger.i('🔑 Acquiring YDJWXT token (forceRefresh: $forceRefresh)...');
    final token = await _authenticate();
    if (token == null || token.isEmpty) {
      throw Exception('身份验证失败，未能获取移动教务系统 Token。请确保已登录。');
    }

    _cachedToken = token;
    _tokenExpiry = _extractTokenExpiry(token) ?? DateTime.now().add(const Duration(hours: 3));
    _logger.i('✅ YDJWXT token acquired successfully, expires at: $_tokenExpiry');
    return token;
  }

  /// 检查 Token 是否仍在有效期内（预留 5 分钟缓冲）
  bool _isTokenValid(String token) {
    if (_tokenExpiry != null) {
      return DateTime.now().isBefore(_tokenExpiry!.subtract(const Duration(minutes: 5)));
    }
    return true;
  }

  /// 从 JWT Token 的 Payload 中解析过期时间
  DateTime? _extractTokenExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final normalized = base64Url.normalize(parts[1]);
      final payloadJson = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
      if (payload.containsKey('exp')) {
        final exp = payload['exp'];
        if (exp is int) {
          if (exp > 1000000000000) {
            return DateTime.fromMillisecondsSinceEpoch(exp);
          } else {
            return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
          }
        }
      }
    } catch (e) {
      _logger.d('⚠️ Could not parse token exp: $e');
    }
    return null;
  }

  /// 通过 HeadlessInAppWebView 完成超星 OAuth 认证并提取 Token
  Future<String?> _authenticate() async {
    final completer = Completer<String?>();
    HeadlessInAppWebView? webView;
    Timer? timeoutTimer;

    try {
      await AppCookieManager().injectAllChaoxingCookies();

      webView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(AppConstants.ydjwxtOAuthUrl)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          userAgent: AppConstants.ydjwxtUA,
          useShouldInterceptRequest: true,
        ),
        onLoadStop: (controller, url) async {
          final token = await controller.evaluateJavascript(source: '''
            (function() {
              return localStorage.getItem('token') || 
                     sessionStorage.getItem('token') || 
                     localStorage.getItem('access_token') || '';
            })()
          ''');
          if (token != null && token.toString().isNotEmpty && token.toString().length > 20) {
            if (!completer.isCompleted) completer.complete(token.toString());
          }
        },
        shouldInterceptRequest: (controller, request) async {
          final headers = request.headers;
          if (headers != null) {
            final token = headers['token'] ?? headers['Token'] ?? headers['authorization'] ?? headers['Authorization'];
            if (token != null && token.isNotEmpty && token.length > 20) {
              if (!token.startsWith('Basic') && !token.startsWith('Bearer ')) {
                if (!completer.isCompleted) completer.complete(token);
              } else if (token.startsWith('Bearer ')) {
                final cleanToken = token.replaceFirst('Bearer ', '');
                if (!completer.isCompleted) completer.complete(cleanToken);
              }
            }
          }
          return null;
        },
      );

      await webView.run();
      timeoutTimer = Timer(const Duration(seconds: 45), () {
        if (!completer.isCompleted) completer.completeError(TimeoutException('移动教务系统身份验证超时'));
      });

      return await completer.future;
    } catch (e) {
      _logger.e('Authentication error: $e');
      return null;
    } finally {
      timeoutTimer?.cancel();
      webView?.dispose();
    }
  }
}
