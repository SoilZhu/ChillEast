import 'package:logger/logger.dart';
import '../models/course_model.dart';
import '../models/timetable_rule_model.dart';
import '../services/timetable_storage.dart';
import '../utils/ics_generator.dart';
import '../utils/ics_parser.dart';
import '../utils/week_parser.dart';

/// 课表规则管理与应用服务
class TimetableRuleService {
  static final TimetableRuleService _instance =
      TimetableRuleService._internal();
  factory TimetableRuleService({TimetableStorage? storage}) {
    if (storage != null) {
      return TimetableRuleService._internal(storage: storage);
    }
    return _instance;
  }
  TimetableRuleService._internal({TimetableStorage? storage})
      : _storage = storage ?? TimetableStorage();

  final Logger _logger = Logger();
  final TimetableStorage _storage;

  /// 获取所有已配置的规则
  Future<List<TimetableRule>> getRules() async {
    return _storage.readRules();
  }

  /// 添加一条新规则并重新应用生成 ICS 与课表
  Future<void> addRule(TimetableRule rule) async {
    final rules = await _storage.readRules();
    rules.add(rule);
    await _storage.saveRules(rules);
    await applyRulesAndRegenerate();
  }

  /// 根据 ID 删除一条规则并重新应用生成 ICS 与课表
  Future<void> deleteRule(String ruleId) async {
    final rules = await _storage.readRules();
    rules.removeWhere((r) => r.id == ruleId);
    await _storage.saveRules(rules);
    await applyRulesAndRegenerate();
  }

  /// 清空所有规则并重新应用恢复原始课表
  Future<void> clearAllRules() async {
    await _storage.deleteRules();
    await applyRulesAndRegenerate();
  }

  /// 纯函数：将规则列表应用到原始课程列表中，返回修改后的课程列表
  List<CourseModel> applyRules(
      List<CourseModel> rawCourses, List<TimetableRule> rules) {
    if (rules.isEmpty) {
      return List<CourseModel>.from(rawCourses);
    }

    // 工作课程列表
    List<CourseModel> workingCourses = List<CourseModel>.from(rawCourses);

    for (final rule in rules) {
      switch (rule.type) {
        case TimetableRuleType.suspension:
          workingCourses = _applySuspension(workingCourses, rule);
          break;
        case TimetableRuleType.reschedule:
          workingCourses = _applyReschedule(workingCourses, rule);
          break;
        case TimetableRuleType.customCourse:
          workingCourses = _applyCustomCourse(workingCourses, rule);
          break;
      }
    }

    // 压缩合并相同课程、过滤空周次课程
    return _compactCourses(workingCourses);
  }

  /// 处理停课规则
  List<CourseModel> _applySuspension(
      List<CourseModel> courses, TimetableRule rule) {
    final startWeek = rule.data['startWeek'] as int? ?? 1;
    final endWeek = rule.data['endWeek'] as int? ?? 25;
    final dayOfWeek = rule.data['dayOfWeek'] as int?;
    final courseName = (rule.data['courseName'] as String?)?.trim();
    final startPeriod = rule.data['startPeriod'] as int?;
    final endPeriod = rule.data['endPeriod'] as int?;

    final updated = <CourseModel>[];

    for (final course in courses) {
      // 课程名称过滤
      if (courseName != null && courseName.isNotEmpty) {
        if (!course.name.toLowerCase().contains(courseName.toLowerCase())) {
          updated.add(course);
          continue;
        }
      }

      // 星期过滤
      if (dayOfWeek != null && dayOfWeek > 0) {
        if (course.dayOfWeek != dayOfWeek) {
          updated.add(course);
          continue;
        }
      }

      // 节次过滤
      if (startPeriod != null && endPeriod != null) {
        final overlap =
            !(course.endPeriod < startPeriod || course.startPeriod > endPeriod);
        if (!overlap) {
          updated.add(course);
          continue;
        }
      }

      // 剔除指定周次
      final weeks = WeekParser.parseWeeks(course.weeks);
      weeks.removeWhere((w) => w >= startWeek && w <= endWeek);

      if (weeks.isNotEmpty) {
        updated.add(course.copyWith(
          weeks: WeekParser.formatWeeksForCourse(weeks),
        ));
      }
      // weeks.isEmpty 时直接不添加到 updated，表示该课完全停课
    }

    return updated;
  }

