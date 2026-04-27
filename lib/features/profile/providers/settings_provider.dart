import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/notification_service.dart';
import '../../timetable/services/timetable_storage.dart';
import '../../homework/services/homework_storage.dart';

class SettingsState {
  final int reminderMinutes; // 0: 不通知, 5, 10, 20, 30, 40, 50, 60
  final double homeworkReminderHours; // 0: 不通知, 0.5, 1, 2, 6, 12, 24, 48

  SettingsState({
    required this.reminderMinutes,
    required this.homeworkReminderHours,
  });

  SettingsState copyWith({
    int? reminderMinutes,
    double? homeworkReminderHours,
  }) {
    return SettingsState(
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      homeworkReminderHours: homeworkReminderHours ?? this.homeworkReminderHours,
    );
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(ref);
});

class SettingsNotifier extends StateNotifier<SettingsState> {
  final Ref _ref;
  static const String _reminderKey = 'course_reminder_minutes';
  static const String _hwReminderKey = 'homework_reminder_hours';

  SettingsNotifier(this._ref) : super(SettingsState(reminderMinutes: 0, homeworkReminderHours: 0)) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final minutes = prefs.getInt(_reminderKey) ?? 0;
    final hwHours = prefs.getDouble(_hwReminderKey) ?? 0;
    state = state.copyWith(reminderMinutes: minutes, homeworkReminderHours: hwHours);
    
    // 初始化时也尝试安排一次通知
    rescheduleNotifications();
  }

  Future<void> setReminderMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_reminderKey, minutes);
    state = state.copyWith(reminderMinutes: minutes);
    
    // 更改设置后，立即重新安排通知
    await rescheduleNotifications();
  }

  Future<void> setHomeworkReminderHours(double hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_hwReminderKey, hours);
    state = state.copyWith(homeworkReminderHours: hours);
    
    // 更改设置后，立即重新安排通知
    await rescheduleNotifications();
  }

  Future<void> rescheduleNotifications() async {
    // 0. 先取消所有旧通知，防止重复或残留
    await NotificationService().cancelAll();

    // 1. 安排课程通知
    final storage = TimetableStorage();
    final hasTimetable = await storage.hasLocalTimetable();
    
    if (hasTimetable) {
      final courses = await storage.readCourseList();
      final meta = await storage.readMetadata();
      if (courses.isNotEmpty && meta != null && meta['firstWeekMonday'] != null) {
        final firstWeekMonday = DateTime.parse(meta['firstWeekMonday'] as String);
        await NotificationService().scheduleCourseReminders(
          courses, 
          firstWeekMonday,
          state.reminderMinutes
        );
      }
    }

    // 2. 安排作业通知
    final hwStorage = HomeworkStorage();
    final homeworks = await hwStorage.readHomeworkList();
    if (homeworks.isNotEmpty) {
      await NotificationService().scheduleHomeworkReminders(
        homeworks,
        state.homeworkReminderHours,
      );
    }
  }
}
