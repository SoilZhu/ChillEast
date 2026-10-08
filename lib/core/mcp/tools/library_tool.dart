import 'package:intl/intl.dart';
import '../../../features/library/models/library_models.dart';
import '../../../features/library/models/library_book_models.dart';
import '../../../features/library/services/library_service.dart';
import '../../../features/library/services/library_book_service.dart';
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

/// MCP Tool: 快速预约图书馆座位 (quick_reserve_library_seat)
class LibraryQuickReserveTool {
  static const String toolName = 'quick_reserve_library_seat';

  static McpTool create({
    LibraryService? service,
    String toolName = toolName,
  }) {
    final libraryService = service ?? LibraryService();

    return McpTool(
      name: toolName,
      description:
          '快速预约图书馆座位（智能匹配空闲座位）。根据指定的时间段与位置偏好（楼层、阅览室）自动寻找可用座位并完成预约。'
          '【重要原则】：在正式执行预约之前，必须先向用户展示匹配到的座位方案（阅览室名称、座位号、预约日期与起止时段），'
          '征得用户明确同意确认后，传入 confirmed=true 方可真正提交预约。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'startTime': {
            'type': 'string',
            'description':
                '预约开始时间，格式为 HH:mm，如 "08:30" 或 "14:00"（可选。若不指定，自动按当前时间选用最近可约时段）。',
          },
          'endTime': {
            'type': 'string',
            'description':
                '预约结束时间，格式为 HH:mm，如 "12:00" 或 "18:00"（可选。若不指定，默认按开始时间后 1.5~2 小时计算）。',
          },
          'day': {
            'type': 'string',
            'description':
                '预约日期，格式为 YYYY-MM-DD（可选。默认选用今天，若今天已无可用时段则顺延至明天）。',
          },
          'floor': {
            'type': 'string',
            'description': '楼层偏好，如 "2楼"、"3楼"、"4楼"、"5楼"、"6楼"（可选）。',
          },
          'room': {
            'type': 'string',
            'description': '阅览室偏好，如 "301"、"自然科学图书阅览一区413"（可选）。',
          },
          'roomId': {
            'type': 'integer',
            'description': '阅览室房间 ID（可选。若在确认步骤中，请传入此前匹配到的 roomId）。',
          },
          'seatNum': {
            'type': 'string',
            'description': '座位编号，如 "042"（可选。若在确认步骤中，请传入此前匹配到的 seatNum）。',
          },
          'confirmed': {
            'type': 'boolean',
            'description':
                '用户是否已明确同意并确认预约。默认为 false。'
                '【极为重要】：首次调用时若用户尚未对具体匹配座位和时间明确同意，请保持 false。'
                '工具将实时匹配空闲座位并返回待确认详情；待用户明确回复同意后，再将 confirmed 设为 true 重新调用以真正完成提交。',
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
        final String? floor = (arguments['floor'] as String?)?.trim();
        final String? room = (arguments['room'] as String?)?.trim();
        final bool confirmed = arguments['confirmed'] as bool? ?? false;

        // 1. 确定预约日期
        final availableDays = LibraryTimeUtils.availableReserveDays();
        if (day == null || day.isEmpty) {
          day = availableDays.first;
          if (LibraryTimeUtils.availableStartSlots(day).isEmpty &&
              availableDays.length > 1) {
            day = availableDays[1];
          }
        }

        // 2. 校验并计算预约时间段
        final currentNow = DateTime.now();
        final isTimeValid = startTime != null &&
            endTime != null &&
            LibraryTimeUtils.isValidRange(day, startTime, endTime,
                now: currentNow);

        if (!isTimeValid) {
          if (startTime == null || startTime.isEmpty) {
            final defStart =
                LibraryTimeUtils.defaultStartTime(day, now: currentNow);
            if (defStart == null) {
              return McpToolResult.error('$day 已无可预约的时段，请选择其他日期。');
            }
            startTime = defStart;
          }
          if (endTime == null || endTime.isEmpty) {
            endTime = LibraryTimeUtils.defaultEndTime(startTime);
            if (endTime == null) {
              return McpToolResult.error('无法为 $startTime 生成有效结束时段');
            }
          }
        }

        // 3. 楼层与阅览室偏好规范化
        String secondLevel = '';
        if (floor != null && floor.isNotEmpty) {
          secondLevel = floor.replaceAll('层', '楼');
          const cnNumMap = {
            '一': '1',
            '二': '2',
            '两': '2',
            '三': '3',
            '四': '4',
            '五': '5',
            '六': '6',
            '七': '7',
          };
          cnNumMap.forEach((cn, digit) {
            secondLevel = secondLevel.replaceAll(cn, digit);
          });
          if (!secondLevel.contains('楼')) {
            secondLevel = '$secondLevel楼';
          }
        }

        final thirdLevel = room ?? '';
        final dayLabel = LibraryTimeUtils.formatDayLabel(day);

        // 4. 若未提供明确的座位编号与房间ID，先进行智能匹配
        LibraryMatchedSeatModel? matchedSeat;
        if (roomId == null || roomId <= 0 || seatNum == null || seatNum.isEmpty) {
          try {
            matchedSeat = await libraryService.matchSeat(
              startTime: startTime,
              endTime: endTime,
              firstLevelName: '图书馆',
              secondLevelName: secondLevel,
              thirdLevelName: thirdLevel,
            );
            roomId = matchedSeat.roomId;
            seatNum = matchedSeat.seatNum;
          } catch (e) {
            return McpToolResult.error('快速匹配座位失败: $e');
          }
        }

        // 5. 【核心控制】：若未获得用户明确确认，拦截提交并返回匹配详情供用户确认
        if (!confirmed) {
          final matchedRoomName = matchedSeat?.fullRoomName ?? '阅览室ID: $roomId';
          return McpToolResult.json({
            'status': 'requires_confirmation',
            'needsUserConsent': true,
            'message':
                '已为您快速匹配到空闲座位【$matchedRoomName】$seatNum号。'
                '【重要】：请必须向用户清晰呈现以下预约详情，并明确询问用户是否同意确认为其预约。'
                '只有用户明确回复同意/确认后，方可再次调用此工具并传入 confirmed: true 以及 roomId 和 seatNum。',
            'matchedSeat': {
              'roomId': roomId,
              'seatNum': seatNum,
              'roomName': matchedRoomName,
              'day': day,
              'dayLabel': dayLabel,
              'startTime': startTime,
              'endTime': endTime,
              'duration':
                  matchedSeat?.duration != null ? '${matchedSeat!.duration}h' : '',
            },
          });
        }

        // 6. 用户已明确确认，真正提交快速预约
        try {
          final result = await libraryService.submitQuickReservation(
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
            'message': '图书馆座位快速预约成功！',
            'reservation': {
              'id': result.id,
              'roomName': result.fullRoomName.isNotEmpty
                  ? result.fullRoomName
                  : '阅览室 $roomId',
              'roomId': result.roomId,
              'seatNum': result.seatNum,
              'day': day,
              'dayLabel': dayLabel,
              'startTime': startTime,
              'endTime': endTime,
            },
          });
        } catch (e) {
          return McpToolResult.error('提交快速预约失败: $e');
        }
      },
    );
  }
}

