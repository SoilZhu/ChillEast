import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/background_worker.dart';
import '../../../core/services/live_scheduler.dart';
import '../../cloudisk/services/cloud_backup_manager.dart';
import '../../timetable/models/course_model.dart';
import '../../timetable/services/timetable_storage.dart';
import '../../timetable/services/timetable_subscription_service.dart';
import '../../homework/services/homework_storage.dart';
import '../../library/services/library_storage.dart';
import '../../exam/services/exam_storage.dart';

class SettingsState {
  final int reminderMinutes; // 0: 不通知, 5, 10, 20, 30, 40, 50, 60
  final double homeworkReminderHours; // 0: 不通知, 0.5, 1, 2, 6, 12, 24, 48
  final bool homeworkRepeatEnabled; // 是否在完成前重复提醒
  final int homeworkRepeatIntervalMinutes; // 重复提醒间隔（分钟，默认 60）
  final bool homeworkRemindAfterDue; // 截止后是否继续提醒（最多24小时）
  final int libraryReminderMinutes; // 0: 不通知, 5, 10, 20, 30, 40, 50, 60
  final bool courseLiveEnabled; // Android 16+ Live Updates 实时活动开关
  final bool flymeLiveEnabled; // Flyme 12+ 实况通知开关（与 courseLiveEnabled 互斥）
  final bool timetableAutoSyncEnabled; // 登录后自动同步课表总开关（默认开）
  final bool cloudBackupAutoSyncEnabled; // 本地更改后自动同步备份到云盘（默认关）
  final bool timetableSubscriptionEnabled; // 课表云端订阅自动上传开关（默认关）
  final String? timetableSubscriptionUuid; // 课表云端订阅 UUID（无则 null）
  final String? manualFirstWeekMondayIso; // 手动指定的本学期第一周周一（ISO 日期，无则 null）
  final bool timetableShowEndTime; // 周视图中显示下课时间（默认关）

  SettingsState({
    required this.reminderMinutes,
    required this.homeworkReminderHours,
    this.homeworkRepeatEnabled = false,
    this.homeworkRepeatIntervalMinutes = 60,
    this.homeworkRemindAfterDue = false,
    required this.libraryReminderMinutes,
    this.courseLiveEnabled = false,
    this.flymeLiveEnabled = false,
    this.timetableAutoSyncEnabled = true,
    this.cloudBackupAutoSyncEnabled = false,
    this.timetableSubscriptionEnabled = false,
    this.timetableSubscriptionUuid,
    this.manualFirstWeekMondayIso,
    this.timetableShowEndTime = false,
  });

