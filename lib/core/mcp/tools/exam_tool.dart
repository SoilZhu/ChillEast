import 'package:intl/intl.dart';
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
            final updated = await examService.fetchExams(cachedExams: local);
            await examStorage.saveExamList(updated);
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
        exams.sort((a, b) => a.time.compareTo(b.time));

        // 6. 格式化结果输出
        final now = DateTime.now();
        final results = exams.map((e) {
          final timeStr = DateFormat('yyyy-MM-dd HH:mm').format(e.time);
          final isPast = e.time.isBefore(now);
          return {
            'id': e.id,
            'title': e.title,
            'courseName': e.courseName,
            'time': timeStr,
            'status': e.status.isNotEmpty ? e.status : (isPast ? '已结束' : '待考'),
            'isPast': isPast,
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
