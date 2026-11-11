import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:ChillEast/features/timetable/models/course_reminder_rule.dart';
import 'package:ChillEast/features/timetable/services/course_reminder_storage.dart';
import 'package:ChillEast/core/mcp/tools/course_reminder_tool.dart';

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final Directory tempDir;
  MockPathProviderPlatform(this.tempDir);

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return tempDir.path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('reminder_test_');
    PathProviderPlatform.instance = MockPathProviderPlatform(tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('CourseReminderRule Model Test', () {
    test('toJson and fromJson work correctly', () {
      final now = DateTime.now();
      final rule = CourseReminderRule(
        id: 'r_1',
        courseName: '高等数学',
        scope: ReminderScope.onlyThis,
        actionType: ReminderActionType.offset,
        offsetMinutes: -15,
        week: 8,
        dayOfWeek: 2,
        startPeriod: 3,
        createdAt: now,
      );

      final json = rule.toJson();
      final restored = CourseReminderRule.fromJson(json);

      expect(restored.id, 'r_1');
      expect(restored.courseName, '高等数学');
      expect(restored.scope, ReminderScope.onlyThis);
      expect(restored.actionType, ReminderActionType.offset);
      expect(restored.baseTime, ReminderBaseTime.settings);
      expect(restored.offsetMinutes, -15);
      expect(restored.isBefore, true);
      expect(restored.isAfter, false);
      expect(restored.week, 8);
      expect(restored.dayOfWeek, 2);
      expect(restored.startPeriod, 3);
    });

    test('Helper getters for offset, disable, and baseTime', () {
      final disableRule = CourseReminderRule(
        id: 'r_2',
        courseName: '英语',
        scope: ReminderScope.all,
        actionType: ReminderActionType.disable,
        baseTime: ReminderBaseTime.classTime,
        createdAt: DateTime.now(),
      );
      expect(disableRule.isDisabled, true);
      expect(disableRule.isBefore, false);
      expect(disableRule.baseTime, ReminderBaseTime.classTime);

      final afterRule = CourseReminderRule(
        id: 'r_3',
        courseName: '物理实验',
        scope: ReminderScope.thisWeekday,
        offsetMinutes: 10,
        dayOfWeek: 4,
        createdAt: DateTime.now(),
      );
      expect(afterRule.isAfter, true);
      expect(afterRule.absMinutes, 10);
    });
  });

  group('Priority Matching (resolveEffectiveRule)', () {
    test('onlyThis has highest priority over thisWeek, thisWeekday, and all', () {
      final rules = [
        CourseReminderRule(
          id: 'rule_all',
          courseName: '操作系统',
          scope: ReminderScope.all,
          offsetMinutes: -5,
          createdAt: DateTime.now(),
        ),
        CourseReminderRule(
          id: 'rule_weekday',
          courseName: '操作系统',
          scope: ReminderScope.thisWeekday,
          dayOfWeek: 1,
          offsetMinutes: -10,
          createdAt: DateTime.now(),
        ),
        CourseReminderRule(
          id: 'rule_week',
          courseName: '操作系统',
          scope: ReminderScope.thisWeek,
          week: 5,
          offsetMinutes: -20,
          createdAt: DateTime.now(),
        ),
        CourseReminderRule(
          id: 'rule_only_this',
          courseName: '操作系统',
          scope: ReminderScope.onlyThis,
          week: 5,
          dayOfWeek: 1,
          startPeriod: 1,
          offsetMinutes: 10, // 延后 10 分钟
          createdAt: DateTime.now(),
        ),
      ];

      // 1. 匹配第 5 周周一第 1 节：命中 onlyThis
      final r1 = CourseReminderStorage.resolveEffectiveRule(
        rules: rules,
        courseName: '操作系统',
        week: 5,
        dayOfWeek: 1,
        startPeriod: 1,
      );
      expect(r1?.id, 'rule_only_this');
      expect(r1?.offsetMinutes, 10);

      // 2. 匹配第 5 周周三第 3 节（无 onlyThis，且 dayOfWeek=3 不是周一）：命中 thisWeek
      final r2 = CourseReminderStorage.resolveEffectiveRule(
        rules: rules,
        courseName: '操作系统',
        week: 5,
        dayOfWeek: 3,
        startPeriod: 3,
      );
      expect(r2?.id, 'rule_week');
      expect(r2?.offsetMinutes, -20);

      // 3. 匹配第 6 周周一第 1 节（非第 5 周）：命中 thisWeekday
      final r3 = CourseReminderStorage.resolveEffectiveRule(
        rules: rules,
        courseName: '操作系统',
        week: 6,
        dayOfWeek: 1,
        startPeriod: 1,
      );
      expect(r3?.id, 'rule_weekday');
      expect(r3?.offsetMinutes, -10);

      // 4. 匹配第 6 周周四第 5 节：命中 all
      final r4 = CourseReminderStorage.resolveEffectiveRule(
        rules: rules,
        courseName: '操作系统',
        week: 6,
        dayOfWeek: 4,
        startPeriod: 5,
      );
      expect(r4?.id, 'rule_all');
      expect(r4?.offsetMinutes, -5);

      // 5. 其它课程无规则：返回 null
      final r5 = CourseReminderStorage.resolveEffectiveRule(
        rules: rules,
        courseName: '大学体育',
        week: 5,
        dayOfWeek: 1,
        startPeriod: 1,
      );
      expect(r5, isNull);
    });
  });

  group('CourseReminderTool (MCP) Integration', () {
    test('set, list, delete, clear flow works correctly', () async {
      final storage = CourseReminderStorage();
      bool rescheduleCalled = false;

      final tool = CourseReminderTool.create(
        storage: storage,
        onRulesChanged: () async {
          rescheduleCalled = true;
        },
      );

      // 1. 初始查询应为空
      final listRes1 = await tool.handler({'action': 'list'});
      expect(listRes1.isError, false);
      expect(listRes1.content.first.text, contains('"count": 0'));

      // 2. 设置单次课提前 15 分钟
      final setRes1 = await tool.handler({
        'action': 'set',
        'courseName': '数据结构',
        'scope': 'only_this',
        'mode': 'before',
        'minutes': 15,
        'week': 7,
        'dayOfWeek': 3,
        'startPeriod': 1,
      });
      expect(setRes1.isError, false);
      expect(rescheduleCalled, true);
      rescheduleCalled = false;

      // 3. 设置全学期延后 5 分钟 (相对于课表时间)
      final setRes2 = await tool.handler({
        'action': 'set',
        'courseName': '算法设计',
        'scope': 'all',
        'mode': 'after',
        'baseTime': 'class_time',
        'minutes': 5,
      });
      expect(setRes2.isError, false);
      expect(setRes2.content.first.text, contains('课表上课时间'));
      expect(rescheduleCalled, true);
      rescheduleCalled = false;

      // 4. 查询全部（count 应为 2）
      final listRes2 = await tool.handler({'action': 'list'});
      expect(listRes2.content.first.text, contains('"count": 2'));

      // 5. 过滤课程查询
      final listResFilter = await tool.handler({
        'action': 'list',
        'courseName': '数据结构',
      });
      expect(listResFilter.content.first.text, contains('"count": 1'));
      expect(listResFilter.content.first.text, contains('数据结构'));

      // 6. 按课程名删除规则
      final deleteRes = await tool.handler({
        'action': 'delete',
        'courseName': '数据结构',
      });
      expect(deleteRes.isError, false);
      expect(rescheduleCalled, true);
      rescheduleCalled = false;

      final listRes3 = await tool.handler({'action': 'list'});
      expect(listRes3.content.first.text, contains('"count": 1'));

      // 7. 清空所有规则
      final clearRes = await tool.handler({'action': 'clear'});
      expect(clearRes.isError, false);
      expect(rescheduleCalled, true);

      final listRes4 = await tool.handler({'action': 'list'});
      expect(listRes4.content.first.text, contains('"count": 0'));
    });
  });
}