  SettingsState copyWith({
    int? reminderMinutes,
    double? homeworkReminderHours,
    bool? homeworkRepeatEnabled,
    int? homeworkRepeatIntervalMinutes,
    bool? homeworkRemindAfterDue,
    int? libraryReminderMinutes,
    bool? courseLiveEnabled,
    bool? flymeLiveEnabled,
    bool? timetableAutoSyncEnabled,
    bool? cloudBackupAutoSyncEnabled,
    bool? timetableSubscriptionEnabled,
    String? timetableSubscriptionUuid,
    String? manualFirstWeekMondayIso,
    bool? timetableShowEndTime,
  }) {
    return SettingsState(
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      homeworkReminderHours:
          homeworkReminderHours ?? this.homeworkReminderHours,
      homeworkRepeatEnabled:
          homeworkRepeatEnabled ?? this.homeworkRepeatEnabled,
      homeworkRepeatIntervalMinutes:
          homeworkRepeatIntervalMinutes ?? this.homeworkRepeatIntervalMinutes,
      homeworkRemindAfterDue:
          homeworkRemindAfterDue ?? this.homeworkRemindAfterDue,
      libraryReminderMinutes:
          libraryReminderMinutes ?? this.libraryReminderMinutes,
      courseLiveEnabled: courseLiveEnabled ?? this.courseLiveEnabled,
      flymeLiveEnabled: flymeLiveEnabled ?? this.flymeLiveEnabled,
      timetableAutoSyncEnabled:
          timetableAutoSyncEnabled ?? this.timetableAutoSyncEnabled,
      cloudBackupAutoSyncEnabled:
          cloudBackupAutoSyncEnabled ?? this.cloudBackupAutoSyncEnabled,
      timetableSubscriptionEnabled:
          timetableSubscriptionEnabled ?? this.timetableSubscriptionEnabled,
      timetableSubscriptionUuid:
          timetableSubscriptionUuid ?? this.timetableSubscriptionUuid,
      manualFirstWeekMondayIso:
          manualFirstWeekMondayIso ?? this.manualFirstWeekMondayIso,
      timetableShowEndTime:
          timetableShowEndTime ?? this.timetableShowEndTime,
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
  static const String _hwRepeatEnabledKey = 'homework_repeat_enabled';
  static const String _hwRepeatIntervalKey = 'homework_repeat_interval_minutes';
  static const String _hwRemindAfterDueKey = 'homework_remind_after_due';
  static const String _libraryReminderKey = 'library_reminder_minutes';
  static const String _courseLiveKey = 'course_live_enabled';
  static const String _flymeLiveKey = 'flyme_live_enabled';

  /// 课表自动同步开关的持久化 key（默认开）。
  /// auth 层的静默同步直接读 SharedPreferences，避免依赖 settings 加载时序。
  /// 实际 key 定义在 TimetableStorage，这里只做别名。
  static const String timetableAutoSyncKey = TimetableStorage.autoSyncKey;

  /// 云备份自动同步开关的持久化 key（默认关）。
  /// 与 CloudBackupManager.toggleKey 同值，单源以 SharedPreferences 为准。
  static const String cloudBackupAutoSyncKey = CloudBackupManager.toggleKey;

  /// 周视图中显示下课时间的持久化 key（默认关）。
  static const String timetableShowEndTimeKey = 'timetable_show_end_time';

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
    final hwRepeatEnabled = prefs.getBool(_hwRepeatEnabledKey) ?? false;
    final hwRepeatInterval = prefs.getInt(_hwRepeatIntervalKey) ?? 60;
    final hwRemindAfterDue = prefs.getBool(_hwRemindAfterDueKey) ?? false;
    final libMinutes = prefs.getInt(_libraryReminderKey) ?? 0;
    final liveEnabled = prefs.getBool(_courseLiveKey) ?? false;
    final flymeEnabled = prefs.getBool(_flymeLiveKey) ?? false;
    final autoSyncEnabled = prefs.getBool(timetableAutoSyncKey) ?? true;
    final cloudBackupEnabled =
        prefs.getBool(cloudBackupAutoSyncKey) ?? false;
    final showEndTime = prefs.getBool(timetableShowEndTimeKey) ?? false;
    final subEnabled =
        prefs.getBool(TimetableSubscriptionService.subscriptionEnabledKey) ??
            false;
    final subUuid =
        prefs.getString(TimetableSubscriptionService.subscriptionUuidKey);
    final storage = TimetableStorage();
    final manualMonday = await storage.readManualFirstWeekMonday();
    // 用户已在加载期间修改设置时，不能用旧快照覆盖新 state。
    if (revision != _settingsRevision) return;
    state = state.copyWith(
      reminderMinutes: minutes,
      homeworkReminderHours: hwHours,
      homeworkRepeatEnabled: hwRepeatEnabled,
      homeworkRepeatIntervalMinutes: hwRepeatInterval,
      homeworkRemindAfterDue: hwRemindAfterDue,
      libraryReminderMinutes: libMinutes,
      courseLiveEnabled: liveEnabled,
      flymeLiveEnabled: flymeEnabled,
      timetableAutoSyncEnabled: autoSyncEnabled,
      cloudBackupAutoSyncEnabled: cloudBackupEnabled,
      timetableSubscriptionEnabled: subEnabled,
      timetableSubscriptionUuid: subUuid,
      manualFirstWeekMondayIso: manualMonday?.toIso8601String(),
      timetableShowEndTime: showEndTime,
    );

    // 初始化时也尝试安排一次通知
    await rescheduleNotifications();
  }

  /// 备份导入后重新从持久化层加载并刷新通知排程。
  Future<void> reload() => _loadSettings();

  Future<void> setReminderMinutes(int minutes) async {
    _settingsRevision++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_reminderKey, minutes);
    state = state.copyWith(reminderMinutes: minutes);

    // 更改设置后，立即重新安排通知
    await rescheduleNotifications();
    CloudBackupManager.instance.markDirty();
  }

