import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/exceptions/app_exceptions.dart';
import 'cims_login.dart';

/// Pure HTTP CIMS/CAS login. Each invocation owns a new, empty cookie jar and
/// obtains its own execution, signature, password token and RSA public key.
class HttpLoginService {
  final HttpClientAdapter Function()? _adapterFactory;
  final void Function(String message)? _onProgress;

  HttpLoginService({
    HttpClientAdapter Function()? adapterFactory,
    void Function(String message)? onProgress,
  })  : _adapterFactory = adapterFactory,
        _onProgress = onProgress;

  Future<Map<Uri, List<Cookie>>> login(String username, String password) async {
    if (username.isEmpty || password.isEmpty) {
      throw const AuthException('账号和密码不能为空');
    }
    final dio = _newLoginDio();
    if (_adapterFactory != null) dio.httpClientAdapter = _adapterFactory!();
    // Do not use DioClient: it has old cookies and logs signed request URLs.
    try {
      return await _HttpLoginAttempt(dio, _onProgress)
          .login(username, password);
    } on HttpException {
      throw const AuthException('登录 Cookie 响应格式异常，未自动重试');
    } on FormatException {
      throw const AuthException('登录响应格式异常，未自动重试');
    } finally {
      dio.close(force: true);
    }
  }
}

Dio _newLoginDio() {
  return Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    sendTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    followRedirects: false,
    responseType: ResponseType.plain,
    validateStatus: (_) => true,
    headers: {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10; Mobile) '
          'AppleWebKit/537.36 (KHTML, like Gecko) '
          'Chrome/147.0.0.0 Mobile Safari/537.36',
      'Accept-Language': 'zh-CN,zh;q=0.9',
    },
  ));
}

class _HttpLoginAttempt {
  _HttpLoginAttempt(this.dio, this.onProgress);

  final Dio dio;
  final void Function(String message)? onProgress;
  String _stage = '初始化 SSO';

  void _progress(String stage) {
    _stage = stage;
    onProgress?.call('HTTP 登录：$stage');
  }

  // Never log signed queries, fragments, response bodies or cookie values.
  static String _safeOrigin(Uri uri) =>
      '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  final CookieJar cookieJar = CookieJar();
  final Map<String, MapEntry<Uri, Cookie>> _receivedCookies = {};

  static final _verifyUri = Uri.parse(
    '${AppConstants.ssoBaseUrl}/portal/user/fetchCurrentUserInfo',
  );
  static final _loginUri = Uri.parse(AppConstants.ssoLoginUrl).replace(
    queryParameters: {
      'service': '${AppConstants.ssoBaseUrl}/portal/auth/casLogin',
    },
  );

