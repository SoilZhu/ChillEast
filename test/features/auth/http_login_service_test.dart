import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/asn1.dart' as asn1;
import 'package:pointycastle/export.dart' as pc;

import 'package:ChillEast/core/exceptions/app_exceptions.dart';
import 'package:ChillEast/features/auth/services/cims_login.dart';
import 'package:ChillEast/features/auth/services/http_login_service.dart';

const _base = 'https://sso.hunau.edu.cn';
const _portal = 'https://portal.hunau.edu.cn';
const _passportApi = 'https://passport2-api.chaoxing.com';
final _loginUri = Uri.parse('$_base/cas/login').replace(
  queryParameters: {'service': '$_base/portal/auth/casLogin'},
);

// Entirely synthetic data, not copied from a user's HAR or saved cookies.
const _html = r'''
<form id="cims_form">
<input type="hidden" name="execution" value="fresh-state&amp;value-GENERATION">
<input type="hidden" name="_eventId" value="login">
<input type="hidden" name="username" value="cimsUser">
<input type="hidden" name="geolocation" value="">
<input type="hidden" name="multi" value="one">
<input type="hidden" name="multi" value="two">
<input type="hidden" name="signedCimsResponse" value="old-signature">
<input type="hidden" disabled name="disabled" value="unused">
<input type="text" name="visible" value="unused">
</form><script>
CIMS.init({
 host: "https:\/\/sso.hunau.edu.cn\/authn",
 postaction: "https:\/\/sso.hunau.edu.cn\/cas\/login",
 sig_request: "REQ|YQ==|AAAA:APP|Yg==|BBBB",
 formid: 'cims_form',
 postArgument: 'signedCimsResponse',
 username: "",
 version: 'v2',
 reAuthError: "false",
});</script>
''';

late pc.RSAPrivateKey _privateKey;
late String _pkcs1;
late String _spki;

Uint8List _decrypt(String cipherText) {
  final cipher = pc.PKCS1Encoding(pc.RSAEngine())
    ..init(false, pc.PrivateKeyParameter<pc.RSAPrivateKey>(_privateKey));
  return cipher.process(base64Decode(cipherText));
}

