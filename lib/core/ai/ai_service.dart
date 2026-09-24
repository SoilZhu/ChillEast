import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../mcp/services/mcp_tool_registry.dart';
import '../../features/timetable/services/timetable_storage.dart';
import '../../features/timetable/utils/date_calculator.dart';

/// AI Message model
class AiChatMessage {
  final String role; // 'system', 'user', 'assistant', 'tool'
  final dynamic content;
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
      content: json['content'],
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

  /// 默认配置：走自建 Cloudflare Worker 中转，运营商 / 模型在 Worker 端切换，
  /// App 无需发版。部署后把 Worker 地址填到 `_fallbackApiUrl`，
  /// 或打包时用 --dart-define=DEFAULT_AI_API_URL=... 覆盖。
  /// （构建密钥含义：此时 DEFAULT_AI_API_KEY 是 Worker 共享密钥 WORKER_API_KEY）
  static const String _envApiUrl = String.fromEnvironment(
    'DEFAULT_AI_API_URL',
    defaultValue: '',
  );

  /// Worker 部署地址（自定义域名），打包时可用
  /// --dart-define=DEFAULT_AI_API_URL=... 覆盖。
  static const String _fallbackApiUrl = 'https://chilleast-llm-api.soilzhu.su/v1';

  static String get defaultApiUrl =>
      _envApiUrl.trim().isNotEmpty ? _envApiUrl.trim() : _fallbackApiUrl;

  static const String _envModel = String.fromEnvironment(
    'DEFAULT_AI_MODEL',
    defaultValue: '',
  );

  /// 默认模型由 Worker 端 UPSTREAM_MODEL 决定，客户端透传该标记即可。
  static const String _fallbackModel = 'soilzhu-latest';

  static String get defaultModel =>
      _envModel.trim().isNotEmpty ? _envModel.trim() : _fallbackModel;

  /// 旧直连默认值（硅基流动）：仅用于识别老用户存量配置并自动迁移，
  /// 不要再作为新默认值使用。
  static const String legacyDefaultApiUrl = 'https://api.siliconflow.cn/v1';
  static const String legacyDefaultModel = 'Qwen/Qwen3.5-4B';

  /// 是否为旧直连硅基流动的存量配置（含 /chat/completions 后缀与末尾斜杠变体）
  static bool isLegacyDefaultApiUrl(String? url) {
    if (url == null) return false;
    var v = url.trim();
    if (v.isEmpty) return false;
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    if (v.endsWith('/chat/completions')) {
      v = v.substring(0, v.length - '/chat/completions'.length);
    }
    return v == legacyDefaultApiUrl;
  }

