import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/core/mcp/tools/timetable_rule_tool.dart';
import 'package:ChillEast/features/timetable/models/course_model.dart';
import 'package:ChillEast/features/timetable/models/timetable_rule_model.dart';
import 'package:ChillEast/features/timetable/services/timetable_rule_service.dart';
import 'package:ChillEast/features/timetable/services/timetable_storage.dart';
import 'package:ChillEast/features/timetable/utils/week_parser.dart';

/// 可追踪 raw 写入行为的假存储：raw 基准一旦存在就绝不能被覆盖。
class BaselineFakeStorage extends TimetableStorage {
  List<CourseModel> rawCourses = [
    const CourseModel(
      id: 'c1',
      name: '高等数学',
      teacher: '张老师',
      classroom: '十教南101',
      weeks: '1-16(周)',
      periods: '01-02',
      dayOfWeek: 1,
      startPeriod: 1,
      endPeriod: 2,
    ),
    const CourseModel(
      id: 'c2',
      name: '高等数学',
      teacher: '张老师',
      classroom: '十教南101',
      weeks: '1-16(周)',
      periods: '03-04',
      dayOfWeek: 1,
      startPeriod: 3,
      endPeriod: 4,
    ),
  ];

  List<CourseModel> savedCourses = [];
  List<TimetableRule> savedRules = [];
  String? savedIcs;
  int saveRawCallCount = 0;
  List<CourseModel>? lastSavedRaw;

  @override
  Future<bool> hasRawCourseList() async => true;

  @override
  Future<List<CourseModel>> readRawCourseList() async =>
      List.from(rawCourses);

  @override
  Future<List<CourseModel>> readCourseList() async => List.from(
      savedCourses.isEmpty ? rawCourses : savedCourses);

  @override
  Future<void> saveCourseList(List<CourseModel> courses) async {
    savedCourses = courses;
  }

  @override
  Future<void> saveRawCourseList(List<CourseModel> courses) async {
    saveRawCallCount++;
    lastSavedRaw = List.from(courses);
  }

  @override
  Future<void> saveTimetable(String ics) async {
    savedIcs = ics;
  }

  @override
  Future<String?> readTimetable() async => savedIcs;

  @override
  Future<List<TimetableRule>> readRules() async =>
      List.from(savedRules);

  @override
  Future<void> saveRules(List<TimetableRule> rules) async {
    savedRules = List.from(rules);
  }

  @override
  Future<void> deleteRules() async {
    savedRules.clear();
  }

  @override
  Future<Map<String, dynamic>?> readMetadata() async => {
        'semester': '2026-2027-1',
        'firstWeekMonday': '2026-09-01T00:00:00.000',
      };
}

void main() {
  group('Raw baseline immutability (rules must stay effective)', () {
    late BaselineFakeStorage fakeStorage;
    late TimetableRuleService ruleService;

    setUp(() {
      fakeStorage = BaselineFakeStorage();
      ruleService = TimetableRuleService(storage: fakeStorage);
    });

    test('adding rules never overwrites existing raw baseline', () async {
      await ruleService.addRule(TimetableRule.createSuspension(
        startWeek: 5,
        endWeek: 5,
        courseName: '高等数学',
      ));
      await ruleService.addRule(TimetableRule.createReschedule(
        sourceWeek: 6,
        sourceDayOfWeek: 1,
        targetWeek: 6,
        targetDayOfWeek: 7,
        courseName: '高等数学',
        sourceStartPeriod: 1,
        sourceEndPeriod: 2,
      ));

      expect(fakeStorage.saveRawCallCount, equals(0),
          reason: '已存在的 raw 基准绝不能被覆盖，否则规则会被 baked 进基准导致后续规则错乱');
      // 基准本身保持原始 1-16 周
      expect(WeekParser.parseWeeks(fakeStorage.rawCourses.first.weeks).length,
          equals(16));
    });

    test('sequential rules compose on the pristine baseline', () async {
      await ruleService.addRule(TimetableRule.createSuspension(
        startWeek: 5,
        endWeek: 5,
        courseName: '高等数学',
      ));
      await ruleService.addRule(TimetableRule.createReschedule(
        sourceWeek: 6,
        sourceDayOfWeek: 1,
        targetWeek: 6,
        targetDayOfWeek: 7,
        courseName: '高等数学',
        sourceStartPeriod: 1,
        sourceEndPeriod: 2,
      ));

      // 周一 1-2 节的高数：第 5 周停课、第 6 周调走
      final monday12 = fakeStorage.savedCourses
          .where((c) => c.dayOfWeek == 1 && c.startPeriod == 1);
      for (final c in monday12) {
        final weeks = WeekParser.parseWeeks(c.weeks);
        expect(weeks.contains(5), isFalse);
        expect(weeks.contains(6), isFalse);
        expect(weeks.contains(7), isTrue);
      }
      // 周日第 6 周出现补课
      final sunday = fakeStorage.savedCourses.where((c) =>
          c.dayOfWeek == 7 &&
          WeekParser.parseWeeks(c.weeks).contains(6) &&
          c.name == '高等数学');
      expect(sunday.isNotEmpty, isTrue);
    });

    test('single-course reschedule only moves the matching period', () async {
      await ruleService.addRule(TimetableRule.createReschedule(
        sourceWeek: 5,
        sourceDayOfWeek: 1,
        sourceStartPeriod: 1,
        sourceEndPeriod: 2,
        targetWeek: 5,
        targetDayOfWeek: 3,
        targetStartPeriod: 1,
        targetEndPeriod: 2,
        courseName: '高等数学',
      ));

      // 1-2 节被调走（第 5 周不在周一）
      final monday12 = fakeStorage.savedCourses
          .where((c) => c.dayOfWeek == 1 && c.startPeriod == 1)
          .toList();
      for (final c in monday12) {
        expect(WeekParser.parseWeeks(c.weeks).contains(5), isFalse);
      }
      // 3-4 节纹丝不动（第 5 周仍在周一）
      final monday34 = fakeStorage.savedCourses
          .where((c) => c.dayOfWeek == 1 && c.startPeriod == 3)
          .toList();
      expect(monday34.isNotEmpty, isTrue);
      for (final c in monday34) {
        expect(WeekParser.parseWeeks(c.weeks).contains(5), isTrue);
      }
    });
  });

  group('MCP manage_timetable_rules schema', () {
    test('reschedule exposes precise period parameters', () {
      final tool = TimetableRuleTool.create(
          service: TimetableRuleService(storage: BaselineFakeStorage()));
      final schema = tool.inputSchema!;
      final props = schema['properties'] as Map<String, dynamic>;
      for (final key in [
        'sourceStartPeriod',
        'sourceEndPeriod',
        'targetStartPeriod',
        'targetEndPeriod',
      ]) {
        expect(props.containsKey(key), isTrue, reason: 'schema 缺少 $key');
      }
    });
  });
}