  Future<void> setHomeworkReminderHours(double hours) async {
    _settingsRevision++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_hwReminderKey, hours);
    state = state.copyWith(homeworkReminderHours: hours);

    // 更改设置后，立即重新安排通知
    await rescheduleNotifications();
    CloudBackupManager.instance.markDirty();
  }

  Future<void> setHomeworkRepeatEnabled(bool enabled) async {
    _settingsRevision++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hwRepeatEnabledKey, enabled);
    state = state.copyWith(homeworkRepeatEnabled: enabled);

    await rescheduleNotifications();
    CloudBackupManager.instance.markDirty();
  }

  Future<void> setHomeworkRepeatIntervalMinutes(int minutes) async {
    _settingsRevision++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_hwRepeatIntervalKey, minutes);
    state = state.copyWith(homeworkRepeatIntervalMinutes: minutes);

    await rescheduleNotifications();
    CloudBackupManager.instance.markDirty();
  }

  Future<void> setHomeworkRemindAfterDue(bool enabled) async {
    _settingsRevision++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hwRemindAfterDueKey, enabled);
    state = state.copyWith(homeworkRemindAfterDue: enabled);

    await rescheduleNotifications();
    CloudBackupManager.instance.markDirty();
  }

  Future<void> setLibraryReminderMinutes(int minutes) async {
    _settingsRevision++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_libraryReminderKey, minutes);
    state = state.copyWith(libraryReminderMinutes: minutes);

    // 更改设置后，立即重新安排通知
    await rescheduleNotifications();
    CloudBackupManager.instance.markDirty();
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
    CloudBackupManager.instance.markDirty();
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
    CloudBackupManager.instance.markDirty();
  }

  /// 课表自动同步总开关（默认开）。
  /// 关闭时删除本地课表（ICS/课程列表/原始课表），但保留调课/停课/加课规则
  /// 和元数据（开学周一）——无本地课表时规则（尤其是手动加课）仍能照常显示。
  /// 并重排通知以清除残留的课程提醒。用户之后可在课表页手动同步/加课。
  Future<void> setTimetableAutoSyncEnabled(bool enabled) async {
    _settingsRevision++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(timetableAutoSyncKey, enabled);
    state = state.copyWith(timetableAutoSyncEnabled: enabled);

    if (!enabled) {
      final storage = TimetableStorage();
      await storage.deleteTimetable();
      await storage.deleteCourseList();
      await storage.deleteRawCourseList();
      // 注意：保留 timetable_rules.json 和元数据（firstWeekMonday）
      await rescheduleNotifications();
    }
    CloudBackupManager.instance.markDirty();
  }

  /// 手动指定本学期第一周周一（仅自动同步关闭时可在课表设置页修改）。
  /// 先写持久化再更新 state，保证监听者重载时能读到新值。
  Future<void> setManualFirstWeekMonday(DateTime monday) async {
    _settingsRevision++;
    final storage = TimetableStorage();
    await storage.saveManualFirstWeekMonday(monday);
    final saved = await storage.readManualFirstWeekMonday();
    state = state.copyWith(
      manualFirstWeekMondayIso: saved?.toIso8601String(),
    );
    CloudBackupManager.instance.markDirty();
  }

  /// 设置是否在周视图中显示下课时间（默认关）。
  Future<void> setTimetableShowEndTime(bool value) async {
    _settingsRevision++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(timetableShowEndTimeKey, value);
    state = state.copyWith(timetableShowEndTime: value);
    CloudBackupManager.instance.markDirty();
  }

  /// 云备份自动同步总开关（默认关）。
  /// 打开后先拉云端最新覆盖本地，云上没有才推本地上去；
  /// 之后本地数据变更经 markDirty 去抖同步。
  /// 返回首次同步结果，调用方在 pulled 时刷新 Provider。
  Future<InitialSyncResult?> setCloudBackupAutoSyncEnabled(
      bool enabled) async {
    _settingsRevision++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(cloudBackupAutoSyncKey, enabled);
    state = state.copyWith(cloudBackupAutoSyncEnabled: enabled);

    if (enabled) {
      return CloudBackupManager.instance.initialSync();
    }
    return null;
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
      try {
        await _doRescheduleNotifications();
      } catch (e) {
        debugPrint('⚠️ 重排通知发生未捕获异常: $e');
      }
    } while (_rescheduleRequested);
  }

  Future<void> _doRescheduleNotifications() async {
    // 开了实时/实况就静默课程+图书馆的传统定时通知（由实时卡接管），作业不受影响
    final liveOn = state.courseLiveEnabled || state.flymeLiveEnabled;

    // 预先准备课程与开学周一（#33, #34：在 cancelAll 之前安全解析并准备，避免解析异常导致整批排程中断）
    List<CourseModel>? coursesToSchedule;
    DateTime? firstWeekMonday;

    if (!liveOn) {
      try {
        final storage = TimetableStorage();
        final hasTimetable = await storage.hasLocalTimetable();
        if (hasTimetable) {
          final courses = await storage.readCourseList();
          if (courses.isNotEmpty) {
            try {
              firstWeekMonday = await storage.resolveFirstWeekMonday();
              coursesToSchedule = courses;
            } catch (e) {
              debugPrint('⚠️ 解析开学周一失败: $e');
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ 准备课程排程数据异常: $e');
      }
    }

    // 0. 先取消所有旧通知，防止重复或残留
    try {
      await NotificationService().cancelAll();
    } catch (e) {
      debugPrint('⚠️ 取消旧通知失败: $e');
    }

    // 1. 安排课程通知
    if (coursesToSchedule != null &&
        coursesToSchedule.isNotEmpty &&
        firstWeekMonday != null) {
      try {
        await NotificationService().scheduleCourseReminders(
          coursesToSchedule,
          firstWeekMonday,
          state.reminderMinutes,
        );
      } catch (e) {
        debugPrint('⚠️ 安排课程提醒失败: $e');
      }
    } else if (!liveOn && state.reminderMinutes > 0) {
      debugPrint('⚠️ 课程列表为空或开学周一不可用，跳过课程提醒排程');
    }

    // 1.1 安排考试通知（跟上课通知一起走，按 reminderMinutes 提醒）
    if (state.reminderMinutes > 0) {
      try {
        final examStorage = ExamStorage();
        final exams = await examStorage.readExamList();
        if (exams.isNotEmpty) {
          await NotificationService().scheduleExamReminders(
            exams,
            state.reminderMinutes,
          );
        }
      } catch (e) {
        debugPrint('⚠️ 安排考试提醒失败: $e');
      }
    }

    // 2. 安排作业通知
    try {
      final hwStorage = HomeworkStorage();
      final homeworks = await hwStorage.readHomeworkList();
      if (homeworks.isNotEmpty) {
        await NotificationService().scheduleHomeworkReminders(
          homeworks,
          state.homeworkReminderHours,
          repeatEnabled: state.homeworkRepeatEnabled,
          repeatIntervalMinutes: state.homeworkRepeatIntervalMinutes,
          remindAfterDue: state.homeworkRemindAfterDue,
        );
      }
    } catch (e) {
      debugPrint('⚠️ 安排作业提醒失败: $e');
    }

    // 3. 安排图书馆预约通知（实时接管时同样静默）
    try {
      final libReserves = await LibraryStorage.getCachedReserves();
      if (!liveOn && libReserves.isNotEmpty) {
        await NotificationService().scheduleLibraryReminders(
          libReserves,
          state.libraryReminderMinutes,
        );
      }
    } catch (e) {
      debugPrint('⚠️ 安排图书馆提醒失败: $e');
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

  Future<void> setTimetableSubscriptionEnabled(bool enabled) async {
    _settingsRevision++;
    final service = TimetableSubscriptionService();
    await service.setEnabled(enabled);
    final uuid = await service.getUuid();
    state = state.copyWith(
      timetableSubscriptionEnabled: enabled,
      timetableSubscriptionUuid: uuid,
    );
  }

  Future<String> resetTimetableSubscriptionUuid() async {
    _settingsRevision++;
    final service = TimetableSubscriptionService();
    final newUuid = await service.resetUuid();
    state = state.copyWith(timetableSubscriptionUuid: newUuid);
    return newUuid;
  }
}
