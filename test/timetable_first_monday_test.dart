import 'dart:io' as io;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/features/timetable/models/course_model.dart';
import 'package:ChillEast/features/timetable/models/timetable_rule_model.dart';
import 'package:ChillEast/features/timetable/services/timetable_rule_service.dart';
import 'package:ChillEast/features/timetable/services/timetable_storage.dart';

/// 第一周周一解析优先级：
/// 自动同步开：元数据 > 手动设置 > 猜测；关：手动设置 > 元数据 > 猜测。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late io.Directory tempDir;
  late TimetableStorage storage;

  setUpAll(() async {
    tempDir = await io.Directory.systemTemp.createTemp('timetable-monday-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => tempDir.path);
    SharedPreferences.setMockInitialValues({});
    storage = TimetableStorage();
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    await storage.deleteTimetable();
    await storage.deleteCourseList();
    await storage.deleteRawCourseList();
    await storage.deleteRules();
    await storage.deleteMetadata();
    await storage.clearManualFirstWeekMonday();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(TimetableStorage.autoSyncKey);
  });

  test('Manual monday is used when no metadata exists', () async {
    await storage.saveManualFirstWeekMonday(DateTime(2025, 9, 3)); // 周三→归一周一
    final resolved = await storage.resolveFirstWeekMonday();
    expect(resolved, equals(DateTime(2025, 9, 1)));
    expect(resolved.weekday, equals(DateTime.monday));
  });

  test('Metadata wins over manual when auto-sync is on', () async {
    await storage.saveMetadata(
      semester: '2025-2026-1',
      firstWeekMonday: DateTime(2025, 9, 1),
    );
    await storage.saveManualFirstWeekMonday(DateTime(2025, 9, 8));
    final resolved = await storage.resolveFirstWeekMonday();
    expect(resolved, equals(DateTime(2025, 9, 1)));
  });

  test('Manual wins over metadata when auto-sync is off', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(TimetableStorage.autoSyncKey, false);
    await storage.saveMetadata(
      semester: '2025-2026-1',
      firstWeekMonday: DateTime(2025, 9, 1),
    );
    await storage.saveManualFirstWeekMonday(DateTime(2025, 9, 8));
    final resolved = await storage.resolveFirstWeekMonday();
    expect(resolved, equals(DateTime(2025, 9, 8)));
  });

  test('Falls back to a Monday guess when nothing is set', () async {
    final resolved = await storage.resolveFirstWeekMonday();
    expect(resolved.weekday, equals(DateTime.monday));
  });

  test('Regenerated ICS uses manual monday when metadata is missing', () async {
    const custom = CourseModel(
      id: 'custom_1',
      name: '自习',
      teacher: '自己',
      classroom: '图书馆',
      weeks: '1-16(周)',
      periods: '09-10',
      dayOfWeek: 1, // 周一：第 1 周的日期 == firstWeekMonday 当天
      startPeriod: 9,
      endPeriod: 10,
    );
    await storage.saveRules([
      TimetableRule.createCustomCourse(course: custom),
    ]);
    await storage.saveManualFirstWeekMonday(DateTime(2025, 9, 1));

    final regenerated = await TimetableRuleService(storage: storage)
        .applyRulesAndRegenerate();
    expect(regenerated.length, equals(1));

    final ics = await storage.readTimetable();
    expect(ics, isNotNull);
    expect(ics!, contains('DTSTART:20250901T'));
  });
}
