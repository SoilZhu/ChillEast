import 'dart:io' as io;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/features/timetable/models/course_model.dart';
import 'package:ChillEast/features/timetable/models/timetable_rule_model.dart';
import 'package:ChillEast/features/timetable/services/timetable_storage.dart';
import 'package:ChillEast/features/timetable/services/ydjwxt_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late io.Directory tempDir;
  late TimetableStorage storage;

  setUpAll(() async {
    tempDir = await io.Directory.systemTemp.createTemp('timetable-rollback-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => tempDir.path);
    storage = TimetableStorage();
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  const course = CourseModel(
    id: 'c1',
    name: '高数',
    teacher: '张老师',
    classroom: '十教',
    weeks: '1-16(周)',
    periods: '01-02',
    dayOfWeek: 1,
    startPeriod: 1,
    endPeriod: 2,
  );
  const icsContent = 'BEGIN:VCALENDAR\nOLD-DATA\nEND:VCALENDAR';
  final firstMonday = DateTime(2025, 9, 1);

  test('Restore brings back overwritten local timetable after failed sync', () async {
    // 1. 模拟同步前的本地旧课表 + 一条停课规则
    await storage.saveTimetable(icsContent);
    await storage.saveMetadata(semester: '2025-2026-1', firstWeekMonday: firstMonday);
    await storage.saveCourseList([course]);
    await storage.saveRawCourseList([course]);
    final rule = TimetableRule.createSuspension(
      startWeek: 2,
      endWeek: 3,
      courseName: '高数',
    );
    await storage.saveRules([rule]);

    final backup = await TimetableBackup.capture(storage);

    // 2. 模拟同步写一半失败：ICS 被覆盖、课程列表被清空
    await storage.saveTimetable('CORRUPT-PARTIAL-WRITE');
    await storage.deleteCourseList();
    await storage.deleteMetadata();

    // 3. 回滚
    await backup.restore(storage);

    // 4. 旧课表完整恢复，规则全程未被触碰
    expect(await storage.readTimetable(), equals(icsContent));
    final meta = await storage.readMetadata();
    expect(meta?['semester'], equals('2025-2026-1'));
    expect(
      DateTime.parse(meta!['firstWeekMonday'] as String),
      equals(firstMonday),
    );
    final courses = await storage.readCourseList();
    expect(courses.length, equals(1));
    expect(courses.first.toJson(), equals(course.toJson()));
    final raw = await storage.readRawCourseList();
    expect(raw.length, equals(1));
    expect(raw.first.toJson(), equals(course.toJson()));
    expect((await storage.readRules()).length, equals(1));
  });

  test('Restore on empty backup cleans up partial writes', () async {
    // 本地原本就没有课表：备份为空
    await storage.deleteTimetable();
    await storage.deleteMetadata();
    await storage.deleteCourseList();
    await storage.deleteRawCourseList();

    final backup = await TimetableBackup.capture(storage);

    // 模拟首次同步失败前的残留写入
    await storage.saveTimetable('CORRUPT-PARTIAL-WRITE');
    await storage.saveCourseList([course]);

    await backup.restore(storage);

    // 应回到“无本地课表”状态，而不是残留坏数据
    expect(await storage.hasLocalTimetable(), isFalse);
    expect(await storage.readCourseList(), isEmpty);
    expect(await storage.readRawCourseList(), isEmpty);
    expect(await storage.readMetadata(), isNull);
  });
}
