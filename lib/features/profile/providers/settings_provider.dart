import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/background_worker.dart';
import '../../../core/services/live_scheduler.dart';
import '../../timetable/services/timetable_storage.dart';
import '../../homework/services/homework_storage.dart';
import '../../library/services/library_storage.dart';

class SettingsState {
  final int reminderMinutes; // 0: 不通知, 5, 10, 20, 30, 40, 50, 60
  final double homeworkReminderHours; // 0: 不通知, 0.5, 1, 2, 6, 12, 24, 48
  final int libraryReminderMinutes; // 0: 不通知, 5, 10, 20, 30, 40, 50, 60
  final bool courseLiveEnabled; // Android 16+ Live Updates 实时活动开关
  final bool flymeLiveEnabled; // Flyme 12+ 实况通知开关（与 courseLiveEnabled 互斥）
  final bool timetableAutoSyncEnabled; // 登录后自动同步课表总开关（默认开）

  SettingsState({
    required this.reminderMinutes,
    required this.homeworkReminderHours,
    required this.libraryReminderMinutes,
    this.courseLiveEnabled = false,
    this.flymeLiveEnabled = false,
    this.timetableAutoSyncEnabled = true,
  });

  SettingsState copyWith({
    int? reminderMinutes,
    double? homeworkReminderHours,
    int? libraryReminderMinutes,
    bool? courseLiveEnabled,
    bool? flymeLiveEnabled,
    bool? timetableAutoSyncEnabled,
  }) {
    return SettingsState(
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      homeworkReminderHours:
          homeworkReminderHours ?? this.homeworkReminderHours,
      libraryReminderMinutes:
          libraryReminderMinutes ?? this.libraryReminderMinutes,
      courseLiveEnabled: courseLiveEnabled ?? this.courseLiveEnabled,
      flymeLiveEnabled: flymeLiveEnabled ?? this.flymeLiveEnabled,
      timetableAutoSyncEnabled:
          timetableAutoSyncEnabled ?? this.timetableAutoSyncEnabled,
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
  static const String _courseLiveKey = 'course_live_enabled';
  static const String _flymeLiveKey = 'flyme_live_enabled';

  /// 课表自动同步开关的持久化 key（默认开）。
  /// auth 层的静默同步直接读 SharedPreferences，避免依赖 settings 加载时序。
  static const String timetableAutoSyncKey = 'timetable_auto_sync_enabled';

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
    final liveEnabled = prefs.getBool(_courseLiveKey) ?? false;
    final flymeEnabled = prefs.getBool(_flymeLiveKey) ?? false;
    final autoSyncEnabled = prefs.getBool(timetableAutoSyncKey) ?? true;
    // 用户已在加载期间修改设置时，不能用旧快照覆盖新 state。
    if (revision != _settingsRevision) return;
    state = state.copyWith(
      reminderMinutes: minutes,
      homeworkReminderHours: hwHours,
      libraryReminderMinutes: libMinutes,
      courseLiveEnabled: liveEnabled,
      flymeLiveEnabled: flymeEnabled,
      timetableAutoSyncEnabled: autoSyncEnabled,
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

  /// Android 16+ Live Updates 实时活动总开关（仅做持久化，不触碰旧排程）。
  /// 开启时自动关闭互斥的 Flyme 实况通知。
  Future<void> setCourseLiveEnabled(bool enabled) async {
    _settingsRevision++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_courseLiveKey, enabled);
    if (enabled) {
      await prefs.setBool(_flymeLiveKey, false);
      state = state.copyWith(courseLiveEnabled: true, flymeLiveEnabled: false);
    } else {
      state = state.copyWith(courseLiveEnabled: false);
    }
    // 传统通知静默/恢复 + 实时闹钟重编排都在 reschedule 里一并处理
    await rescheduleNotifications();
  }

  /// Flyme 12+ 实况通知总开关（仅做持久化）。
  /// 开启时自动关闭互斥的 AOSP 实时活动。
  Future<void> setFlymeLiveEnabled(bool enabled) async {
    _settingsRevision++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_flymeLiveKey, enabled);
    if (enabled) {
      await prefs.setBool(_courseLiveKey, false);
      state = state.copyWith(flymeLiveEnabled: true, courseLiveEnabled: false);
    } else {
      state = state.copyWith(flymeLiveEnabled: false);
    }
    await rescheduleNotifications();
  }

  /// 课表自动同步总开关（默认开）。
  /// 关闭时删除本地课表（ICS/元数据/课程列表/原始课表），但保留调课/停课等规则，
  /// 并重排通知以清除残留的课程提醒。用户之后可在课表页下拉手动同步。
  Future<void> setTimetableAutoSyncEnabled(bool enabled) async {
    _settingsRevision++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(timetableAutoSyncKey, enabled);
    state = state.copyWith(timetableAutoSyncEnabled: enabled);

    if (!enabled) {
      final storage = TimetableStorage();
      await storage.deleteTimetable();
      await storage.deleteMetadata();
      await storage.deleteCourseList();
      await storage.deleteRawCourseList();
      // 注意：保留 timetable_rules.json
      await rescheduleNotifications();
    }
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
    // 开了实时/实况就静默课程+图书馆的传统定时通知（由实时卡接管），作业不受影响
    final liveOn = state.courseLiveEnabled || state.flymeLiveEnabled;

    // 0. 先取消所有旧通知，防止重复或残留
    await NotificationService().cancelAll();
    // 1. 安排课程通知
    final storage = TimetableStorage();
    final hasTimetable = await storage.hasLocalTimetable();

    if (!liveOn && hasTimetable) {
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

    // 3. 安排图书馆预约通知（实时接管时同样静默）
    final libReserves = await LibraryStorage.getCachedReserves();
    if (!liveOn && libReserves.isNotEmpty) {
      await NotificationService().scheduleLibraryReminders(
        libReserves,
        state.libraryReminderMinutes,
      );
    }

    // 4. 同步后台周期任务注册状态
    try {
      await BackgroundWorker.ensurePeriodicReschedule();
    } catch (_) {}

    // 5. 实时卡闹钟全量重编排（关开关时会清闹钟+撤残留卡）
    try {
      await LiveScheduler().sync();
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
