import '../../../features/workspace/services/electricity_service.dart';
import '../models/mcp_tool.dart';

/// MCP Tool: 电费充值与查询 (recharge_electricity)
class ElectricityTool {
  static const String toolName = 'recharge_electricity';

  static McpTool create({
    ElectricityService? service,
  }) {
    return McpTool(
      name: toolName,
      description:
          '湖南农业大学宿舍电费充值与电费余额查询工具。支持从校园卡扣款进行电费在线充值（操作类型 recharge），以及查询指定宿舍房间的电费剩余度数/金额（query_balance），并支持获取校区、楼栋、房间列表。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'action': {
            'type': 'string',
            'enum': ['recharge', 'query_balance', 'get_areas', 'get_buildings', 'get_rooms'],
            'description': '操作类型：recharge(宿舍电费充值, 默认), query_balance(查询宿舍电费余额), get_areas(获取校区列表), get_buildings(获取楼栋列表), get_rooms(获取房间列表)。',
            'default': 'recharge',
          },
          'areaName': {
            'type': 'string',
            'description': '校区名称（例如“东湖校区”或由 get_areas 获取的校区）。充值或查询余额时必填。',
          },
          'buildingName': {
            'type': 'string',
            'description': '楼栋名称（例如“丰泽学生公寓1栋”、“东湖公寓2栋”等）。充值或查询余额时必填。',
          },
          'roomId': {
            'type': 'string',
            'description': '房间号或房间ID（例如“101”、“203”等）。充值或查询余额时必填。',
          },
          'mertype': {
            'type': 'string',
            'description': '电表类型代码（例如“yk”预付费表或“rt”实时表），通常通过 get_rooms 获得，默认为“yk”。',
            'default': 'yk',
          },
          'amount': {
            'type': 'number',
            'description': '充值金额（单位：元，必须为正数，如 10, 20, 50, 100）。执行充值 action=recharge 时必填。',
            'minimum': 1,
          },
        },
      },
      handler: (arguments) async {
        if (service == null) {
          return McpToolResult.error('未提供 ElectricityService 实例');
        }

        final action = arguments['action'] as String? ?? 'recharge';
        final areaName = arguments['areaName'] as String?;
        final buildingName = arguments['buildingName'] as String?;
        final roomId = arguments['roomId'] as String?;
        final mertype = arguments['mertype'] as String? ?? 'yk';
        final amountNum = arguments['amount'] as num?;

        try {
          switch (action) {
            case 'get_areas':
              final areas = await service.getAreas();
              return McpToolResult.json({
                'areas': areas.map((a) => {'id': a.id, 'name': a.name}).toList(),
              });

            case 'get_buildings':
              if (areaName == null || areaName.trim().isEmpty) {
                return McpToolResult.error('获取楼栋列表需要提供 areaName (校区名称)');
              }
              final buildings = await service.getBuildings(areaName);
              return McpToolResult.json({
                'areaName': areaName,
                'buildings': buildings.map((b) => {'id': b.id, 'name': b.name}).toList(),
              });

            case 'get_rooms':
              if (areaName == null || areaName.trim().isEmpty ||
                  buildingName == null || buildingName.trim().isEmpty) {
                return McpToolResult.error('获取房间列表需要提供 areaName 和 buildingName');
              }
              final rooms = await service.getRooms(areaName, buildingName);
              return McpToolResult.json({
                'areaName': areaName,
                'buildingName': buildingName,
                'rooms': rooms.map((r) => {'id': r.id, 'name': r.name, 'mertype': r.mertype}).toList(),
              });

            case 'query_balance':
              if (areaName == null || areaName.trim().isEmpty ||
                  buildingName == null || buildingName.trim().isEmpty ||
                  roomId == null || roomId.trim().isEmpty) {
                return McpToolResult.error('查询电费余额需要提供 areaName、buildingName 和 roomId');
              }
              final balanceInfo = await service.getBalance(
                areaName: areaName,
                buildingName: buildingName,
                roomId: roomId,
                mertype: mertype,
              );
              return McpToolResult.json({
                'areaName': areaName,
                'buildingName': buildingName,
                'roomId': roomId,
                'balance': balanceInfo.balance,
                'detail': balanceInfo.detail,
                'unit': '元/度',
                'status': 'success',
              });

            case 'recharge':
            default:
              if (areaName == null || areaName.trim().isEmpty ||
                  buildingName == null || buildingName.trim().isEmpty ||
                  roomId == null || roomId.trim().isEmpty) {
                return McpToolResult.error('执行电费充值需要提供 areaName、buildingName 和 roomId');
              }
              if (amountNum == null || amountNum <= 0) {
                return McpToolResult.error('充值金额必须大于 0 元');
              }

              final success = await service.recharge(
                areaName: areaName,
                buildingName: buildingName,
                roomId: roomId,
                mertype: mertype,
                amount: amountNum.toDouble(),
              );

              return McpToolResult.json({
                'success': success,
                'message': success ? '电费充值成功' : '电费充值失败，请检查卡内余额或稍后重试',
                'areaName': areaName,
                'buildingName': buildingName,
                'roomId': roomId,
                'amount': amountNum,
                'unit': '元',
              });
          }
        } catch (e) {
          return McpToolResult.error('电费操作失败 ($action): $e');
        }
      },
    );
  }
}
