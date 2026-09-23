import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/mcp_protocol.dart';
import '../models/mcp_tool.dart';
import '../tools/timetable_tool.dart';
import '../tools/timetable_rule_tool.dart';
import '../tools/homework_tools.dart';
import '../tools/classroom_tool.dart';
import '../tools/score_tool.dart';
import '../tools/campus_card_tool.dart';
import '../tools/electricity_tool.dart';
import '../tools/notice_tool.dart';
import '../tools/library_tool.dart';
import '../tools/sunshine_tool.dart';
import '../tools/questionnaire_tool.dart';
import '../tools/leave_tool.dart';
import '../tools/transaction_tool.dart';
import '../tools/repair_tool.dart';
import '../../../features/workspace/services/electricity_service.dart';
import '../../../features/workspace/services/campus_card_service.dart';
import '../../../features/workspace/services/transaction_service.dart';
import '../../../features/library/providers/library_provider.dart';
import '../../../features/sunshine/services/sunshine_service.dart';
import '../../../features/questionnaire/services/questionnaire_service.dart';
import '../../../features/leave/services/leave_service.dart';
import '../../../features/repairs/services/repair_service.dart';

/// MCP Tool Registry Provider
final mcpToolRegistryProvider = Provider<McpToolRegistry>((ref) {
  final electricityService = ref.watch(electricityServiceProvider);
  final campusCardService = ref.watch(campusCardServiceProvider);
  final libraryService = ref.watch(libraryServiceProvider);
  final sunshineService = ref.watch(sunshineServiceProvider);
  final questionnaireService = ref.watch(questionnaireServiceProvider);
  final leaveService = ref.watch(leaveServiceProvider);
  final transactionService = ref.watch(transactionServiceProvider);
  final repairService = ref.watch(repairServiceProvider);

  final registry = McpToolRegistry();

  // 注册标准 MCP 工具
  // 1. 课表查询
  registry.register(TimetableTool.create());

  // 1.1 课表规则管理（调休、停课、手动添加课程、删除规则）
  registry.register(TimetableRuleTool.create());

  // 2. 作业查询
  registry.register(HomeworkQueryTool.create());

  // 3. 作业添加
  registry.register(HomeworkAddTool.create());

  // 4. 作业完成（仅限手动添加）
  registry.register(HomeworkCompleteTool.create());

  // 5. 空教室查询
  registry.register(ClassroomTool.create());

  // 6. 成绩查询
  registry.register(ScoreTool.create());

  // 7. 校园卡余额查询
  registry.register(CampusCardTool.create(service: campusCardService));

  // 8. 电费充值与查询 (同时注册 recharge_electricity 与 query_electricity 别名以提高模型兼容度)
  registry.register(ElectricityTool.create(service: electricityService));
  registry.register(ElectricityTool.create(service: electricityService, toolName: 'query_electricity'));

  // 9. 通知查询
  registry.register(NoticeTool.create());

  // 10. 图书馆上次座位查询
  registry.register(LibraryLastSeatQueryTool.create(service: libraryService));

  // 11. 图书馆座位预约（支持默认上次座位与强制确认）
  registry.register(LibraryReserveTool.create(service: libraryService));

  // 12. 阳光服务受理部门查询
  registry.register(SunshineDepartmentsQueryTool.create(service: sunshineService));

  // 13. 阳光服务诉求快速提交
  registry.register(SunshineSubmitTool.create(service: sunshineService));

  // 14. 学工问卷列表查询
  registry.register(QuestionnaireListTool.create(service: questionnaireService));

  // 15. 学工问卷题目查询
  registry.register(QuestionnaireDetailTool.create(service: questionnaireService));

  // 16. 学工问卷代填提交（需用户确认）
  registry.register(QuestionnaireSubmitTool.create(service: questionnaireService));

  // 17. 请假记录查询
  registry.register(LeaveListTool.create(service: leaveService));

  // 18. 请假单详情查询
  registry.register(LeaveDetailTool.create(service: leaveService));

  // 19. 请假代提交（需用户确认）
  registry.register(LeaveSubmitTool.create(service: leaveService));

  // 20. 校园卡账单查询 (同时注册 query_card_transactions 与 query_bill 别名)
  registry.register(TransactionTool.create(service: transactionService));
  registry.register(TransactionTool.create(service: transactionService, toolName: 'query_bill'));

  // 21. 报修工单查询 (同时注册 query_repairs 与 query_repair_orders 别名)
  registry.register(RepairOrdersQueryTool.create(service: repairService));
  registry.register(RepairOrdersQueryTool.create(service: repairService, toolName: 'query_repair_orders'));

  // 22. 报修工单详情查询
  registry.register(RepairDetailTool.create(service: repairService));

  // 23. 报修工单提交（后勤报修必带图，需用户确认）
  registry.register(RepairSubmitTool.create(service: repairService));

  // 24. 报修工单取消（需用户确认）
  registry.register(RepairCancelTool.create(service: repairService));

  return registry;
});

