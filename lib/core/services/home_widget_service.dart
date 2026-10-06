import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/homework/models/homework_model.dart';
import '../../features/homework/services/homework_storage.dart';
import '../../features/timetable/models/course_model.dart';
import '../../features/timetable/services/timetable_storage.dart';
import '../../features/timetable/utils/course_color_utils.dart';
import '../../features/timetable/utils/date_calculator.dart';
import '../../features/timetable/utils/ics_parser.dart';
import '../../features/timetable/utils/week_parser.dart';
import '../../l10n/app_localizations.dart';

/// 桌面小组件（Android AppWidget）数据同步服务。
///
/// 三个小组件共用两份 JSON 数据，均存在 SharedPreferences 里，
/// 原生侧直接读取 `flutter.<key>` 前缀的 key（shared_preferences 插件约定）：
/// - `widget_agenda_json`：今日/明日日程
/// - `widget_quick_json`：快捷功能按钮（独立配置，不跟随首页）
///
/// 写完数据后通过 `home_widget` MethodChannel 通知原生刷新。
class HomeWidgetService {
  static const String agendaJsonKey = 'widget_agenda_json';
  static const String quickIdsKey = 'widget_quick_ids';
  static const String quickJsonKey = 'widget_quick_json';
  static const String updatedAtKey = 'widget_updated_at';

  static const MethodChannel _channel = MethodChannel('home_widget');

  /// 快捷功能独立配置的默认值（4 个，对应 2x2 与长条横排）。
  static const List<String> defaultQuickIds = [
    'payment_code',
    'library',
    'repairs',
    'empty_classroom',
  ];

  /// 所有可选功能 id（与外观设置共用同一套 id）。
  static const List<String> allFunctionIds = [
    'payment_code',
    'recharge',
    'ele_recharge',
    'library',
    'empty_classroom',
    'repairs',
    'sunshine',
    'ehall',
    'questionnaire',
    'leave',
    'gym',
    'xgxt',
    'teaching_eval',
    'score',
    'vpn',
    'campus_card',
    'bus',
    'cs_bus',
    'campus_bus_route',
  ];

  /// 按钮 emoji（保留给「日程 + 快捷」长条组件使用；2x2 快捷组件已改用与 App 一致的矢量图标）。
  static const Map<String, String> functionEmoji = {
    'payment_code': '💳',
    'recharge': '👛',
    'ele_recharge': '⚡',
    'library': '📚',
    'empty_classroom': '🚪',
    'ehall': '🏛️',
    'repairs': '🛠️',
    'sunshine': '☀️',
    'questionnaire': '📋',
    'leave': '📄',
    'gym': '🏀',
    'teaching_eval': '📝',
    'score': '📊',
    'vpn': '🔒',
    'campus_card': '💰',
    'bus': '🚌',
    'cs_bus': '🚏',
    'campus_bus_route': '🗺️',
    'xgxt': '🏫',
  };

  /// 功能配色（与外观设置 _masterPool 一致，原生侧为矢量图标着色）。
  static const Map<String, int> functionColors = {
    'sunshine': 0xFF09C489,
    'ehall': 0xFF1E88E5,
    'questionnaire': 0xFF3476E6,
    'leave': 0xFF009688,
    'payment_code': 0xFF00C853,
    'recharge': 0xFFFF9800,
    'library': 0xFF795548,
    'empty_classroom': 0xFF9C27B0,
    'xgxt': 0xFF3476E6,
    'repairs': 0xFF607D8B,
    'gym': 0xFFE91E63,
    'teaching_eval': 0xFF00BCD4,
    'score': 0xFFE63476,
    'vpn': 0xFF607D8B,
    'campus_card': 0xFF008268,
    'ele_recharge': 0xFFFFEB3B,
    'bus': 0xFF34E676,
    'cs_bus': 0xFF2196F3,
    'campus_bus_route': 0xFF00A86B,
  };