  /// 处理调休/调课规则
  List<CourseModel> _applyReschedule(
      List<CourseModel> courses, TimetableRule rule) {
    final sourceWeek = rule.data['sourceWeek'] as int;
    final sourceDayOfWeek = rule.data['sourceDayOfWeek'] as int;
    final targetWeek = rule.data['targetWeek'] as int;
    final targetDayOfWeek = rule.data['targetDayOfWeek'] as int;
    final courseName = (rule.data['courseName'] as String?)?.trim();
    final isSwap = rule.data['isSwap'] as bool? ?? false;
    final sourceStartPeriod = rule.data['sourceStartPeriod'] as int?;
    final sourceEndPeriod = rule.data['sourceEndPeriod'] as int?;
    final targetStartPeriod = rule.data['targetStartPeriod'] as int?;
    final targetEndPeriod = rule.data['targetEndPeriod'] as int?;

    // 1. 查找源日期需要移动的课程（记录下标，避免依赖对象 identity）
    bool isSourceMatch(CourseModel c) {
      if (c.dayOfWeek != sourceDayOfWeek) return false;
      if (!WeekParser.parseWeeks(c.weeks).contains(sourceWeek)) return false;
      if (courseName != null && courseName.isNotEmpty) {
        if (!c.name.toLowerCase().contains(courseName.toLowerCase()))
          return false;
      }
      if (sourceStartPeriod != null && sourceEndPeriod != null) {
        if (c.startPeriod != sourceStartPeriod ||
            c.endPeriod != sourceEndPeriod) return false;
      }
      return true;
    }

    final sourceMatchedIdx = <int>{};
    for (var i = 0; i < courses.length; i++) {
      if (isSourceMatch(courses[i])) sourceMatchedIdx.add(i);
    }
    final sourceMatches = sourceMatchedIdx.map((i) => courses[i]).toList();

    _logger.i(
        'Reschedule: looking for w:$sourceWeek d:$sourceDayOfWeek c:$courseName p:$sourceStartPeriod-$sourceEndPeriod => matched ${sourceMatches.length} courses');
    if (sourceMatches.isEmpty) {
      _logger.w(
          '⚠️ Reschedule rule matched 0 courses! Source week:$sourceWeek day:$sourceDayOfWeek course:$courseName');
    }

    // 2. 若是互换模式，查找目标日期需要移动的课程
    final targetMatchedIdx = <int>{};
    if (isSwap) {
      for (var i = 0; i < courses.length; i++) {
        final c = courses[i];
        if (c.dayOfWeek != targetDayOfWeek) continue;
        if (!WeekParser.parseWeeks(c.weeks).contains(targetWeek)) continue;
        if (courseName != null && courseName.isNotEmpty) {
          if (!c.name.toLowerCase().contains(courseName.toLowerCase()))
            continue;
        }
        targetMatchedIdx.add(i);
      }
    }
    final targetMatches = targetMatchedIdx.map((i) => courses[i]).toList();

    final updated = <CourseModel>[];

    for (var i = 0; i < courses.length; i++) {
      final course = courses[i];
      var currentCourse = course;

      // 如果是源日期的匹配课程，移除 sourceWeek
      if (sourceMatchedIdx.contains(i)) {
        final weeks = WeekParser.parseWeeks(currentCourse.weeks);
        weeks.remove(sourceWeek);
        if (weeks.isEmpty) {
          continue; // 原时段不再有这门课
        }
        currentCourse = currentCourse.copyWith(
          weeks: WeekParser.formatWeeksForCourse(weeks),
        );
      }

      // 处理目标日期原有的课：如果不是互换且源日期有课移过去，目标日期当前周被冲突课程应当被冲掉/替换
      if (!isSwap &&
          sourceMatches.isNotEmpty &&
          currentCourse.dayOfWeek == targetDayOfWeek) {
        final weeks = WeekParser.parseWeeks(currentCourse.weeks);
        if (weeks.contains(targetWeek)) {
          // 如果是指定单门课程且指定了目标节次，只冲突同节次或同名课程
          final bool shouldReplace;
          if (targetStartPeriod != null && targetEndPeriod != null) {
            final overlap = !(currentCourse.endPeriod < targetStartPeriod ||
                currentCourse.startPeriod > targetEndPeriod);
            shouldReplace = overlap ||
                (courseName != null &&
                    courseName.isNotEmpty &&
                    currentCourse.name
                        .toLowerCase()
                        .contains(courseName.toLowerCase()));
          } else if (courseName != null && courseName.isNotEmpty) {
            shouldReplace = currentCourse.name
                .toLowerCase()
                .contains(courseName.toLowerCase());
          } else {
            // 整天替换
            shouldReplace = true;
          }

          if (shouldReplace) {
            weeks.remove(targetWeek);
            if (weeks.isEmpty) {
              continue;
            }
            currentCourse = currentCourse.copyWith(
              weeks: WeekParser.formatWeeksForCourse(weeks),
            );
          }
        }
      } else if (isSwap && targetMatchedIdx.contains(i)) {
        // 互换模式下，目标课程移除 targetWeek
        final weeks = WeekParser.parseWeeks(currentCourse.weeks);
        weeks.remove(targetWeek);
        if (weeks.isEmpty) {
          continue;
        }
        currentCourse = currentCourse.copyWith(
          weeks: WeekParser.formatWeeksForCourse(weeks),
        );
      }

      updated.add(currentCourse);
    }

    // 3. 将源课程放置到目标日期 (targetWeek, targetDayOfWeek)
    for (final sc in sourceMatches) {
      final startP = targetStartPeriod ?? sc.startPeriod;
      final endP = targetEndPeriod ?? sc.endPeriod;
      final periodStr = '$startP-$endP';
      updated.add(CourseModel(
        id: '${sc.id}_rescheduled_to_${targetWeek}_${targetDayOfWeek}_$periodStr',
        name: sc.name,
        teacher: sc.teacher,
        classroom: sc.classroom,
        weeks: WeekParser.formatWeeksForCourse([targetWeek]),
        periods: periodStr,
        dayOfWeek: targetDayOfWeek,
        startPeriod: startP,
        endPeriod: endP,
      ));
    }

    // 4. 若为互换模式，将目标课程放置到源日期 (sourceWeek, sourceDayOfWeek)
    if (isSwap) {
      for (final tc in targetMatches) {
        updated.add(CourseModel(
          id: '${tc.id}_rescheduled_to_${sourceWeek}_$sourceDayOfWeek',
          name: tc.name,
          teacher: tc.teacher,
          classroom: tc.classroom,
          weeks: WeekParser.formatWeeksForCourse([sourceWeek]),
          periods: tc.periods,
          dayOfWeek: sourceDayOfWeek,
          startPeriod: tc.startPeriod,
          endPeriod: tc.endPeriod,
        ));
      }
    }

    return updated;
  }

