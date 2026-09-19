import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/core/mcp/models/mcp_tool.dart';
import 'package:ChillEast/core/mcp/tools/timetable_rule_tool.dart';
import 'package:ChillEast/features/timetable/models/course_model.dart';
import 'package:ChillEast/features/timetable/models/timetable_rule_model.dart';
import 'package:ChillEast/features/timetable/services/timetable_rule_service.dart';
import 'package:ChillEast/features/timetable/services/timetable_storage.dart';

class FakeRuleTimetableStorage extends TimetableStorage {
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
      name: '大学物理',
      teacher: '李老师',
      classroom: '十教北202',
      weeks: '1-8(周)',
      periods: '03-04',
      dayOfWeek: 5,
      startPeriod: 3,
      endPeriod: 4,
    ),
  ];

  List<CourseModel> savedCourses = [];
  List<TimetableRule> savedRules = [];
  String? savedIcs;

  @override
  Future<List<CourseModel>> readRawCourseList() async => List.from(rawCourses);

  @override
  Future<List<CourseModel>> readCourseList() async => List.from(savedCourses.isEmpty ? rawCourses : savedCourses);

  @override
  Future<void> saveCourseList(List<CourseModel> courses) async {
    savedCourses = courses;
  }

  @override
  Future<void> saveTimetable(String ics) async {
    savedIcs = ics;
  }

  @override
  Future<List<TimetableRule>> readRules() async => List.from(savedRules);

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
  group('TimetableRuleTool MCP Tests', () {
    late FakeRuleTimetableStorage fakeStorage;
    late TimetableRuleService ruleService;
    late McpTool tool;

    setUp(() {
      fakeStorage = FakeRuleTimetableStorage();
      ruleService = TimetableRuleService(storage: fakeStorage);
      tool = TimetableRuleTool.create(service: ruleService);
    });

    test('list action returns empty list initially', () async {
      final result = await tool.execute({'action': 'list'});

      expect(result.isError, isFalse);
      final json = jsonDecode(result.content.first.text!);
      expect(json['totalCount'], equals(0));
      expect(json['rules'], isEmpty);
    });

    test('add_reschedule adds rule and regenerates timetable', () async {
      final result = await tool.execute({
        'action': 'add_reschedule',
        'sourceWeek': 1,
        'sourceDayOfWeek': 5,
        'targetWeek': 2,
        'targetDayOfWeek': 7,
        'courseName': '大学物理',
        'isSwap': false,
      });

      expect(result.isError, isFalse);
      final json = jsonDecode(result.content.first.text!);
      expect(json['status'], equals('success'));
      expect(fakeStorage.savedRules.length, equals(1));
      expect(fakeStorage.savedRules.first.type, equals(TimetableRuleType.reschedule));

      // 验证 ICS 已经被重新生成
      expect(fakeStorage.savedIcs, isNotNull);
      expect(fakeStorage.savedIcs, contains('大学物理'));

      // 验证在目标周日生成了新课程
      expect(fakeStorage.savedCourses.any((c) => c.name == '大学物理' && c.dayOfWeek == 7), isTrue);
    });

    test('add_suspension adds suspension rule and updates courses', () async {
      final result = await tool.execute({
        'action': 'add_suspension',
        'startWeek': 1,
        'endWeek': 4,
        'courseName': '高等数学',
      });

      expect(result.isError, isFalse);
      final json = jsonDecode(result.content.first.text!);
      expect(json['status'], equals('success'));
      expect(fakeStorage.savedRules.length, equals(1));
      expect(fakeStorage.savedRules.first.type, equals(TimetableRuleType.suspension));

      // 高数前 4 周停课后，周次应该变成 5-16
      final math = fakeStorage.savedCourses.firstWhere((c) => c.name == '高等数学');
      expect(math.weeks, equals('5-16(周)'));
    });

    test('add_custom_course adds new course to timetable', () async {
      final result = await tool.execute({
        'action': 'add_custom_course',
        'customCourseName': '人工智能实验',
        'teacher': '孙老师',
        'classroom': '图信楼401',
        'weeks': '1-8(周)',
        'customDayOfWeek': 3,
        'customStartPeriod': 5,
        'customEndPeriod': 6,
      });

      expect(result.isError, isFalse);
      final json = jsonDecode(result.content.first.text!);
      expect(json['status'], equals('success'));
      expect(fakeStorage.savedRules.length, equals(1));

      expect(fakeStorage.savedCourses.any((c) => c.name == '人工智能实验'), isTrue);
      expect(fakeStorage.savedIcs, contains('人工智能实验'));
    });

    test('delete_rule deletes specified rule and restores timetable', () async {
      // 先添加一条停课规则
      await tool.execute({
        'action': 'add_suspension',
        'startWeek': 1,
        'endWeek': 16,
        'courseName': '高等数学',
      });
      expect(fakeStorage.savedRules.length, equals(1));
      final ruleId = fakeStorage.savedRules.first.id;

      // 删除该规则
      final result = await tool.execute({
        'action': 'delete_rule',
        'ruleId': ruleId,
      });

      expect(result.isError, isFalse);
      expect(fakeStorage.savedRules, isEmpty);

      // 高数恢复 1-16 周
      final math = fakeStorage.savedCourses.firstWhere((c) => c.name == '高等数学');
      expect(math.weeks, equals('1-16(周)'));
    });

    test('clear_rules removes all rules and restores raw timetable', () async {
      await tool.execute({
        'action': 'add_custom_course',
        'customCourseName': '测试课程1',
      });
      await tool.execute({
        'action': 'add_custom_course',
        'customCourseName': '测试课程2',
      });
      expect(fakeStorage.savedRules.length, equals(2));

      final result = await tool.execute({
        'action': 'clear_rules',
      });

      expect(result.isError, isFalse);
      expect(fakeStorage.savedRules, isEmpty);
      expect(fakeStorage.savedCourses.any((c) => c.name == '测试课程1'), isFalse);
    });
  });
}