void main() {
  setUpAll(() {
    final random = pc.FortunaRandom()
      ..seed(pc.KeyParameter(Uint8List.fromList(List.generate(32, (i) => i))));
    final generator = pc.RSAKeyGenerator()
      ..init(pc.ParametersWithRandom(
        pc.RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64),
        random,
      ));
    final pair = generator.generateKeyPair();
    _privateKey = pair.privateKey as pc.RSAPrivateKey;
    final public = pair.publicKey as pc.RSAPublicKey;
    final rsa = asn1.ASN1Sequence(elements: [
      asn1.ASN1Integer(public.modulus),
      asn1.ASN1Integer(public.exponent),
    ]).encode();
    _pkcs1 = base64Encode(rsa);
    _spki = base64Encode(asn1.ASN1Sequence(elements: [
      asn1.ASN1Sequence(elements: [
        asn1.ASN1ObjectIdentifier.fromIdentifierString('1.2.840.113549.1.1.1'),
        asn1.ASN1Null(),
      ]),
      asn1.ASN1BitString(stringValues: rsa),
    ]).encode());
  });

  group('CIMS bootstrap', () {
    test('preserves hidden CAS fields and SDK decodeURI behavior', () {
      final bootstrap = CimsLoginBootstrap.parse(_html, _loginUri);
      expect(bootstrap.authBase.toString(), '$_base/authn/');
      expect(bootstrap.postUri.toString(), '$_base/cas/login');
      expect(bootstrap.sign, 'REQ|YQ%3D%3D|AAAA');
      expect(bootstrap.appSignature, 'APP|Yg==|BBBB');
      expect(bootstrap.appUrl, '$_base/portal/auth/casLogin');
      expect(bootstrap.signatureField, 'signedCimsResponse');
      expect(Map.fromEntries(bootstrap.fields)['username'], 'cimsUser');
      expect(Map.fromEntries(bootstrap.fields)['execution'],
          'fresh-state&value-GENERATION');
      expect(
          bootstrap.fields.where((e) => e.key == 'multi').map((e) => e.value),
          ['one', 'two']);
      expect(
          bootstrap.fields.any((e) => ['disabled', 'visible'].contains(e.key)),
          isFalse);
    });

    test('decodeURI preserves reserved escapes and literal plus', () {
      expect(decodeCimsUri('A%7CB%3D%2B%2F+%20'), 'A|B%3D%2B%2F+ ');
      expect(decodeCimsUri('%E4%B8%AD%23'), '中%23');
    });

    test('omitted optional strings use defaults; expressions are rejected', () {
      final page = _html
          .replaceAll(" version: 'v2',", '')
          .replaceAll(" postArgument: 'signedCimsResponse',", '');
      final bootstrap = CimsLoginBootstrap.parse(page, _loginUri);
      expect(bootstrap.signatureField, 'sig_response');
      expect(bootstrap.iframeUri.queryParameters['version'], 'v2');
      expect(
          () => CimsLoginBootstrap.parse(
                _html.replaceAll('username: ""', 'username: getUser()'),
                _loginUri,
              ),
          throwsA(isA<AuthException>()));
    });

    test('rejects changed forms, secondary authentication and callbacks', () {
      for (final page in [
        _html.replaceAll('execution', 'gone'),
        _html.replaceAll('CIMS.init', 'Other.init'),
        _html.replaceAll('username: ""', 'username: "existing-user"'),
        _html.replaceAll(" version: 'v2',", ' submit_callback: doLogin,'),
        _html.replaceAll('sso.hunau.edu.cn', 'evil.test'),
        _html.replaceAll('REQ|YQ==|AAAA:APP|Yg==|BBBB', 'ERR|invalid'),
      ]) {
        expect(() => CimsLoginBootstrap.parse(page, _loginUri),
            throwsA(isA<AuthException>()));
      }
    });

    test('credentials cannot leave the SSO HTTPS origin', () {
      for (final url in [
        'http://sso.hunau.edu.cn/',
        'https://sso.hunau.edu.cn.evil.test/',
        'https://sso.hunau.edu.cn@evil.test/',
        'https://user@sso.hunau.edu.cn/',
        'https://sso.hunau.edu.cn:444/',
        '//evil.test/',
      ]) {
        expect(
            () => trustedSsoUri(Uri.parse(url)), throwsA(isA<AuthException>()));
      }
    });
  });

  group('CIMS RSA', () {
    test('SPKI/PKCS1, PEM/base64, and random PKCS1 padding match the script',
        () {
      for (final key in [
        _spki,
        '-----BEGIN PUBLIC KEY-----\n$_spki\n-----END PUBLIC KEY-----',
        _pkcs1,
        '-----BEGIN RSA PUBLIC KEY-----\n$_pkcs1\n-----END RSA PUBLIC KEY-----',
      ]) {
        final a =
            encryptCimsPassword(key, 'INTERNATIONAL', '密码abc', 'new-token');
        final b =
            encryptCimsPassword(key, 'INTERNATIONAL', '密码abc', 'new-token');
        expect(a, isNot(b));
        expect(_decrypt(a), utf8.encode('密码abc|new-token'));
      }
    });

    test('astral characters are encoded as UTF-16 units, like JSEncrypt 2.3',
        () {
      final encrypted = encryptCimsPassword(_spki, 'INTERNATIONAL', '😀', 't');
      expect(_decrypt(encrypted),
          [0xed, 0xa0, 0xbd, 0xed, 0xb8, 0x80, 0x7c, 0x74]);
    });

    test('invalid keys, oversized passwords and unsupported algorithms stop',
        () {
      for (final mode in ['NATIONAL', 'unknown', '']) {
        expect(() => encryptCimsPassword(_spki, mode, 'x', 't'),
            throwsA(isA<AuthException>()));
      }
      expect(
          () => encryptCimsPassword('SECRET', 'INTERNATIONAL', 'x', 't'),
          throwsA(isA<AuthException>().having(
              (e) => e.message, 'redacted', isNot(contains('SECRET')))));
      expect(() => encryptCimsPassword(_spki, 'INTERNATIONAL', 'x' * 300, 't'),
          throwsA(isA<AuthException>()));
    });
  });

  group('pure HTTP login', () {
    test('completes CIMS, verifies user info, then authorizes the app portal',
        () async {
      final adapter = _SsoAdapter(1);
      final service = HttpLoginService(adapterFactory: () => adapter);
      final result = await service.login('test-user', 'test-password');
      expect(adapter.requests.length, 14);
      final handoff = adapter.requests
          .skip(9)
          .map((r) =>
              '${r.uri.host}${r.uri.path}${r.uri.queryParameters.containsKey('ticket') ? '?ticket' : ''}')
          .toList();
      expect(handoff, [
        'sso.hunau.edu.cn/cas/login',
        'portal.hunau.edu.cn/login?ticket',
        'portal.hunau.edu.cn/login',
        'passport2-api.chaoxing.com/api/v2/login6',
        'portal.hunau.edu.cn/index',
      ]);
      expect(adapter.requests.every((r) => r.followRedirects == false), isTrue);
      expect(adapter.closed, isTrue);
      final cookies = result.values.expand((c) => c).toList();
      final tgc = cookies.singleWhere((c) => c.name == 'TGC');
      expect(tgc.value, 'tgc-1');
      expect(tgc.path, '/cas');
      expect(tgc.domain, isNull);
      expect(tgc.secure, isTrue);
      expect(tgc.httpOnly, isTrue);
      expect(tgc.expires, isNotNull);
      expect(tgc.maxAge, isNull);
      final apiCookie = cookies.singleWhere((c) => c.name == 'API_SESSION');
      expect(apiCookie.path, '/api');
      expect(apiCookie.domain, isNull);
      expect(
          result.entries
              .singleWhere((e) => e.value.contains(apiCookie))
              .key
              .host,
          'passport2-api.chaoxing.com');
      expect(cookies.any((c) => c.name == 'INITIAL'), isFalse);
      expect(
          cookies.singleWhere((c) => c.name == 'UID').domain, '.chaoxing.com');
      expect(result.keys.every((u) => !u.hasQuery && !u.hasFragment), isTrue);
    });

    test('every login starts empty and gets new execution, token and cookies',
        () async {
      final attempts = <_SsoAdapter>[];
      final service = HttpLoginService(adapterFactory: () {
        final adapter = _SsoAdapter(attempts.length + 1);
        attempts.add(adapter);
        return adapter;
      });
      final first = await service.login('test-user', 'test-password');
      final second = await service.login('test-user', 'test-password');
      expect(attempts.length, 2);
      expect(attempts.every((a) => a.requests.first.headers['Cookie'] == null),
          isTrue);
      expect(
          first.values
              .expand((c) => c)
              .singleWhere((c) => c.name == 'TGC')
              .value,
          'tgc-1');
      expect(
          second.values
              .expand((c) => c)
              .singleWhere((c) => c.name == 'TGC')
              .value,
          'tgc-2');
    });

    test('a failed attempt cannot leak cookies or tokens into the next login',
        () async {
      var generation = 0;
      final service = HttpLoginService(adapterFactory: () {
        final adapter = _SsoAdapter(++generation);
        if (generation == 1) {
          adapter.responseOverride = (r) => r.uri.path.endsWith('checkAuthcode')
              ? _json({'status': 9052, 'msg': 'SECRET'})
              : null;
        }
        return adapter;
      });
      await expectLater(service.login('test-user', 'test-password'),
          throwsA(isA<AuthException>()));
      final second = await service.login('test-user', 'test-password');
      expect(
          second.values
              .expand((c) => c)
              .singleWhere((c) => c.name == 'TGC')
              .value,
          'tgc-2');
    });

    test('unsupported policy never submits an account or password', () async {
      for (final initial in [
        {'policy': 2, 'authtypes': '8,3', 'token': 'qr'},
        {'policy': 0, 'authtypes': '3', 'token': 'qr'},
        {'policy': 0, 'authtypes': '8'},
      ]) {
        final adapter = _SsoAdapter(1)
          ..responseOverride = (r) => r.uri.path.endsWith('getqrcode')
              ? _json({'status': 1000, ...initial})
              : null;
        await expectLater(
            HttpLoginService(adapterFactory: () => adapter)
                .login('test-user', 'test-password'),
            throwsA(isA<AuthException>()));
        expect(adapter.requests.length, 3);
        expect(adapter.requests.every((r) => r.method == 'GET'), isTrue);
      }
    });

    test(
        'password rejection/challenge is redacted and never automatically retried',
        () async {
      for (final code in [
        90091,
        9401,
        9009,
        9001,
        9011,
        9052,
        9005,
        'SECRET'
      ]) {
        final adapter = _SsoAdapter(1)
          ..responseOverride = (r) => r.uri.path.endsWith('checkAuthcode')
              ? _json({'status': code, 'msg': 'SECRET'})
              : null;
        await expectLater(
            HttpLoginService(adapterFactory: () => adapter)
                .login('test-user', 'test-password'),
            throwsA(isA<AuthException>().having(
                (e) => e.toString(), 'redacted', isNot(contains('SECRET')))));
        expect(adapter.requests.length, 5);
        expect(adapter.closed, isTrue);
      }
    });

    test('unverified SSO sessions are not published or used for portal auth',
        () async {
      for (final response in [
        _json({
          'ok': false,
          'data': {'userId': 'user'}
        }),
        _json({
          'ok': true,
          'data': {'userId': ''}
        }),
        _json({'ok': true, 'data': {}}),
        _json({
          'ok': 'true',
          'data': {'userId': 'user'}
        }),
        _body('<html>login</html>'),
        _redirect('/cas/login'),
      ]) {
        final adapter = _SsoAdapter(1)
          ..responseOverride = (r) =>
              r.uri.path.endsWith('fetchCurrentUserInfo') ? response : null;
        await expectLater(
            HttpLoginService(adapterFactory: () => adapter)
                .login('test-user', 'test-password'),
            throwsA(isA<AuthException>()));
        expect(adapter.requests.length, 9);
      }
    });

    test('rejects cross-origin/downgrade redirects before sending any secrets',
        () async {
      for (final target in [
        'https://evil.test/?ticket=SECRET',
        'http://sso.hunau.edu.cn/cas/login'
      ]) {
        final adapter = _SsoAdapter(1)
          ..responseOverride = (_) => _redirect(target);
        await expectLater(
            HttpLoginService(adapterFactory: () => adapter)
                .login('test-user', 'test-password'),
            throwsA(isA<AuthException>()));
        expect(adapter.requests.length, 1);
      }
    });

    test('does not replay CAS POST bodies for 307/308', () async {
      for (final status in [307, 308]) {
        final adapter = _SsoAdapter(1)
          ..responseOverride = (r) =>
              r.method == 'POST' && r.uri.path == '/cas/login'
                  ? _redirect('/cas/login', status: status)
                  : null;
        await expectLater(
            HttpLoginService(adapterFactory: () => adapter)
                .login('test-user', 'test-password'),
            throwsA(isA<AuthException>()));
        expect(adapter.requests.length, 6);
      }
    });

    test('AJAX redirects and missing password configuration fail closed',
        () async {
      for (final response in [
        _redirect('/authn/api/verify/othertype'),
        _json({
          'status': 1000,
          'response_body': {'token': 'x'}
        }),
        _json({
          'status': 1000,
          'response_body': {
            'token': 'x',
            'publicKey': _spki,
            'encryptor': 'NATIONAL'
          }
        }),
        _body('not JSON'),
      ]) {
        final adapter = _SsoAdapter(1)
          ..responseOverride =
              (r) => r.uri.path.endsWith('othertype') ? response : null;
        await expectLater(
            HttpLoginService(adapterFactory: () => adapter)
                .login('test-user', 'test-password'),
            throwsA(isA<AuthException>()));
        expect(adapter.requests.length, 4);
      }
    });

    test('known portal HTTP redirects are upgraded without exposing tickets',
        () async {
      final progress = <String>[];
      final adapter = _SsoAdapter(1)
        ..responseOverride = (r) {
          if (r.uri.path == '/cas/login' &&
              r.uri.queryParameters['service'] == '$_portal/login') {
            return _redirect(
                'http://portal.hunau.edu.cn/login?ticket=SECRET%2B%2F&refer=a%26b');
          }
          if (r.uri.host == 'portal.hunau.edu.cn' && r.uri.path == '/login') {
            expect(r.uri.toString(),
                'https://portal.hunau.edu.cn/login?ticket=SECRET%2B%2F&refer=a%26b');
            return _redirect(
                'http://passport2.chaoxing.com:80/sso/login?ticket=SECRET',
                cookies: [
                  'FUSION=fusion-1; Path=/; Secure; HttpOnly',
                ]);
          }
          if (r.uri.host == 'passport2.chaoxing.com') {
            expect(r.uri.scheme, 'https');
            expect(r.uri.port, 443);
            expect('${r.headers['Cookie'] ?? ''}', isNot(contains('TGC')));
            return _redirect('http://portal.hunau.edu.cn/index', cookies: [
              'UID=uid-1; Domain=.chaoxing.com; Path=/; Secure; HttpOnly',
            ]);
          }
          return null;
        };
      final cookies = await HttpLoginService(
        adapterFactory: () => adapter,
        onProgress: progress.add,
      ).login('test-user', 'test-password');
      expect(adapter.requests.every((r) => r.uri.scheme == 'https'), isTrue);
      expect(
          cookies.values
              .expand((c) => c)
              .singleWhere((c) => c.name == 'UID')
              .value,
          'uid-1');
      expect(progress.where((line) => line.contains('升级为 HTTPS')).length, 3);
      expect(progress.join('\n'), isNot(contains('SECRET')));
    });

    test('portal exceptions reveal only origin, not credentials or signed URL',
        () async {
      for (final target in [
        'https://evil.test/private/SECRET?ticket=SECRET#SECRET',
        'http://portal.hunau.edu.cn.evil.test/login?ticket=SECRET',
        'https://passport2-api.chaoxing.com.evil.test/api/v2/login6?pd=SECRET',
        'http://sso.hunau.edu.cn/cas/login?ticket=SECRET',
        'http://portal.hunau.edu.cn:8080/index?ticket=SECRET',
        'https://USER:SECRET@portal.hunau.edu.cn/index?ticket=SECRET',
      ]) {
        final progress = <String>[];
        final adapter = _SsoAdapter(1)
          ..responseOverride = (r) => r.uri.path == '/cas/login' &&
                  r.uri.queryParameters['service'] == '$_portal/login'
              ? _redirect(target)
              : null;
        await expectLater(
            HttpLoginService(
              adapterFactory: () => adapter,
              onProgress: progress.add,
            ).login('test-user', 'test-password'),
            throwsA(isA<AuthException>()
                .having((e) => e.message, 'target host',
                    contains(Uri.parse(target).host))
                .having((e) => e.message, 'redacted', isNot(contains('SECRET')))
                .having((e) => e.message, 'no URL user info',
                    isNot(contains('USER')))));
        expect(adapter.requests.length, 10);
        expect(progress.join('\n'), isNot(contains('SECRET')));
      }
    });

    test(
        'progress separates SSO and portal stages without logging sensitive values',
        () async {
      final progress = <String>[];
      final adapter = _SsoAdapter(1);
      await HttpLoginService(
              adapterFactory: () => adapter, onProgress: progress.add)
          .login('test-user', 'test-password');
      final text = progress.join('\n');
      expect(text, contains('SSO 验证通过，授权融合门户'));
      expect(text, contains('融合门户授权完成'));
      expect(text, contains('HTTP 302'));
      for (final secret in [
        'SECRET',
        'test-user',
        'test-password',
        'password-token-1',
        'fresh-state',
        'REQ|',
        'AUTH|',
        'tgc-1',
        'uid-1',
        'fusion-1',
        'SIGNED_USER',
        'SIGNED_PASSWORD',
        'SIGNED_SIGNATURE',
        'SIGNED_ENC'
      ]) {
        expect(text, isNot(contains(secret)));
      }
    });

    test('untrusted portal redirect or login page cannot finish login',
        () async {
      for (final response in [
        _redirect('https://evil.test/'),
        _body('<script>CIMS.init({})</script>'),
      ]) {
        final adapter = _SsoAdapter(1)
          ..responseOverride = (r) =>
              r.uri.host == 'portal.hunau.edu.cn' && r.uri.path == '/index'
                  ? response
                  : null;
        await expectLater(
            HttpLoginService(adapterFactory: () => adapter)
                .login('test-user', 'test-password'),
            throwsA(isA<AuthException>()));
        expect(adapter.requests.length, 14);
      }
    });

    test(
        'redirect loops and missing Locations stop without retrying credentials',
        () async {
      final loop = _SsoAdapter(1)
        ..responseOverride = (_) => _redirect('/cas/login');
      await expectLater(
          HttpLoginService(adapterFactory: () => loop)
              .login('test-user', 'test-password'),
          throwsA(isA<AuthException>()));
      expect(loop.requests.length, 12);
      final missing = _SsoAdapter(1)
        ..responseOverride = (_) => _body('', status: 302);
      await expectLater(
          HttpLoginService(adapterFactory: () => missing)
              .login('test-user', 'test-password'),
          throwsA(isA<AuthException>()));
      expect(missing.requests.length, 1);
    });

    test(
        'network diagnostics distinguish transport failures and redact raw errors',
        () async {
      final cases = <({
        DioExceptionType type,
        Object? cause,
        String code,
        String message
      })>[
        (
          type: DioExceptionType.connectionTimeout,
          cause: null,
          code: 'network_connectionTimeout',
          message: '建立连接超时（10 秒）'
        ),
        (
          type: DioExceptionType.receiveTimeout,
          cause: null,
          code: 'network_receiveTimeout',
          message: '等待服务器响应超时（30 秒）'
        ),
        (
          type: DioExceptionType.sendTimeout,
          cause: null,
          code: 'network_sendTimeout',
          message: '发送请求超时'
        ),
        (
          type: DioExceptionType.cancel,
          cause: null,
          code: 'network_cancel',
          message: '请求已取消'
        ),
        (
          type: DioExceptionType.connectionError,
          cause: const io.SocketException("Failed host lookup: 'SECRET'",
              osError: io.OSError('SECRET', 7)),
          code: 'network_dns_lookup',
          message: 'DNS 域名解析失败'
        ),
        (
          type: DioExceptionType.connectionError,
          cause: const io.SocketException('Network is unreachable SECRET',
              osError: io.OSError('SECRET', 101)),
          code: 'network_network_unreachable',
          message: '没有可用的网络路由'
        ),
        (
          type: DioExceptionType.connectionError,
          cause: const io.SocketException('Connection refused SECRET'),
          code: 'network_connection_refused',
          message: '拒绝连接'
        ),
        (
          type: DioExceptionType.connectionError,
          cause: const io.SocketException('Connection reset by peer SECRET'),
          code: 'network_connection_reset',
          message: '连接被服务器或中间网络重置'
        ),
        (
          type: DioExceptionType.connectionError,
          cause: const io.SocketException('SECRET'),
          code: 'network_socket_error',
          message: '网络连接异常'
        ),
        (
          type: DioExceptionType.unknown,
          cause:
              const io.HandshakeException('CERTIFICATE_VERIFY_FAILED SECRET'),
          code: 'network_tls_certificate',
          message: 'TLS 证书校验失败'
        ),
        (
          type: DioExceptionType.unknown,
          cause: const io.HandshakeException('TLS handshake failure SECRET'),
          code: 'network_tls_handshake',
          message: 'TLS 握手失败'
        ),
        (
          type: DioExceptionType.badCertificate,
          cause: null,
          code: 'network_tls_certificate',
          message: 'TLS 证书校验失败'
        ),
        (
          type: DioExceptionType.unknown,
          cause: const io.HttpException(
              'Connection closed before full header SECRET'),
          code: 'network_http_connection',
          message: 'HTTP 连接异常'
        ),
        (
          type: DioExceptionType.connectionError,
          cause: null,
          code: 'network_connectionError',
          message: '无法建立网络连接'
        ),
        (
          type: DioExceptionType.unknown,
          cause: StateError('SECRET'),
          code: 'network_unknown',
          message: '未分类异常'
        ),
      ];
      for (final scenario in cases) {
        final progress = <String>[];
        final adapter = _SsoAdapter(1)
          ..responseOverride = (r) => throw DioException(
                requestOptions: r,
                type: scenario.type,
                error: scenario.cause,
                message: 'SECRET',
              );
        await expectLater(
            HttpLoginService(
                    adapterFactory: () => adapter, onProgress: progress.add)
                .login('test-user', 'test-password'),
            throwsA(isA<AuthException>()
                .having((e) => e.code, 'network classification', scenario.code)
                .having((e) => e.message, 'stage', contains('初始化 SSO'))
                .having((e) => e.message, 'cause', contains(scenario.message))
                .having((e) => e.toString(), 'redacted',
                    isNot(contains('SECRET')))));
        expect(adapter.closed, isTrue);
        expect(adapter.requests.length, 1);
        final text = progress.join('\n');
        expect(text, contains('开始请求'));
        expect(text, contains('Dio=${scenario.type.name}'));
        expect(text, contains('code=${scenario.code}'));
        expect(text, isNot(contains('SECRET')));
        expect(text, isNot(contains('test-user')));
        expect(text, isNot(contains('test-password')));
      }
    });

    test('password request timeout retains its stage and is never replayed',
        () async {
      final progress = <String>[];
      final adapter = _SsoAdapter(1)
        ..responseOverride = (r) {
          if (!r.uri.path.endsWith('/checkAuthcode')) return null;
          throw DioException(
              requestOptions: r,
              type: DioExceptionType.receiveTimeout,
              message: 'SECRET');
        };
      await expectLater(
          HttpLoginService(
                  adapterFactory: () => adapter, onProgress: progress.add)
              .login('test-user', 'test-password'),
          throwsA(isA<AuthException>()
              .having((e) => e.message, 'stage', contains('校验加密密码'))
              .having((e) => e.message, 'no retry', contains('未自动重试'))
              .having((e) => e.code, 'cause', 'network_receiveTimeout')));
      expect(adapter.requests.length, 5);
      final text = progress.join('\n');
      for (final secret in [
        'SECRET',
        'password-token-1',
        'test-password',
        'test-user',
        'REQ|'
      ]) {
        expect(text, isNot(contains(secret)));
      }
    });

    test('bad HTTP response diagnostics omit server bodies and signed queries',
        () async {
      final adapter = _SsoAdapter(1)
        ..responseOverride = (r) => throw DioException(
              requestOptions: r,
              type: DioExceptionType.badResponse,
              message: 'SECRET',
              response:
                  Response(requestOptions: r, statusCode: 503, data: 'SECRET'),
            );
      await expectLater(
          HttpLoginService(adapterFactory: () => adapter)
              .login('test-user', 'test-password'),
          throwsA(isA<AuthException>()
              .having((e) => e.message, 'HTTP status', contains('HTTP 状态 503'))
              .having(
                  (e) => e.toString(), 'redacted', isNot(contains('SECRET')))));
    });

    test('network exceptions never expose credentials, cookies or signed URLs',
        () async {
      final adapter = _SsoAdapter(1)
        ..responseOverride = (r) => throw DioException(
              requestOptions: r,
              message: 'SECRET',
              type: DioExceptionType.connectionTimeout,
            );
      await expectLater(
          HttpLoginService(adapterFactory: () => adapter)
              .login('test-user', 'test-password'),
          throwsA(isA<AuthException>().having(
              (e) => e.toString(), 'redacted', isNot(contains('SECRET')))));
      expect(adapter.closed, isTrue);
      expect(adapter.requests.length, 1);
    });
  });
}