  Future<Map<Uri, List<Cookie>>> login(String username, String password) async {
    _progress('初始化 SSO');
    final page = await _request('GET', _loginUri);
    final state = CimsLoginBootstrap.parse(page.data ?? '', page.realUri);
    final iframe =
        await _request('GET', state.iframeUri, referer: state.parentUri);
    if (iframe.realUri.path != state.iframeUri.path) {
      throw const AuthException('认证 iframe 出现非预期跳转');
    }
    final initial = _successfulApi(await _request(
      'GET',
      state.authBase.resolve('api/verify/getqrcode').replace(
        queryParameters: {
          'type': '0',
          'sign': state.sign,
          'username': '',
          'urlCode': state.appUrl,
        },
      ),
      referer: state.iframeUri,
      ajax: true,
      follow: false,
    ));
    if ('${initial['token'] ?? ''}'.isEmpty) {
      throw const AuthException('认证初始化响应缺少 token');
    }
    final policy = '${initial['policy']}';
    final authTypes = '${initial['authtypes']}'.split(',');
    if (!['0', '1'].contains(policy) || !authTypes.contains('8')) {
      throw const AuthException('本次策略不允许普通密码登录或需要组合认证，请使用官方页面');
    }
    // The initial QR token MUST NOT be used for password authentication.
    _progress('获取一次性密码 token 和公钥');
    final issued = _successfulApi(await _request(
      'POST',
      state.authBase.resolve('api/verify/othertype'),
      referer: state.iframeUri,
      ajax: true,
      follow: false,
      data: _form({
        'sign': state.sign,
        'username': username,
        'type': '8',
        'appUrl': state.appUrl
      }),
    ))['response_body'];
    if (issued is! Map ||
        !['token', 'publicKey', 'encryptor'].every((key) =>
            issued[key] is String && (issued[key] as String).isNotEmpty)) {
      throw const AuthException('认证响应缺少 token、公钥或加密配置');
    }
    final token = issued['token'] as String;
    final encrypted = encryptCimsPassword(
      issued['publicKey'] as String,
      issued['encryptor'] as String,
      password,
      token,
    );
    _progress('校验加密密码');
    final checked = _successfulApi(await _request(
      'POST',
      state.authBase.resolve('api/verify/checkAuthcode'),
      referer: state.iframeUri,
      ajax: true,
      follow: false,
      data: _form({
        'sign': state.sign,
        'token': token,
        'authcode': encrypted,
        'type': '8',
        'username': username,
        'vericode': '',
        'verificationcode': '',
        'uuid': '',
        'appUrl': state.appUrl,
      }),
    ))['response_body'];
    final signed = checked is Map ? checked['usersign'] : null;
    if (signed is! String ||
        !RegExp(r'^[A-Z]{4}\|[A-Za-z0-9+/]+=*\|[A-Za-z0-9+/]+=*$')
            .hasMatch(signed)) {
      throw const AuthException('认证接口没有返回有效的 usersign');
    }
    // Preserve hidden CAS username (e.g. cimsUser), duplicate inputs and execution.
    // Only sig_response is replaced; the user's password never goes to CAS.
    final fields = state.fields
        .where((e) => e.key != state.signatureField)
        .toList()
      ..add(MapEntry(state.signatureField, '$signed:${state.appSignature}'));
    _progress('提交 CAS 签名');
    await _request('POST', state.postUri,
        referer: state.parentUri, data: _encodeForm(fields));

    _progress('验证 SSO 用户信息');
    final verified = await _request(
      'GET',
      _verifyUri,
      referer: Uri.parse(AppConstants.ssoMainPage),
      follow: false,
    );
    Object? user;
    try {
      user = jsonDecode(verified.data ?? '');
    } on FormatException {
      // HTML/login redirects are never proof of authentication.
    }
    if (verified.statusCode != 200 ||
        verified.realUri != _verifyUri ||
        user is! Map ||
        user['ok'] != true ||
        user['data'] is! Map ||
        !_hasUserId(user['data']['userId'])) {
      throw const AuthException('认证已提交，但门户用户信息接口未确认登录成功');
    }

    // The reference script stops at the SSO portal. The app additionally needs
    // portal/Chaoxing cookies for profile, notices, library and campus services.
    _progress('SSO 验证通过，授权融合门户');
    final portal = await _request(
      'GET',
      Uri.parse(AppConstants.ssoLoginUrl).replace(
        queryParameters: {'service': '${AppConstants.portalBaseUrl}/login'},
      ),
      allowPortalRedirects: true,
    );
    if (portal.statusCode != 200 ||
        portal.realUri.host != Uri.parse(AppConstants.portalBaseUrl).host ||
        portal.realUri.path == '/login' ||
        portal.realUri.path.contains('/cas/login') ||
        (portal.data ?? '').contains('CIMS.init')) {
      throw const AuthException('SSO 认证成功，但融合门户授权未完成，请重新登录');
    }
    _progress('融合门户授权完成');
    final cookies = <Uri, List<Cookie>>{};
    for (final entry in _receivedCookies.values) {
      if (_isExpired(entry.value)) continue;
      cookies.putIfAbsent(entry.key, () => []).add(entry.value);
    }
    return cookies;
  }

  static bool _hasUserId(Object? value) =>
      value is String ? value.isNotEmpty : value is num && value != 0;

  static String _form(Map<String, String> fields) =>
      _encodeForm(fields.entries);

