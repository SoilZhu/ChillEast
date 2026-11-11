import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/core/state/auth_state.dart';
import 'package:ChillEast/core/utils/fallback_localizations_delegate.dart';
import 'package:ChillEast/features/auth/screens/login_screen.dart';
import 'package:ChillEast/features/cloudisk/screens/cloud_sync_prompt_screen.dart';
import 'package:ChillEast/features/cloudisk/services/cloud_backup_manager.dart';
import 'package:ChillEast/features/home/screens/main_scaffold.dart';
import 'package:ChillEast/features/onboarding/providers/onboarding_provider.dart';
import 'package:ChillEast/features/onboarding/screens/onboarding_screen.dart';
import 'package:ChillEast/features/profile/providers/settings_provider.dart';
import 'package:ChillEast/features/profile/screens/profile_screen.dart';
import 'package:ChillEast/l10n/app_localizations.dart';

Widget _buildTestApp({
  required Widget child,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _MockSettingsNotifier()),
      ...overrides,
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        AppMaterialLocalizationsDelegate(),
        AppCupertinoLocalizationsDelegate(),
        AppWidgetsLocalizationsDelegate(),
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OnboardingNotifier Tests', () {
    test('Loads false when no stored preference', () async {
      final notifier = OnboardingNotifier();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(notifier.state, isFalse);
    });

    test('Loads true when has_seen_onboarding is stored', () async {
      SharedPreferences.setMockInitialValues({
        OnboardingNotifier.hasSeenOnboardingKey: true,
      });
      final notifier = OnboardingNotifier();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(notifier.state, isTrue);
    });

    test('completeOnboarding sets state to true and writes to prefs', () async {
      final notifier = OnboardingNotifier();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(notifier.state, isFalse);

      await notifier.completeOnboarding();
      expect(notifier.state, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(OnboardingNotifier.hasSeenOnboardingKey), isTrue);
    });

    test('resetOnboarding resets state to false and clears prefs', () async {
      SharedPreferences.setMockInitialValues({
        OnboardingNotifier.hasSeenOnboardingKey: true,
      });
      final notifier = OnboardingNotifier();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(notifier.state, isTrue);

      await notifier.resetOnboarding();
      expect(notifier.state, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(OnboardingNotifier.hasSeenOnboardingKey), isNull);
    });
  });

  group('LoginScreen Navigation Tests', () {
    testWidgets('LoginScreen renders close button and can pop', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: const LoginScreen(),
          overrides: [
            authStateProvider.overrideWith((ref) => _MockAuthNotifier(
                  const AuthState(status: AuthStatus.unauthenticated),
                )),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });

  group('OnboardingScreen Widget Tests', () {
    testWidgets('Renders full-screen welcome page with background, SVG, and login button', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: const OnboardingScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Check background image exists and has Alignment.bottomLeft + BoxFit.cover
      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);
      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.fit, BoxFit.cover);
      expect(imageWidget.alignment, Alignment.bottomLeft);

      // Check SVG title exists
      expect(find.byKey(const Key('welcome_login_button')), findsOneWidget);
      expect(find.text('登录'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
    });

    testWidgets('Tapping login button on welcome screen opens LoginScreen and can pop back', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: const OnboardingScreen(),
          overrides: [
            authStateProvider.overrideWith((ref) => _MockAuthNotifier(
                  const AuthState(status: AuthStatus.unauthenticated),
                )),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('welcome_login_button')));
      await tester.pumpAndSettle();

      // Should have navigated to LoginScreen
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Close login screen
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Should return to OnboardingScreen
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });


    testWidgets('ProfileScreen shows startGuide entry and opens CloudSyncPromptScreen', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: const ProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('开始引导'), findsOneWidget);
      await tester.tap(find.text('开始引导'));
      await tester.pumpAndSettle();

      expect(find.byType(CloudSyncPromptScreen), findsOneWidget);
    });
  });

  group('CloudSyncPromptScreen 7-Step Wizard Tests', () {
    testWidgets('Renders 7 steps with navigation, time dropdowns, skip/enable buttons, and completion page', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: const CloudSyncPromptScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1: 云备份
      expect(find.text('开启自动同步'), findsOneWidget);
      expect(find.text('跳过'), findsOneWidget);
      expect(find.text('开启'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);

      // Verify image is limited to 50% width and height, aligned to bottomLeft
      final fracBox = tester.widget<FractionallySizedBox>(find.byType(FractionallySizedBox).first);
      expect(fracBox.widthFactor, 0.5);
      expect(fracBox.heightFactor, 0.5);
      expect(fracBox.alignment, Alignment.bottomLeft);

      // No progress bar, close icon is absent, no step text
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.close_rounded), findsNothing);

      // Advance to Step 2: 课表自动同步
      await tester.tap(find.text('跳过'));
      await tester.pumpAndSettle();

      expect(find.text('课表自动同步'), findsOneWidget);
      expect(find.text('自动拉取教务系统，时刻获取最新课表。'), findsOneWidget);

      // Advance to Step 3: 上课提醒 (with dropdown)
      await tester.tap(find.text('跳过'));
      await tester.pumpAndSettle();

      expect(find.text('上课提醒'), findsOneWidget);
      expect(find.text('在课程开始前通知提醒上课教室。'), findsOneWidget);
      expect(find.text('上课提醒时间'), findsOneWidget);
      // Default: 30min
      expect(find.text('30分钟前'), findsOneWidget);

      // Test back navigation to Step 2
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.text('课表自动同步'), findsOneWidget);

      // Advance to Step 3 again
      await tester.tap(find.text('开启'));
      await tester.pumpAndSettle();

      expect(find.text('上课提醒'), findsOneWidget);

      // Advance to Step 4: 作业截止提醒 (with dropdown)
      await tester.tap(find.text('开启'));
      await tester.pumpAndSettle();

      expect(find.text('作业截止提醒'), findsOneWidget);
      expect(find.text('作业截止前通知提醒，避免错过作业提交。'), findsOneWidget);
      expect(find.text('作业提醒时间'), findsOneWidget);
      // Default: 48h
      expect(find.text('48小时前'), findsOneWidget);

      // Advance to Step 5: 图书馆座位提醒 (with dropdown)
      await tester.tap(find.text('开启'));
      await tester.pumpAndSettle();

      expect(find.text('图书馆座位提醒'), findsOneWidget);
      expect(find.text('预约时段开始前发送通知，防止错过预约'), findsOneWidget);
      expect(find.text('图书馆预约提醒时间'), findsOneWidget);
      // Default: 30min
      expect(find.text('30分钟前'), findsOneWidget);

      // Advance to Step 6: 课表日历订阅
      await tester.tap(find.text('开启'));
      await tester.pumpAndSettle();

      expect(find.text('课表日历订阅'), findsOneWidget);
      expect(
        find.text('生成 Webcal 订阅，一键导入系统日历与 Google Calendar。'),
        findsOneWidget,
      );
      expect(find.text('跳过'), findsOneWidget);
      expect(find.text('开启'), findsOneWidget);

      // Advance to Step 7: 大功告成完成页
      await tester.tap(find.text('开启'));
      await tester.pumpAndSettle();

      expect(find.text('大功告成！'), findsOneWidget);
      expect(find.text('欢迎使用「自在东湖」，更多选项请访问「设置」。'), findsOneWidget);
      expect(find.text('允许匿名统计'), findsOneWidget);
      expect(find.text('仅使用绝对匿名方式，统计您的使用版本。'), findsOneWidget);
      expect(find.text('完成'), findsOneWidget);
      expect(find.text('跳过'), findsNothing);

      // Finish wizard on last step by tapping 完成
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(CloudBackupManager.promptDecidedKey), isTrue);
      expect(
        prefs.getInt(CloudSyncPromptScreen.kLastSeenGuideVersionKey),
        equals(CloudSyncPromptScreen.kCurrentOnboardingGuideVersion),
      );
    });

    testWidgets('CloudSyncPromptScreen has no close button and cannot be swiped', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: const CloudSyncPromptScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Top-right close button is absent
      expect(find.byIcon(Icons.close_rounded), findsNothing);

      // Attempt to drag/swipe horizontally to advance page
      expect(find.text('开启自动同步'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();

      // Page should still be on step 1 (swipe disabled)
      expect(find.text('开启自动同步'), findsOneWidget);
      expect(find.text('课表自动同步'), findsNothing);
    });

    testWidgets('CloudSyncPromptScreen pre-fills existing settings', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: const CloudSyncPromptScreen(),
          overrides: [
            settingsProvider.overrideWith(
              (ref) => _MockSettingsNotifier(
                initialState: SettingsState(
                  reminderMinutes: 20,
                  homeworkReminderHours: 12.0,
                  libraryReminderMinutes: 15,
                  courseLiveEnabled: true,
                  flymeLiveEnabled: false,
                  timetableAutoSyncEnabled: true,
                  cloudBackupAutoSyncEnabled: true,
                  timetableSubscriptionEnabled: true,
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Go to Step 3: 上课提醒
      await tester.tap(find.text('跳过'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('跳过'));
      await tester.pumpAndSettle();

      // Should be prefilled with 20min
      expect(find.text('20分钟前'), findsOneWidget);

      // Go to Step 4: 作业截止提醒
      await tester.tap(find.text('跳过'));
      await tester.pumpAndSettle();

      // Should be prefilled with 12h
      expect(find.text('12小时前'), findsOneWidget);

      // Go to Step 5: 图书馆座位提醒
      await tester.tap(find.text('跳过'));
      await tester.pumpAndSettle();

      // Should be prefilled with 15min
      expect(find.text('15分钟前'), findsOneWidget);
    });
  });

  group('MainScaffold Version-based Guide Popup Tests', () {
    testWidgets('MainScaffold automatically pops up CloudSyncPromptScreen if lastSeenVersion < current', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        _buildTestApp(
          child: const MainScaffold(),
          overrides: [
            authStateProvider.overrideWith((ref) => _MockAuthNotifier(
                  const AuthState.authenticated(username: '20230001'),
                )),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CloudSyncPromptScreen), findsOneWidget);

      // Drain remaining timers before tearDown
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('MainScaffold does NOT pop up CloudSyncPromptScreen if lastSeenVersion >= current', (tester) async {
      SharedPreferences.setMockInitialValues({
        CloudSyncPromptScreen.kLastSeenGuideVersionKey: CloudSyncPromptScreen.kCurrentOnboardingGuideVersion,
      });
      await tester.pumpWidget(
        _buildTestApp(
          child: const MainScaffold(),
          overrides: [
            authStateProvider.overrideWith((ref) => _MockAuthNotifier(
                  const AuthState.authenticated(username: '20230001'),
                )),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CloudSyncPromptScreen), findsNothing);

      // Drain remaining timers before tearDown
      await tester.pump(const Duration(seconds: 4));
    });
  });
}

class _MockAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  _MockAuthNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockSettingsNotifier extends SettingsNotifier {
  _MockSettingsNotifier({SettingsState? initialState}) : super() {
    if (initialState != null) {
      state = initialState;
    }
  }

  @override
  Future<void> rescheduleNotifications() async {}

  @override
  Future<void> setReminderMinutes(int minutes) async {
    state = state.copyWith(reminderMinutes: minutes);
  }

  @override
  Future<void> setTimetableAutoSyncEnabled(bool enabled) async {
    state = state.copyWith(timetableAutoSyncEnabled: enabled);
  }

  @override
  Future<void> setHomeworkReminderHours(double hours) async {
    state = state.copyWith(homeworkReminderHours: hours);
  }

  @override
  Future<void> setLibraryReminderMinutes(int minutes) async {
    state = state.copyWith(libraryReminderMinutes: minutes);
  }

  @override
  Future<void> setTimetableSubscriptionEnabled(bool enabled) async {
    state = state.copyWith(timetableSubscriptionEnabled: enabled);
  }

  @override
  Future<InitialSyncResult?> setCloudBackupAutoSyncEnabled(bool enabled) async {
    state = state.copyWith(cloudBackupAutoSyncEnabled: enabled);
    return null;
  }

  @override
  Future<void> setCourseLiveEnabled(bool enabled) async {
    state = state.copyWith(courseLiveEnabled: enabled, flymeLiveEnabled: false);
  }

  @override
  Future<void> setFlymeLiveEnabled(bool enabled) async {
    state = state.copyWith(flymeLiveEnabled: enabled, courseLiveEnabled: false);
  }
}
