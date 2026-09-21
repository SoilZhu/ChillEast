import '../../../features/workspace/models/electricity_model.dart';
import '../../../features/workspace/services/electricity_service.dart';
import '../models/mcp_tool.dart';

/// MCP Tool: 电费充值与查询 (recharge_electricity)
class ElectricityTool {
  static const String toolName = 'recharge_electricity';

  /// 解析房间，确保 targetRoomId 是服务端需要的 ID (可能为32位Hash)，
  /// 并解析出人类可读的友好房间名 (如 "302")
  static Future<({String roomId, String roomName, String mertype})> _resolveRoom({
    required ElectricityService service,
    required String areaName,
    required String buildingName,
    required String inputRoomId,
    String? inputRoomName,
    String fallbackMertype = 'yk',
    SavedElectricityRoom? saved,
  }) async {
    String resolvedId = inputRoomId;
    String resolvedName = inputRoomName ?? '';
    String resolvedMertype = fallbackMertype;

    // 如果已有保存的房间且 ID 匹配且有非哈希的友好名称
    if (saved != null &&
        saved.roomId == inputRoomId &&
        saved.roomName.isNotEmpty &&
        !RegExp(r'^[A-Fa-f0-9]{32}$').hasMatch(saved.roomName)) {
      resolvedName = saved.roomName;
    }

    try {
      final rooms = await service.getRooms(areaName, buildingName);
      if (rooms.isNotEmpty) {
        // 1. 精确匹配 ID
        var matched = rooms.where((r) => r.id == inputRoomId).firstOrNull;
        // 2. 若无，匹配名称或模糊匹配（比如用户传入了 "302"）
        matched ??= rooms.where((r) => r.name == inputRoomId || r.name.contains(inputRoomId)).firstOrNull;
        // 3. 匹配 inputRoomName
        if (matched == null && inputRoomName != null && inputRoomName.isNotEmpty) {
          matched = rooms.where((r) => r.name == inputRoomName || r.name.contains(inputRoomName)).firstOrNull;
        }

        if (matched != null) {
          resolvedId = matched.id;
          resolvedName = matched.name;
          resolvedMertype = matched.mertype;

          // 如果持久化记录中的名称是空或哈希，自动自愈更新
          if (saved != null &&
              saved.roomId == matched.id &&
              (saved.roomName.isEmpty ||
                  saved.roomName == saved.roomId ||
                  RegExp(r'^[A-Fa-f0-9]{32}$').hasMatch(saved.roomName))) {
            await service.saveSavedRoom(
              SavedElectricityRoom(
                areaName: areaName,
                buildingName: buildingName,
                roomId: matched.id,
                roomName: matched.name,
                mertype: matched.mertype,
              ),
            );
          }
        }
      }
    } catch (_) {}

    if (resolvedName.isEmpty || RegExp(r'^[A-Fa-f0-9]{32}$').hasMatch(resolvedName)) {
      resolvedName = (inputRoomName != null && inputRoomName.isNotEmpty) ? inputRoomName : inputRoomId;
    }

    return (roomId: resolvedId, roomName: resolvedName, mertype: resolvedMertype);
  }