  static bool isLegacyDefaultModel(String? model) {
    if (model == null) return false;
    final v = model.trim();
    // Qwen 直连旧值，以及过渡期的 worker-default 标记，都视为“跟随默认”
    return v == legacyDefaultModel || v == 'worker-default';
  }

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
1. 你拥有调用本地校园能力与 MCP 工具（如查询课表、管理课表规则（调休/停课/手动添加课程/删除规则）、作业管理、空教室查询、成绩查询、校园卡余额与账单、电费充值与查询、校园通知、图书馆预约、阳光服务诉求提交、学工问卷查询与代填、请假申请查询与代提交、报修工单查询与提交等）的权限。
2. 当用户涉及调休、停课、改课、手动加课或清除规则时，主动调用 manage_timetable_rules 工具完成规则配置或查询，修改后本地课表和日历 ICS 文件会自动实时重算。
3. 【作业管理准则】：
   - 查作业调用 query_homework（status 可选 pending/completed/archived/all）。
   - 当用户说"添加/记一笔/新增作业或待办"时，必须调用 add_homework 工具（必填 title，时间必须换算成 "YYYY-MM-DD HH:MM:SS" 绝对时间后再传入），成功后向用户复述标题与截止时间，严禁只用文字回复说"已添加"而不调工具。
   - 当用户说"完成/做完某作业"时，调用 complete_homework（仅手动作业可完成，超星同步作业只能提示去学习通完成）。
   - 添加/完成后不要自动再调 query_homework 验证，直接按工具返回结果回复。
4. 如果工具返回错误或提示未登录，请友善提示用户在 App 内登录教务系统或对应服务。
5. 【图书馆座位预约准则】：
   - 当用户需要预约图书馆时，调用 reserve_library_seat。
   - 若用户未指定具体的阅览室或座位编号，系统会自动回退默认使用用户上一次预约的历史座位。
   - 【极为重要 - 用户确认原则】：在真正执行预约提交之前，必须先将整理好的预约方案（阅览室名称、座位号、预约日期及具体起止时段）明确呈现给用户，并明确征得用户的同意与确认（首次调用 reserve_library_seat 时 confirmed 必须保持 false）。只有当用户明确回复确认同意（如“确认”、“好的”、“预约吧”）后，方可在下一次调用时传入 confirmed=true 完成正式提交！
6. 【阳光服务快速提交准则】：
   - 当用户希望向学校反馈诉求、建议、投诉、咨询或表扬时，调用 submit_sunshine_letter 或 query_sunshine_departments。
   - 快速协助用户整理诉求信息，并在向用户清晰展示受理单位、类别、标题与正文后，征得用户同意确认后再正式提交。
7. 【宿舍电费查询与充值准则】：
   - 查询电费调用 recharge_electricity (action="query_balance")。若用户未特别指明宿舍，工具会自动使用其在电费页面记住的宿舍。
   - 回答宿舍位置时，务必使用工具返回的友好房间名称（location 或 roomName），严禁向用户输出十六进制哈希 ID。
   - 【扣款充值安全原则】：当用户明确要求充值电费且指定了具体金额时方可调用 action="recharge"。
8. 【学工问卷代填准则】：
   - 当用户提到假期去向统计、问卷调查、学工问卷时，调用 query_questionnaires 查列表，query_questionnaire_detail 看题目。
   - 代填用 submit_questionnaire，answers 的 key 为题目标题关键词。首次调用 confirmed 保持 false，先把每道题的答案逐题呈现给用户核对，用户明确同意后再传 confirmed=true 提交。
9. 【请假代提交准则】：
   - 当用户要请假、查请假记录时，调用 query_leaves 查记录，query_leave_detail 看详情。
   - 代提交用 submit_leave，时长由起止时间自动计算。首次调用 confirmed 保持 false，先把申请内容逐项呈现给用户核对，用户明确同意后再传 confirmed=true 提交。附件只能用户在 App 内手工补，代提交后要提醒。
10. 【报修工单查询、提交与取消准则】：
   - 当用户需要查询报修单时，调用 query_repairs（支持 status="处理中" / "已完成" / "草稿箱" / "全部"）。
   - 当用户需要查看具体工单详情与流转日志时，调用 query_repair_detail。
   - 当用户需要报修时，调用 submit_repair_order。
   - 学校报修支持四大分类：后勤报修（宿舍生活公用设施，如水管漏水、门窗家具、照明空调等）、校园网络报修（校园网/WiFi/网线等）、一校通报修（校园卡与终端设备）、业务系统报修（教务/研究生等软件业务系统）。
   - 【极为重要 - 后勤报修必须有图】：后勤报修（宿舍生活、公用设施等）必须附带现场故障图片！若用户在聊天中已发送图片，请将图片本地路径传入 image_path（工具亦会自动关联）；若用户未提供图片，必须明确告知并引导用户在对话中发送/上传故障现场照片，否则无法提交。
   - 【用户确认原则】：提交前请向用户清晰展示报修分类、故障地点、故障描述、预约时间与照片情况，首次调用 confirmed 保持 false。经用户明确同意确认后再传 confirmed=true 完成正式提交。
   - 【工单取消准则】：当用户需要取消报修工单时，调用 cancel_repair_order。工单取消操作不可逆，首次调用 confirmed 必须保持 false，先向用户展示待取消工单的信息（工单号、分类、描述、状态等）并明确征得用户确认。用户明确同意确认后，方可再次调用并将 confirmed 设为 true 正式取消。若工单当前状态不允许取消（如已被接单/派工/已完结），工具会自动返回明确说明。
11. 【核心要求】回答必须极度简洁明了、直击核心、精炼扼要，严禁多余客套与废话，适配手机悬浮小卡片快速扫视阅读。
12. 善用 Markdown 格式（加粗、简短无序列表）呈现关键信息，段落紧凑。
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
    String? model,
    void Function(String toolName, String statusMessage)? onToolExecuting,
  }) async {
    final effectiveApiKey = apiKey.trim().isNotEmpty
        ? apiKey.trim()
        : (defaultApiKey.isNotEmpty ? defaultApiKey : '');

    if (effectiveApiKey.isEmpty) {
      throw Exception('未配置 API Key，请先在「AI 助理设置」中填入 API Key');
    }

    final effectiveEndpoint = normalizeEndpointUrl(apiUrl);
    final effectiveModel =
        (model != null && model.trim().isNotEmpty) ? model.trim() : defaultModel;

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
              'api-key': effectiveApiKey,
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

          // 提取文本内容（失败时带上明确前缀，避免模型幻觉成成功）
          String toolOutputText = '';
          if (toolResult.content.isNotEmpty) {
            toolOutputText = toolResult.content.map((c) => c.text ?? c.data ?? '').join('\n');
            if (toolResult.isError) {
              toolOutputText = '工具调用失败: $toolOutputText';
            }
          } else {
            toolOutputText = toolResult.isError ? '工具调用失败' : '工具调用完成';
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
      case 'manage_timetable_rules':
        return '课表规则管理';
      case 'query_homework':
        return '作业查询';
      case 'add_homework':
        return '添加待办作业';
      case 'complete_homework':
        return '完成作业';
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
      case 'recharge_electricity':
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
      case 'query_questionnaires':
        return '查询学工问卷';
      case 'query_questionnaire_detail':
        return '查询问卷题目';
      case 'submit_questionnaire':
        return '代填学工问卷';
      case 'query_leaves':
        return '查询请假记录';
      case 'query_leave_detail':
        return '查询请假详情';
      case 'submit_leave':
        return '代提交请假';
      case 'query_card_transactions':
      case 'query_bill':
        return '校园卡账单';
      default:
        return name;
    }
  }
}
