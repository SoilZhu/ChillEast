import 'dart:io' as io;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/features/timetable/models/course_model.dart';
import 'package:ChillEast/features/timetable/models/timetable_rule_model.dart';
import 'package:ChillEast/features/timetable/services/timetable_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late io.Directory tempDir;
  late TimetableStorage storage;

  setUpAll(() async {
    tempDir = await io.Directory.systemTemp.createTemp('storage-rule-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => tempDir.path);
    storage = TimetableStorage();
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  test('raw course list save, read and delete', () async {
    const course = CourseModel(
      id: 'raw1',
      name: '测试原始课程',
      teacher: '测试老师',
      classroom: '测试教室',
      weeks: '1-16(周)',
      periods: '01-02',
      dayOfWeek: 1,
      startPeriod: 1,
      endPeriod: 2,
    );

    await storage.saveRawCourseList([course]);
    final readList = await storage.readRawCourseList();
    expect(readList.length, equals(1));
    expect(readList.first.name, equals('测试原始课程'));

    await storage.deleteRawCourseList();
    // 删掉 raw 后，若 courses.json 也没有，返回空
    final emptyList = await storage.readRawCourseList();
    expect(emptyList, isEmpty);
  });

  test('rules save, read and delete', () async {
    final rule = TimetableRule.createSuspension(
      startWeek: 1,
      endWeek: 2,
      courseName: '测试课程',
    );

    await storage.saveRules([rule]);
    final readRules = await storage.readRules();
    expect(readRules.length, equals(1));
    expect(readRules.first.type, equals(TimetableRuleType.suspension));
    expect(readRules.first.description, contains('测试课程'));

    await storage.deleteRules();
    final clearedRules = await storage.readRules();
    expect(clearedRules, isEmpty);
  });
}