/// MCP Tool: 检索图书馆图书 (search_library_books)
class LibraryBookSearchTool {
  static const String toolName = 'search_library_books';

  static McpTool create({
    LibraryBookService? service,
    String toolName = toolName,
  }) {
    final bookService = service ?? LibraryBookService();

    return McpTool(
      name: toolName,
      description:
          '检索湖南农业大学图书馆馆藏图书。支持按题名(书名)、责任者(作者)、主题词、标准编码(ISBN)进行检索，返回匹配的图书列表、索书号、出版社、出版年、detailParam详情参数等。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'keyword': {
            'type': 'string',
            'description': '检索关键词，如书名、作者、主题或标准编码/ISBN。',
          },
          'searchType': {
            'type': 'string',
            'description':
                '检索方式。可选: "title"(题名/书名，默认), "author"(责任者/作者), "subject"(主题词), "Identifier"(标准编码/ISBN)。',
            'enum': ['title', 'author', 'subject', 'Identifier'],
            'default': 'title',
          },
        },
        'required': ['keyword'],
      },
      handler: (arguments) async {
        final keyword = (arguments['keyword'] as String?)?.trim() ?? '';
        if (keyword.isEmpty) {
          return McpToolResult.error('请提供有效的检索关键词');
        }

        final searchType = (arguments['searchType'] as String?)?.trim() ?? 'title';

        try {
          final result = await bookService.searchBooks(
            keyword: keyword,
            searchType: searchType,
          );

          return McpToolResult.json({
            'keyword': keyword,
            'searchType': searchType,
            'totalCount': result.totalCount,
            'totalPages': result.totalPages,
            'bookCount': result.books.length,
            'books': result.books.map((b) => {
              'title': b.title,
              'author': b.author,
              'callNumber': b.callNumber,
              'publisher': b.publisher,
              'publishYear': b.publishYear,
              'isbn': b.isbn,
              'detailParam': b.detailParam,
            }).toList(),
          });
        } catch (e) {
          return McpToolResult.error('检索图书馆图书失败: $e');
        }
      },
    );
  }
}

