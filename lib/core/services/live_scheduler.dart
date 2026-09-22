import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../l10n/app_localizations.dart';
import '../../features/timetable/models/course_model.dart';
import '../../features/timetable/services/timetable_storage.dart';
import '../../features/timetable/utils/date_calculator.dart';
import '../../features/timetable/utils/week_parser.dart';
import '../../features/library/services/library_storage.dart';
import 'course_live_service.dart';
import 'flyme_live_service.dart';

/// 一次“课前/预约前倒计时”窗口：[start - leadMin, start)。
class LiveWindow {
  final int id;
  final String kind; // 'course' | 'library'
  final String name;
  final String location;
  final DateTime start;
  final int leadMin;

  LiveWindow({
    required this.id,
    required this.kind,
    required this.name,
    required this.location,
    required this.start,
    required this.leadMin,
  });

  DateTime get windowStart => start.subtract(Duration(minutes: leadMin));
}

/// 实时卡调度器（单例）。
///
/// - 前台/进程存活：30s tick + resume 即时对账，发卡/按分钟更新/到点撤卡。
/// - 进程被杀：靠原生精确闹钟（live_alarm 通道，Dart 算好窗口一次性编排，
///   事件持久化在原生侧，开机/覆盖安装后自动重建）。
/// - 通道由开关快照决定：flyme 开 → 走 Flyme，否则走 AOSP。
class LiveScheduler {
  static final LiveScheduler _instance = LiveScheduler._internal();
  factory LiveScheduler() => _instance;
  LiveScheduler._internal();

  static const MethodChannel _alarmChannel = MethodChannel('live_alarm');

  // 与 SettingsNotifier 保持一致的 key（各自定义一份，避免循环引用）
  static const String _kCourseLive = 'course_live_enabled';
  static const String _kFlymeLive = 'flyme_live_enabled';
  static const String _kReminder = 'course_reminder_minutes';
  static const String _kLibReminder = 'library_reminder_minutes';

