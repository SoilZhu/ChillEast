import 'package:intl/intl.dart';
import '../../../features/exam/models/exam_schedule_model.dart';
import '../../../features/exam/services/exam_service.dart';
import '../../../features/exam/services/exam_storage.dart';
import '../models/mcp_tool.dart';

/// MCP Tool: 考试日程与安排查询 (query_exams / query_exam_schedule)
class ExamQueryTool {
  static const String toolName = 'query_exams';

  static McpTool create({
    ExamStorage? storage,
    ExamService? service,
    String toolName = toolName,
  }) {
    final examStorage = storage ?? ExamStorage();
    final examService = service ?? ExamService();

    return McpTool(
      name: toolName,
      description:
          '查询学生的超星/学习通考试日程与考试安排。支持按本学期筛选、关键词搜索及刷新最新考试数据。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'currentSemesterOnly': {
            'type': 'boolean',
            'description': '是否仅查询本学期的考试。默认为 true。',
            'default': true,
          },
          'keyword': {
            'type': 'string',
            'description': '按考试名称关键词进行模糊搜索。',
          },
          'forceRefresh': {
            'type': 'boolean',
            'description': '是否强制从超星学习通重新抓取最新的考试日程数据。默认为 false。',
          },
        },
      },
      handler: (arguments) async {
        final bool currentSemesterOnly =
            arguments['currentSemesterOnly'] as bool? ?? true;
        final String? keyword = arguments['keyword'] as String?;
        final bool forceRefresh = arguments['forceRefresh'] as bool? ?? false;

        // 1. 如果需要强制刷新，从网络获取并落盘
        if (forceRefresh) {
          try {
            final local = await examStorage.readExamList();
            final manual = local.where((e) => e.isManual).toList();
            final updated = await examService.fetchExams();
            final merged = [...manual, ...updated]
              ..sort(ExamScheduleModel.compareTime);
            await examStorage.saveExamList(merged);
          } catch (e) {
            return McpToolResult.error('刷新考试数据失败: $e');
          }
        }

        // 2. 读取本地缓存
        var exams = await examStorage.readExamList();

        // 如果本地为空且不是强制刷新，尝试自动静默拉取一次
        if (exams.isEmpty && !forceRefresh) {
          try {
            exams = await examService.fetchExams();
            await examStorage.saveExamList(exams);
          } catch (_) {
            // 忽略错误，继续返回空列表
          }
        }

        // 3. 筛选本学期考试
        if (currentSemesterOnly) {
          exams = exams.where((e) => e.isCurrentSemester()).toList();
        }

        // 4. 关键词筛选
        if (keyword != null && keyword.trim().isNotEmpty) {
          final kw = keyword.trim().toLowerCase();
          exams = exams.where((e) {
            final matchTitle = e.title.toLowerCase().contains(kw);
            final matchCourse = e.courseName.toLowerCase().contains(kw);
            return matchTitle || matchCourse;
          }).toList();
        }

        // 5. 按考试时间升序排列
        exams.sort(ExamScheduleModel.compareTime);

        // 6. 格式化结果输出
        final now = DateTime.now();
        final results = exams.map((e) {
          final timeStr = e.time != null ? DateFormat('yyyy-MM-dd HH:mm').format(e.time!) : '未定';
          final isPast = e.time != null && e.time!.isBefore(now);
          return {
            'id': e.id,
            'title': e.title,
            'courseName': e.courseName,
            'time': timeStr,
            'status': e.status.isNotEmpty ? e.status : (isPast ? '已结束' : '待考'),
            'isPast': isPast,
            'isManual': e.isManual,
            'location': e.location ?? '',
            'remarks': e.remarks ?? '',
            'studentName': e.studentName ?? '',
            'studentId': e.studentId ?? '',
            'detailUrl': e.detailUrl,
          };
        }).toList();

        final semesterDesc = currentSemesterOnly ? '（本学期）' : '（全量）';
        return McpToolResult.json({
          'summary': '共查询到 ${results.length} 门考试$semesterDesc',
          'total': results.length,
          'currentSemesterOnly': currentSemesterOnly,
          'exams': results,
        });
      },
    );
  }
}