  /// 课程配色（与应用内 [CourseColorUtils] 同一色板，保证小组件与课表日程页同色）。
  static const List<int> coursePalette = [
    0xFFEF5350,
    0xFFE53935,
    0xFFD32F2F,
    0xFFEC407A,
    0xFFD81B60,
    0xFFC2185B,
    0xFFAB47BC,
    0xFF8E24AA,
    0xFF7B1FA2,
    0xFF7E57C2,
    0xFF5E35B1,
    0xFF512DA8,
    0xFF5C6BC0,
    0xFF3949AB,
    0xFF303F9F,
    0xFF42A5F5,
    0xFF1E88E5,
    0xFF1976D2,
    0xFF03A9F4,
    0xFF0288D1,
    0xFF00BCD4,
    0xFF0097A7,
    0xFF26A69A,
    0xFF00897B,
    0xFF00796B,
    0xFF66BB6A,
    0xFF43A047,
    0xFF388E3C,
    0xFF8BC34A,
    0xFF689F38,
    0xFFC0CA33,
    0xFF9E9D24,
    0xFFFFA000,
    0xFFFF9800,
    0xFFFB8C00,
    0xFFF57C00,
    0xFFFF7043,
    0xFFF4511E,
    0xFFE64A19,
    0xFF8D6E63,
  ];

  static const int homeworkAccent = 0xFFF39C12;

  // ---------- 纯函数（可单元测试） ----------

  /// 22 点规则：22:00 后预览明天，否则预览今天（只保留年月日）。
  static DateTime previewDateFor(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    if (now.hour >= 22) return today.add(const Duration(days: 1));
    return today;
  }

  static bool isTomorrowPreview(DateTime now) => now.hour >= 22;

  /// 按星期与周次筛选当天课程（week <= 0 时不过滤周次），按开始节排序。
  static List<CourseModel> filterDayCourses(
    List<CourseModel> all,
    int dayOfWeek,
    int week,
  ) {
    final result = all.where((course) {
      if (course.dayOfWeek != dayOfWeek) return false;
      if (week > 0) {
        return WeekParser.parseWeeks(course.weeks).contains(week);
      }
      return true;
    }).toList()
      ..sort((a, b) => a.startPeriod.compareTo(b.startPeriod));
    return result;
  }

  /// 筛选截止于预览日期的待办作业，按截止时间排序。
  static List<HomeworkModel> filterDayHomework(
    List<HomeworkModel> all,
    DateTime previewDate,
  ) {
    final result = all.where((h) {
      if (h.status != HomeworkStatus.pending) return false;
      final end = h.endTime;
      if (end == null) return false;
      return end.year == previewDate.year &&
          end.month == previewDate.month &&
          end.day == previewDate.day;
    }).toList()
      ..sort((a, b) => a.endTime!.compareTo(b.endTime!));
    return result;
  }

  /// 仅保留今天 22 点前未结束的课程（预览明天时不过滤）。
  static List<CourseModel> filterFinishedCourses(
    List<CourseModel> courses,
    TimeOfDay now,
  ) {
    final currentMinutes = now.hour * 60 + now.minute;
    return courses.where((course) {
      final end = DateCalculator.getSectionTime(course.endPeriod)['end'];
      if (end == null) return true;
      return (end.hour * 60 + end.minute) > currentMinutes;
    }).toList();
  }

  /// 稳定字符串哈希（djb2），避免 Dart String.hashCode 跨运行不一致。
  static int stableHash(String input) {
    var hash = 5381;
    for (final rune in input.runes) {
      hash = ((hash << 5) + hash + rune) & 0xFFFFFFFF;
    }
    return hash;
  }

  /// 与课表日程页同色：直接委托 [CourseColorUtils]，避免两端配色分叉。
  static int courseColorFor(String courseName) {
    return CourseColorUtils.getColorForCourse(courseName).toARGB32();
  }

  static String courseTimeRange(CourseModel course) {
    String two(int v) => v.toString().padLeft(2, '0');
    final start = DateCalculator.getSectionTime(course.startPeriod)['start']!;
    final end = DateCalculator.getSectionTime(course.endPeriod)['end']!;
    return '${two(start.hour)}:${two(start.minute)}-'
        '${two(end.hour)}:${two(end.minute)}';
  }