  static McpTool create({
    ElectricityService? service,
    String? toolName,
  }) {
    final effectiveToolName = toolName ?? ElectricityTool.toolName;
    return McpTool(
      name: effectiveToolName,
      description:
          '湖南农业大学宿舍电费余额查询与在线充值工具。支持查询指定宿舍房间的电费剩余金额（query_balance, 默认），以及从校园卡扣款执行在线充值（recharge），并支持获取校区、楼栋、房间列表。若未指定 areaName、buildingName、roomId，则默认自动使用用户已保存的宿舍。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'action': {
            'type': 'string',
            'enum': ['query_balance', 'recharge', 'get_areas', 'get_buildings', 'get_rooms'],
            'description': '操作类型：query_balance(查询宿舍电费余额, 默认), recharge(宿舍电费在线充值), get_areas(获取校区列表), get_buildings(获取楼栋列表), get_rooms(获取房间列表)。',
            'default': 'query_balance',
          },
          'areaName': {
            'type': 'string',
            'description': '校区或公寓名称（例如“金岸公寓空调”、“东湖公寓照明”或通过 get_areas 获取）。如未提供则默认使用已保存的宿舍校区。',
          },
          'buildingName': {
            'type': 'string',
            'description': '楼栋名称（例如“金岸1栋”、“东湖公寓2栋”等）。如未提供则默认使用已保存的宿舍楼栋。',
          },
          'roomId': {
            'type': 'string',
            'description': '房间号或房间ID（例如“101”、“302”或房间哈希ID）。如未提供则默认使用已保存的宿舍房间。',
          },
          'roomName': {
            'type': 'string',
            'description': '友好房间展示名称（例如“302室”）。若未指定，系统会自动匹配并解析真实房间号。',
          },
          'mertype': {
            'type': 'string',
            'description': '电表类型代码（例如“yk”预付费表或“rt”实时表），默认为已保存的宿舍表类型或“yk”。',
            'default': 'yk',
          },
          'amount': {
            'type': 'number',
            'description': '充值金额（单位：元，如 10, 20, 50, 100）。执行充值 action=recharge 时必填。',
            'minimum': 1,
          },
        },
      },
      handler: (arguments) async {
        if (service == null) {
          return McpToolResult.error('未提供 ElectricityService 实例');
        }

        final action = arguments['action'] as String? ?? 'query_balance';
        final areaName = arguments['areaName'] as String?;
        final buildingName = arguments['buildingName'] as String?;
        final roomId = arguments['roomId'] as String?;
        final roomName = arguments['roomName'] as String?;
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
              var targetArea = areaName;
              var targetBuilding = buildingName;
              var targetRoomId = roomId;
              var targetRoomName = roomName;
              var targetMertype = mertype;

              final saved = await service.getSavedRoom();
              if (targetArea == null || targetArea.trim().isEmpty ||
                  targetBuilding == null || targetBuilding.trim().isEmpty ||
                  targetRoomId == null || targetRoomId.trim().isEmpty) {
                if (saved != null) {
                  targetArea ??= saved.areaName.isNotEmpty ? saved.areaName : null;
                  targetBuilding ??= saved.buildingName.isNotEmpty ? saved.buildingName : null;
                  if (targetRoomId == null || targetRoomId.trim().isEmpty) {
                    targetRoomId = saved.roomId.isNotEmpty ? saved.roomId : null;
                    targetRoomName = saved.roomName.isNotEmpty ? saved.roomName : null;
                  }
                  if (arguments['mertype'] == null && saved.mertype.isNotEmpty) {
                    targetMertype = saved.mertype;
                  }
                }
              }

              if (targetArea == null || targetArea.trim().isEmpty ||
                  targetBuilding == null || targetBuilding.trim().isEmpty ||
                  targetRoomId == null || targetRoomId.trim().isEmpty) {
                return McpToolResult.error('查询电费余额需要提供 areaName、buildingName 和 roomId，或先在电费充值页面选择宿舍');
              }

              // 解析友好房间名与真实ID
              final resolved = await _resolveRoom(
                service: service,
                areaName: targetArea,
                buildingName: targetBuilding,
                inputRoomId: targetRoomId,
                inputRoomName: targetRoomName,
                fallbackMertype: targetMertype,
                saved: saved,
              );
              targetRoomId = resolved.roomId;
              targetRoomName = resolved.roomName;
              targetMertype = resolved.mertype;

              final balanceInfo = await service.getBalance(
                areaName: targetArea,
                buildingName: targetBuilding,
                roomId: targetRoomId,
                mertype: targetMertype,
              );

              // 检查电表状态是否异常 (elestatus == 1 表示正常)
              if (balanceInfo.elestatus != null && balanceInfo.elestatus != 1) {
                return McpToolResult.error('电表状态异常 (状态码: ${balanceInfo.elestatus})，请稍后重试');
              }

              // 如果 targetRoomName 依然为空或是 32 位哈希，尝试从 accname (如 "XS-JA-1-629(学生公寓空调.金岸1栋.629)") 提取纯房号 (如 "629")
              if (targetRoomName.isEmpty || RegExp(r'^[A-Fa-f0-9]{32}$').hasMatch(targetRoomName)) {
                final accname = balanceInfo.accname ?? '';
                final match1 = RegExp(r'\.([^.)]+)\)').firstMatch(accname);
                final match2 = RegExp(r'-([0-9A-Za-z]+)\(').firstMatch(accname);
                final extracted = match1?.group(1)?.trim() ?? match2?.group(1)?.trim();
                if (extracted != null && extracted.isNotEmpty) {
                  targetRoomName = extracted;
                  if (saved != null) {
                    await service.saveSavedRoom(
                      SavedElectricityRoom(
                        areaName: targetArea,
                        buildingName: targetBuilding,
                        roomId: targetRoomId,
                        roomName: extracted,
                        mertype: targetMertype,
                      ),
                    );
                  }
                }
              }

              final displayRoomName = (targetRoomName.isNotEmpty && !RegExp(r'^[A-Fa-f0-9]{32}$').hasMatch(targetRoomName))
                  ? targetRoomName
                  : (targetRoomId.isNotEmpty && !RegExp(r'^[A-Fa-f0-9]{32}$').hasMatch(targetRoomId) ? targetRoomId : '所选宿舍');
              final locationStr = '$targetArea - $targetBuilding - $displayRoomName';

              return McpToolResult.json({
                'location': locationStr,
                'areaName': targetArea,
                'buildingName': targetBuilding,
                'roomName': displayRoomName,
                'balance': balanceInfo.balance,
                'balanceYuan': '${balanceInfo.balance} 元',
                'accountName': balanceInfo.accname,
                'detail': balanceInfo.detail,
                'unit': '元',
                'status': 'success',
                'tip': '如需充值电费，请告诉我金额（支持 10-100 元）。充值将从校园卡中划扣。',
              });

            case 'recharge':
            default:
              var targetArea = areaName;
              var targetBuilding = buildingName;
              var targetRoomId = roomId;
              var targetRoomName = roomName;
              var targetMertype = mertype;

              final saved = await service.getSavedRoom();
              if (targetArea == null || targetArea.trim().isEmpty ||
                  targetBuilding == null || targetBuilding.trim().isEmpty ||
                  targetRoomId == null || targetRoomId.trim().isEmpty) {
                if (saved != null) {
                  targetArea ??= saved.areaName.isNotEmpty ? saved.areaName : null;
                  targetBuilding ??= saved.buildingName.isNotEmpty ? saved.buildingName : null;
                  if (targetRoomId == null || targetRoomId.trim().isEmpty) {
                    targetRoomId = saved.roomId.isNotEmpty ? saved.roomId : null;
                    targetRoomName = saved.roomName.isNotEmpty ? saved.roomName : null;
                  }
                  if (arguments['mertype'] == null && saved.mertype.isNotEmpty) {
                    targetMertype = saved.mertype;
                  }
                }
              }

              if (targetArea == null || targetArea.trim().isEmpty ||
                  targetBuilding == null || targetBuilding.trim().isEmpty ||
                  targetRoomId == null || targetRoomId.trim().isEmpty) {
                return McpToolResult.error('执行电费充值需要提供 areaName、buildingName 和 roomId，或先在电费充值页面选择宿舍');
              }
              if (amountNum == null || amountNum <= 0) {
                return McpToolResult.error('充值金额必须大于 0 元');
              }

              // 解析友好房间名与真实ID
              final resolved = await _resolveRoom(
                service: service,
                areaName: targetArea,
                buildingName: targetBuilding,
                inputRoomId: targetRoomId,
                inputRoomName: targetRoomName,
                fallbackMertype: targetMertype,
                saved: saved,
              );
              targetRoomId = resolved.roomId;
              targetRoomName = resolved.roomName;
              targetMertype = resolved.mertype;

              final displayRoomName = (targetRoomName.isNotEmpty && !RegExp(r'^[A-Fa-f0-9]{32}$').hasMatch(targetRoomName))
                  ? targetRoomName
                  : (targetRoomId.isNotEmpty && !RegExp(r'^[A-Fa-f0-9]{32}$').hasMatch(targetRoomId) ? targetRoomId : '所选宿舍');
              final locationStr = '$targetArea - $targetBuilding - $displayRoomName';

              final success = await service.recharge(
                areaName: targetArea,
                buildingName: targetBuilding,
                roomId: targetRoomId,
                roomName: targetRoomName,
                mertype: targetMertype,
                amount: amountNum.toDouble(),
              );

              return McpToolResult.json({
                'success': success,
                'message': success ? '电费充值成功' : '电费充值失败，请检查卡内余额或稍后重试',
                'location': locationStr,
                'areaName': targetArea,
                'buildingName': targetBuilding,
                'roomName': displayRoomName,
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

