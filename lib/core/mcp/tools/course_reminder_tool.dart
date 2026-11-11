import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/timetable/models/course_reminder_rule.dart';
import '../../../features/timetable/services/course_reminder_storage.dart';
import '../../../features/profile/providers/settings_provider.dart';
import '../models/mcp_tool.dart';

/// MCP Tool: 课程个性化提醒管理 (manage_course_reminder)
class CourseReminderTool {
  static const String toolName = 'manage_course_reminder';

  static McpTool create({
    CourseReminderStorage? storage,
    Ref? ref,
    Future<void> Function()? onRulesChanged,
  }) {
    final reminderStorage = storage ?? CourseReminderStorage();

    Future<void> triggerReschedule() async {
      if (onRulesChanged != null) {
        await onRulesChanged();
      } else if (ref != null) {
        try {
          await ref.read(settingsProvider.notifier).rescheduleNotifications();
        } catch (_) {}
      }
    }

    return McpTool(
      name: toolName,
      description: '管理单门或批量课程的上课提醒配置。'
          '支持动作：'
          'list（查询自定义提醒规则，支持按 courseName 过滤）；'
          'set（为指定课程设置提前/延后/准时/关闭提醒，并指定生效范围）；'
          'delete（根据 ruleId 或 courseName 删除提醒规则）；'
          'clear（清空所有自定义课程提醒规则）。'
          '设置后自动重新排程系统通知。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'action': {
            'type': 'string',
            'enum': ['list', 'set', 'delete', 'clear'],
            'description': '要执行的操作动作：list (查询), set (设置/新增), delete (删除), clear (清空)。',
          },
          'ruleId': {
            'type': 'string',
            'description': '规则 ID（当 action=delete 且按 ID 精准删除时必填）。',
          },
          'courseName': {
            'type': 'string',
            'description': '课程名称。设置 (set) 时必填，查询或删除时可选用于过滤。',
          },
          'scope': {
            'type': 'string',
            'enum': ['only_this', 'this_weekday', 'this_week', 'all'],
            'description':
                '提醒规则的生效范围：\n'
                '- only_this: 仅本次课（需提供 week、dayOfWeek，可选 startPeriod）\n'
                '- this_weekday: 该课程所有在周X的课（需提供 dayOfWeek）\n'
                '- this_week: 该课程在本周所有的课（需提供 week）\n'
                '- all: 该课程全学期所有的课（默认）',
          },
          'mode': {
            'type': 'string',
            'enum': ['before', 'after', 'exact', 'disable'],
            'description':
                '提醒方式：\n'
                '- before: 提前提醒（搭配 minutes，例如提前 15 分钟）\n'
                '- after: 延后提醒（搭配 minutes，例如上课后 5 分钟提醒）\n'
                '- exact: 准时提醒（上课时刻提醒，即 0 分钟）\n'
                '- disable: 关闭提醒（针对此范围不发送上课通知）',
          },
          'baseTime': {
            'type': 'string',
            'enum': ['settings', 'class_time'],
            'description':
                '提醒计算的基准时间（默认为 settings）：\n'
                '- settings: 相对于系统设置里的默认提前提醒时间\n'
                '- class_time: 相对于课表上的正式开课时间',
          },
          'minutes': {
            'type': 'integer',
            'minimum': 0,
            'maximum': 120,
            'description': '提前或延后的分钟数。例如 10 表示提前 10 分钟或延后 10 分钟。在 exact / disable 模式下可忽略。',
          },
          'week': {
            'type': 'integer',
            'minimum': 1,
            'maximum': 25,
            'description': '目标周次 (1-25)。当 scope 为 only_this 或 this_week 时使用。',
          },
          'dayOfWeek': {
            'type': 'integer',
            'minimum': 1,
            'maximum': 7,
            'description': '目标星期几 (1 为周一 ... 7 为周日)。当 scope 为 only_this 或 this_weekday 时使用。',
          },
          'startPeriod': {
            'type': 'integer',
            'minimum': 1,
            'maximum': 12,
            'description': '起始节次 (1-12)。当 scope 为 only_this 时可选用于精确区分同日多节课。',
          },
        },
        'required': ['action'],
      },
      handler: (arguments) async {
        final action = arguments['action'] as String;

        switch (action) {
          case 'list': {
            final filterCourse = arguments['courseName'] as String?;
            final rules = await reminderStorage.readRules();
            final filtered = filterCourse != null && filterCourse.trim().isNotEmpty
                ? rules.where((r) => r.courseName.contains(filterCourse.trim())).toList()
                : rules;

            return McpToolResult.json({
              'count': filtered.length,
              'rules': filtered.map((r) => r.toJson()).toList(),
            });
          }

          case 'set': {
            final courseName = (arguments['courseName'] as String?)?.trim();
            if (courseName == null || courseName.isEmpty) {
              return McpToolResult.error('设置提醒必须提供课程名称 (courseName)');
            }

            final scopeStr = arguments['scope'] as String? ?? 'all';
            final ReminderScope scope;
            switch (scopeStr) {
              case 'only_this':
                scope = ReminderScope.onlyThis;
                break;
              case 'this_weekday':
                scope = ReminderScope.thisWeekday;
                break;
              case 'this_week':
                scope = ReminderScope.thisWeek;
                break;
              case 'all':
              default:
                scope = ReminderScope.all;
                break;
            }

            final week = (arguments['week'] as num?)?.toInt();
            final dayOfWeek = (arguments['dayOfWeek'] as num?)?.toInt();
            final startPeriod = (arguments['startPeriod'] as num?)?.toInt();

            if (scope == ReminderScope.onlyThis) {
              if (week == null || dayOfWeek == null) {
                return McpToolResult.error(
                    '设置「仅本次课」提醒时，必须同时提供 week (周次) 和 dayOfWeek (星期几)');
              }
            } else if (scope == ReminderScope.thisWeek) {
              if (week == null) {
                return McpToolResult.error('设置「本周所有课」提醒时，必须提供 week (周次)');
              }
            } else if (scope == ReminderScope.thisWeekday) {
              if (dayOfWeek == null) {
                return McpToolResult.error('设置「本周几所有课」提醒时，必须提供 dayOfWeek (星期几)');
              }
            }

            final mode = arguments['mode'] as String? ?? 'before';
            final minutes = (arguments['minutes'] as num?)?.toInt() ?? 10;
            final baseTimeStr = arguments['baseTime'] as String? ?? 'settings';
            final baseTime = baseTimeStr == 'class_time'
                ? ReminderBaseTime.classTime
                : ReminderBaseTime.settings;

            final ReminderActionType actionType;
            final int offsetMinutes;

            if (mode == 'disable') {
              actionType = ReminderActionType.disable;
              offsetMinutes = 0;
            } else if (mode == 'exact') {
              actionType = ReminderActionType.offset;
              offsetMinutes = 0;
            } else if (mode == 'after') {
              actionType = ReminderActionType.offset;
              offsetMinutes = minutes.abs();
            } else {
              // before
              actionType = ReminderActionType.offset;
              offsetMinutes = -minutes.abs();
            }

            final ruleId = 'reminder_${DateTime.now().millisecondsSinceEpoch}_${courseName.hashCode.abs() % 10000}';
            final rule = CourseReminderRule(
              id: ruleId,
              courseName: courseName,
              scope: scope,
              actionType: actionType,
              baseTime: baseTime,
              offsetMinutes: offsetMinutes,
              week: week,
              dayOfWeek: dayOfWeek,
              startPeriod: startPeriod,
              createdAt: DateTime.now(),
            );

            await reminderStorage.addOrUpdateRule(rule);
            await triggerReschedule();

            final baseDesc = baseTime == ReminderBaseTime.settings ? '设置提醒时间' : '课表上课时间';
            String modeDesc;
            if (actionType == ReminderActionType.disable) {
              modeDesc = '已关闭提醒';
            } else if (offsetMinutes < 0) {
              modeDesc = '相对于$baseDesc 提前 ${offsetMinutes.abs()} 分钟提醒';
            } else if (offsetMinutes > 0) {
              modeDesc = '相对于$baseDesc 延后 $offsetMinutes 分钟提醒';
            } else {
              modeDesc = '相对于$baseDesc 准时提醒';
            }

            String scopeDesc;
            switch (scope) {
              case ReminderScope.onlyThis:
                scopeDesc = '仅第 $week 周 周$dayOfWeek 本次课';
                break;
              case ReminderScope.thisWeekday:
                scopeDesc = '所有在周 $dayOfWeek 的课';
                break;
              case ReminderScope.thisWeek:
                scopeDesc = '第 $week 周所有的课';
                break;
              case ReminderScope.all:
                scopeDesc = '全学期所有的课';
                break;
            }

            return McpToolResult.json({
              'success': true,
              'message': '已成功为《$courseName》配置提醒：$modeDesc（生效范围：$scopeDesc）',
              'rule': rule.toJson(),
            });
          }

          case 'delete': {
            final ruleId = arguments['ruleId'] as String?;
            final courseName = (arguments['courseName'] as String?)?.trim();

            if (ruleId != null && ruleId.isNotEmpty) {
              final ok = await reminderStorage.deleteRule(ruleId);
              if (ok) {
                await triggerReschedule();
                return McpToolResult.json({
                  'success': true,
                  'message': '已删除提醒规则: $ruleId',
                });
              } else {
                return McpToolResult.error('未找到 ID 为 $ruleId 的提醒规则');
              }
            } else if (courseName != null && courseName.isNotEmpty) {
              final scopeStr = arguments['scope'] as String?;
              ReminderScope? scope;
              if (scopeStr != null) {
                scope = ReminderScope.values.firstWhere(
                  (e) => e.name == scopeStr || e.toJson() == scopeStr,
                  orElse: () => ReminderScope.all,
                );
              }
              final deletedCount = await reminderStorage.deleteRulesForCourse(courseName, scope: scope);
              await triggerReschedule();
              return McpToolResult.json({
                'success': true,
                'message': '已为《$courseName》清除 $deletedCount 条提醒规则',
                'deletedCount': deletedCount,
              });
            } else {
              return McpToolResult.error('删除规则必须提供 ruleId 或 courseName');
            }
          }

          case 'clear': {
            await reminderStorage.clearRules();
            await triggerReschedule();
            return McpToolResult.json({
              'success': true,
              'message': '已清空所有课程个性化提醒规则',
            });
          }

          default:
            return McpToolResult.error('未知 action: $action');
        }
      },
    );
  }
}
