import 'dart:io' as io;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as webview;
import 'package:ChillEast/core/state/auth_state.dart';
import 'package:ChillEast/core/network/cookie_manager.dart';
import 'package:ChillEast/features/auth/providers/auth_provider.dart';
import 'package:ChillEast/features/timetable/models/timetable_rule_model.dart';
import 'package:ChillEast/features/timetable/models/course_model.dart';
import 'package:ChillEast/features/timetable/services/timetable_storage.dart';

class _FakeBrowserPlatform extends webview.InAppWebViewPlatform {
  @override
  webview.PlatformCookieManager createPlatformCookieManager(
          webview.PlatformCookieManagerCreationParams params) =>
      _FakeCookieManager();
}

class _FakeCookieManager extends webview.PlatformCookieManager {
  _FakeCookieManager()
      : super.implementation(const webview.PlatformCookieManagerCreationParams());

  @override
  Future<bool> deleteAllCookies() async => true;
}

class FakeAuthService extends AuthService {
  @override
  Future<void> logout() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late io.Directory tempDir;
  late TimetableStorage storage;

  setUpAll(() async {
    tempDir = await io.Directory.systemTemp.createTemp('auth-logout-rule-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => tempDir.path);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dexterous.com/flutter/local_notifications'),
            (call) async => true);
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    webview.InAppWebViewPlatform.instance = _FakeBrowserPlatform();
    await AppCookieManager().initialize();
    storage = TimetableStorage();
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  test('Calling logout() deletes all timetable rules and raw courses automatically', () async {
    // 1. 模拟本地已经存在规则、原始课表和生成课表
    final rule = TimetableRule.createSuspension(
      startWeek: 2,
      endWeek: 3,
      courseName: '高数',
    );
    const course = CourseModel(
      id: 'c1',
      name: '高数',
      teacher: '张老师',
      classroom: '十教',
      weeks: '1-16(周)',
      periods: '01-02',
      dayOfWeek: 1,
      startPeriod: 1,
      endPeriod: 2,
    );

    await storage.saveRules([rule]);
    await storage.saveRawCourseList([course]);
    await storage.saveCourseList([course]);
    await storage.saveTimetable('BEGIN:VCALENDAR\nEND:VCALENDAR');

    expect((await storage.readRules()).length, equals(1));
    expect((await storage.readRawCourseList()).length, equals(1));
    expect(await storage.hasLocalTimetable(), isTrue);

    // 2. 调用 logout
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(FakeAuthService()),
      ],
    );
    final authNotifier = container.read(authStateProvider.notifier);
    await authNotifier.logout();

    // 3. 验证规则和课表均已被自动清空
    final remainingRules = await storage.readRules();
    expect(remainingRules, isEmpty);
    final remainingRawCourses = await storage.readRawCourseList();
    expect(remainingRawCourses, isEmpty);
    expect(await storage.hasLocalTimetable(), isFalse);
  });
}
