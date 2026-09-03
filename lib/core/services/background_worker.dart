import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'notification_service.dart';
import '../../features/timetable/services/timetable_storage.dart';
import '../../features/homework/services/homework_storage.dart';
import '../../features/library/services/library_storage.dart';

/// 后台周期重调度任务名称
const String kRescheduleTaskUnique = 'chilleast_reschedule_periodic';
const String kRescheduleTaskName = 'rescheduleNotifications';

/// WorkManager 回调分发器（必须为顶层函数）
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      if (task == kRescheduleTaskName || task == kRescheduleTaskUnique) {
        // 后台 isolate 需重新初始化
        try {
          await NotificationService().init().timeout(const Duration(seconds: 5));
        } catch (e) {
          debugPrint('⚠️ BG NotificationService init failed: $e');
        }

        final prefs = await SharedPreferences.getInstance();
        final reminderMinutes = prefs.getInt('course_reminder_minutes') ?? 0;
        final hwHours = prefs.getDouble('homework_reminder_hours') ?? 0;
        final libMinutes = prefs.getInt('library_reminder_minutes') ?? 0;

        if (reminderMinutes <= 0 && hwHours <= 0 && libMinutes <= 0) {
          return Future.value(true);
        }

        // 先清理旧的
        await NotificationService().cancelAll();

        // 课程
        if (reminderMinutes > 0) {
          try {
            final storage = TimetableStorage();
            final has = await storage.hasLocalTimetable();
            if (has) {
              final courses = await storage.readCourseList();
              final meta = await storage.readMetadata();
              if (courses.isNotEmpty && meta != null && meta['firstWeekMonday'] != null) {
                final firstWeekMonday = DateTime.parse(meta['firstWeekMonday'] as String);
                await NotificationService().scheduleCourseReminders(courses, firstWeekMonday, reminderMinutes);
              }
            }
          } catch (e) {
            debugPrint('⚠️ BG course reschedule failed: $e');
          }
        }

        // 作业
        if (hwHours > 0) {
          try {
            final hwStorage = HomeworkStorage();
            final list = await hwStorage.readHomeworkList();
            if (list.isNotEmpty) {
              await NotificationService().scheduleHomeworkReminders(list, hwHours);
            }
          } catch (e) {
            debugPrint('⚠️ BG homework reschedule failed: $e');
          }
        }

        // 图书馆
        if (libMinutes > 0) {
          try {
            final reserves = await LibraryStorage.getCachedReserves();
            if (reserves.isNotEmpty) {
              await NotificationService().scheduleLibraryReminders(reserves, libMinutes);
            }
          } catch (e) {
            debugPrint('⚠️ BG library reschedule failed: $e');
          }
        }

        try {
          await prefs.setInt('last_notification_reschedule_ts', DateTime.now().millisecondsSinceEpoch);
        } catch (_) {}

        debugPrint('✅ BG reschedule done');
      }
      return Future.value(true);
    } catch (e) {
      debugPrint('❌ BG task failed: $e');
      return Future.value(false);
    }
  });
}

class BackgroundWorker {
  static bool _initialized = false;

  /// 在 main() 中尽早调用（目前仅 Android 需要滚动补定，iOS 本地通知由系统保障）
  static Future<void> initialize() async {
    if (!Platform.isAndroid) return;
    if (_initialized) return;
    try {
      await Workmanager().initialize(callbackDispatcher);
      _initialized = true;
      debugPrint('✅ Workmanager initialized');
    } catch (e) {
      debugPrint('⚠️ Workmanager init failed: $e');
    }
  }

  /// 注册周期任务：每 24 小时（受系统 Doze 影响，实际可能延迟）
  /// 仅在至少有一个提醒开启时注册，否则取消
  static Future<void> ensurePeriodicReschedule() async {
    if (!Platform.isAndroid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final reminderMinutes = prefs.getInt('course_reminder_minutes') ?? 0;
      final hwHours = prefs.getDouble('homework_reminder_hours') ?? 0;
      final libMinutes = prefs.getInt('library_reminder_minutes') ?? 0;
      final hasAny = reminderMinutes > 0 || hwHours > 0 || libMinutes > 0;

      if (!hasAny) {
        try {
          await Workmanager().cancelByUniqueName(kRescheduleTaskUnique);
        } catch (_) {}
        return;
      }

      await Workmanager().registerPeriodicTask(
        kRescheduleTaskUnique,
        kRescheduleTaskName,
        frequency: const Duration(hours: 24),
        initialDelay: const Duration(hours: 12),
        constraints: Constraints(networkType: NetworkType.notRequired),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        backoffPolicy: BackoffPolicy.exponential,
      );
      debugPrint('✅ Periodic reschedule registered (24h)');
    } catch (e) {
      debugPrint('⚠️ registerPeriodicTask failed: $e');
    }
  }

  static Future<void> cancelAll() async {
    try {
      await Workmanager().cancelByUniqueName(kRescheduleTaskUnique);
    } catch (_) {}
  }
}