ResponseBody _body(String text,
        {int status = 200, Map<String, List<String>> headers = const {}}) =>
    ResponseBody.fromString(text, status, headers: headers);
ResponseBody _json(Map<String, Object?> value) =>
    _body(jsonEncode(value), headers: {
      Headers.contentTypeHeader: ['application/json; charset=utf-8'],
    });
ResponseBody _redirect(String location,
        {int status = 302, List<String> cookies = const []}) =>
    _body('', status: status, headers: {
      'location': [location],
      'set-cookie': cookies
    });

class _SsoAdapter implements HttpClientAdapter {
  _SsoAdapter(this.generation);

  final int generation;
  final List<RequestOptions> requests = [];
  ResponseBody? Function(RequestOptions)? responseOverride;
  bool closed = false;

  @override
  Future<ResponseBody> fetch(RequestOptions r, Stream<Uint8List>? requestStream,
      Future<void>? cancelFuture) async {
    requests.add(r);
    final overridden = responseOverride?.call(r);
    if (overridden != null) return overridden;
    final uri = r.uri;
    final cookie = '${r.headers['Cookie'] ?? ''}';
    final fields = r.data is String
        ? Uri.splitQueryString(r.data as String)
        : <String, String>{};
    expect(r.followRedirects, isFalse);
    if (uri.path == '/cas/login' && r.method == 'GET') {
      if (uri.queryParameters['service'] == '$_base/portal/auth/casLogin') {
        expect(cookie, isEmpty,
            reason: 'Every login must start with an empty jar');
        return _body(
            _html
                .replaceAll('GENERATION', '$generation')
                .replaceAll('AAAA', 'AAAA$generation'),
            headers: {
              'set-cookie': [
                'INITIAL=initial-$generation; Path=/cas; Secure; HttpOnly',
                'AUTHN=authn-$generation; Path=/authn; Secure',
              ],
            });
      }
      expect(uri.queryParameters['service'], '$_portal/login');
      expect(cookie, contains('TGC=tgc-$generation'));
      expect(cookie, isNot(contains('INITIAL=')));
      return _redirect('$_portal/login?ticket=SECRET', cookies: [
        'SSO_HOST_ONLY=must-not-leak; Path=/; Secure; HttpOnly',
      ]);
    }
    if (uri.path == '/authn/login.html') {
      expect(cookie, contains('AUTHN=authn-$generation'));
      expect(cookie, isNot(contains('INITIAL=')));
      expect(r.headers['Referer'], _loginUri.toString());
      return _body('<html>iframe</html>');
    }
    if (uri.path.endsWith('/getqrcode')) {
      expect(uri.queryParameters['sign'], 'REQ|YQ%3D%3D|AAAA$generation');
      expect(uri.queryParameters['urlCode'], '$_base/portal/auth/casLogin');
      expect(r.headers['X-Requested-With'], 'XMLHttpRequest');
      return _json({
        'status': 1000,
        'policy': 0,
        'authtypes': '3,8',
        'token': 'qr-not-password'
      });
    }
    if (uri.path.endsWith('/othertype')) {
      expect(r.method, 'POST');
      expect(r.headers['Origin'], _base);
      expect(r.contentType, Headers.formUrlEncodedContentType);
      expect(fields['username'], 'test-user');
      expect(fields['type'], '8');
      expect(fields['sign'], 'REQ|YQ%3D%3D|AAAA$generation');
      return _json({
        'status': '1000',
        'response_body': {
          'token': 'password-token-$generation',
          'publicKey': _spki,
          'encryptor': 'INTERNATIONAL',
        }
      });
    }
    if (uri.path.endsWith('/checkAuthcode')) {
      expect(r.method, 'POST');
      expect(fields['token'], 'password-token-$generation');
      expect(_decrypt(fields['authcode']!),
          utf8.encode('test-password|password-token-$generation'));
      expect(fields['username'], 'test-user');
      expect(fields['vericode'], '');
      expect(fields['verificationcode'], '');
      expect(fields['uuid'], '');
      return _json({
        'status': 1000,
        'response_body': {'usersign': 'AUTH|YQ==|CCCC'}
      });
    }
    if (uri.path == '/cas/login' && r.method == 'POST') {
      expect(fields['execution'], 'fresh-state&value-$generation');
      expect(fields['username'], 'cimsUser');
      expect(fields['signedCimsResponse'], 'AUTH|YQ==|CCCC:APP|Yg==|BBBB');
      expect(Uri(query: r.data as String).queryParametersAll['multi'],
          ['one', 'two']);
      expect(fields.containsKey('authcode'), isFalse);
      expect(fields.containsKey('password'), isFalse);
      expect(cookie, contains('INITIAL=initial-$generation'));
      return _redirect('/portal/auth/casLogin?ticket=SECRET', cookies: [
        'TGC=tgc-$generation; Path=/cas; Secure; HttpOnly; SameSite=Lax; Max-Age=3600',
        'INITIAL=; Path=/cas; Secure; Max-Age=0',
      ]);
    }
    if (uri.path == '/portal/auth/casLogin') {
      expect(r.method, 'GET');
      expect(r.data, isNull);
      expect(r.headers.containsKey('Origin'), isFalse);
      expect(cookie, isNot(contains('TGC=')));
      return _redirect('/portal/main.html', cookies: [
        'PORTAL_SESSION=sso-session-$generation; Path=/portal; Secure; HttpOnly',
      ]);
    }
    if (uri.path == '/portal/main.html') {
      return _body('<html>SSO portal</html>');
    }
    if (uri.path == '/portal/user/fetchCurrentUserInfo') {
      expect(cookie, contains('PORTAL_SESSION=sso-session-$generation'));
      return _json({
        'ok': true,
        'data': {'userId': 'synthetic-user'}
      });
    }
    // Route order is from portal.hunau.edu.cn.har. That HAR omits Cookie /
    // Set-Cookie; all identities, signed values and cookies here are synthetic.
    if (uri.host == 'portal.hunau.edu.cn' && uri.path == '/login') {
      expect(r.method, 'GET');
      expect(r.data, isNull);
      expect(cookie, isNot(contains('SSO_HOST_ONLY')));
      expect(cookie, isNot(contains('TGC')));
      if (uri.queryParameters.containsKey('ticket')) {
        return _redirect('/login', cookies: [
          'FUSION=fusion-$generation; Path=/; Secure; HttpOnly',
        ]);
      }
      expect(cookie, contains('FUSION=fusion-$generation'));
      return _redirect(
          '$_passportApi/api/v2/login6?appid=synthetic-app&schoolid=synthetic-school'
          '&name=SIGNED_USER%2B%2F&pd=SIGNED_PASSWORD%3D&enc=SIGNED_ENC'
          '&refer=https%3A%2F%2Fportal.hunau.edu.cn%2Findex'
          '&authurl=https%3A%2F%2Fportal.hunau.edu.cn%2Flogin'
          '&json=1&oauth=1&cookiefid=1&time=1234567890&signature=SIGNED_SIGNATURE%2B');
    }
    if (uri.host == 'passport2-api.chaoxing.com') {
      expect(uri.path, '/api/v2/login6');
      expect(uri.queryParameters['name'], 'SIGNED_USER+/');
      expect(uri.queryParameters['pd'], 'SIGNED_PASSWORD=');
      expect(uri.queryParameters['signature'], 'SIGNED_SIGNATURE+');
      expect(cookie, isEmpty,
          reason: 'Redirect host-only cookies must stay on their origin');
      return _redirect('$_portal/index', cookies: [
        'UID=uid-$generation; Domain=.chaoxing.com; Path=/; Secure; HttpOnly',
        'API_SESSION=api-$generation; Path=/api; Secure; HttpOnly',
      ]);
    }
    if (uri.host == 'portal.hunau.edu.cn' && uri.path == '/index') {
      expect(cookie, contains('FUSION=fusion-$generation'));
      expect(cookie, isNot(contains('UID=')));
      expect(cookie, isNot(contains('SSO_HOST_ONLY')));
      return _body('<div class="infoTxt"><em>Test user</em></div>');
    }
    fail('Unexpected request to ${uri.host}${uri.path}');
  }

  @override
  void close({bool force = false}) {
    closed = true;
  }
}
