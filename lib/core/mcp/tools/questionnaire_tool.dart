import '../../../features/questionnaire/models/questionnaire_models.dart';
import '../../../features/questionnaire/services/questionnaire_service.dart';
import '../models/mcp_tool.dart';

QuestionnaireService _resolveService(QuestionnaireService? service) =>
    service ?? QuestionnaireService();

/// 按标题关键词或任务标识匹配问卷。
QuestionnaireItem? _matchQuestionnaire(
    List<QuestionnaireItem> items, String input) {
  final keyword = input.trim();
  if (keyword.isEmpty) return null;
  for (final item in items) {
    if (item.taskTimeM == keyword || item.dm == keyword) return item;
  }
  for (final item in items) {
    if (item.title == keyword) return item;
  }
  for (final item in items) {
    if (item.title.contains(keyword) || keyword.contains(item.title)) {
      return item;
    }
  }
  return null;
}

Map<String, dynamic> _formatItem(QuestionnaireItem item) => {
      'id': item.taskTimeM,
      'dm': item.dm,
      'title': item.title,
      'timeRange': item.timeRange,
      'startTime': item.startTime,
      'endTime': item.endTime,
      'status': item.statusLabel,
      'isSubmitted': item.isSubmitted,
      'isExpired': item.isExpired,
    };

String _questionKind(QuestionnaireQuestion q) {
  if (q.isMultiChoice) return '多选';
  if (q.isChoice) return '单选';
  if (q.isDate) return '日期';
  if (q.isPhone) return '电话';
  return '填空';
}

Map<String, dynamic> _formatQuestion(QuestionnaireQuestion q) => {
      'dm': q.dm,
      'title': q.title,
      'required': q.required,
      'kind': _questionKind(q),
      'options': q.options.map((o) => {'dm': o.dm, 'name': o.name}).toList(),
    };

/// MCP Tool: 查询学工问卷列表 (query_questionnaires)
class QuestionnaireListTool {
  static const String toolName = 'query_questionnaires';

  static McpTool create({QuestionnaireService? service}) {
    final questionnaireService = _resolveService(service);

    return McpTool(
      name: toolName,
      description:
          '查询学校学工系统“学工问卷”（问卷调查）列表，如国庆/中秋等假期学生去向统计。返回每份问卷的标题、起止时间与填写状态（待填写/已提交/已截止）。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'status': {
            'type': 'string',
            'description': '按状态过滤：待填写、已提交、全部。默认为全部。',
          },
        },
      },
      handler: (arguments) async {
        final status = (arguments['status'] as String?)?.trim() ?? '全部';
        try {
          final items = await questionnaireService.fetchList();
          final filtered = items.where((item) {
            if (status.contains('待填')) {
              return !item.isSubmitted && !item.isExpired;
            }
            if (status.contains('已提交')) return item.isSubmitted;
            return true;
          }).toList();
          return McpToolResult.json({
            'success': true,
            'count': filtered.length,
            'questionnaires': filtered.map(_formatItem).toList(),
          });
        } catch (e) {
          return McpToolResult.error('查询学工问卷列表失败: $e');
        }
      },
    );
  }
}

/// MCP Tool: 查询问卷题目结构 (query_questionnaire_detail)
class QuestionnaireDetailTool {
  static const String toolName = 'query_questionnaire_detail';