  static String _encodeForm(Iterable<MapEntry<String, String>> fields) => fields
      .map((e) =>
          '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
      .join('&');

  static bool _isExpired(Cookie cookie) =>
      cookie.expires != null && !cookie.expires!.isAfter(DateTime.now());

  Uri _trustedUri(Uri uri, bool allowPortalRedirects) {
    if (!allowPortalRedirects) return trustedSsoUri(uri);
    final ssoHost = Uri.parse(AppConstants.ssoBaseUrl).host;
    final portalHost = Uri.parse(AppConstants.portalBaseUrl).host;
    // The captured portal handoff uses passport2-api's /api/v2/login6.
    // Keep the older passport host for compatibility; do not trust arbitrary
    // Chaoxing subdomains or suffix lookalikes.
    final portalHosts = {
      portalHost,
      'passport2.chaoxing.com',
      'passport2-api.chaoxing.com',
    };

    // Legacy portal/passport deployments can emit http:// Location headers
    // even when the request arrived over HTTPS. Upgrade only these known
    // destinations, preserving the ticket/query verbatim. Never send a ticket
    // over HTTP, never downgrade TLS, and never relax the SSO password origin.
    if (uri.userInfo.isEmpty &&
        uri.scheme == 'http' &&
        uri.port == 80 &&
        portalHosts.contains(uri.host)) {
      onProgress?.call('HTTP 登录：将已信任门户跳转升级为 HTTPS（${uri.host}）');
      uri = uri.replace(scheme: 'https', port: 443);
    }
    if (uri.scheme != 'https' ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        !(uri.host == ssoHost || portalHosts.contains(uri.host))) {
      // This is enough to diagnose an unknown host or scheme without exposing
      // CAS tickets, Chaoxing tokens, referer queries or URL user info.
      final origin = _safeOrigin(uri);
      onProgress?.call('HTTP 登录：融合门户跳转被拦截（$origin）');
      throw AuthException('融合门户跳转被拦截：$origin（仅显示域名，不含票据）');
    }
    return uri;
  }

  Future<Response<String>> _request(
    String method,
    Uri uri, {
    Uri? referer,
    bool ajax = false,
    bool follow = true,
    bool allowPortalRedirects = false,
    String? data,
  }) async {
    if (allowPortalRedirects && method != 'GET') {
      throw const AuthException('融合门户授权仅允许 GET 跳转');
    }
    for (var redirect = 0; redirect < 12; redirect++) {
      uri = _trustedUri(uri, allowPortalRedirects);
      final cookies = (await cookieJar.loadForRequest(uri))
          .where((c) => !_isExpired(c))
          .toList()
        ..sort((a, b) => (b.path?.length ?? 0).compareTo(a.path?.length ?? 0));
      final timer = Stopwatch()..start();
      onProgress?.call('HTTP 登录[$_stage] $method ${_safeOrigin(uri)} 开始请求');
      late final Response<String> response;
      try {
        response = await dio.requestUri<String>(
          uri,
          data: data,
          options: Options(
            method: method,
            contentType:
                method == 'POST' ? Headers.formUrlEncodedContentType : null,
            headers: {
              if (referer != null) 'Referer': referer.toString(),
              if (method == 'POST') 'Origin': AppConstants.ssoBaseUrl,
              if (ajax) 'X-Requested-With': 'XMLHttpRequest',
              'Accept': ajax
                  ? 'application/json'
                  : 'text/html,application/json;q=0.9,*/*;q=0.8',
              if (cookies.isNotEmpty)
                'Cookie': cookies.map((c) => '${c.name}=${c.value}').join('; '),
            },
          ),
        );
      } on DioException catch (error) {
        final failure = _loginNetworkFailure(error, _stage);
        final cause = error.error;
        final osCode =
            cause is SocketException ? cause.osError?.errorCode : null;
        onProgress?.call('HTTP 登录[$_stage] 网络失败：${failure.message} '
            '[Dio=${error.type.name}, code=${failure.code}'
            '${osCode == null ? '' : ', OS=$osCode'}, elapsedMs=${timer.elapsedMilliseconds}]');
        throw failure;
      }
      // Save only against the response origin. Dio CookieManager also copies
      // redirect cookies to Location's origin, which breaks host-only isolation.
      await _saveCookies(
          uri, response.headers[HttpHeaders.setCookieHeader] ?? []);
      final status = response.statusCode ?? 0;
      onProgress
          ?.call('HTTP 登录[$_stage] $method ${_safeOrigin(uri)} → HTTP $status');
      if (follow && [301, 302, 303, 307, 308].contains(status)) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location == null || location.isEmpty) {
          throw const AuthException('认证重定向缺少 Location');
        }
        final nextUri =
            _trustedUri(uri.resolve(location), allowPortalRedirects);
        if (method != 'GET' && [307, 308].contains(status)) {
          throw const AuthException('认证请求要求重复提交，已停止以避免重复认证');
        }
        if ([301, 302, 303].contains(status)) {
          method = 'GET';
          data = null;
        }
        if (referer != null && nextUri.origin != referer.origin) {
          referer = Uri.parse('${referer.origin}/');
        }
        uri = nextUri;
        continue;
      }
      if (status < 200 || status >= 400) {
        throw const AuthException('登录服务返回 HTTP 错误，未自动重试');
      }
      if (ajax && status != 200) {
        throw const AuthException('认证接口发生非预期跳转或返回非 200 状态');
      }
      return response;
    }
    throw const AuthException('登录重定向次数超出限制');
  }

  Future<void> _saveCookies(Uri uri, List<String> headers) async {
    final cookies = <Cookie>[];
    // Some servers fold multiple Set-Cookie values, including Expires commas.
    for (final header in headers) {
      for (final value in header.split(RegExp(r',(?=\s*[^;,=\s]+=)'))) {
        final cookie = Cookie.fromSetCookieValue(value.trim());
        final domain = cookie.domain?.replaceFirst(RegExp(r'^\.'), '');
        if (domain != null &&
            uri.host != domain &&
            !uri.host.endsWith('.$domain')) {
          throw const AuthException('认证响应包含非预期域名的 Cookie');
        }
        if (cookie.path == null || !cookie.path!.startsWith('/')) {
          final slash = uri.path.lastIndexOf('/');
          cookie.path = slash <= 0 ? '/' : uri.path.substring(0, slash);
        }
        // Keep absolute expiry when exporting, rather than restarting Max-Age.
        if (cookie.maxAge != null) {
          cookie.expires =
              DateTime.now().add(Duration(seconds: cookie.maxAge!));
          cookie.maxAge = null;
        }
        final origin =
            Uri(scheme: uri.scheme, host: uri.host, path: cookie.path);
        final scope = domain == null ? 'host:${uri.host}' : 'domain:$domain';
        _receivedCookies['$scope|${cookie.path}|${cookie.name}'] =
            MapEntry(origin, cookie);
        cookies.add(cookie);
      }
    }
    await cookieJar.saveFromResponse(uri, cookies);
  }

  Map<String, dynamic> _successfulApi(Response<String> response) {
    final body = jsonDecode(response.data ?? '');
    if (body is! Map<String, dynamic>) {
      throw const AuthException('认证接口返回结构异常');
    }
    final code = '${body['status'] ?? ''}';
    if (code != '1000') {
      const messages = {
        '90091': '需要图形验证码，请在官方页面完成验证，未自动重试',
        '9401': '需要初始化或重置密码，请在官方页面完成',
        '9009': '认证会话已过期或需要其他认证方式，请重新登录',
        '9001': '签名无效，请重新登录',
        '9011': '账号、密码或验证码验证失败，未自动重试',
        '9052': '账号或密码错误，未自动重试',
        '9005': '服务端限制了请求频率，请稍后再试',
      };
      // Never display the server body: it can contain credentials or signatures.
      throw AuthException(messages[code] ?? '认证接口拒绝本次请求',
          code: messages.containsKey(code) ? code : null);
    }
    return body;
  }
}

