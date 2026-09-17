import 'dart:async';
import 'dart:io' as io;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as webview;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ChillEast/core/exceptions/app_exceptions.dart';
import 'package:ChillEast/core/network/cookie_manager.dart';
import 'package:ChillEast/core/network/dio_client.dart';
import 'package:ChillEast/core/state/auth_state.dart';
import 'package:ChillEast/core/utils/secure_storage_helper.dart';
import 'package:ChillEast/features/auth/providers/auth_provider.dart';
import 'package:ChillEast/features/auth/services/http_login_service.dart';
import 'package:ChillEast/features/auth/services/portal_identity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late io.Directory directory;
  final manager = AppCookieManager();
  final browserCookies = _BrowserCookies();
  late _ProfileAdapter profileAdapter;
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
    await DioClient().initialize();
  });

  setUp(() async {
    await manager.clearAllCookies();
    browserCookies.clearCount = 0;
    browserCookies.failWrites = false;
    browserCookies.handler = null;
    browserCookies.maxActive = 0;
    browserCookies.clearedWhileWriting = false;
    profileAdapter = _ProfileAdapter();
    DioClient().dio.httpClientAdapter = profileAdapter;
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
    final auth = AuthService(httpLoginService: http);
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
    final auth = AuthService(httpLoginService: _HttpStub((_, __) async {
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
    final auth = AuthService(httpLoginService: _HttpStub((_, __) {
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
  test('batching preserves several paths of one host and default paths',
      () async {
    await manager.saveHttpLoginCookies({
      sso: [io.Cookie('SESSION', 'cas')..path = '/cas'],
      sso.resolve('/authn/login.html'): [
        io.Cookie('SESSION', 'authn')..path = '/authn'
      ],
      sso.resolve('/portal/home'): [io.Cookie('DEFAULT', 'default-path')],
    });
    final reloaded =
        PersistCookieJar(storage: FileStorage('${directory.path}/.cookies'));
    expect((await reloaded.loadForRequest(sso)).single.value, 'cas');
    expect(
        (await reloaded.loadForRequest(sso.resolve('/authn/login.html')))
            .single
            .value,
        'authn');
    expect(
        (await reloaded.loadForRequest(sso.resolve('/portal/home')))
            .single
            .value,
        'default-path');
    expect(await reloaded.loadForRequest(sso.resolve('/')), isEmpty);
  });

  test('WebView writes use bounded concurrency without same-domain overlap',
      () async {
    final activeDomains = <String>{};
    browserCookies.handler = (call) async {
      final scope =
          (call['domain'] as String? ?? Uri.parse(call['url'] as String).host)
              .replaceFirst(RegExp(r'^\.'), '');
      expect(activeDomains.add(scope), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      activeDomains.remove(scope);
      return true;
    };
    await manager.saveHttpLoginCookies({
      sso: [
        io.Cookie('A', '1')..path = '/cas',
        io.Cookie('B', '2')..path = '/authn'
      ],
      portal: [io.Cookie('C', '3')..path = '/'],
      passport: [io.Cookie('D', '4')..path = '/'],
      passportApi: [io.Cookie('E', '5')..path = '/api'],
      Uri.parse('https://chaoxing.com/'): [io.Cookie('F', '6')..path = '/'],
    });
    expect(browserCookies.maxActive, 4);
    expect(browserCookies.writes.length, 6);
    expect(activeDomains, isEmpty);
  });

  test('rollback waits for in-flight WebView writes before clearing', () async {
    final lateWriteStarted = Completer<void>();
    final release = Completer<void>();
    browserCookies.handler = (call) async {
      if (call['name'] == 'FAIL') return false;
      lateWriteStarted.complete();
      await release.future;
      return true;
    };
    final operation = manager.saveHttpLoginCookies({
      sso: [io.Cookie('FAIL', 'x')..path = '/cas'],
      portal: [io.Cookie('LATE', 'x')..path = '/'],
    });
    final assertion = expectLater(operation, throwsA(isA<CookieException>()));
    await lateWriteStarted.future;
    await Future<void>.delayed(Duration.zero);
    expect(browserCookies.clearCount, 0);
    release.complete();
    await assertion;
    expect(browserCookies.clearCount, 1);
    expect(browserCookies.clearedWhileWriting, isFalse);
    expect(browserCookies.writes, isEmpty);
    expect(await manager.dioCookieJar.loadForRequest(portal), isEmpty);
  });

  test('startup auto-login clears old cookies once, not twice', () async {
    await SecureStorageHelper().saveUsername('test-user');
    await SecureStorageHelper().savePassword('test-password');
    final attempted = Completer<void>();
    final auth = AuthService(httpLoginService: _HttpStub((_, __) async {
      attempted.complete();
      throw const AuthException('Synthetic stop before background services');
    }));
    final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(auth)]);
    addTearDown(container.dispose);
    container.read(authStateProvider);
    await attempted.future;
    await Future<void>.delayed(Duration.zero);
    expect(browserCookies.clearCount, 1);
    expect(
        container.read(authStateProvider).status, AuthStatus.unauthenticated);
  });

  test('guest startup still clears stale cookies', () async {
    await manager.dioCookieJar
        .saveFromResponse(sso, [io.Cookie('OLD', 'x')..path = '/cas']);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final initialized = Completer<void>();
    container.listen(authStateProvider, (previous, next) {
      if (next.isInitialized && !initialized.isCompleted) {
        initialized.complete();
      }
    });
    await initialized.future;
    expect(browserCookies.clearCount, 1);
    expect(await manager.dioCookieJar.loadForRequest(sso), isEmpty);
  });

  test('profile reuses login HTML and fetches the avatar only once', () async {
    final auth = AuthService(
        httpLoginService: _ResultStub((_, __) async => HttpLoginResult(
              cookies: {
                passport: [
                  io.Cookie('UID', 'uid-test')
                    ..domain = '.chaoxing.com'
                    ..path = '/'
                ]
              },
              profile: const PortalIdentity(
                  username: 'test-user', realName: 'Synthetic name'),
            )));
    await auth.login('test-user', 'test-password');
    final profile = await auth.fetchFullUserInfo();
    expect(profile['realName'], 'Synthetic name');
    expect(profile['username'], 'test-user');
    expect(profileAdapter.requests.length, 1);
    expect(profileAdapter.requests.single.uri.host, 'photo.chaoxing.com');
    expect(await io.File(profile['avatarUrl']!).readAsBytes(),
        _ProfileAdapter.image);
  });

  test('profile is discarded if logout occurs during avatar download',
      () async {
    final auth = AuthService(
        httpLoginService: _ResultStub((_, __) async => HttpLoginResult(
              cookies: {
                passport: [
                  io.Cookie('UID', 'uid-old')
                    ..domain = '.chaoxing.com'
                    ..path = '/'
                ]
              },
              profile: const PortalIdentity(
                  username: 'test-user', realName: 'Old profile'),
            )));
    await auth.login('test-user', 'test-password');
    final started = Completer<void>();
    final release = Completer<ResponseBody>();
    profileAdapter.handler = (options) {
      started.complete();
      return release.future;
    };
    final profile = auth.fetchFullUserInfo();
    await started.future;
    await auth.logout();
    release.complete(_ProfileAdapter.imageResponse());
    expect(await profile, isEmpty);
  });

  test('logout while login is pending prevents publishing its session',
      () async {
    final started = Completer<void>();
    final release = Completer<HttpLoginResult>();
    final auth = AuthService(httpLoginService: _ResultStub((_, __) {
      started.complete();
      return release.future;
    }));
    final login = auth.login('test-user', 'test-password');
    final assertion = expectLater(login, throwsA(isA<AuthException>()));
    await started.future;
    await auth.logout();
    release.complete(HttpLoginResult(cookies: {
      sso: [io.Cookie('TGC', 'cancelled')..path = '/cas']
    }));
    await assertion;
    expect(await manager.dioCookieJar.loadForRequest(sso), isEmpty);
    expect(await SecureStorageHelper().getUsername(), isNull);
  });
}

class _HttpStub extends HttpLoginService {
  _HttpStub(this.callback);
  final Future<Map<Uri, List<io.Cookie>>> Function(String, String) callback;
  @override
  Future<HttpLoginResult> login(String username, String password) async =>
      HttpLoginResult(cookies: await callback(username, password));
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
  Future<bool> Function(Map<String, Object?>)? handler;
  int active = 0;
  int maxActive = 0;
  bool clearedWhileWriting = false;

  @override
  Future<bool> deleteAllCookies() async {
    clearCount++;
    if (active != 0) clearedWhileWriting = true;
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
    final call = <String, Object?>{
      'url': url.toString(),
      'name': name,
      'value': value,
      'path': path,
      'domain': domain,
      'expiresDate': expiresDate,
      'isSecure': isSecure,
      'isHttpOnly': isHttpOnly,
      'sameSite': sameSite,
    };
    active++;
    if (active > maxActive) maxActive = active;
    try {
      if (failWrites) return false;
      final callback = handler;
      if (callback != null && !await callback(call)) return false;
      writes.add(call);
      return true;
    } finally {
      active--;
    }
  }
}

class _ResultStub extends HttpLoginService {
  _ResultStub(this.callback);
  final Future<HttpLoginResult> Function(String, String) callback;
  @override
  Future<HttpLoginResult> login(String username, String password) =>
      callback(username, password);
}

class _ProfileAdapter implements HttpClientAdapter {
  static const image = <int>[137, 80, 78, 71, 13, 10, 26, 10];
  final List<RequestOptions> requests = [];
  Future<ResponseBody> Function(RequestOptions)? handler;
  static ResponseBody imageResponse() =>
      ResponseBody.fromBytes(image, 200, headers: {
        Headers.contentTypeHeader: ['image/png']
      });
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final callback = handler;
    if (callback != null) return callback(options);
    if (options.uri.host != 'photo.chaoxing.com') {
      throw StateError(
          'Unexpected profile request: ${options.uri.host}${options.uri.path}');
    }
    return imageResponse();
  }

  @override
  void close({bool force = false}) {}
}
