import 'package:intl/intl.dart';
import '../../../features/library/models/library_models.dart';
import '../../../features/library/services/library_service.dart';
import '../../../features/library/services/library_storage.dart';
import '../../../features/library/utils/library_time_utils.dart';
import '../models/mcp_tool.dart';

/// MCP Tool: 查询图书馆上次预约座位 (query_library_last_seat)
class LibraryLastSeatQueryTool {
  static const String toolName = 'query_library_last_seat';

  static McpTool create({LibraryService? service}) {
    final libraryService = service ?? LibraryService();

    return McpTool(
      name: toolName,
      description: '查询用户在图书馆最近或上一次预约的座位记录（包括阅览室名称、房间ID、座位编号、起止时段等）。',
      inputSchema: {
        'type': 'object',
        'properties': {},
      },
      handler: (arguments) async {
        LibraryReserveModel? lastReserve;
        try {
          final indexData = await libraryService.fetchIndexData();
          if (indexData.curReserves.isNotEmpty) {
            lastReserve = indexData.curReserves.first;
          } else if (indexData.nearReserves.isNotEmpty) {
            lastReserve = indexData.nearReserves.first;
          }
        } catch (_) {
          final cached = await LibraryStorage.getCachedReserves();
          if (cached.isNotEmpty) {
            lastReserve = cached.first;
          }
        }

        if (lastReserve == null) {
          final cached = await LibraryStorage.getCachedReserves();
          if (cached.isNotEmpty) {
            lastReserve = cached.first;
          }
        }

        if (lastReserve == null) {
          return McpToolResult.json({
            'found': false,
            'message': '未找到用户过往的图书馆预约记录。',
          });
        }

        final timeFormat = DateFormat('HH:mm');
        final startTimeStr = timeFormat.format(lastReserve.startTime);
        final endTimeStr = timeFormat.format(lastReserve.endTime);

        final availableDays = LibraryTimeUtils.availableReserveDays();
        String recommendDay = availableDays.first;
        if (LibraryTimeUtils.availableStartSlots(recommendDay).isEmpty && availableDays.length > 1) {
          recommendDay = availableDays[1];
        }

        return McpToolResult.json({
          'found': true,
          'roomId': lastReserve.roomId,
          'roomName': lastReserve.fullRoomName,
          'seatNum': lastReserve.seatNum,
          'lastDay': lastReserve.today,
          'lastStartTime': startTimeStr,
          'lastEndTime': endTimeStr,
          'recommendedDay': recommendDay,
          'recommendedDayLabel': LibraryTimeUtils.formatDayLabel(recommendDay),
        });
      },
    );
  }
}

/// MCP Tool: 预约图书馆座位 (reserve_library_seat)
class LibraryReserveTool {
  static const String toolName = 'reserve_library_seat';

