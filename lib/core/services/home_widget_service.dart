import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/homework/models/homework_model.dart';
import '../../features/homework/services/homework_storage.dart';
import '../../features/timetable/models/course_model.dart';
import '../../features/timetable/services/timetable_storage.dart';
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
    'empty_classroom',
    'bus',
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

  /// 按钮 emoji（原生 RemoteViews 不便使用 Flutter Icon，用 emoji 代替）。
  static const Map<String, String> functionEmoji = {
    'payment_code': '💳',
    'recharge': '👛',
    'ele_recharge': '⚡',
    'library': '📚',
    'empty_classroom': '🚪',
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

  /// 课程配色（与应用内 CourseColorUtils 同色系，稳定哈希保证多次同步一致）。
  static const List<int> coursePalette = [
    0xFFEF5350,
    0xFFE53935,
    0xFFEC407A,
    0xFFAB47BC,
    0xFF7E57C2,
    0xFF5C6BC0,
    0xFF42A5F5,
    0xFF03A9F4,
    0xFF00BCD4,
    0xFF26A69A,
    0xFF66BB6A,
    0xFF8BC34A,
    0xFFFFA000,
    0xFFFF9800,
    0xFFFF7043,
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

  static int courseColorFor(String courseName) {
    if (courseName.isEmpty) return coursePalette[0];
    return coursePalette[stableHash(courseName) % coursePalette.length];
  }

  static String courseTimeRange(CourseModel course) {
    String two(int v) => v.toString().padLeft(2, '0');
    final start = DateCalculator.getSectionTime(course.startPeriod)['start']!;
    final end = DateCalculator.getSectionTime(course.endPeriod)['end']!;
    return '${two(start.hour)}:${two(start.minute)}-'
        '${two(end.hour)}:${two(end.minute)}';
  }

  /// 组装日程数据（作业在前、课程在后，最多 [maxItems] 条）。
  static Map<String, dynamic> buildAgendaMap({
    required String title,
    required String dateLine,
    required bool isTomorrow,
    required String emptyText,
    required List<HomeworkModel> dayHomework,
    required List<CourseModel> dayCourses,
    required String deadlinePrefix,
    required String noDeadline,
    int maxItems = 4,
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
        'color': homeworkAccent,
      });
    }
    for (final c in dayCourses) {
      if (items.length >= maxItems) break;
      final room = c.classroom.trim();
      items.add({
        'kind': 'course',
        'title': c.name,
        'sub': room.isEmpty
            ? courseTimeRange(c)
            : '${courseTimeRange(c)} @ $room',
        'color': courseColorFor(c.name),
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

  /// 组装快捷功能数据（固定补齐/截断到 4 个，保证原生布局稳定）。
  static Map<String, dynamic> buildQuickMap({
    required List<String> ids,
    required String Function(String id) labelOf,
    String title = '',
  }) {
    final picked = ids.where(allFunctionIds.contains).toList();
    for (final fallback in defaultQuickIds) {
      if (picked.length >= 4) break;
      if (!picked.contains(fallback)) picked.add(fallback);
    }
    final items = picked.take(4).map((id) => {
          'id': id,
          'label': labelOf(id),
          'emoji': functionEmoji[id] ?? '🔹',
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
      if (ids.isEmpty) return List<String>.from(defaultQuickIds);
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
      await sp.setString(agendaJsonKey, jsonEncode(agenda));
      await sp.setInt(updatedAtKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('⚠️ HomeWidget sync failed: $e');
    }
    try {
      await _channel.invokeMethod('updateWidgets');
    } catch (_) {
      // 原生侧尚未就绪（如桌面暂无小组件）时忽略
    }
  }

  /// 从 TimetableStorage / HomeworkStorage 计算当前应展示的日程。
  Future<Map<String, dynamic>> buildAgendaData(AppLocalizations l10n) async {
    final now = DateTime.now();
    final target = previewDateFor(now);
    final isTomorrow = isTomorrowPreview(now);

    List<CourseModel> dayCourses = [];
    try {
      final storage = TimetableStorage();
      if (await storage.hasLocalTimetable()) {
        final icsContent = await storage.readTimetable();
        if (icsContent != null) {
          final allCourses = IcsParser.parse(icsContent);
          int week = 0;
          try {
            final monday = await storage.resolveFirstWeekMonday();
            week = DateCalculator.getCurrentWeekNumber(monday, target);
          } catch (_) {}
          dayCourses = filterDayCourses(allCourses, target.weekday, week);
          if (!isTomorrow) {
            dayCourses =
                filterFinishedCourses(dayCourses, TimeOfDay.fromDateTime(now));
          }
        }
      }
    } catch (_) {}

    List<HomeworkModel> dayHomework = [];
    try {
      final all = await HomeworkStorage().readHomeworkList();
      dayHomework = filterDayHomework(all, target);
    } catch (_) {}

    final dateLine =
        '${target.month}月${target.day}日 ${weekdayName(l10n, target.weekday)}';
    return buildAgendaMap(
      title: isTomorrow ? l10n.tomorrowAgenda : l10n.todayAgenda,
      dateLine: dateLine,
      isTomorrow: isTomorrow,
      emptyText: isTomorrow ? l10n.noCoursesTomorrow : l10n.noCoursesToday,
      dayHomework: dayHomework,
      dayCourses: dayCourses,
      deadlinePrefix: l10n.deadlinePrefix,
      noDeadline: l10n.noDeadline,
    );
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
