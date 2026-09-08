import 'dart:async';
import 'dart:io' as io;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as webview;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ChillEast/core/exceptions/app_exceptions.dart';
import 'package:ChillEast/core/network/cookie_manager.dart';
import 'package:ChillEast/core/utils/secure_storage_helper.dart';
import 'package:ChillEast/features/auth/providers/auth_provider.dart';
import 'package:ChillEast/features/auth/services/http_login_service.dart';
import 'package:ChillEast/features/workspace/services/campus_card_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late io.Directory directory;
  final manager = AppCookieManager();
  final browserCookies = _BrowserCookies();
  final sso = Uri.parse('https://sso.hunau.edu.cn/cas/login');
  final portal = Uri.parse('https://portal.hunau.edu.cn/index');
  final passport = Uri.parse('https://passport2.chaoxing.com/');
  final passportApi =
      Uri.parse('https://passport2-api.chaoxing.com/api/v2/login6');

  setUpAll(() async {
    directory =
        await io.Directory.systemTemp.createTemp('chilleast-auth-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => directory.path);
    webview.InAppWebViewPlatform.instance = _BrowserPlatform(browserCookies);
    await manager.initialize();
  });

  setUp(() async {
    await manager.clearAllCookies();
    browserCookies.clearCount = 0;
    browserCookies.failWrites = false;
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDownAll(() async {
    await manager.clearAllCookies();
    await directory.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null);
  });

  test('clears all login paths and shared domains from memory AND persistence',
      () async {
    final jar = manager.dioCookieJar;
    await jar.saveFromResponse(sso, [
      io.Cookie('TGC', 'old-tgc')..path = '/cas',
      io.Cookie('AUTHN', 'old-authn')..path = '/authn',
      io.Cookie('PORTAL_SESSION', 'old-session')..path = '/portal',
      io.Cookie('SHARED', 'old-shared')
        ..domain = '.hunau.edu.cn'
        ..path = '/',
    ]);
    await jar.saveFromResponse(
        portal, [io.Cookie('FUSION', 'old-fusion')..path = '/']);
    await jar.saveFromResponse(passport, [
      io.Cookie('UID', 'old-uid')
        ..domain = '.chaoxing.com'
        ..path = '/',
    ]);
    await jar.saveFromResponse(passportApi, [
      io.Cookie('API_SESSION', 'old-api')..path = '/api',
    ]);
    final unrelated = Uri.parse('https://webvpn.hunau.edu.cn/');
    await jar
        .saveFromResponse(unrelated, [io.Cookie('VPN', 'keep')..path = '/']);

    await manager.clearSsoCookies();
    final reloaded =
        PersistCookieJar(storage: FileStorage('${directory.path}/.cookies'));
    for (final url in [
      sso,
      sso.resolve('/authn/api/verify/othertype'),
      sso.resolve('/portal/main.html'),
      portal,
      passport,
      passportApi,
      Uri.parse('https://notice.chaoxing.com/')
    ]) {
      expect(await jar.loadForRequest(url), isEmpty);
      expect(await reloaded.loadForRequest(url), isEmpty);
    }
    expect((await jar.loadForRequest(unrelated)).single.value, 'keep');
    expect(browserCookies.clearCount, 1);
  });

  test(
      'new HTTP cookies preserve path, host-only scope, flags and expiry in both stores',
      () async {
    final expiry = DateTime.now().add(const Duration(hours: 1));
    final tgc = io.Cookie('TGC', 'fresh')
      ..path = '/cas'
      ..secure = true
      ..httpOnly = true
      ..expires = expiry
      ..sameSite = io.SameSite.lax;
    final uid = io.Cookie('UID', 'fresh-uid')
      ..domain = '.chaoxing.com'
      ..path = '/';
    await manager.saveHttpLoginCookies({
      sso: [tgc],
      passport: [uid]
    });

    final saved = (await manager.dioCookieJar.loadForRequest(sso)).single;
    expect(saved.domain, isNull);
    expect(saved.path, '/cas');
    expect(saved.secure, isTrue);
    expect(saved.httpOnly, isTrue);
    expect(saved.sameSite, io.SameSite.lax);
    expect(
        await manager.dioCookieJar.loadForRequest(sso.resolve('/')), isEmpty);
    expect(
        await manager.dioCookieJar.loadForRequest(
            Uri.parse('https://child.sso.hunau.edu.cn/cas/login')),
        isEmpty);
    expect(
        (await manager.dioCookieJar
                .loadForRequest(Uri.parse('https://notice.chaoxing.com/')))
            .single
            .value,
        'fresh-uid');

    final browserTgc =
        browserCookies.writes.singleWhere((c) => c['name'] == 'TGC');
    expect(browserTgc['domain'], isNull);
    expect(browserTgc['path'], '/cas');
    expect(browserTgc['isSecure'], isTrue);
    expect(browserTgc['isHttpOnly'], isTrue);
    expect(browserTgc['expiresDate'], expiry.millisecondsSinceEpoch);
    expect(browserTgc['sameSite'], webview.HTTPCookieSameSitePolicy.LAX);
  });

  test('failed WebView publication removes partially saved login cookies',
      () async {
    browserCookies.failWrites = true;
    await expectLater(
        manager.saveHttpLoginCookies({
          sso: [io.Cookie('TGC', 'partial')..path = '/cas'],
        }),
        throwsA(isA<CookieException>()));
    expect(await manager.dioCookieJar.loadForRequest(sso), isEmpty);
    expect(browserCookies.clearCount, 1);
  });

  test(
      'manual and silent login both clear old cookies and publish a new session',
      () async {
    var attempts = 0;
    final http = _HttpStub((username, password) async {
      attempts++;
      expect(username, 'test-user');
      expect(password, 'test-password');
      expect(await manager.dioCookieJar.loadForRequest(sso), isEmpty);
      expect(await manager.dioCookieJar.loadForRequest(portal), isEmpty);
      return {
        sso: [io.Cookie('TGC', 'fresh-$attempts')..path = '/cas']
      };
    });
    final auth = AuthService(CampusCardService(), httpLoginService: http);
    await manager.dioCookieJar
        .saveFromResponse(sso, [io.Cookie('TGC', 'old')..path = '/cas']);
    await auth.login('test-user', 'test-password');
    expect((await manager.dioCookieJar.loadForRequest(sso)).single.value,
        'fresh-1');
    expect(await SecureStorageHelper().getUsername(), 'test-user');
    expect(await SecureStorageHelper().getPassword(), 'test-password');
    await auth.silentLogin();
    expect((await manager.dioCookieJar.loadForRequest(sso)).single.value,
        'fresh-2');
    expect(attempts, 2);
    expect(browserCookies.clearCount, 2);
  });

  test(
      'failed authentication never saves credentials and permits a fresh retry',
      () async {
    var fail = true;
    final auth = AuthService(CampusCardService(),
        httpLoginService: _HttpStub((_, __) async {
      if (fail) throw const AuthException('认证失败');
      return {
        sso: [io.Cookie('TGC', 'fresh')..path = '/cas']
      };
    }));
    await expectLater(auth.login('test-user', 'test-password'),
        throwsA(isA<AuthException>()));
    expect(await SecureStorageHelper().getUsername(), isNull);
    expect(await SecureStorageHelper().getPassword(), isNull);
    fail = false;
    await auth.login('test-user', 'test-password');
    expect(
        (await manager.dioCookieJar.loadForRequest(sso)).single.value, 'fresh');
  });

  test('concurrent login cannot clear or overwrite an in-flight session',
      () async {
    final started = Completer<void>();
    final result = Completer<Map<Uri, List<io.Cookie>>>();
    final auth =
        AuthService(CampusCardService(), httpLoginService: _HttpStub((_, __) {
      started.complete();
      return result.future;
    }));
    final first = auth.login('test-user', 'test-password');
    await started.future;
    await expectLater(auth.login('second-user', 'second-password'),
        throwsA(isA<AuthException>()));
    expect(browserCookies.clearCount, 1);
    result.complete({
      sso: [io.Cookie('TGC', 'first')..path = '/cas']
    });
    await first;
    expect(
        (await manager.dioCookieJar.loadForRequest(sso)).single.value, 'first');
    expect(await SecureStorageHelper().getUsername(), 'test-user');
  });
}

class _HttpStub extends HttpLoginService {
  _HttpStub(this.callback);
  final Future<Map<Uri, List<io.Cookie>>> Function(String, String) callback;
  @override
  Future<Map<Uri, List<io.Cookie>>> login(String username, String password) =>
      callback(username, password);
}

class _BrowserPlatform extends webview.InAppWebViewPlatform {
  _BrowserPlatform(this.cookies);
  final _BrowserCookies cookies;
  @override
  webview.PlatformCookieManager createPlatformCookieManager(
          webview.PlatformCookieManagerCreationParams params) =>
      cookies;
}

class _BrowserCookies extends webview.PlatformCookieManager {
  _BrowserCookies()
      : super.implementation(
            const webview.PlatformCookieManagerCreationParams());
  final List<Map<String, Object?>> writes = [];
  int clearCount = 0;
  bool failWrites = false;

  @override
  Future<bool> deleteAllCookies() async {
    clearCount++;
    writes.clear();
    return true;
  }

  @override
  Future<bool> setCookie({
    required webview.WebUri url,
    required String name,
    required String value,
    String path = '/',
    String? domain,
    int? expiresDate,
    int? maxAge,
    bool? isSecure,
    bool? isHttpOnly,
    webview.HTTPCookieSameSitePolicy? sameSite,
    webview.PlatformInAppWebViewController? iosBelow11WebViewController,
    webview.PlatformInAppWebViewController? webViewController,
  }) async {
    if (failWrites) return false;
    writes.add({
      'url': url.toString(),
      'name': name,
      'value': value,
      'path': path,
      'domain': domain,
      'expiresDate': expiresDate,
      'isSecure': isSecure,
      'isHttpOnly': isHttpOnly,
      'sameSite': sameSite,
    });
    return true;
  }
}