  static McpTool create({QuestionnaireService? service}) {
    final questionnaireService = _resolveService(service);

    return McpTool(
      name: toolName,
      description:
          '查询某份学工问卷的题目结构（题干、是否必填、单选/多选/填空/日期/电话类型及选项名单）。先调用 query_questionnaires 拿到问卷，再用本工具看题目。填写问卷前建议先调用本工具确认题目。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'questionnaire': {
            'type': 'string',
            'description': '问卷标题关键词（如“国庆”）或问卷 id（列表返回的 id 字段）。',
          },
        },
        'required': ['questionnaire'],
      },
      handler: (arguments) async {
        final input = (arguments['questionnaire'] as String?)?.trim() ?? '';
        if (input.isEmpty) {
          return McpToolResult.error('请指定问卷标题关键词或 id');
        }
        try {
          final items = await questionnaireService.fetchList();
          final matched = _matchQuestionnaire(items, input);
          if (matched == null) {
            final titles = items.take(8).map((e) => e.title).join('、');
            return McpToolResult.error(
                '未找到问卷“$input”。参考：$titles 等，可调用 query_questionnaires 查看完整列表。');
          }
          final detail = await questionnaireService.fetchDetail(matched);
          return McpToolResult.json({
            'success': true,
            'id': matched.taskTimeM,
            'title': detail.title,
            'canSubmit': detail.canSubmit,
            'isSubmitted': matched.isSubmitted,
            'questions': detail.questions.map(_formatQuestion).toList(),
          });
        } catch (e) {
          return McpToolResult.error('查询问卷题目失败: $e');
        }
      },
    );
  }
}

/// MCP Tool: 代填学工问卷 (submit_questionnaire)
class QuestionnaireSubmitTool {
  static const String toolName = 'submit_questionnaire';

  static McpTool create({QuestionnaireService? service}) {
    final questionnaireService = _resolveService(service);

    return McpTool(
      name: toolName,
      description: '代用户填写并提交学工问卷。answers 以题目标题关键词为 key：'
          '单选题 value 传选项名（支持模糊，如“是”）；多选题 value 传选项名数组；'
          '填空/电话题传文本；日期题传 YYYY-MM-DD。'
          '【重要】：首次调用保持 confirmed=false，工具返回待确认的问卷与答案预览；'
          '向用户逐题核对后，征得明确同意再传 confirmed=true 真正提交。已提交过的问卷允许重复提交，新答案将覆盖之前的提交。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'questionnaire': {
            'type': 'string',
            'description': '问卷标题关键词（如“国庆”）或问卷 id。',
          },
          'answers': {
            'type': 'object',
            'description':
                '答案映射，key 为题目标题关键词或题目 dm，value 为答案（单选传选项名/选项 dm，多选传数组，填空/日期传文本）。',
          },
          'confirmed': {
            'type': 'boolean',
            'description':
                '用户是否已对下方预览中的每道题答案做最终确认。默认为 false；仅当用户明确同意提交后才传 true。',
            'default': false,
          },
        },
        'required': ['questionnaire', 'answers'],
      },
      handler: (arguments) async {
        final input = (arguments['questionnaire'] as String?)?.trim() ?? '';
        if (input.isEmpty) {
          return McpToolResult.error('请指定问卷标题关键词或 id');
        }
        final rawAnswers = arguments['answers'];
        if (rawAnswers is! Map) {
          return McpToolResult.error('answers 须为对象（题目关键词 -> 答案）');
        }
        final confirmed = arguments['confirmed'] as bool? ?? false;

        // 1. 定位问卷并拉取题目
        QuestionnaireItem matched;
        QuestionnaireDetail detail;
        try {
          final items = await questionnaireService.fetchList();
          final found = _matchQuestionnaire(items, input);
          if (found == null) {
            return McpToolResult.error('未找到问卷“$input”，可调用 query_questionnaires 查看列表。');
          }
          matched = found;
          detail = await questionnaireService.fetchDetail(matched);
        } catch (e) {
          return McpToolResult.error('读取问卷失败，请检查登录状态或稍后重试: $e');
        }

        if (!detail.canSubmit) {
          return McpToolResult.error(
              '问卷《${detail.title}》当前不可提交（可能已截止）。');
        }

        // 2. 按题目逐一把用户答案映射为提交载荷（key 均为题目 dm）
        final payload = <String, dynamic>{};
        final preview = <Map<String, dynamic>>[];
        for (final question in detail.questions) {
          final hit = _findAnswer(question, rawAnswers);
          if (question.isChoice) {
            final mapped = _mapChoiceAnswer(question, hit);
            if (mapped == null) {
              if (question.required) {
                return McpToolResult.error(
                    '必填题“${question.title}”缺少有效答案，可选项：${question.options.map((o) => o.name).join('、')}。');
              }
              payload[question.dm] =
                  question.isMultiChoice ? <String>[] : '';
            } else {
              payload[question.dm] = mapped;
            }
            preview.add({
              'question': question.title,
              'required': question.required,
              'kind': _questionKind(question),
              'answer': _previewValue(question, mapped),
            });
          } else {
            final text = hit?.toString().trim() ?? '';
            if (text.isEmpty && question.required) {
              return McpToolResult.error('必填题“${question.title}”缺少答案。');
            }
            payload[question.dm] = text;
            preview.add({
              'question': question.title,
              'required': question.required,
              'kind': _questionKind(question),
              'answer': text,
            });
          }
        }

        // 3. 未确认：只返回预览
        if (!confirmed) {
          return McpToolResult.json({
            'status': 'requires_confirmation',
            'needsUserConsent': true,
            'message': '学工问卷已就绪。【重要】：请向用户逐题呈现以下待提交答案并征得明确同意，'
                '用户确认后传入 confirmed=true 重新调用本工具正式提交。'
                '${matched.isSubmitted ? '注意：该问卷已提交过，本次提交将覆盖之前的答案。' : ''}',
            'questionnaire': detail.title,
            'isResubmit': matched.isSubmitted,
            'answersPreview': preview,
          });
        }

        // 4. 已确认：真正提交（不重试写入，避免重复投递）
        try {
          await questionnaireService.submit(detail: detail, answers: payload);
          return McpToolResult.json({
            'status': 'success',
            'message': '问卷《${detail.title}》提交成功！',
          });
        } catch (e) {
          return McpToolResult.error('提交问卷失败: $e');
        }
      },
    );
  }
}

