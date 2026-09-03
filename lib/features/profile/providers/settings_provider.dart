import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/background_worker.dart';
import '../../timetable/services/timetable_storage.dart';
import '../../homework/services/homework_storage.dart';
import '../../library/services/library_storage.dart';

class SettingsState {
  final int reminderMinutes; // 0: 不通知, 5, 10, 20, 30, 40, 50, 60
  final double homeworkReminderHours; // 0: 不通知, 0.5, 1, 2, 6, 12, 24, 48
  final int libraryReminderMinutes; // 0: 不通知, 5, 10, 20, 30, 40, 50, 60

  SettingsState({
    required this.reminderMinutes,
    required this.homeworkReminderHours,
    required this.libraryReminderMinutes,
  });

  SettingsState copyWith({
    int? reminderMinutes,
    double? homeworkReminderHours,
    int? libraryReminderMinutes,
  }) {
    return SettingsState(
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      homeworkReminderHours:
          homeworkReminderHours ?? this.homeworkReminderHours,
      libraryReminderMinutes:
          libraryReminderMinutes ?? this.libraryReminderMinutes,
    );
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(ref);
});

class SettingsNotifier extends StateNotifier<SettingsState> {
  // 多个 Provider 可能同时触发重排程（例如课表/作业/图书馆同步）。
  // 串行化 cancelAll + schedule，避免后一个调用在前一个调用排程期间把通知清空。
  Future<void>? _rescheduleInFlight;
  bool _rescheduleRequested = false;
  int _settingsRevision = 0;
  static const String _reminderKey = 'course_reminder_minutes';
  static const String _hwReminderKey = 'homework_reminder_hours';
  static const String _libraryReminderKey = 'library_reminder_minutes';

  SettingsNotifier([Ref? _])
      : super(SettingsState(
          reminderMinutes: 0,
          homeworkReminderHours: 0,
          libraryReminderMinutes: 0,
        )) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final revision = _settingsRevision;
    final prefs = await SharedPreferences.getInstance();
    final minutes = prefs.getInt(_reminderKey) ?? 0;
    final hwHours = prefs.getDouble(_hwReminderKey) ?? 0;
    final libMinutes = prefs.getInt(_libraryReminderKey) ?? 0;
    // 用户已在加载期间修改设置时，不能用旧快照覆盖新 state。
    if (revision != _settingsRevision) return;
    state = state.copyWith(
      reminderMinutes: minutes,
      homeworkReminderHours: hwHours,
      libraryReminderMinutes: libMinutes,
    );

    // 初始化时也尝试安排一次通知
    await rescheduleNotifications();
  }

  Future<void> setReminderMinutes(int minutes) async {
    _settingsRevision++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_reminderKey, minutes);
    state = state.copyWith(reminderMinutes: minutes);

    // 更改设置后，立即重新安排通知
    await rescheduleNotifications();
  }

  Future<void> setHomeworkReminderHours(double hours) async {
    _settingsRevision++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_hwReminderKey, hours);
    state = state.copyWith(homeworkReminderHours: hours);

    // 更改设置后，立即重新安排通知
    await rescheduleNotifications();
  }

  Future<void> setLibraryReminderMinutes(int minutes) async {
    _settingsRevision++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_libraryReminderKey, minutes);
    state = state.copyWith(libraryReminderMinutes: minutes);

    // 更改设置后，立即重新安排通知
    await rescheduleNotifications();
  }

  Future<int> getPendingNotificationCount() {
    return NotificationService().getPendingCount();
  }

  Future<void> rescheduleNotifications() {
    // 多个数据源可能在同一时间请求重排程。合并请求，避免重复执行
    // cancelAll -> schedule，减少日志中的重复清空，也缩短通知缺口窗口。
    _rescheduleRequested = true;
    return _rescheduleInFlight ??= _runRescheduleLoop().whenComplete(() {
      _rescheduleInFlight = null;
    });
  }

  Future<void> _runRescheduleLoop() async {
    do {
      _rescheduleRequested = false;
      await _doRescheduleNotifications();
    } while (_rescheduleRequested);
  }

  Future<void> _doRescheduleNotifications() async {
    // 0. 先取消所有旧通知，防止重复或残留
    await NotificationService().cancelAll();
    // 1. 安排课程通知
    final storage = TimetableStorage();
    final hasTimetable = await storage.hasLocalTimetable();

    if (hasTimetable) {
      final courses = await storage.readCourseList();
      final meta = await storage.readMetadata();
      if (courses.isNotEmpty &&
          meta != null &&
          meta['firstWeekMonday'] != null) {
        final firstWeekMonday =
            DateTime.parse(meta['firstWeekMonday'] as String);
        await NotificationService().scheduleCourseReminders(
          courses,
          firstWeekMonday,
          state.reminderMinutes,
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

    // 3. 安排图书馆预约通知
    final libReserves = await LibraryStorage.getCachedReserves();
    if (libReserves.isNotEmpty) {
      await NotificationService().scheduleLibraryReminders(
        libReserves,
        state.libraryReminderMinutes,
      );
    }

    // 4. 同步后台周期任务注册状态
    try {
      await BackgroundWorker.ensurePeriodicReschedule();
    } catch (_) {}

    // 只有整批排程走完后才更新时间戳。若中途失败，App 恢复时会再次补排。
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'last_notification_reschedule_ts',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }
}
