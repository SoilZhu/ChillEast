import '../../../features/workspace/models/transaction_model.dart';
import '../../../features/workspace/services/transaction_service.dart';
import '../models/mcp_tool.dart';

/// MCP Tool: 校园卡账单（流水）查询 (query_card_transactions)
class TransactionTool {
  static const String toolName = 'query_card_transactions';

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDate(String s) {
    try {
      final parts = s.split('-');
      if (parts.length != 3) return null;
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (_) {
      return null;
    }
  }

  /// 接受取值（-1/1/2/3/4）或中文名（全部/消费/充值/补助/转账）
  static TransactionType _parseType(String? s) {
    final v = (s ?? '').trim();
    for (final t in TransactionType.values) {
      if (t.value == v || t.label == v) return t;
    }
    return TransactionType.all;
  }

  static McpTool create({
    TransactionService? service,
    String? toolName,
  }) {
    final effectiveToolName = toolName ?? TransactionTool.toolName;
    return McpTool(
      name: effectiveToolName,
      description:
          '湖南农业大学校园卡账单（消费流水）查询工具。按起止日期与流水类型查询校园卡的每一笔消费/充值/补助/转账记录，每条包含商户名称、金额与时间。起止间隔最长 31 天，截止日期不能超过今天；未指定日期时默认查询近 7 天（含今天）。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'beginDate': {
            'type': 'string',
            'description': '起始日期，格式 yyyy-MM-dd（例如 2026-09-15）。不填则默认为 6 天前。',
          },
          'endDate': {
            'type': 'string',
            'description': '截止日期，格式 yyyy-MM-dd（例如 2026-09-22），不能超过今天。不填则默认为今天。',
          },
          'tradeType': {
            'type': 'string',
            'enum': ['全部', '消费', '充值', '补助', '转账'],
            'description': '流水类型，默认为全部。',
            'default': '全部',
          },
        },
      },
      handler: (arguments) async {
        if (service == null) {
          return McpToolResult.error('未提供 TransactionService 实例');
        }

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final defaultBegin = today.subtract(const Duration(days: 6));

        final beginStr = arguments['beginDate'] as String?;
        final endStr = arguments['endDate'] as String?;
        final type = _parseType(arguments['tradeType'] as String?);

        final begin = (beginStr == null || beginStr.trim().isEmpty)
            ? defaultBegin
            : _parseDate(beginStr.trim());
        final end = (endStr == null || endStr.trim().isEmpty)
            ? today
            : _parseDate(endStr.trim());

        if (begin == null) {
          return McpToolResult.error('起始日期格式错误，请使用 yyyy-MM-dd（例如 2026-09-15）');
        }
        if (end == null) {
          return McpToolResult.error('截止日期格式错误，请使用 yyyy-MM-dd（例如 2026-09-22）');
        }
        if (begin.isAfter(end)) {
          return McpToolResult.error('截止日期不能早于起始日期');
        }
        if (end.isAfter(today)) {
          return McpToolResult.error('截止日期不能超过今天');
        }
        if (end.difference(begin).inDays > 31) {
          return McpToolResult.error('日期区间最长为 31 天，请缩小范围后重试');
        }

        try {
          final records = await service.queryTransactions(
            beginDate: _fmt(begin),
            endDate: _fmt(end),
            tradeType: type.value,
          );

          // 保护上下文：最多返回 100 条
          const limit = 100;
          final truncated = records.length > limit;
          final shown = truncated ? records.sublist(0, limit) : records;

          return McpToolResult.json({
            'beginDate': _fmt(begin),
            'endDate': _fmt(end),
            'tradeType': type.label,
            'count': records.length,
            'truncated': truncated,
            'records': shown
                .map((r) => {
                      'merchantName': r.merchantName,
                      'amount': r.amount,
                      'time': r.time,
                    })
                .toList(),
            'unit': '元',
            'status': 'success',
          });
        } catch (e) {
          return McpToolResult.error('查询校园卡账单失败: $e');
        }
      },
    );
  }
}