/// Translate transport failures without echoing Dio's signed URL, request body,
/// headers, server response, or arbitrary low-level error text.
AuthException _loginNetworkFailure(DioException error, String stage) {
  final cause = error.error;
  String code;
  String reason;
  if (error.type == DioExceptionType.badCertificate || cause is TlsException) {
    final certificateFailure = error.type == DioExceptionType.badCertificate ||
        cause.toString().contains('CERTIFICATE_VERIFY_FAILED');
    code = certificateFailure ? 'tls_certificate' : 'tls_handshake';
    reason = certificateFailure
        ? 'TLS 证书校验失败，请检查设备时间和网络代理'
        : 'TLS 握手失败，请检查网络代理或网络拦截';
  } else if (cause is SocketException &&
      error.type != DioExceptionType.connectionTimeout) {
    final message = cause.message.toLowerCase();
    if (message.contains('failed host lookup') ||
        message.contains('name or service not known') ||
        message.contains('temporary failure in name resolution') ||
        message.contains('nodename nor servname')) {
      code = 'dns_lookup';
      reason = 'DNS 域名解析失败，请检查设备 DNS 或网络连接';
    } else if (message.contains('connection refused')) {
      code = 'connection_refused';
      reason = '服务器或代理拒绝连接';
    } else if (message.contains('connection reset') ||
        message.contains('connection abort')) {
      code = 'connection_reset';
      reason = '连接被服务器或中间网络重置';
    } else if (message.contains('network is unreachable') ||
        message.contains('no route to host')) {
      code = 'network_unreachable';
      reason = '设备没有可用的网络路由';
    } else {
      code = 'socket_error';
      reason = '网络连接异常';
    }
  } else if (cause is HttpException) {
    code = 'http_connection';
    reason = 'HTTP 连接异常，服务器可能在响应完成前关闭了连接';
  } else {
    code = error.type.name;
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        final seconds = error.requestOptions.connectTimeout?.inSeconds;
        reason = '建立连接超时${seconds == null ? '' : '（$seconds 秒）'}';
      case DioExceptionType.sendTimeout:
        reason = '发送请求超时';
      case DioExceptionType.receiveTimeout:
        final seconds = error.requestOptions.receiveTimeout?.inSeconds;
        reason = '等待服务器响应超时${seconds == null ? '' : '（$seconds 秒）'}';
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        reason = '服务器返回异常 HTTP 状态${status == null ? '' : ' $status'}';
      case DioExceptionType.cancel:
        reason = '请求已取消';
      case DioExceptionType.connectionError:
        reason = '无法建立网络连接';
      case DioExceptionType.badCertificate:
        reason = 'TLS 证书校验失败';
      case DioExceptionType.unknown:
        reason = '网络客户端发生未分类异常';
    }
  }
  return AuthException('$stage：$reason（${error.requestOptions.uri.host}），未自动重试',
      code: 'network_$code');
}