/// MCP Tool: 查询图书馆图书详情与馆藏信息 (query_library_book_detail)
class LibraryBookDetailTool {
  static const String toolName = 'query_library_book_detail';

  static McpTool create({
    LibraryBookService? service,
    String toolName = toolName,
  }) {
    final bookService = service ?? LibraryBookService();

    return McpTool(
      name: toolName,
      description:
          '查询图书馆具体图书的完整书目详情与馆藏副本分布信息（包括题名/责任者、索书号、出版项、载体形态、各个校区/馆藏地点的馆藏副本条码、单册类型、状态及是否在库）。'
          '支持直接传入 detailParam，或者传入 title/keyword 自动检索后提取详情。',
      inputSchema: {
        'type': 'object',
        'properties': {
          'detailParam': {
            'type': 'string',
            'description':
                '图书详情参数字符串（如 "{\\"marc_no\\":\\"zyk0161024\\"}"，由 search_library_books 搜索结果中的 detailParam 字段提供）。若未指定，需提供 title 或 keyword。',
          },
          'title': {
            'type': 'string',
            'description': '图书书名/题名（可选。若未提供 detailParam，系统将按此书名检索并查询首条图书详情）。',
          },
          'author': {
            'type': 'string',
            'description': '作者/责任者（可选）。',
          },
          'publisher': {
            'type': 'string',
            'description': '出版社（可选）。',
          },
          'callNumber': {
            'type': 'string',
            'description': '索书号（可选）。',
          },
        },
      },
      handler: (arguments) async {
        String detailParam = (arguments['detailParam'] as String?)?.trim() ?? '';
        String title = (arguments['title'] as String?)?.trim() ?? '';
        String author = (arguments['author'] as String?)?.trim() ?? '';
        String publisher = (arguments['publisher'] as String?)?.trim() ?? '';
        String callNumber = (arguments['callNumber'] as String?)?.trim() ?? '';

        try {
          // 若未直接传入 detailParam，但提供了 title，先进行检索获取首本图书的 detailParam
          if (detailParam.isEmpty) {
            final query = title.isNotEmpty
                ? title
                : ((arguments['keyword'] as String?)?.trim() ?? '');
            if (query.isEmpty) {
              return McpToolResult.error('请提供 detailParam 或书名 title 以查询图书详情');
            }

            final searchResult = await bookService.searchBooks(
              keyword: query,
              searchType: 'title',
            );
            if (searchResult.books.isEmpty) {
              return McpToolResult.error('未在图书馆检索到与 "$query" 匹配的图书');
            }

            final firstBook = searchResult.books.first;
            detailParam = firstBook.detailParam;
            if (title.isEmpty) title = firstBook.title;
            if (author.isEmpty) author = firstBook.author;
            if (publisher.isEmpty) publisher = firstBook.publisher;
            if (callNumber.isEmpty) callNumber = firstBook.callNumber;
          }

          final book = LibraryBook(
            detailParam: detailParam,
            title: title,
            author: author,
            publisher: publisher,
            callNumber: callNumber,
          );

          final detail = await bookService.fetchBookDetail(book);

          return McpToolResult.json({
            'title': detail.title,
            'author': detail.author,
            'callNumber': detail.callNumber,
            'subject': detail.subject,
            'isbn': detail.isbn,
            'price': detail.price,
            'publishInfo': detail.publishInfo,
            'physicalDesc': detail.physicalDesc,
            'series': detail.series,
            'summary': detail.summary,
            'catalogItems': detail.effectiveCatalogItems.map((e) => {
              'label': e.key,
              'value': e.value,
            }).toList(),
            'totalHoldings': detail.totalCount,
            'availableHoldings': detail.availableCount,
            'holdings': detail.holdings.map((h) => {
              'barcode': h.barcode,
              'accessionNo': h.accessionNo,
              'copyType': h.copyType,
              'status': h.status,
              'price': h.price,
              'holdingUnit': h.holdingUnit,
              'location': h.location,
              'isAvailable': h.isAvailable,
            }).toList(),
          });
        } catch (e) {
          return McpToolResult.error('查询图书详情失败: $e');
        }
      },
    );
  }
}