/// MCP Tool Registry for managing and invoking standard MCP tools.
class McpToolRegistry {
  final Map<String, McpTool> _tools = {};

  McpToolRegistry([List<McpTool>? initialTools]) {
    if (initialTools != null) {
      for (final tool in initialTools) {
        register(tool);
      }
    }
  }

  /// Register an MCP tool
  void register(McpTool tool) {
    _tools[tool.name] = tool;
  }

  /// Unregister a tool by name
  void unregister(String name) {
    _tools.remove(name);
  }

  /// Get a registered tool by name
  McpTool? getTool(String name) => _tools[name];

  /// Get all registered tools
  List<McpTool> getAllTools() => _tools.values.toList();

  /// List all tool definitions conforming to the MCP specification (`tools/list`)
  List<Map<String, dynamic>> listTools() {
    return _tools.values.map((tool) => tool.toJson()).toList();
  }

  /// Call a registered tool by name with arguments (`tools/call`)
  Future<McpToolResult> callTool(String name, [Map<String, dynamic>? arguments]) async {
    final tool = _tools[name];
    if (tool == null) {
      return McpToolResult.error('未知 MCP 工具: $name');
    }
    return await tool.execute(arguments ?? {});
  }

  /// Handle an incoming MCP JSON-RPC 2.0 request
  Future<McpResponse> handleRequest(McpRequest request) async {
    switch (request.method) {
      case 'initialize':
        return McpResponse.success(
          id: request.id,
          result: {
            'protocolVersion': '2024-11-05',
            'serverInfo': {
              'name': 'ChillEast-MCP-Server',
              'version': '1.0.0',
            },
            'capabilities': {
              'tools': {
                'listChanged': false,
              },
            },
          },
        );

      case 'ping':
        return McpResponse.success(id: request.id, result: {});

      case 'tools/list':
        return McpResponse.success(
          id: request.id,
          result: {
            'tools': listTools(),
          },
        );

      case 'tools/call':
        final params = request.params;
        if (params == null) {
          return McpResponse.error(
            id: request.id,
            code: McpError.invalidParams,
            message: '缺少请求参数 params',
          );
        }

        final toolName = params['name'] as String?;
        if (toolName == null || toolName.isEmpty) {
          return McpResponse.error(
            id: request.id,
            code: McpError.invalidParams,
            message: '缺少工具名称 params.name',
          );
        }

        final rawArgs = params['arguments'];
        final Map<String, dynamic> arguments = rawArgs is Map
            ? Map<String, dynamic>.from(rawArgs)
            : <String, dynamic>{};
        final result = await callTool(toolName, arguments);

        return McpResponse.success(
          id: request.id,
          result: result.toJson(),
        );

      default:
        return McpResponse.error(
          id: request.id,
          code: McpError.methodNotFound,
          message: '未知的 MCP 方法: ${request.method}',
        );
    }
  }
}
