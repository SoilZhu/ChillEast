import '../../../features/notice/models/message_model.dart';
import '../../../features/notice/services/notice_service.dart';
import '../models/mcp_tool.dart';

/// MCP Tool: 通知查询 (query_notices)
class NoticeTool {
  static const String toolName = 'query_notices';

  static McpTool create({
    NoticeService? service,
  }) {
    final noticeService = service ?? NoticeService();

    return McpTool(
      name: toolName,
      description:
          '查询学校或超星平台的通知公告消息。支持按未读状态过滤、关键词搜索，以及通过通知 UUID 获取详细公告正文内容。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'action': {
            'type': 'string',
            'enum': ['query', 'get_detail'],
            'description': '操作类型：query(查询通知列表, 默认), get_detail(获取指定通知的完整详情内容)。',
            'default': 'query',
          },
          'keyword': {
            'type': 'string',
            'description': '按通知标题或发布者姓名进行关键词搜索过滤。',
          },
          'unreadOnly': {
            'type': 'boolean',
            'description': '是否仅查询未读通知。默认为 false。',
          },
          'limit': {
            'type': 'integer',
            'description': '返回的最大通知条数，默认为 15。',
            'minimum': 1,
            'maximum': 50,
          },
          'noticeUuid': {
            'type': 'string',
            'description': '通知的唯一标识 UUID（当 action=get_detail 时必填）。',
          },
        },
      },
      handler: (arguments) async {
        final action = arguments['action'] as String? ?? 'query';
        final String? noticeUuid = arguments['noticeUuid'] as String?;
        final String? keyword = arguments['keyword'] as String?;
        final bool unreadOnly = arguments['unreadOnly'] as bool? ?? false;
        final int limit = arguments['limit'] as int? ?? 15;

        try {
          // 1. 获取通知详情
          if (action == 'get_detail' || (noticeUuid != null && noticeUuid.isNotEmpty && action != 'query')) {
            if (noticeUuid == null || noticeUuid.isEmpty) {
              return McpToolResult.error('获取通知详情必须提供 noticeUuid');
            }
            final detail = await noticeService.fetchNoticeDetail(noticeUuid);
            return McpToolResult.json({
              'uuid': noticeUuid,
              'detail': detail,
            });
          }

          // 2. 查询通知列表
          final result = await noticeService.fetchMessageList();
          List<MessageModel> messages = result.messages;

          // 未读过滤
          if (unreadOnly) {
            messages = messages.where((m) => !m.isRead).toList();
          }

          // 关键词过滤
          if (keyword != null && keyword.trim().isNotEmpty) {
            final kw = keyword.trim().toLowerCase();
            messages = messages.where((m) {
              return m.title.toLowerCase().contains(kw) ||
                  m.createrName.toLowerCase().contains(kw) ||
                  m.content.toLowerCase().contains(kw);
            }).toList();
          }

          // 限制条数
          if (messages.length > limit) {
            messages = messages.sublist(0, limit);
          }

          final formattedList = messages.map((m) {
            return {
              'uuid': m.uuid,
              'idCode': m.idCode,
              'title': m.title,
              'sender': m.createrName,
              'sendTime': m.sendTime,
              'isRead': m.isRead,
              'contentSnippet': m.content.length > 100 ? '${m.content.substring(0, 100)}...' : m.content,
            };
          }).toList();

          return McpToolResult.json({
            'totalCount': formattedList.length,
            'unreadOnly': unreadOnly,
            if (keyword != null) 'keyword': keyword,
            'notices': formattedList,
          });
        } catch (e) {
          return McpToolResult.error('查询通知失败: $e');
        }
      },
    );
  }
}
