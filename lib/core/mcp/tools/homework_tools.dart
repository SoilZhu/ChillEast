import '../../../features/homework/models/homework_model.dart';
import '../../../features/homework/services/homework_service.dart';
import '../../../features/homework/services/homework_storage.dart';
import '../../../core/utils/secure_storage_helper.dart';
import '../models/mcp_tool.dart';

/// MCP Tool: 作业查询 (query_homework)
class HomeworkQueryTool {
  static const String toolName = 'query_homework';

  static McpTool create({
    HomeworkStorage? storage,
    HomeworkService? service,
    SecureStorageHelper? secureStorage,
  }) {
    final homeworkStorage = storage ?? HomeworkStorage();
    final homeworkService = service ?? HomeworkService();
    final secStorage = secureStorage ?? SecureStorageHelper();

    return McpTool(
      name: toolName,
      description:
          '查询学生的超星/学习通作业及手动添加的作业列表。支持按状态（待完成 pending、已完成 completed、已存档 archived 或全部 all）、课程名称关键词进行筛选。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'status': {
            'type': 'string',
            'enum': ['all', 'pending', 'completed', 'archived'],
            'description': '作业状态筛选：pending(待完成/未提交), completed(已完成/已提交), archived(已过期/已存档), all(全部)。默认为 pending。',
            'default': 'pending',
          },
          'courseName': {
            'type': 'string',
            'description': '按课程名称关键词过滤作业。',
          },
          'keyword': {
            'type': 'string',
            'description': '按作业标题或备注关键词搜索。',
          },
          'forceRefresh': {
            'type': 'boolean',
            'description': '是否从超星学习通重新抓取最新的作业数据。默认为 false。',
          },
        },
      },
      handler: (arguments) async {
        final String statusStr = arguments['status'] as String? ?? 'pending';
        final String? courseName = arguments['courseName'] as String?;
        final String? keyword = arguments['keyword'] as String?;
        final bool forceRefresh = arguments['forceRefresh'] as bool? ?? false;

        // 1. 如果需要强制刷新或本地无数据
        if (forceRefresh) {
          final studentId = await secStorage.getUsername();
          if (studentId != null && studentId.isNotEmpty) {
            try {
              final scraped = await homeworkService.fetchHomeworkList(studentId);
              final local = await homeworkStorage.readHomeworkList();
              final manual = local.where((e) => e.isManual).toList();
              final merged = [...manual, ...scraped];
              await homeworkStorage.saveHomeworkList(merged);
            } catch (e) {
              return McpToolResult.error('刷新作业失败: $e');
            }
          }
        }

        // 2. 读取作业列表
        final homeworks = await homeworkStorage.readHomeworkList();

        // 3. 状态筛选
        HomeworkStatus? filterStatus;
        if (statusStr == 'pending') {
          filterStatus = HomeworkStatus.pending;
        } else if (statusStr == 'completed') {
          filterStatus = HomeworkStatus.completed;
        } else if (statusStr == 'archived') {
          filterStatus = HomeworkStatus.archived;
        }

        final filtered = homeworks.where((hw) {
          if (filterStatus != null && hw.status != filterStatus) {
            return false;
          }
          if (courseName != null && courseName.trim().isNotEmpty) {
            if (!hw.courseName.toLowerCase().contains(courseName.trim().toLowerCase())) {
              return false;
            }
          }
          if (keyword != null && keyword.trim().isNotEmpty) {
            final kw = keyword.trim().toLowerCase();
            final matchTitle = hw.title.toLowerCase().contains(kw);
            final matchCourse = hw.courseName.toLowerCase().contains(kw);
            final matchRemarks = hw.remarks.toLowerCase().contains(kw);
            if (!matchTitle && !matchCourse && !matchRemarks) {
              return false;
            }
          }
          return true;
        }).toList();

        // 4. 排序 (按截止时间升序，没有截止时间的放后面)
        filtered.sort((a, b) {
          if (a.endTime == null && b.endTime == null) return 0;
          if (a.endTime == null) return 1;
          if (b.endTime == null) return -1;
          return a.endTime!.compareTo(b.endTime!);
        });

        // 5. 格式化输出
        final results = filtered.map((hw) {
          String statusName;
          switch (hw.status) {
            case HomeworkStatus.pending:
              statusName = '待完成';
              break;
            case HomeworkStatus.completed:
              statusName = '已完成';
              break;
            case HomeworkStatus.archived:
              statusName = '已存档/已截止';
              break;
          }

          return {
            'id': hw.id,
            'title': hw.title,
            'courseName': hw.courseName.isNotEmpty ? hw.courseName : '自定义作业',
            'status': statusName,
            'statusCode': hw.status.name,
            'endTime': hw.endTime?.toIso8601String(),
            'rawTimeStr': hw.rawTimeStr,
            'isManual': hw.isManual,
            'remarks': hw.remarks,
            'dataUrl': hw.dataUrl,
          };
        }).toList();

        return McpToolResult.json({
          'filterStatus': statusStr,
          'totalCount': results.length,
          'homeworkList': results,
        });
      },
    );
  }
}

/// MCP Tool: 作业添加 (add_homework)
class HomeworkAddTool {
  static const String toolName = 'add_homework';

  static McpTool create({
    HomeworkStorage? storage,
  }) {
    final homeworkStorage = storage ?? HomeworkStorage();

    return McpTool(
      name: toolName,
      description:
          '手动添加一条作业或待办事项。可以指定作业标题、所属课程、截止日期时间以及备注。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'title': {
            'type': 'string',
            'description': '作业标题或待办任务内容（必填）。',
          },
          'courseName': {
            'type': 'string',
            'description': '所属课程名称（可选，如不传则默认为“自定义任务”）。',
          },
          'endTime': {
            'type': 'string',
            'description': '截止时间（可选，格式如 "2026-09-01 23:59:00" 或 ISO8601 字符串 "2026-09-01T23:59:00"）。',
          },
          'remarks': {
            'type': 'string',
            'description': '作业备注或补充要求（可选）。',
          },
        },
        'required': ['title'],
      },
      handler: (arguments) async {
        final title = arguments['title'] as String?;
        if (title == null || title.trim().isEmpty) {
          return McpToolResult.error('作业标题不能为空');
        }

        final courseName = (arguments['courseName'] as String?)?.trim() ?? '';
        final remarks = (arguments['remarks'] as String?)?.trim() ?? '';
        final endTimeStr = arguments['endTime'] as String?;

        DateTime? parsedEndTime;
        if (endTimeStr != null && endTimeStr.trim().isNotEmpty) {
          final trimmed = endTimeStr.trim();
          parsedEndTime = DateTime.tryParse(trimmed) ?? DateTime.tryParse(trimmed.replaceFirst(' ', 'T'));
        }

        final newItem = HomeworkModel(
          id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
          title: title.trim(),
          courseName: courseName,
          endTime: parsedEndTime,
          status: HomeworkStatus.pending,
          studentId: 'manual',
          isManual: true,
          createdAt: DateTime.now(),
          remarks: remarks,
        );

        final currentList = await homeworkStorage.readHomeworkList();
        final updatedList = [newItem, ...currentList];
        await homeworkStorage.saveHomeworkList(updatedList);

        return McpToolResult.json({
          'success': true,
          'message': '作业添加成功',
          'homework': {
            'id': newItem.id,
            'title': newItem.title,
            'courseName': newItem.courseName,
            'endTime': newItem.endTime?.toIso8601String(),
            'status': '待完成',
            'isManual': true,
            'remarks': newItem.remarks,
            'createdAt': newItem.createdAt?.toIso8601String(),
          },
        });
      },
    );
  }
}
