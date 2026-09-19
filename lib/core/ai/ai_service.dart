import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../mcp/services/mcp_tool_registry.dart';
import '../../features/timetable/services/timetable_storage.dart';
import '../../features/timetable/utils/date_calculator.dart';

/// AI Message model
class AiChatMessage {
  final String role; // 'system', 'user', 'assistant', 'tool'
  final String? content;
  final String? name;
  final String? toolCallId;
  final List<dynamic>? toolCalls;

  AiChatMessage({
    required this.role,
    this.content,
    this.name,
    this.toolCallId,
    this.toolCalls,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'role': role};
    if (content != null) {
      map['content'] = content;
    } else if (role == 'assistant' && (toolCalls == null || toolCalls!.isEmpty)) {
      map['content'] = '';
    }
    if (name != null) map['name'] = name;
    if (toolCallId != null) map['tool_call_id'] = toolCallId;
    if (toolCalls != null) map['tool_calls'] = toolCalls;
    return map;
  }

  factory AiChatMessage.fromJson(Map<String, dynamic> json) {
    return AiChatMessage(
      role: json['role'] as String? ?? 'user',
      content: json['content'] as String?,
      name: json['name'] as String?,
      toolCallId: json['tool_call_id'] as String?,
      toolCalls: json['tool_calls'] as List<dynamic>?,
    );
  }
}