  /// 处理手动添加课程规则
  List<CourseModel> _applyCustomCourse(
      List<CourseModel> courses, TimetableRule rule) {
    final custom = rule.customCourse;
    if (custom != null) {
      return [...courses, custom];
    }
    return courses;
  }

  /// 压缩整理课程：合并相同基本属性的课程周次，去重
  List<CourseModel> _compactCourses(List<CourseModel> courses) {
    final Map<String, List<CourseModel>> grouped = {};

    for (final course in courses) {
      final key =
          '${course.name}|${course.teacher}|${course.classroom}|${course.dayOfWeek}|${course.startPeriod}|${course.endPeriod}';
      grouped.putIfAbsent(key, () => []).add(course);
    }

    final result = <CourseModel>[];

    grouped.forEach((key, list) {
      final first = list.first;
      final allWeeks = <int>{};
      for (final c in list) {
        allWeeks.addAll(WeekParser.parseWeeks(c.weeks));
      }

      if (allWeeks.isNotEmpty) {
        final sortedWeeks = allWeeks.toList()..sort();
        result.add(first.copyWith(
          id: first.id,
          weeks: WeekParser.formatWeeksForCourse(sortedWeeks),
        ));
      }
    });

    return result;
  }

  /// 重新从本地原始课表应用所有规则，并覆盖保存 current_timetable.ics 和 courses.json
  ///
  /// 数据不变式：
  /// - raw_courses.json 是教务原始数据（不可变基准），仅在两种情况下写入：
  ///   1) 从教务同步全新课表时（见 YdjwxtService.syncTimetable）；
  ///   2) 历史版本升级的一次性迁移（本地无 raw 文件但有旧 courses.json 时）。
  /// - 已存在的 raw 基准绝不被覆盖，避免把已应用规则的数据写回基准导致规则“没生效”或叠加错乱。
  /// - ICS 是 lossy 的派生产物（会拆散非连续周、重造 id），绝不用它作为规则计算的基准。
  Future<List<CourseModel>> applyRulesAndRegenerate() async {
    try {
      _logger.i('Applying timetable rules and regenerating ICS...');
      // 1. 读取原始课程（不可变基准优先）
      final hasRaw = await _storage.hasRawCourseList();
      List<CourseModel> rawCourses = await _storage.readRawCourseList();
      if (rawCourses.isEmpty) {
        // 一次性迁移：历史版本没有 raw 文件，用旧 courses.json 作为基准并固化一次
        final legacyCourses = await _storage.readCourseList();
        if (legacyCourses.isNotEmpty) {
          rawCourses = legacyCourses;
          if (!hasRaw) {
            await _storage.saveRawCourseList(rawCourses);
            _logger.i(
                'Migrated legacy courses.json to raw baseline (${rawCourses.length} courses)');
          }
        }
      }
      if (rawCourses.isEmpty) {
        // 最后兜底：从已有 ICS 日历文件解析（仅展示恢复，不作为精确基准时也需固化，避免反复走 ICS 回退）
        final icsContent = await _storage.readTimetable();
        if (icsContent != null && icsContent.isNotEmpty) {
          rawCourses = IcsParser.parse(icsContent);
          if (rawCourses.isNotEmpty && !hasRaw) {
            await _storage.saveRawCourseList(rawCourses);
          }
        }
      }

      // 2. 读取规则
      final rules = await _storage.readRules();
      _logger.i(
          'Applying ${rules.length} rules to ${rawCourses.length} raw courses...');

      // 3. 应用规则
      final modifiedCourses = applyRules(rawCourses, rules);

      // 4. 读取开学周一
      final metadata = await _storage.readMetadata();
      DateTime? firstWeekMonday;
      if (metadata != null && metadata['firstWeekMonday'] != null) {
        firstWeekMonday =
            DateTime.tryParse(metadata['firstWeekMonday'] as String);
      }
      firstWeekMonday ??= _guessFirstWeekMonday();

      // 5. 生成 ICS 并保存
      final icsContent =
          IcsGenerator.generate(modifiedCourses, firstWeekMonday);
      await _storage.saveTimetable(icsContent);
      await _storage.saveCourseList(modifiedCourses);

      _logger.i(
          'Timetable regenerated with ${modifiedCourses.length} courses (rules count: ${rules.length})');
      return modifiedCourses;
    } catch (e) {
      _logger.e('Failed to apply rules and regenerate timetable: $e');
      rethrow;
    }
  }

  DateTime _guessFirstWeekMonday() {
    final now = DateTime.now();
    DateTime guess;
    if (now.month >= 8 || now.month <= 1) {
      guess = DateTime(now.month <= 1 ? now.year - 1 : now.year, 9, 1);
    } else {
      guess = DateTime(now.year, 2, 17);
    }
    while (guess.weekday != DateTime.monday) {
      guess = guess.add(const Duration(days: 1));
    }
    return guess;
  }
}