  /// 组装日程数据（作业在前、课程在后，默认展示全部未发生日程，
  /// [maxItems] 仅作兜底上限，避免极端数据撑爆小组件）。
  static Map<String, dynamic> buildAgendaMap({
    required String title,
    required String dateLine,
    required bool isTomorrow,
    required String emptyText,
    required List<HomeworkModel> dayHomework,
    required List<CourseModel> dayCourses,
    required String deadlinePrefix,
    required String noDeadline,
    DateTime? targetDate,
    int maxItems = 20,
  }) {
    final items = <Map<String, dynamic>>[];
    for (final h in dayHomework) {
      if (items.length >= maxItems) break;
      final end = h.endTime;
      final time = end != null
          ? '${end.hour.toString().padLeft(2, '0')}:'
              '${end.minute.toString().padLeft(2, '0')}'
          : noDeadline;
      final course = h.courseName.trim();
      items.add({
        'kind': 'homework',
        'title': h.title,
        'sub': course.isEmpty ? '$deadlinePrefix $time' : '$course · $deadlinePrefix $time',
        'room': '',
        'color': homeworkAccent,
        'endTimeMs': end?.millisecondsSinceEpoch ?? 0,
      });
    }
    for (final c in dayCourses) {
      if (items.length >= maxItems) break;
      // 小组件三行样式：标题课程名 / `@教室` / 副文本`时间段, 老师`
      final room = c.classroom.trim();
      final teacher = c.teacher.trim();
      final sub = [
        courseTimeRange(c),
        teacher,
      ].where((s) => s.isNotEmpty).join(', ');
      int endTimeMs = 0;
      if (targetDate != null) {
        final endSection = DateCalculator.getSectionTime(c.endPeriod)['end'];
        if (endSection != null) {
          final endDt = DateTime(
            targetDate.year,
            targetDate.month,
            targetDate.day,
            endSection.hour,
            endSection.minute,
          );
          endTimeMs = endDt.millisecondsSinceEpoch;
        }
      }
      items.add({
        'kind': 'course',
        'title': c.name,
        'room': room,
        'sub': sub,
        'color': courseColorFor(c.name),
        'endTimeMs': endTimeMs,
      });
    }
    return {
      'title': title,
      'dateLine': dateLine,
      'isTomorrow': isTomorrow,
      'emptyText': emptyText,
      'items': items,
    };
  }

  /// 提取关键闹钟唤醒时刻（下课时刻、作业截止、每日 22:00 切明日、每日 00:00 跨天）。
  static List<int> extractAlarmTimestamps({
    required DateTime now,
    required List<Map<String, dynamic>> days,
  }) {
    final nowMs = now.millisecondsSinceEpoch;
    final alarmSet = <int>{};

    for (final day in days) {
      final dateStr = day['date'] as String?;
      if (dateStr == null) continue;
      final parts = dateStr.split('-');
      if (parts.length != 3) continue;
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final dayNum = int.tryParse(parts[2]);
      if (year == null || month == null || dayNum == null) continue;

      // 1. 每日 22:00:01（切明日）
      final switchTomorrow = DateTime(year, month, dayNum, 22, 0, 1).millisecondsSinceEpoch;
      if (switchTomorrow > nowMs) {
        alarmSet.add(switchTomorrow);
      }

      // 2. 每日 00:00:01（跨天）
      final switchMidnight = DateTime(year, month, dayNum, 0, 0, 1).millisecondsSinceEpoch;
      if (switchMidnight > nowMs) {
        alarmSet.add(switchMidnight);
      }

      // 3. 课程下课时刻与作业截止时刻（+1秒，保证到点时已过期）
      final items = day['items'] as List<dynamic>?;
      if (items != null) {
        for (final item in items) {
          if (item is Map) {
            final endMs = item['endTimeMs'] as int? ?? 0;
            if (endMs > nowMs) {
              alarmSet.add(endMs + 1000);
            }
          }
        }
      }
    }

    final sorted = alarmSet.toList()..sort();
    return sorted.take(30).toList();
  }

  /// 组装快捷功能数据（按传入的 ids 顺序最多取 4 个；少于 4 个不再自动补齐，原生组件上留空）。
  static Map<String, dynamic> buildQuickMap({
    required List<String> ids,
    required String Function(String id) labelOf,
    String title = '',
  }) {
    final picked = ids.where(allFunctionIds.contains).take(4).toList();
    final items = picked.map((id) => {
          'id': id,
          'label': labelOf(id),
          'emoji': functionEmoji[id] ?? '🔹',
          'color': functionColors[id] ?? 0xFF09C489,
        }).toList();
    return {'title': title, 'items': items};
  }

  // ---------- 本地化 ----------

  static String functionLabel(AppLocalizations l10n, String id) {
    switch (id) {
      case 'sunshine':
        return l10n.funcSunshine;
      case 'questionnaire':
        return l10n.funcQuestionnaire;
      case 'leave':
        return l10n.funcLeave;
      case 'payment_code':
        return l10n.funcPaymentCode;
      case 'recharge':
        return l10n.funcRecharge;
      case 'library':
        return l10n.funcLibrary;
      case 'empty_classroom':
        return l10n.funcEmptyClassroom;
      case 'ehall':
        return l10n.funcEhall;
      case 'xgxt':
        return l10n.funcXgxt;
      case 'repairs':
        return l10n.funcRepairs;
      case 'gym':
        return l10n.funcGym;
      case 'teaching_eval':
        return l10n.funcTeachingEval;
      case 'score':
        return l10n.funcScore;
      case 'vpn':
        return l10n.funcVpn;
      case 'campus_card':
        return l10n.funcCampusCard;
      case 'ele_recharge':
        return l10n.funcEleRecharge;
      case 'bus':
        return l10n.funcBus;
      case 'cs_bus':
        return l10n.funcCsBus;
      case 'campus_bus_route':
        return l10n.funcCampusBusRoute;
      default:
        return id;
    }
  }

