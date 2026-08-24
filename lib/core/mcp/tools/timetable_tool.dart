import '../../../features/timetable/models/course_model.dart';
import '../../../features/timetable/services/timetable_service.dart';
import '../../../features/timetable/services/timetable_storage.dart';
import '../../../features/timetable/utils/date_calculator.dart';
import '../../../features/timetable/utils/week_parser.dart';
import '../../../core/constants/app_constants.dart';
import '../models/mcp_tool.dart';

/// MCP Tool: 课表查询 (query_timetable)
class TimetableTool {
  static const String toolName = 'query_timetable';

  static McpTool create({
    TimetableStorage? storage,
    TimetableService? service,
  }) {
    final timetableStorage = storage ?? TimetableStorage();
    final timetableService = service ?? TimetableService();

    return McpTool(
      name: toolName,
      description:
          '查询学生的课程表信息。支持按指定周次（第1-20周）、星期几（周一到周日 1-7）、是否为今日课程、或课程名称关键词进行筛选过滤。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'week': {
            'type': 'integer',
            'description': '查询指定周次的课程，范围 1-20。如不提供且未指定 today，则默认查询全学期或当前周课程。',
            'minimum': 1,
            'maximum': 20,
          },
          'dayOfWeek': {
            'type': 'integer',
            'description': '查询星期几的课程，1 为周一，2 为周二 ... 7 为周日。',
            'minimum': 1,
            'maximum': 7,
          },
          'today': {
            'type': 'boolean',
            'description': '若为 true，则自动计算当前周次和今天的星期，仅查询今天所要上的课程。',
          },
          'courseName': {
            'type': 'string',
            'description': '课程名称关键词，用于模糊匹配特定课程。',
          },
          'forceRefresh': {
            'type': 'boolean',
            'description': '是否强制从教务系统重新同步并覆盖本地课表（需要已在 App 中登录）。默认为 false。',
          },
        },
      },
      handler: (arguments) async {
        final bool forceRefresh = arguments['forceRefresh'] as bool? ?? false;
        final bool today = arguments['today'] as bool? ?? false;
        int? targetWeek = arguments['week'] as int?;
        int? targetDayOfWeek = arguments['dayOfWeek'] as int?;
        final String? keyword = arguments['courseName'] as String?;

        // 1. 如果指定了强制刷新
        if (forceRefresh) {
          try {
            await timetableService.downloadAndSaveTimetable(
              semester: AppConstants.defaultSemester,
            );
          } catch (e) {
            return McpToolResult.error('课表同步失败: $e');
          }
        }

        // 2. 读取本地课程列表与元数据
        List<CourseModel> courses = await timetableStorage.readCourseList();
        final metadata = await timetableStorage.readMetadata();

        DateTime? firstWeekMonday;
        if (metadata != null && metadata['firstWeekMonday'] != null) {
          firstWeekMonday = DateTime.tryParse(metadata['firstWeekMonday'] as String);
        }

        // 若本地没有课表且未强制刷新，尝试同步一次
        if (courses.isEmpty && !forceRefresh) {
          try {
            await timetableService.downloadAndSaveTimetable(
              semester: AppConstants.defaultSemester,
            );
            courses = await timetableStorage.readCourseList();
          } catch (_) {
            // 同步失败则提示本地无课表
          }
        }

        if (courses.isEmpty) {
          return McpToolResult.text('本地暂无课表数据。请先登录教务系统或设置 forceRefresh=true 尝试同步。');
        }

        // 3. 计算当前时间信息
        final now = DateTime.now();
        int? currentCalculatedWeek;
        if (firstWeekMonday != null) {
          currentCalculatedWeek = DateCalculator.getCurrentWeekNumber(firstWeekMonday, now);
        }

        if (today) {
          targetDayOfWeek = now.weekday;
          if (currentCalculatedWeek != null && currentCalculatedWeek > 0 && currentCalculatedWeek <= 20) {
            targetWeek = currentCalculatedWeek;
          }
        }

        // 4. 筛选课程
        final filteredCourses = courses.where((course) {
          // 关键词过滤
          if (keyword != null && keyword.trim().isNotEmpty) {
            if (!course.name.toLowerCase().contains(keyword.trim().toLowerCase()) &&
                !course.teacher.toLowerCase().contains(keyword.trim().toLowerCase()) &&
                !course.classroom.toLowerCase().contains(keyword.trim().toLowerCase())) {
              return false;
            }
          }

          // 星期过滤
          if (targetDayOfWeek != null && course.dayOfWeek != targetDayOfWeek) {
            return false;
          }

          // 周次过滤 (例如 course.weeks = "1-16(周)")
          if (targetWeek != null) {
            final activeWeeks = WeekParser.parseWeeks(course.weeks);
            if (!activeWeeks.contains(targetWeek)) {
              return false;
            }
          }

          return true;
        }).toList();

        // 5. 按星期和节次排序
        filteredCourses.sort((a, b) {
          if (a.dayOfWeek != b.dayOfWeek) {
            return a.dayOfWeek.compareTo(b.dayOfWeek);
          }
          return a.startPeriod.compareTo(b.startPeriod);
        });

        // 6. 构造返回结果
        final weekdayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
        final List<Map<String, dynamic>> results = filteredCourses.map((c) {
          return {
            'courseName': c.name,
            'teacher': c.teacher,
            'classroom': c.classroom,
            'dayOfWeek': c.dayOfWeek,
            'dayOfWeekText': (c.dayOfWeek >= 1 && c.dayOfWeek <= 7) ? weekdayNames[c.dayOfWeek] : '${c.dayOfWeek}',
            'startPeriod': c.startPeriod,
            'endPeriod': c.endPeriod,
            'periods': c.periods,
            'weeks': c.weeks,
          };
        }).toList();

        final summary = {
          'queryConditions': {
            if (targetWeek != null) 'week': targetWeek,
            if (targetDayOfWeek != null) 'dayOfWeek': (targetDayOfWeek >= 1 && targetDayOfWeek <= 7) ? weekdayNames[targetDayOfWeek] : targetDayOfWeek,
            if (today) 'isToday': true,
            if (keyword != null) 'keyword': keyword,
          },
          'currentSemesterWeek': currentCalculatedWeek,
          'totalCount': results.length,
          'courses': results,
        };

        return McpToolResult.json(summary);
      },
    );
  }
}
