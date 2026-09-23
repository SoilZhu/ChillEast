import 'dart:io' as io;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/features/timetable/models/course_model.dart';
import 'package:ChillEast/features/timetable/models/timetable_rule_model.dart';
import 'package:ChillEast/features/timetable/services/timetable_rule_service.dart';
import 'package:ChillEast/features/timetable/services/timetable_storage.dart';

/// 本地无课表（关闭自动同步后）时，规则尤其是手动加课仍应生效。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late io.Directory tempDir;
  late TimetableStorage storage;
  late TimetableRuleService ruleService;

  setUpAll(() async {
    tempDir = await io.Directory.systemTemp.createTemp('timetable-rules-nolocal-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => tempDir.path);
    storage = TimetableStorage();
    ruleService = TimetableRuleService(storage: storage);
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    // 每个用例开始：模拟“关闭自动同步后”的状态——无 ICS/课程/原始课表，
    // 保留元数据（开学周一）以便日期正确。
    await storage.deleteTimetable();
    await storage.deleteCourseList();
    await storage.deleteRawCourseList();
    await storage.deleteRules();
    await storage.saveMetadata(
      semester: '2025-2026-1',
      firstWeekMonday: DateTime(2025, 9, 1),
    );
  });

  const custom = CourseModel(
    id: 'custom_1',
    name: '自习',
    teacher: '自己',
    classroom: '图书馆',
    weeks: '1-16(周)',
    periods: '09-10',
    dayOfWeek: 3,
    startPeriod: 9,
    endPeriod: 10,
  );

  test('Custom course rule takes effect with empty base and regenerates files', () async {
    await storage.saveRules([
      TimetableRule.createCustomCourse(course: custom),
    ]);

    // 空基准应用规则：加课应出现
    final applied = ruleService.applyRules([], await storage.readRules());
    expect(applied.length, equals(1));
    expect(applied.first.name, equals('自习'));

    // 全链路：重新生成并落盘，课表页可直接展示
    final regenerated = await ruleService.applyRulesAndRegenerate();
    expect(regenerated.length, equals(1));
    expect(await storage.hasLocalTimetable(), isTrue);
    final stored = await storage.readCourseList();
    expect(stored.length, equals(1));
    expect(stored.first.toJson(), equals(custom.toJson()));
  });

  test('Suspension-only rules on empty base yield empty without crash', () async {
    await storage.saveRules([
      TimetableRule.createSuspension(startWeek: 2, endWeek: 3, courseName: '高数'),
    ]);

    final applied = ruleService.applyRules([], await storage.readRules());
    expect(applied, isEmpty);
    expect(await ruleService.applyRulesAndRegenerate(), isEmpty);
  });

  test('No rules and no local timetable yields empty', () async {
    expect(await ruleService.applyRulesAndRegenerate(), isEmpty);
    expect(await storage.readCourseList(), isEmpty);
  });
}
