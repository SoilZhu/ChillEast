import '../../../features/workspace/services/campus_card_service.dart';
import '../models/mcp_tool.dart';

/// MCP Tool: 校园卡余额查询 (query_campus_card_balance)
class CampusCardTool {
  static const String toolName = 'query_campus_card_balance';

  static McpTool create({
    CampusCardService? service,
  }) {
    final cardService = service ?? CampusCardService();

    return McpTool(
      name: toolName,
      description:
          '查询湖南农业大学学生的校园卡账户信息，包括持卡人姓名、学号/卡号（idserial）以及当前校园卡可用余额。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'forceRefresh': {
            'type': 'boolean',
            'description': '是否强制重新授权并从校园卡服务平台拉取最新余额。默认为 false。',
          },
        },
      },
      handler: (arguments) async {
        final bool forceRefresh = arguments['forceRefresh'] as bool? ?? false;

        try {
          // 如果强制刷新或无缓存信息，则调用 fetchRechargeInfo
          if (forceRefresh || cardService.cachedInfo == null) {
            final info = await cardService.fetchRechargeInfo(isRetry: true);
            return McpToolResult.json({
              'name': info.name,
              'studentId': info.idserial,
              'balance': info.balance,
              'unit': '元',
              'status': 'success',
            });
          }

          final cached = cardService.cachedInfo!;
          return McpToolResult.json({
            'name': cached.name,
            'studentId': cached.idserial,
            'balance': cached.balance,
            'unit': '元',
            'status': 'success',
          });
        } catch (e) {
          return McpToolResult.error('查询校园卡余额失败: $e');
        }
      },
    );
  }
}
