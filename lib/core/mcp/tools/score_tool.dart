import '../../../features/score/models/score_model.dart';
import '../../../features/score/services/score_service.dart';
import '../models/mcp_tool.dart';

/// MCP Tool: 成绩查询 (query_scores)
class ScoreTool {
  static const String toolName = 'query_scores';

  static McpTool create({
    ScoreService? service,
  }) {
    final scoreService = service ?? ScoreService();

    return McpTool(
      name: toolName,
      description:
          '查询湖南农业大学学生的课程考试成绩。可按学年（xn，如“2024-2025”）和学期（xq，如“1”或“2”）进行查询，也可按课程名称关键词过滤。如不指定学年学期则返回最新学期成绩及可用学期列表。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'academicYear': {
            'type': 'string',
            'description': '学年，例如“2024-2025”、“2023-2024”。如不填则默认查询最新学期。',
          },
          'semester': {
            'type': 'string',
            'description': '学期，例如“1”(第1学期) 或 “2”(第2学期)。如不填则默认查询最新学期。',
          },
          'courseName': {
            'type': 'string',
            'description': '课程名称关键词，用于过滤指定课程成绩。',
          },
        },
      },
      handler: (arguments) async {
        final xn = arguments['academicYear'] as String?;
        final xq = arguments['semester'] as String?;
        final courseName = arguments['courseName'] as String?;

        try {
          final semesters = await scoreService.fetchSemesterList();
          String targetSemester = '';
          if (xn != null && xq != null) {
            targetSemester = '$xn-$xq';
          } else if (xq != null && xq.contains('-')) {
            targetSemester = xq;
          } else if (semesters.isNotEmpty) {
            final active = semesters.firstWhere((s) => s.isActive, orElse: () => semesters.first);
            targetSemester = active.id;
          }

          final List<ScoreModel> scores = targetSemester.isNotEmpty
              ? await scoreService.fetchScores(semester: targetSemester)
              : <ScoreModel>[];

          // 过滤课程
          final filteredScores = scores.where((s) {
            if (courseName != null && courseName.trim().isNotEmpty) {
              return s.courseName.toLowerCase().contains(courseName.trim().toLowerCase());
            }
            return true;
          }).toList();

          final formattedSemesters = semesters.map((sem) => {
            'name': sem.name,
            'academicYear': sem.value,
            'semester': sem.xq,
            'isActive': sem.isActive,
          }).toList();

          final formattedScores = filteredScores.map((s) => {
            'courseName': s.courseName,
            'score': s.score,
            'credit': s.credit,
            'dailyScore': s.dailyScore,
            'examType': s.examType,
          }).toList();

          return McpToolResult.json({
            'queriedAcademicYear': xn,
            'queriedSemester': xq,
            'totalScoresCount': formattedScores.length,
            'scores': formattedScores,
            'availableSemesters': formattedSemesters,
          });
        } catch (e) {
          return McpToolResult.error('查询成绩失败: $e');
        }
      },
    );
  }
}
