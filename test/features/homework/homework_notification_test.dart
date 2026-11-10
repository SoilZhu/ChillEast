import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:ChillEast/core/services/notification_service.dart';
import 'package:ChillEast/features/homework/models/homework_model.dart';
import 'package:ChillEast/features/profile/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (MethodCall methodCall) async {
        return null;
      },
    );
  });

  group('Homework Notification & Repeat Reminder Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('scheduleHomeworkReminders gracefully handles edge cases and completed homework', () async {
      final service = NotificationService();

      // 1. advanceHours <= 0 应安全跳过
      await expectLater(
        service.scheduleHomeworkReminders([], 0),
        completes,
      );

      final completedHw = HomeworkModel(
        id: 'hw_done_1',
        title: '物理实验报告',
        courseName: '大学物理',
        status: HomeworkStatus.completed,
        studentId: '123456',
        endTime: DateTime.now().add(const Duration(hours: 3)),
      );

      // 已完成的作业不应安排提醒
      await expectLater(
        service.scheduleHomeworkReminders([completedHw], 2.0, repeatEnabled: true),
        completes,
      );
    });

    test('scheduleHomeworkReminders supports repeat reminder and overdue options', () async {
      final service = NotificationService();

      final pendingHw = HomeworkModel(
        id: 'hw_pending_1',
        title: '微积分大作业',
        courseName: '高等数学',
        status: HomeworkStatus.pending,
        studentId: '123456',
        endTime: DateTime.now().add(const Duration(hours: 5)),
      );

      // 开启未完成重复提醒，间隔 30 分钟，逾期继续提醒
      await expectLater(
        service.scheduleHomeworkReminders(
          [pendingHw],
          2.0,
          repeatEnabled: true,
          repeatIntervalMinutes: 30,
          remindAfterDue: true,
        ),
        completes,
      );

      // 取消单条作业的通知槽位
      await expectLater(
        service.cancelHomeworkReminders(pendingHw.id),
        completes,
      );
    });

    test('SettingsNotifier manages homework repeat settings correctly', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(settingsProvider.notifier);

      expect(container.read(settingsProvider).homeworkRepeatEnabled, false);
      expect(container.read(settingsProvider).homeworkRepeatIntervalMinutes, 60);
      expect(container.read(settingsProvider).homeworkRemindAfterDue, false);

      // 1. 开启未完成重复催促
      await notifier.setHomeworkRepeatEnabled(true);
      expect(container.read(settingsProvider).homeworkRepeatEnabled, true);

      // 2. 修改间隔为 30 分钟
      await notifier.setHomeworkRepeatIntervalMinutes(30);
      expect(container.read(settingsProvider).homeworkRepeatIntervalMinutes, 30);

      // 3. 开启逾期提醒
      await notifier.setHomeworkRemindAfterDue(true);
      expect(container.read(settingsProvider).homeworkRemindAfterDue, true);

      // 验证 SharedPreferences 持久化
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('homework_repeat_enabled'), true);
      expect(prefs.getInt('homework_repeat_interval_minutes'), 30);
      expect(prefs.getBool('homework_remind_after_due'), true);
    });
  });
}