  Future<AppLocalizations> _getL10n() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString('app_language_code');
      if (code != null && code != 'system') {
        return lookupAppLocalizations(Locale(code));
      }
    } catch (_) {}
    try {
      final platformLocale = WidgetsBinding.instance.platformDispatcher.locale;
      return lookupAppLocalizations(platformLocale);
    } catch (_) {
      return lookupAppLocalizations(const Locale('zh'));
    }
  }

  bool _started = false;
  _ResumeObserver? _observer;

  /// App 启动后调用一次（main.dart），幂等。
  void start() {
    if (kIsWeb || _started) return;
    try {
      if (!Platform.isAndroid) return;
    } catch (_) {
      return;
    }
    _started = true;
    _observer = _ResumeObserver(() => tick());
    try {
      WidgetsBinding.instance.addObserver(_observer!);
    } catch (_) {}
    // Timer 随进程生命周期存在，单例常驻无需持有/取消
    Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(tick().catchError((_) {}));
    });
    unawaited(sync().catchError((_) {}));
  }

  /// 全量同步：重算窗口 → 原生闹钟全量替换 → 立即对账一次。
  /// 在课表/预约/开关变化后调用（SettingsNotifier._doRescheduleNotifications 末尾）。
  Future<void> sync() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid) return;
    final prefs = await SharedPreferences.getInstance();
    final channel = _channelOf(prefs);
    final now = DateTime.now();
    final reminderMin = prefs.getInt(_kReminder) ?? 0;
    final libMin = prefs.getInt(_kLibReminder) ?? 0;
    final windows = await _computeWindows(now, reminderMin, libMin);

    if (channel == null) {
      // 双双关闭：清原生闹钟 + 撤掉窗口期附近可能残留的卡
      try {
        await _alarmChannel.invokeMethod('cancelAll');
      } catch (_) {}
      for (final w in windows) {
        if (w.windowStart.isBefore(now.add(const Duration(hours: 1))) &&
            w.start.isAfter(now.subtract(const Duration(hours: 3)))) {
          try {
            await CourseLiveService().cancel(w.id);
          } catch (_) {}
          try {
            await FlymeLiveService().cancel(w.id);
          } catch (_) {}
        }
      }
      return;
    }

    final events = <Map<String, dynamic>>[];
    for (final w in windows) {
      events.addAll(_eventsFor(w, channel, now));
    }
    try {
      await _alarmChannel.invokeMethod('program', {
        'events': jsonEncode(events),
      });
    } catch (_) {}
    await tick(windowsOverride: windows, nowOverride: now, channelOverride: channel);
  }

  /// 即时对账：窗口内发卡/更新，到点撤卡。tick 驱动 + resume + sync 后各调一次。
  Future<void> tick({
    List<LiveWindow>? windowsOverride,
    DateTime? nowOverride,
    String? channelOverride,
  }) async {
    if (kIsWeb) return;
    if (!Platform.isAndroid) return;
    try {
      final now = nowOverride ?? DateTime.now();
      String? channel = channelOverride;
      int reminderMin = 0;
      int libMin = 0;
      if (channel == null || windowsOverride == null) {
        final prefs = await SharedPreferences.getInstance();
        channel ??= _channelOf(prefs);
        reminderMin = prefs.getInt(_kReminder) ?? 0;
        libMin = prefs.getInt(_kLibReminder) ?? 0;
      }
      if (channel == null) return;
      final windows =
          windowsOverride ?? await _computeWindows(now, reminderMin, libMin);
      for (final w in windows) {
        if (!w.windowStart.isAfter(now) && now.isBefore(w.start)) {
          await _fireNow(w, channel, now);
        } else if (!now.isBefore(w.start) &&
            now.isBefore(w.start.add(const Duration(hours: 3)))) {
          // 错过撤卡闹钟的兜底：开课 3h 内看到残留就撤
          try {
            await CourseLiveService().cancel(w.id);
          } catch (_) {}
          try {
            await FlymeLiveService().cancel(w.id);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  // ---------------- 内部 ----------------

  String? _channelOf(SharedPreferences prefs) {
    final flymeOn = prefs.getBool(_kFlymeLive) ?? false;
    final courseOn = prefs.getBool(_kCourseLive) ?? false;
    if (flymeOn) return 'flyme';
    if (courseOn) return 'aosp';
    return null;
  }

  /// 计算未来 7 天 + 过去 3h（供撤残留）内的窗口。
  Future<List<LiveWindow>> _computeWindows(
    DateTime now,
    int reminderMin,
    int libMin,
  ) async {
    final windows = <LiveWindow>[];
    final horizon = now.add(const Duration(days: 7));
    final past = now.subtract(const Duration(hours: 3));

    if (reminderMin > 0) {
      try {
        final storage = TimetableStorage();
        if (await storage.hasLocalTimetable()) {
          final courses = await storage.readCourseList();
          final meta = await storage.readMetadata();
          final firstMondayStr = meta?['firstWeekMonday'] as String?;
          if (courses.isNotEmpty && firstMondayStr != null) {
            final firstMonday = DateTime.parse(firstMondayStr);
            for (final c in courses) {
              windows.addAll(_courseWindows(
                c, firstMonday, reminderMin, now, horizon, past,
              ));
            }
          }
        }
      } catch (_) {}
    }

    if (libMin > 0) {
      try {
        final l10n = await _getL10n();
        final reserves = await LibraryStorage.getCachedReserves();
        for (final r in reserves) {
          final start = r.startTime;
          final ws = start.subtract(Duration(minutes: libMin));
          if (start.isBefore(past) || ws.isAfter(horizon)) continue;
          final id = 82000000 +
              ((r.id.hashCode ^ start.millisecondsSinceEpoch) & 0x7fffffff) %
                  1000000;
          windows.add(LiveWindow(
            id: id,
            kind: 'library',
            name: l10n.seatWithNumber(r.seatNum),
            location: r.fullRoomName,
            start: start,
            leadMin: libMin,
          ));
        }
      } catch (_) {}
    }
    return windows;
  }

  List<LiveWindow> _courseWindows(
    CourseModel c,
    DateTime firstMonday,
    int leadMin,
    DateTime now,
    DateTime horizon,
    DateTime past,
  ) {
    final out = <LiveWindow>[];
    late final List<int> weeks;
    try {
      weeks = WeekParser.parseWeeks(c.weeks).toList();
    } catch (_) {
      return out;
    }
    for (final weekNum in weeks) {
      DateTime date;
      try {
        date = DateCalculator.calculateDate(
          firstWeekMonday: firstMonday,
          weekNumber: weekNum,
          dayOfWeek: c.dayOfWeek,
        );
      } catch (_) {
        continue;
      }
      Map<String, dynamic> timeMap;
      try {
        timeMap = DateCalculator.getSectionTime(c.startPeriod);
      } catch (_) {
        continue;
      }
      final tod = timeMap['start'];
      final start = DateTime(date.year, date.month, date.day,
          (tod.hour as int), (tod.minute as int));
      final ws = start.subtract(Duration(minutes: leadMin));
      if (start.isBefore(past) || ws.isAfter(horizon)) continue;
      final id = 81000000 +
          ((c.id.hashCode ^ start.millisecondsSinceEpoch) & 0x7fffffff) %
              1000000;
      out.add(LiveWindow(
        id: id,
        kind: 'course',
        name: c.name,
        location: c.classroom,
        start: start,
        leadMin: leadMin,
      ));
    }
    return out;
  }

  /// 单个窗口的原生闹钟事件：发卡 + 数个更新点 + 到点撤卡（更新点至多 6 个）。
  List<Map<String, dynamic>> _eventsFor(
    LiveWindow w,
    String channel,
    DateTime now,
  ) {
    final events = <Map<String, dynamic>>[];
    final startMs = w.start.millisecondsSinceEpoch;
    Map<String, dynamic> ev(int slot, String action, DateTime at) => {
          'code': w.id * 10 + slot,
          'action': action,
          'triggerAt': at.millisecondsSinceEpoch,
          'liveId': w.id,
          'kind': w.kind,
          'name': w.name,
          'location': w.location,
          'startTs': startMs,
          'leadMin': w.leadMin,
          'channel': channel,
          'windowEnd': startMs,
        };
    const fire = 'su.soilzhu.chilleast.LIVE_FIRE';
    const end = 'su.soilzhu.chilleast.LIVE_END';

    if (w.windowStart.isAfter(now)) {
      events.add(ev(0, fire, w.windowStart));
    }
    if (w.leadMin > 1) {
      final step = ((w.leadMin - 1) / 6).ceil().clamp(1, w.leadMin);
      var updates = 0;
      var r = w.leadMin - step;
      final marks = <int>[];
      while (r > 1 && updates < 5) {
        marks.add(r);
        updates++;
        r -= step;
      }
      if (updates < 6) marks.add(1);
      var slot = 1;
      for (final m in marks) {
        final at = w.start.subtract(Duration(minutes: m));
        if (at.isAfter(now)) events.add(ev(slot, fire, at));
        slot++;
      }
    }
    if (w.start.isAfter(now)) {
      events.add(ev(9, end, w.start));
    }
    return events;
  }

  Future<void> _fireNow(LiveWindow w, String channel, DateTime now) async {
    final remaining =
        ((w.start.millisecondsSinceEpoch - now.millisecondsSinceEpoch + 59999) ~/
                60000)
            .clamp(1, w.leadMin);
    final hh = w.start.hour.toString().padLeft(2, '0');
    final mm = w.start.minute.toString().padLeft(2, '0');
    final l10n = await _getL10n();

    if (w.kind == 'library') {
      final title = '${w.name} · ${w.location}';
      final text = l10n.liveMinutesRemainingSeat(remaining);
      if (channel == 'flyme') {
        await FlymeLiveService().upsert(
          id: w.id,
          title: title,
          text: text,
          capsuleText: w.location,
          timeText: l10n.liveSeatStartingTime('$hh:$mm'),
        );
      } else {
        await CourseLiveService().upsert(
          id: w.id,
          title: title,
          text: text,
          shortText: w.location,
          progress: w.leadMin - remaining,
          total: w.leadMin,
          whenMs: w.start.millisecondsSinceEpoch,
        );
      }
    } else {
      final title = '${w.name} · ${w.location}';
      final text = l10n.liveMinutesRemainingClass(remaining);
      if (channel == 'flyme') {
        await FlymeLiveService().upsert(
          id: w.id,
          title: title,
          text: text,
          capsuleText: w.location,
          timeText: l10n.liveClassStartingTime('$hh:$mm'),
        );
      } else {
        await CourseLiveService().upsert(
          id: w.id,
          title: title,
          text: text,
          shortText: w.location,
          progress: w.leadMin - remaining,
          total: w.leadMin,
          whenMs: w.start.millisecondsSinceEpoch,
        );
      }
    }
  }
}

class _ResumeObserver extends WidgetsBindingObserver {
  final Future<void> Function() onResume;
  _ResumeObserver(this.onResume);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(onResume().catchError((_) {}));
    }
  }
}