/// 在 answers 中按题目 dm 精确或标题模糊查找用户给的答案。
Object? _findAnswer(QuestionnaireQuestion question, Map rawAnswers) {
  if (rawAnswers.containsKey(question.dm)) return rawAnswers[question.dm];
  for (final entry in rawAnswers.entries) {
    final key = entry.key.toString().trim();
    if (key.isEmpty) continue;
    if (question.title.contains(key) || key.contains(question.title)) {
      return entry.value;
    }
  }
  return null;
}

/// 把用户答案映射为选项 dm（单选返回 String，多选返回 List<String>）。
/// 找不到有效选项时返回 null。
Object? _mapChoiceAnswer(QuestionnaireQuestion question, Object? hit) {
  String? matchOne(String text) {
    final keyword = text.trim();
    if (keyword.isEmpty) return null;
    for (final option in question.options) {
      if (option.dm == keyword || option.name == keyword) return option.dm;
    }
    for (final option in question.options) {
      if (option.name.contains(keyword) || keyword.contains(option.name)) {
        return option.dm;
      }
    }
    return null;
  }

  if (hit is List) {
    final matched = <String>[];
    for (final item in hit) {
      final dm = matchOne(item.toString());
      if (dm != null) matched.add(dm);
    }
    if (matched.isEmpty) return null;
    return question.isMultiChoice ? matched : matched.first;
  }
  if (hit is String) {
    // 多选题也允许逗号/顿号分隔的一串文本
    if (question.isMultiChoice && RegExp(r'[,，、;；]').hasMatch(hit)) {
      final matched = hit
          .split(RegExp(r'[,，、;；]'))
          .map(matchOne)
          .whereType<String>()
          .toList();
      return matched.isEmpty ? null : matched;
    }
    return matchOne(hit);
  }
  return null;
}

Object _previewValue(QuestionnaireQuestion question, Object? mapped) {
  String nameOf(String dm) => question.options
      .firstWhere((o) => o.dm == dm,
          orElse: () => QuestionnaireOption(dm: dm, name: dm))
      .name;
  if (mapped is List) return mapped.map((e) => nameOf(e.toString())).toList();
  if (mapped is String && mapped.isNotEmpty) return nameOf(mapped);
  return '';
}
