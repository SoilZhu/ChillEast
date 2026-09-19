import '../../../features/timetable/models/course_model.dart';
import '../../../features/timetable/models/timetable_rule_model.dart';
import '../../../features/timetable/services/timetable_rule_service.dart';
import '../../../features/timetable/utils/week_parser.dart';
import '../models/mcp_tool.dart';

/// MCP Tool: 课表规则管理 (manage_timetable_rules)
class TimetableRuleTool {
  static const String toolName = 'manage_timetable_rules';

  static McpTool create({
    TimetableRuleService? service,
  }) {
    final ruleService = service ?? TimetableRuleService();

    return McpTool(
      name: toolName,
      description: '管理课表调整：调课、停课、加课、查看与删除。'
          '动作：'
          'list 查询已有调整；'
          'add_reschedule 调课（挪动或对调）；'
          'add_suspension 停课；'
          'add_custom_course 加课；'
          'delete_rule 按 ruleId 删除；'
          'clear_rules 清空。'
          '改动后课表自动更新。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'action': {
            'type': 'string',
            'enum': [
              'list',
              'add_reschedule',
              'add_suspension',
              'add_custom_course',
              'delete_rule',
              'clear_rules',
            ],
            'description': '要执行的操作动作。',
          },
          'ruleId': {
            'type': 'string',
            'description': '要删除的规则 ID（当 action 为 delete_rule 时必填）。',
          },
          'sourceWeek': {
            'type': 'integer',
            'description': '调休源周次 (1-25)。',
            'minimum': 1,
            'maximum': 25,
          },
          'sourceDayOfWeek': {
            'type': 'integer',
            'description': '调休源星期几 (1-7)。',
            'minimum': 1,
            'maximum': 7,
          },
          'targetWeek': {
            'type': 'integer',
            'description': '调休目标周次 (1-25)。',
            'minimum': 1,
            'maximum': 25,
          },
          'targetDayOfWeek': {
            'type': 'integer',
            'description': '调休目标星期几 (1-7)。',
            'minimum': 1,
            'maximum': 7,
          },
          'courseName': {
            'type': 'string',
            'description': '指定调休或停课的课程名称（可选，留空则针对整天/所有课程）。',
          },
          'isSwap': {
            'type': 'boolean',
            'description': '调休时是否为双向互换。默认为 false (移动/单向补课模式)。',
          },
          'sourceStartPeriod': {
            'type': 'integer',
            'description': '调课源节次起始 (1-12，可选；单门调课时建议提供以精确定位)。',
            'minimum': 1,
            'maximum': 12,
          },
          'sourceEndPeriod': {
            'type': 'integer',
            'description': '调课源节次结束 (1-12，可选)。',
            'minimum': 1,
            'maximum': 12,
          },
          'targetStartPeriod': {
            'type': 'integer',
            'description': '调课目标节次起始 (1-12，可选；不提供则保持原节次)。',
            'minimum': 1,
            'maximum': 12,
          },
          'targetEndPeriod': {
            'type': 'integer',
            'description': '调课目标节次结束 (1-12，可选)。',
            'minimum': 1,
            'maximum': 12,
          },
          'startWeek': {
            'type': 'integer',
            'description': '停课起始周次 (1-25)。',
            'minimum': 1,
            'maximum': 25,
          },
          'endWeek': {
            'type': 'integer',
            'description': '停课结束周次 (1-25)。',
            'minimum': 1,
            'maximum': 25,
          },
          'dayOfWeek': {
            'type': 'integer',
            'description': '停课星期几 (1-7，可选)。',
            'minimum': 1,
            'maximum': 7,
          },
          'startPeriod': {
            'type': 'integer',
            'description': '停课起始节次 (1-12，可选)。',
          },
          'endPeriod': {
            'type': 'integer',
            'description': '停课结束节次 (1-12，可选)。',
          },
          'customCourseName': {
            'type': 'string',
            'description': '手动添加课程的名称（必填）。',
          },
          'teacher': {
            'type': 'string',
            'description': '授课教师姓名（可选）。',
          },
          'classroom': {
            'type': 'string',
            'description': '上课教室/地点（可选）。',
          },
          'weeks': {
            'type': 'string',
            'description': '上课周次，例如 "1-16(周)" 或 "1,3,5(周)"。',
          },
          'customDayOfWeek': {
            'type': 'integer',
            'description': '上课星期几 (1-7)。',
            'minimum': 1,
            'maximum': 7,
          },
          'customStartPeriod': {
            'type': 'integer',
            'description': '起始节次 (1-12)。',
            'minimum': 1,
            'maximum': 12,
          },
          'customEndPeriod': {
            'type': 'integer',
            'description': '结束节次 (1-12)。',
            'minimum': 1,
            'maximum': 12,
          },
        },
        'required': ['action'],
      },
      handler: (arguments) async {
        final action = arguments['action'] as String?;
        if (action == null || action.isEmpty) {
          return McpToolResult.error('未指定 action 操作');
        }

        // JSON 传输中数字可能是 int 或 double，这里统一兼容为 int
        int? asInt(Object? v) {
          if (v == null) return null;
          if (v is int) return v;
          if (v is double) return v.toInt();
          if (v is num) return v.toInt();
          if (v is String) return int.tryParse(v);
          return null;
        }

        switch (action) {
          case 'list':
            final rules = await ruleService.getRules();
            final list = rules
                .map((r) => {
                      'id': r.id,
                      'type': r.type.name,
                      'description': r.description,
                      'createdAt': r.createdAt.toIso8601String(),
                      'data': r.data,
                    })
                .toList();
            return McpToolResult.json({
              'totalCount': list.length,
              'rules': list,
            });

          case 'add_reschedule':
            final sourceWeek = asInt(arguments['sourceWeek']);
            final sourceDayOfWeek = asInt(arguments['sourceDayOfWeek']);
            final targetWeek = asInt(arguments['targetWeek']);
            final targetDayOfWeek = asInt(arguments['targetDayOfWeek']);
            final sourceStartPeriod = asInt(arguments['sourceStartPeriod']);
            final sourceEndPeriod = asInt(arguments['sourceEndPeriod']);
            final targetStartPeriod = asInt(arguments['targetStartPeriod']);
            final targetEndPeriod = asInt(arguments['targetEndPeriod']);
            final courseName = arguments['courseName'] as String?;
            final isSwap = arguments['isSwap'] as bool? ?? false;

            if (sourceWeek == null ||
                sourceDayOfWeek == null ||
                targetWeek == null ||
                targetDayOfWeek == null) {
              return McpToolResult.error(
                  '调休/调课规则需要提供 sourceWeek, sourceDayOfWeek, targetWeek, targetDayOfWeek 参数');
            }

            final rule = TimetableRule.createReschedule(
              sourceWeek: sourceWeek,
              sourceDayOfWeek: sourceDayOfWeek,
              targetWeek: targetWeek,
              targetDayOfWeek: targetDayOfWeek,
              courseName: courseName,
              sourceStartPeriod: sourceStartPeriod,
              sourceEndPeriod: sourceEndPeriod,
              targetStartPeriod: targetStartPeriod,
              targetEndPeriod: targetEndPeriod,
              isSwap: isSwap,
            );

            await ruleService.addRule(rule);
            return McpToolResult.json({
              'status': 'success',
              'message': '调课已保存，课表已更新。',
              'rule': rule.toJson(),
            });

          case 'add_suspension':
            final startWeek = asInt(arguments['startWeek']);
            final endWeek = asInt(arguments['endWeek']) ?? startWeek;
            final dayOfWeek = asInt(arguments['dayOfWeek']);
            final courseName = arguments['courseName'] as String?;
            final startPeriod = asInt(arguments['startPeriod']);
            final endPeriod = asInt(arguments['endPeriod']);

            if (startWeek == null) {
              return McpToolResult.error('停课规则需要提供 startWeek 参数');
            }

            final rule = TimetableRule.createSuspension(
              startWeek: startWeek,
              endWeek: endWeek!,
              dayOfWeek: dayOfWeek,
              courseName: courseName,
              startPeriod: startPeriod,
              endPeriod: endPeriod,
            );

            await ruleService.addRule(rule);
            return McpToolResult.json({
              'status': 'success',
              'message': '停课已保存，课表已更新。',
              'rule': rule.toJson(),
            });

          case 'add_custom_course':
            final courseName = arguments['customCourseName'] as String?;
            final teacher = arguments['teacher'] as String? ?? '';
            final classroom = arguments['classroom'] as String? ?? '';
            final weeks = arguments['weeks'] as String? ?? '1-16(周)';
            final dayOfWeek = asInt(arguments['customDayOfWeek']) ?? 1;
            final startPeriod = asInt(arguments['customStartPeriod']) ?? 1;
            final endPeriod =
                asInt(arguments['customEndPeriod']) ?? (startPeriod + 1);

            if (courseName == null || courseName.trim().isEmpty) {
              return McpToolResult.error('手动添加课程必须提供 customCourseName');
            }

            final formattedWeeks = weeks.endsWith('(周)') ? weeks : '$weeks(周)';
            final periodsStr = startPeriod == endPeriod
                ? startPeriod.toString().padLeft(2, '0')
                : '${startPeriod.toString().padLeft(2, '0')}-${endPeriod.toString().padLeft(2, '0')}';

            final course = CourseModel(
              id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
              name: courseName.trim(),
              teacher: teacher.trim(),
              classroom: classroom.trim(),
              weeks: formattedWeeks,
              periods: periodsStr,
              dayOfWeek: dayOfWeek,
              startPeriod: startPeriod,
              endPeriod: endPeriod,
            );

            final rule = TimetableRule.createCustomCourse(course: course);
            await ruleService.addRule(rule);
            return McpToolResult.json({
              'status': 'success',
              'message': '已添加到课表。',
              'rule': rule.toJson(),
            });

          case 'delete_rule':
            final ruleId = arguments['ruleId'] as String?;
            if (ruleId == null || ruleId.trim().isEmpty) {
              return McpToolResult.error('删除规则需要提供 ruleId');
            }
            await ruleService.deleteRule(ruleId.trim());
            return McpToolResult.json({
              'status': 'success',
              'message': '已删除，课表已更新。',
            });

          case 'clear_rules':
            await ruleService.clearAllRules();
            return McpToolResult.json({
              'status': 'success',
              'message': '已清空，课表已恢复。',
            });

          default:
            return McpToolResult.error('未知操作类型: $action');
        }
      },
    );
  }
}