  static String weekdayName(AppLocalizations l10n, int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return l10n.weekdayMon;
      case DateTime.tuesday:
        return l10n.weekdayTue;
      case DateTime.wednesday:
        return l10n.weekdayWed;
      case DateTime.thursday:
        return l10n.weekdayThu;
      case DateTime.friday:
        return l10n.weekdayFri;
      case DateTime.saturday:
        return l10n.weekdaySat;
      default:
        return l10n.weekdaySun;
    }
  }

  static String monthName(AppLocalizations l10n, int month) {
    switch (month) {
      case 1:
        return l10n.month1;
      case 2:
        return l10n.month2;
      case 3:
        return l10n.month3;
      case 4:
        return l10n.month4;
      case 5:
        return l10n.month5;
      case 6:
        return l10n.month6;
      case 7:
        return l10n.month7;
      case 8:
        return l10n.month8;
      case 9:
        return l10n.month9;
      case 10:
        return l10n.month10;
      case 11:
        return l10n.month11;
      default:
        return l10n.month12;
    }
  }

  // ---------- 持久化与同步 ----------

  Future<List<String>> getWidgetQuickIds({SharedPreferences? prefs}) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    try {
      final raw = sp.getString(quickIdsKey);
      if (raw == null) return List<String>.from(defaultQuickIds);
      final decoded = jsonDecode(raw);
      if (decoded is! List) return List<String>.from(defaultQuickIds);
      final ids =
          decoded.map((e) => e.toString()).where(allFunctionIds.contains).toList();
      return ids;
    } catch (_) {
      return List<String>.from(defaultQuickIds);
    }
  }

  Future<void> saveWidgetQuickIds(List<String> ids) async {
    final valid = ids.where(allFunctionIds.contains).take(4).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(quickIdsKey, jsonEncode(valid));
    await syncWidgets(prefs: prefs);
  }

  /// 读取当前语言并解析为 Locale（跟随系统时按设备语言粗略判断）。
  Future<AppLocalizations> _resolveLocalizations(SharedPreferences prefs) async {
    final code = prefs.getString('app_language_code');
    try {
      if (code != null && code.isNotEmpty && code != 'system') {
        final locale = _localeFromCode(code);
        if (locale != null) return lookupAppLocalizations(locale);
      }
      final device = PlatformDispatcher.instance.locale;
      return lookupAppLocalizations(device);
    } catch (_) {
      return lookupAppLocalizations(const Locale('zh'));
    }
  }

  Locale? _localeFromCode(String code) {
    switch (code) {
      case 'zh':
        return const Locale('zh');
      case 'zh_HK':
        return const Locale('zh', 'HK');
      case 'zh_TW':
        return const Locale('zh', 'TW');
      case 'en':
        return const Locale('en');
      case 'ja':
        return const Locale('ja');
      case 'es':
        return const Locale('es');
      case 'fr':
        return const Locale('fr');
      case 'pt':
        return const Locale('pt');
      case 'ru':
        return const Locale('ru');
      default:
        // 方言等小语种的组件文案回退中文，避免缺 key 崩溃
        return const Locale('zh');
    }
  }

  /// 全量同步：重新计算日程 + 快捷按钮并通知原生刷新。
  Future<void> syncWidgets({SharedPreferences? prefs}) async {
    List<int> alarms = [];
    try {
      final sp = prefs ?? await SharedPreferences.getInstance();
      final l10n = await _resolveLocalizations(sp);

      final ids = await getWidgetQuickIds(prefs: sp);
      final quick = buildQuickMap(
        ids: ids,
        labelOf: (id) => functionLabel(l10n, id),
        title: l10n.quickActions,
      );
      await sp.setString(quickJsonKey, jsonEncode(quick));

      final agenda = await buildAgendaData(l10n);
      alarms = (agenda['alarms'] as List<dynamic>?)?.cast<int>() ?? [];
      await sp.setString(agendaJsonKey, jsonEncode(agenda));
      await sp.setInt(updatedAtKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('⚠️ HomeWidget sync failed: $e');
    }
    try {
      await _channel.invokeMethod('updateWidgets', {
        'alarms': alarms,
      });
    } catch (_) {
      // 原生侧尚未就绪（如桌面暂无小组件）时忽略
    }
  }

  /// 从 TimetableStorage / HomeworkStorage 计算当前应展示的日程及未来 7 天日程。
  Future<Map<String, dynamic>> buildAgendaData(AppLocalizations l10n) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = previewDateFor(now);
    final isTomorrow = isTomorrowPreview(now);

    List<CourseModel> allCourses = [];
    DateTime? firstWeekMonday;
    try {
      final storage = TimetableStorage();
      if (await storage.hasLocalTimetable()) {
        final icsContent = await storage.readTimetable();
        if (icsContent != null) {
          allCourses = IcsParser.parse(icsContent);
          try {
            firstWeekMonday = await storage.resolveFirstWeekMonday();
          } catch (_) {}
        }
      }
    } catch (_) {}

    List<HomeworkModel> allHomework = [];
    try {
      allHomework = await HomeworkStorage().readHomeworkList();
    } catch (_) {}

    // 1. 单日传统数据（供老逻辑及顶层字段兼容）
    int currentWeek = 0;
    if (firstWeekMonday != null) {
      try {
        currentWeek = DateCalculator.getCurrentWeekNumber(firstWeekMonday, target);
      } catch (_) {}
    }
    var dayCourses = filterDayCourses(allCourses, target.weekday, currentWeek);
    if (!isTomorrow) {
      dayCourses =
          filterFinishedCourses(dayCourses, TimeOfDay.fromDateTime(now));
    }
    final dayHomework = filterDayHomework(allHomework, target);

    final singleDateLine =
        '${target.month}月${target.day}日 ${weekdayName(l10n, target.weekday)}';
    final singleMap = buildAgendaMap(
      title: isTomorrow ? l10n.tomorrowAgenda : l10n.todayAgenda,
      dateLine: singleDateLine,
      isTomorrow: isTomorrow,
      emptyText: isTomorrow ? l10n.noCoursesTomorrow : l10n.noCoursesToday,
      dayHomework: dayHomework,
      dayCourses: dayCourses,
      deadlinePrefix: l10n.deadlinePrefix,
      noDeadline: l10n.noDeadline,
      targetDate: target,
    );

    // 2. 多日结构（未来 7 天全量待办与课程，附带 endTimeMs）
    String two(int v) => v.toString().padLeft(2, '0');
    final days = <Map<String, dynamic>>[];

    for (int i = 0; i < 7; i++) {
      final dayDate = today.add(Duration(days: i));
      int w = 0;
      if (firstWeekMonday != null) {
        try {
          w = DateCalculator.getCurrentWeekNumber(firstWeekMonday, dayDate);
        } catch (_) {}
      }
      final coursesForDay = filterDayCourses(allCourses, dayDate.weekday, w);
      final homeworkForDay = filterDayHomework(allHomework, dayDate);
      final dl =
          '${dayDate.month}月${dayDate.day}日 ${weekdayName(l10n, dayDate.weekday)}';
      final dateStr =
          '${dayDate.year}-${two(dayDate.month)}-${two(dayDate.day)}';

      final dayMap = buildAgendaMap(
        title: '',
        dateLine: dl,
        isTomorrow: false,
        emptyText: '',
        dayHomework: homeworkForDay,
        dayCourses: coursesForDay,
        deadlinePrefix: l10n.deadlinePrefix,
        noDeadline: l10n.noDeadline,
        targetDate: dayDate,
      );

      days.add({
        'date': dateStr,
        'dateLine': dl,
        'items': dayMap['items'],
      });
    }

    // 3. 提取所有关键时间节点闹钟
    final alarms = extractAlarmTimestamps(now: now, days: days);

    return {
      ...singleMap,
      'todayTitle': l10n.todayAgenda,
      'tomorrowTitle': l10n.tomorrowAgenda,
      'todayEmptyText': l10n.noCoursesToday,
      'tomorrowEmptyText': l10n.noCoursesTomorrow,
      'days': days,
      'alarms': alarms,
    };
  }

  /// 取出原生侧暂存的小组件点击动作（取后即清）。
  Future<String?> consumeInitialWidgetAction() async {
    try {
      return await _channel.invokeMethod<String>('getInitialWidgetAction');
    } catch (_) {
      return null;
    }
  }
}