/// AI Assistant Service
class AiAssistantService {
  final Logger _logger = Logger();
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
    ),
  );

  /// 默认配置：硅基流动中国站 + Qwen/Qwen3.5-4B
  static const String defaultApiUrl = 'https://api.siliconflow.cn/v1';
  static const String defaultModel = 'Qwen/Qwen3.5-4B';

  /// 从 CI / 构建环境通过 --dart-define=DEFAULT_AI_API_KEY=xxx 注入的默认 Key
  static const String defaultApiKey = String.fromEnvironment(
    'DEFAULT_AI_API_KEY',
    defaultValue: '',
  );

  /// 格式化请求端点 URL
  static String normalizeEndpointUrl(String? inputUrl) {
    String url = (inputUrl == null || inputUrl.trim().isEmpty)
        ? defaultApiUrl
        : inputUrl.trim();
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (!url.endsWith('/chat/completions')) {
      url = '$url/chat/completions';
    }
    return url;
  }

  /// 构建当前上下文系统提示词
  Future<String> buildSystemPrompt() async {
    final now = DateTime.now();
    final weekdayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final weekdayStr = weekdayNames[now.weekday];
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    int? currentWeek;
    try {
      final storage = TimetableStorage();
      final metadata = await storage.readMetadata();
      if (metadata != null && metadata['firstWeekMonday'] != null) {
        final firstWeekMonday = DateTime.parse(metadata['firstWeekMonday'] as String);
        currentWeek = DateCalculator.getCurrentWeekNumber(firstWeekMonday, now);
      }
    } catch (_) {}

    final weekInfo = currentWeek != null && currentWeek > 0 && currentWeek <= 25
        ? '当前学期教学周：第 $currentWeek 周'
        : '当前学期周次未知';

    return '''你是由“自在东湖 (ChillEast)”校园客户端内置的 AI 校园智能助理。
当前现实时间：$dateStr $weekdayStr $timeStr
$weekInfo

【能力与准则】
1. 你拥有调用本地校园能力与 MCP 工具（如查询课表、管理课表规则（调休/停课/手动添加课程/删除规则）、作业管理、空教室查询、成绩查询、校园卡余额、电费充值与查询、校园通知、图书馆预约、阳光服务诉求提交等）的权限。
2. 当用户涉及调休、停课、改课、手动加课或清除规则时，主动调用 manage_timetable_rules 工具完成规则配置或查询，修改后本地课表和日历 ICS 文件会自动实时重算。
3. 当用户的提问涉及学生课表、待办作业、电费、成绩、校园卡或空教室等具体数据时，务必主动调用对应的 Tool 工具获取准确数据后再回答，不要凭空捏造。
4. 如果工具返回错误或提示未登录，请友善提示用户在 App 内登录教务系统或对应服务。
4. 【图书馆座位预约准则】：
   - 当用户需要预约图书馆时，调用 reserve_library_seat。
   - 若用户未指定具体的阅览室或座位编号，系统会自动回退默认使用用户上一次预约的历史座位。
   - 【极为重要 - 用户确认原则】：在真正执行预约提交之前，必须先将整理好的预约方案（阅览室名称、座位号、预约日期及具体起止时段）明确呈现给用户，并明确征得用户的同意与确认（首次调用 reserve_library_seat 时 confirmed 必须保持 false）。只有当用户明确回复确认同意（如“确认”、“好的”、“预约吧”）后，方可在下一次调用时传入 confirmed=true 完成正式提交！
5. 【阳光服务快速提交准则】：
   - 当用户希望向学校反馈诉求、建议、投诉、咨询或表扬时，调用 submit_sunshine_letter 或 query_sunshine_departments。
   - 快速协助用户整理诉求信息，并在向用户清晰展示受理单位、类别、标题与正文后，征得用户同意确认后再正式提交。
6. 【核心要求】回答必须极度简洁明了、直击核心、精炼扼要，严禁多余客套与废话，适配手机悬浮小卡片快速扫视阅读。
7. 善用 Markdown 格式（加粗、简短无序列表）呈现关键信息，段落紧凑。
''';
  }

  /// 将 MCP 工具转换为 OpenAI tools 规范
  List<Map<String, dynamic>> _convertMcpTools(McpToolRegistry registry) {
    return registry.getAllTools().map((tool) {
      return {
        'type': 'function',
        'function': {
          'name': tool.name,
          'description': tool.description,
          'parameters': tool.inputSchema,
        },
      };
    }).toList();
  }

  /// 执行一轮或多轮对话，自动完成 Function Calling (支持任意兼容 OpenAI 的 API 端点)
  Future<String> chat({
    required String apiKey,
    required List<AiChatMessage> conversationHistory,
    required McpToolRegistry toolRegistry,
    String? apiUrl,
    String model = defaultModel,
    void Function(String toolName, String statusMessage)? onToolExecuting,
  }) async {
    final effectiveApiKey = apiKey.trim().isNotEmpty
        ? apiKey.trim()
        : (defaultApiKey.isNotEmpty ? defaultApiKey : '');

    if (effectiveApiKey.isEmpty) {
      throw Exception('未配置 API Key，请先在「AI 助理设置」中填入 API Key');
    }

    final effectiveEndpoint = normalizeEndpointUrl(apiUrl);
    final effectiveModel = model.trim().isNotEmpty ? model.trim() : defaultModel;

    final systemPrompt = await buildSystemPrompt();
    final tools = _convertMcpTools(toolRegistry);

    // 组装完整的消息列表
    final messages = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content': systemPrompt,
      },
      ...conversationHistory.map((m) => m.toJson()),
    ];

    int loopCount = 0;
    const int maxLoops = 6;

    while (loopCount < maxLoops) {
      loopCount++;

      final requestData = {
        'model': effectiveModel,
        'messages': messages,
        'temperature': 0.6,
        if (tools.isNotEmpty) 'tools': tools,
        if (tools.isNotEmpty) 'tool_choice': 'auto',
      };

      _logger.d('Sending chat completion request to $effectiveEndpoint with model $effectiveModel (loop $loopCount)');

      Response response;
      try {
        response = await _dio.post(
          effectiveEndpoint,
          data: requestData,
          options: Options(
            headers: {
              'Authorization': 'Bearer $effectiveApiKey',
              'Content-Type': 'application/json',
            },
          ),
        );
      } on DioException catch (e) {
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;
        _logger.e('DioException: status=$statusCode, data=$responseData, msg=${e.message}');

        String errorMsg = '网络请求失败';
        if (responseData is Map && responseData['error'] != null) {
          final err = responseData['error'];
          if (err is Map && err['message'] != null) {
            errorMsg = '${err['message']}';
          } else {
            errorMsg = '$err';
          }
        } else if (responseData is Map && responseData['message'] != null) {
          errorMsg = '${responseData['message']}';
        } else if (statusCode == 401) {
          errorMsg = 'API Key 无效或未授权，请检查 API Key 配置';
        } else if (statusCode == 404) {
          errorMsg = 'API 端点不存在 (404)，请检查 URL 地址是否正确';
        } else if (statusCode == 429) {
          errorMsg = 'API 调用频率超限或余额不足 (429)';
        } else if (e.message != null && e.message!.isNotEmpty) {
          errorMsg = e.message!;
        }
        throw Exception(errorMsg);
      } catch (e) {
        _logger.e('Unknown request error: $e');
        rethrow;
      }

      if (response.statusCode != 200) {
        throw Exception('API 请求失败 (${response.statusCode}): ${response.data}');
      }

      final data = response.data;
      if (data is! Map) {
        throw Exception('API 返回数据格式异常');
      }

      final choices = data['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw Exception('模型未返回有效结果: $data');
      }

      final messageMap = choices[0]['message'] as Map<String, dynamic>;
      final content = messageMap['content'] as String?;
      final toolCalls = messageMap['tool_calls'] as List<dynamic>?;

      // 如果模型决定调用工具
      if (toolCalls != null && toolCalls.isNotEmpty) {
        // 先把 assistant 的 tool_calls 消息加入历史
        messages.add(messageMap);

        for (final toolCall in toolCalls) {
          final toolCallId = toolCall['id'] as String? ?? 'call_${DateTime.now().millisecondsSinceEpoch}';
          final function = toolCall['function'] as Map<String, dynamic>? ?? {};
          final toolName = function['name'] as String? ?? '';
          final rawArguments = function['arguments'];

          Map<String, dynamic> arguments = {};
          if (rawArguments is String && rawArguments.trim().isNotEmpty) {
            try {
              arguments = jsonDecode(rawArguments) as Map<String, dynamic>;
            } catch (e) {
              _logger.w('Failed to parse tool arguments: $rawArguments');
            }
          } else if (rawArguments is Map) {
            arguments = Map<String, dynamic>.from(rawArguments);
          }

          final friendlyToolName = _getFriendlyToolName(toolName);
          onToolExecuting?.call(toolName, '正在使用「$friendlyToolName」获取信息...');

          // 本地执行 MCP 工具
          final toolResult = await toolRegistry.callTool(toolName, arguments);

          // 提取文本内容
          String toolOutputText = '';
          if (toolResult.content.isNotEmpty) {
            toolOutputText = toolResult.content.map((c) => c.text ?? c.data ?? '').join('\n');
          } else {
            toolOutputText = toolResult.isError ? '工具调用异常' : '工具调用完成';
          }

          // 将 tool 角色响应加进消息中
          messages.add({
            'role': 'tool',
            'tool_call_id': toolCallId,
            'content': toolOutputText,
          });
        }
        // 继续下一个循环将工具结果发送给模型
        continue;
      }

      // 如果已正常结束，返回最终文本
      if (content != null && content.isNotEmpty) {
        return content;
      }

      // 特殊情况：如果既没有 tool_calls 也没有 content，退出
      break;
    }

    return '抱歉，暂时未能生成回复，请稍后再试。';
  }

  String _getFriendlyToolName(String name) {
    switch (name) {
      case 'query_timetable':
        return '课表查询';
      case 'query_homework':
        return '作业查询';
      case 'add_homework':
        return '添加待办作业';
      case 'query_empty_classroom':
      case 'query_empty_classrooms':
        return '空教室查询';
      case 'query_score':
      case 'query_scores':
        return '成绩查询';
      case 'query_campus_card':
      case 'query_campus_card_balance':
        return '一卡通余额';
      case 'query_electricity':
        return '宿舍电费';
      case 'query_notice':
        return '校园通知';
      case 'query_library_last_seat':
        return '查询上次座位';
      case 'reserve_library_seat':
        return '预约图书馆座位';
      case 'query_sunshine_departments':
        return '查询阳光服务部门';
      case 'submit_sunshine_letter':
        return '提交阳光服务';
      default:
        return name;
    }
  }
}