  static McpTool create({LibraryService? service}) {
    final libraryService = service ?? LibraryService();

    return McpTool(
      name: toolName,
      description:
          '预约图书馆阅览室座位。如果没有指定座位和房间，系统将默认采用用户上一次预约的历史座位。'
          '【重要】：在正式执行预约之前，必须先向用户展示预约方案（阅览室名称、座位号、预约日期与起止时间），'
          '征得用户明确同意确认后，传入 confirmed=true 方可真正提交预约。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'roomId': {
            'type': 'integer',
            'description': '阅览室房间 ID（可选。若不指定，将默认自动使用上次预约的阅览室）。',
          },
          'seatNum': {
            'type': 'string',
            'description': '座位编号，如 "034" 或 "052"（可选。若不指定，将默认自动使用上次预约的座位编号）。',
          },
          'day': {
            'type': 'string',
            'description': '预约日期，格式为 YYYY-MM-DD（可选。默认自动选用今天或明天最近可约日期）。',
          },
          'startTime': {
            'type': 'string',
            'description': '开始时间，格式为 HH:mm，如 "08:30" 或 "14:00"（可选。若不指定，优先沿用上次预约时段或推荐时段）。',
          },
          'endTime': {
            'type': 'string',
            'description': '结束时间，格式为 HH:mm，如 "12:00" 或 "18:00"（可选。若不指定，优先沿用上次预约时段或推荐时段）。',
          },
          'confirmed': {
            'type': 'boolean',
            'description':
                '用户是否已明确同意并确认预约。默认为 false。'
                '【极为重要】：首次调用时若用户尚未对具体座位和时间进行明确确认，请保持 false。'
                '工具将返回待确认的预约详情；待用户明确回复同意后，再将 confirmed 设为 true 重新调用以真正完成提交。',
            'default': false,
          },
        },
      },
      handler: (arguments) async {
        int? roomId = arguments['roomId'] is int
            ? arguments['roomId'] as int
            : int.tryParse(arguments['roomId']?.toString() ?? '');
        String? seatNum = (arguments['seatNum'] as String?)?.trim();
        String? day = (arguments['day'] as String?)?.trim();
        String? startTime = (arguments['startTime'] as String?)?.trim();
        String? endTime = (arguments['endTime'] as String?)?.trim();
        final bool confirmed = arguments['confirmed'] as bool? ?? false;

        bool isDefaultedFromLastSeat = false;
        String roomName = '';

        // 1. 如果没有指定 roomId 或 seatNum，回退到上次历史座位
        if (roomId == null || roomId <= 0 || seatNum == null || seatNum.isEmpty) {
          LibraryReserveModel? lastReserve;
          try {
            final indexData = await libraryService.fetchIndexData();
            if (indexData.curReserves.isNotEmpty) {
              lastReserve = indexData.curReserves.first;
            } else if (indexData.nearReserves.isNotEmpty) {
              lastReserve = indexData.nearReserves.first;
            }
          } catch (_) {
            final cached = await LibraryStorage.getCachedReserves();
            if (cached.isNotEmpty) {
              lastReserve = cached.first;
            }
          }

          if (lastReserve == null) {
            final cached = await LibraryStorage.getCachedReserves();
            if (cached.isNotEmpty) {
              lastReserve = cached.first;
            }
          }

          if (lastReserve != null) {
            roomId ??= lastReserve.roomId;
            seatNum ??= lastReserve.seatNum;
            roomName = lastReserve.fullRoomName;
            isDefaultedFromLastSeat = true;

            // 若未指定时间，优先沿用历史时段
            final timeFormat = DateFormat('HH:mm');
            startTime ??= timeFormat.format(lastReserve.startTime);
            endTime ??= timeFormat.format(lastReserve.endTime);
          } else {
            return McpToolResult.error('未找到您上次预约的历史座位记录，请指定要预约的阅览室与座位号。');
          }
        }

        // 2. 确定预约日期
        final availableDays = LibraryTimeUtils.availableReserveDays();
        if (day == null || day.isEmpty) {
          day = availableDays.first;
          // 若今天已无可约开始时段且明天可选，则自动切换到明天
          if (LibraryTimeUtils.availableStartSlots(day).isEmpty && availableDays.length > 1) {
            day = availableDays[1];
          }
        }

        // 3. 校验并计算预约时间段
        final currentNow = DateTime.now();
        final isTimeValid = startTime != null &&
            endTime != null &&
            LibraryTimeUtils.isValidRange(day, startTime, endTime, now: currentNow);

        if (!isTimeValid) {
          final defStart = LibraryTimeUtils.defaultStartTime(day, now: currentNow);
          if (defStart == null) {
            return McpToolResult.error('$day 已无可预约的时段，请选择其他日期。');
          }
          startTime = defStart;
          endTime = LibraryTimeUtils.defaultEndTime(startTime);
          if (endTime == null) {
            return McpToolResult.error('无法为 $startTime 生成有效结束时段');
          }
        }

        final dayLabel = LibraryTimeUtils.formatDayLabel(day);

        // 4. 【核心控制】：若未获得用户明确确认，拦截提交并返回预约详情
        if (!confirmed) {
          return McpToolResult.json({
            'status': 'requires_confirmation',
            'needsUserConsent': true,
            'message':
                '已为您准备好座位预约方案${isDefaultedFromLastSeat ? "（未指定座位，已默认采用您上次的座位）" : ""}。'
                '【重要】：请必须向用户清晰呈现以下预约详情，并明确询问用户是否同意确认为其预约。'
                '只有用户明确回复同意/确认后，方可再次调用此工具并传入 confirmed: true。',
            'pendingReservation': {
              'roomName': roomName.isNotEmpty ? roomName : '阅览室ID: $roomId',
              'roomId': roomId,
              'seatNum': seatNum,
              'day': day,
              'dayLabel': dayLabel,
              'startTime': startTime,
              'endTime': endTime,
              'isDefaultedFromLastSeat': isDefaultedFromLastSeat,
            },
          });
        }

        // 5. 用户已确认，真正执行提交
        try {
          final result = await libraryService.submitReservation(
            roomId: roomId,
            seatNum: seatNum,
            day: day,
            startTime: startTime,
            endTime: endTime,
          );

          // 更新本地缓存
          final cached = await LibraryStorage.getCachedReserves();
          final updated = [result, ...cached.where((r) => r.id != result.id)];
          await LibraryStorage.saveReserves(updated);

          return McpToolResult.json({
            'status': 'success',
            'message': '图书馆座位预约成功！',
            'reservation': {
              'id': result.id,
              'roomName': result.fullRoomName.isNotEmpty ? result.fullRoomName : roomName,
              'roomId': result.roomId,
              'seatNum': result.seatNum,
              'day': day,
              'dayLabel': dayLabel,
              'startTime': startTime,
              'endTime': endTime,
            },
          });
        } catch (e) {
          return McpToolResult.error('提交图书馆座位预约失败: $e');
        }
      },
    );
  }
}
