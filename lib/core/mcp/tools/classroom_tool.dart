import '../../../features/workspace/services/classroom_service.dart';
import '../models/mcp_tool.dart';

/// MCP Tool: 空教室查询 (query_empty_classrooms)
class ClassroomTool {
  static const String toolName = 'query_empty_classrooms';

  static McpTool create({
    ClassroomService? service,
  }) {
    final classroomService = service ?? ClassroomService();

    return McpTool(
      name: toolName,
      description:
          '查询湖南农业大学各教学楼的空闲教室情况。可按教学楼名称（如“第十教学楼”、“第九教学楼”等）、周次、节次（如“0102”、“0304”）和星期几（1-7）进行精确查询；也可获取当前支持的教学楼与节次选项列表。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'action': {
            'type': 'string',
            'enum': ['query', 'get_options'],
            'description': '操作类型：query(执行空教室查询，默认), get_options(获取可用的教学楼、节次、周次选项列表)。',
            'default': 'query',
          },
          'building': {
            'type': 'string',
            'description': '教学楼名称，例如“第十教学楼”、“第九教学楼”、“第一教学楼”、“第二教学楼”、“第十三教学楼”等。',
          },
          'week': {
            'type': 'string',
            'description': '周次编号（第几周），例如“1”、“2”...“20”。如不提供则默认为“1”。',
          },
          'section': {
            'type': 'string',
            'description': '节次代码，例如“0102”(第1-2节)、“0304”(第3-4节)、“0506”(第5-6节)、“0708”(第7-8节)、“0910”(第9-10节)。如不提供则默认为“0102”。',
          },
          'dayOfWeek': {
            'type': 'string',
            'description': '星期几（1为周一，2为周二 ... 7为周日）。如不提供则默认为当前星期。',
          },
        },
      },
      handler: (arguments) async {
        final action = arguments['action'] as String? ?? 'query';

        // 1. 获取选项列表
        if (action == 'get_options') {
          try {
            final options = await classroomService.fetchOptions();
            return McpToolResult.json({
              'buildings': options.buildings,
              'sections': options.sections,
              'weeks': options.weeks,
              'days': options.days,
            });
          } catch (e) {
            return McpToolResult.error('获取空教室查询选项失败: $e');
          }
        }

        // 2. 执行查询
        String? building = arguments['building'] as String?;
        String week = (arguments['week'] ?? '').toString();
        String section = (arguments['section'] ?? '').toString();
        String day = (arguments['dayOfWeek'] ?? '').toString();

        // 默认值填充
        if (week.isEmpty) week = '1';
        if (section.isEmpty) section = '0102';
        if (day.isEmpty) {
          day = '${DateTime.now().weekday}';
        }

        if (building == null || building.trim().isEmpty) {
          // 若未指定教学楼，先获取选项列表并默认使用第一栋楼或提示
          try {
            final options = await classroomService.fetchOptions();
            if (options.buildings.isNotEmpty) {
              building = options.buildings.first;
            } else {
              building = '第十教学楼';
            }
          } catch (_) {
            building = '第十教学楼';
          }
        }

        try {
          final classrooms = await classroomService.queryClassrooms(
            building: building,
            week: week,
            jc: section,
            day: day,
          );

          final results = classrooms.map((c) {
            return {
              'classroomName': c.jsmc,
              'seats': c.zws,
            };
          }).toList();

          return McpToolResult.json({
            'building': building,
            'week': week,
            'section': section,
            'dayOfWeek': day,
            'totalCount': results.length,
            'emptyClassrooms': results,
          });
        } catch (e) {
          return McpToolResult.error('查询空教室失败: $e');
        }
      },
    );
  }
}