/// MCP Tool: 考试添加 (add_exam / add_exam_schedule)
class ExamAddTool {
  static const String toolName = 'add_exam';

  static McpTool create({
    ExamStorage? storage,
    Future<void> Function()? onChanged,
    String toolName = toolName,
  }) {
    final examStorage = storage ?? ExamStorage();

    return McpTool(
      name: toolName,
      description:
          '手动添加一场考试日程安排。当用户说"添加考试"、"新增考试"、"记一下考试时间"等时必须调用本工具，而不是只用文字回复。可以指定考试名称、课程名称、考试时间、考场地点以及备注。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'title': {
            'type': 'string',
            'description': '考试名称或标题（必填，如“期末考试”、“大学英语六级”）。',
          },
          'time': {
            'type': 'string',
            'description':
                '考试开始时间（必填，必须是 "YYYY-MM-DD HH:MM:SS" 或 ISO8601，例如 "2026-11-20 14:30:00"。系统提示词中已提供当前时间，请把"明天下午两点/下周一"等换算成绝对时间后再传入）。',
          },
          'courseName': {
            'type': 'string',
            'description': '所属课程名称（可选）。',
          },
          'location': {
            'type': 'string',
            'description': '考场或教室地点（可选，例如“文科楼402”、“第一教学楼101”）。',
          },
          'remarks': {
            'type': 'string',
            'description': '考试备注或准备事项（可选，例如“自带2B铅笔和橡皮”、“带计算器”）。',
          },
        },
        'required': ['title', 'time'],
      },
      handler: (arguments) async {
        final title = arguments['title'] as String?;
        if (title == null || title.trim().isEmpty) {
          return McpToolResult.error('考试名称不能为空');
        }

        final timeStr = arguments['time'] as String?;
        if (timeStr == null || timeStr.trim().isEmpty) {
          return McpToolResult.error('考试时间不能为空');
        }

        final trimmedTime = timeStr.trim();
        final parsedTime = DateTime.tryParse(trimmedTime) ??
            DateTime.tryParse(trimmedTime.replaceFirst(' ', 'T')) ??
            DateTime.tryParse(trimmedTime.replaceAll('/', '-'));

        if (parsedTime == null) {
          return McpToolResult.error('无效的考试时间格式，必须为 YYYY-MM-DD HH:MM:SS 或 ISO8601');
        }

        final courseName = (arguments['courseName'] as String?)?.trim() ?? '';
        final location = (arguments['location'] as String?)?.trim() ?? '';
        final remarks = (arguments['remarks'] as String?)?.trim() ?? '';

        final newExam = ExamScheduleModel(
          id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
          title: title.trim(),
          courseName: courseName,
          time: parsedTime,
          allTimes: [parsedTime],
          rawTimeStrs: [DateFormat('yyyy-MM-dd HH:mm').format(parsedTime)],
          status: '待考',
          isManual: true,
          location: location.isNotEmpty ? location : null,
          remarks: remarks.isNotEmpty ? remarks : null,
          createdAt: DateTime.now(),
        );

        final currentList = await examStorage.readExamList();
        final updated = [...currentList, newExam];
        updated.sort(ExamScheduleModel.compareTime);
        await examStorage.saveExamList(updated);

        if (onChanged != null) {
          await onChanged();
        }

        final formattedTime = DateFormat('yyyy-MM-dd HH:mm').format(parsedTime);
        return McpToolResult.json({
          'summary': '已成功添加考试「${title.trim()}」，考试时间为 $formattedTime',
          'exam': {
            'id': newExam.id,
            'title': newExam.title,
            'courseName': newExam.courseName,
            'time': formattedTime,
            'location': location,
            'remarks': remarks,
            'isManual': true,
          },
        });
      },
    );
  }
}
