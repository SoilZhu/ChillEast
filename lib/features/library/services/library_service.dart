import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import '../../../core/network/dio_client.dart';
import '../../../core/network/cookie_manager.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../models/library_models.dart';

class LibraryService {
  final _logger = AppLogger.instance;
  static const String deptIdEnc = '4dc85b11270eab26';
  static const String officeBase = 'https://office.chaoxing.com';

  Dio get _dio => DioClient().dio;
  bool _hasInitializedSession = false;

  /// 确保 Cookie 已经同步/回流，并访问第三方入口完成凭证置换
  Future<void> _ensureCookies({bool forceInit = false}) async {
    await AppCookieManager().injectAllChaoxingCookies();
    if (!_hasInitializedSession || forceInit) {
      try {
        _logger.i('🔑 Initializing seat session via third entrance...');
        await _dio.get(
          '$officeBase/front/third/apps/seat/index?fidEnc=$deptIdEnc',
          options: Options(
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 15; Pixel 9) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Mobile Safari/537.36',
            },
          ),
        );
        _hasInitializedSession = true;
      } catch (e) {
        _logger.w('⚠️ Third entrance init warning: $e');
      }
    }
  }

  /// 安全解析 Map 结构，兼容 String / dynamic
  Map<String, dynamic> _parseResponseMap(dynamic raw,
      [String defaultError = '获取数据失败']) {
    if (raw == null) {
      throw AppException(defaultError);
    }
    Map<String, dynamic>? map;
    if (raw is Map<String, dynamic>) {
      map = raw;
    } else if (raw is Map) {
      map = raw.cast<String, dynamic>();
    } else if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is Map<String, dynamic>) {
            map = decoded;
          } else if (decoded is Map) {
            map = decoded.cast<String, dynamic>();
          }
        } catch (_) {}
      }
      if (map == null) {
        if (trimmed.contains('<html') || trimmed.contains('<!DOCTYPE html>')) {
          throw const AppException('登录会话已过期，请尝试重新登录');
        }
        throw AppException('$defaultError: $trimmed');
      }
    } else {
      throw AppException(defaultError);
    }

    if (map['success'] != true) {
      final msg =
          map['msg']?.toString() ?? map['message']?.toString() ?? defaultError;
      throw AppException(msg);
    }

    return map;
  }

  /// 获取图书馆首页数据（当前预约、历史预约、系统规则）
  Future<LibraryIndexData> fetchIndexData() async {
    await _ensureCookies();
    final url =
        '$officeBase/data/apps/seat/index?fidEnc=$deptIdEnc&r=${DateTime.now().millisecondsSinceEpoch}';
    _logger.i('📚 Fetching Library Index data...');

    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'Referer':
                '$officeBase/front/third/apps/seat/index?fidEnc=$deptIdEnc',
            'X-Requested-With': 'XMLHttpRequest',
          },
        ),
      );

      if (response.statusCode != 200) {
        throw NetworkException('获取图书馆首页数据失败: HTTP ${response.statusCode}');
      }

      final jsonMap = _parseResponseMap(response.data, '获取图书馆数据失败');
      final resData = jsonMap['data'] is Map
          ? (jsonMap['data'] as Map).cast<String, dynamic>()
          : <String, dynamic>{};

      LibrarySeatConfig? config;
      if (resData['seatConfig'] != null && resData['seatConfig'] is Map) {
        config = LibrarySeatConfig.fromJson(
            (resData['seatConfig'] as Map).cast<String, dynamic>());
      }

      final curReservesRaw = resData['curReserves'] as List<dynamic>? ?? [];
      final nearReservesRaw = resData['nearReserves'] as List<dynamic>? ?? [];

      final curReserves = curReservesRaw
          .whereType<Map>()
          .map((e) => LibraryReserveModel.fromJson(e.cast<String, dynamic>()))
          .toList();
      final nearReserves = nearReservesRaw
          .whereType<Map>()
          .map((e) => LibraryReserveModel.fromJson(e.cast<String, dynamic>()))
          .toList();

      return LibraryIndexData(
        config: config,
        curReserves: curReserves,
        nearReserves: nearReserves,
      );
    } catch (e) {
      _logger.e('❌ fetchIndexData error: $e');
      rethrow;
    }
  }

  /// 查询指定日期的阅览室列表
  Future<List<LibraryRoomModel>> fetchRoomList({required String day}) async {
    await _ensureCookies();
    final url =
        '$officeBase/data/apps/seat/room/list?time=&cpage=1&pageSize=100&firstLevelName=&secondLevelName=&thirdLevelName=&day=$day&deptIdEnc=$deptIdEnc';
    _logger.i('📚 Fetching Library Rooms for day=$day...');

    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'Referer':
                '$officeBase/front/third/apps/seat/list?deptIdEnc=$deptIdEnc',
            'X-Requested-With': 'XMLHttpRequest',
          },
        ),
      );

      if (response.statusCode != 200) {
        throw NetworkException('获取阅览室列表失败: HTTP ${response.statusCode}');
      }

      final jsonMap = _parseResponseMap(response.data, '获取阅览室列表失败');
      final resData = jsonMap['data'] is Map
          ? (jsonMap['data'] as Map).cast<String, dynamic>()
          : <String, dynamic>{};

      final roomListRaw = resData['seatRoomList'] as List<dynamic>? ?? [];
      return roomListRaw
          .whereType<Map>()
          .map((e) => LibraryRoomModel.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (e) {
      _logger.e('❌ fetchRoomList error: $e');
      rethrow;
    }
  }

  /// 检查阅览室预约窗口状态
  Future<Map<String, dynamic>> checkReserveWindow({
    required int roomId,
    required String day,
  }) async {
    await _ensureCookies();
    final url =
        '$officeBase/data/apps/seat/room/reserve-window/check?roomId=$roomId&day=$day&deptIdEnc=$deptIdEnc&fidEnc=$deptIdEnc';

    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'Referer':
                '$officeBase/front/third/apps/seat/list?deptIdEnc=$deptIdEnc',
            'X-Requested-With': 'XMLHttpRequest',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final jsonMap = _parseResponseMap(response.data, '检查预约窗口失败');
        return jsonMap['data'] is Map
            ? (jsonMap['data'] as Map).cast<String, dynamic>()
            : <String, dynamic>{};
      }
      return {};
    } catch (e) {
      _logger.w('⚠️ checkReserveWindow error: $e');
      return {};
    }
  }

  /// 获取阅览室座位网格坐标与结构
  Future<LibrarySeatGridData> fetchSeatGrid({required int roomId}) async {
    await _ensureCookies();
    final url =
        '$officeBase/data/apps/seat/seatgrid/roomid?roomId=$roomId&fidEnc=$deptIdEnc';
    _logger.i('📚 Fetching Seat Grid for roomId=$roomId...');

    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'Referer':
                '$officeBase/front/third/apps/seat/select?deptIdEnc=$deptIdEnc&id=$roomId&fidEnc=$deptIdEnc',
            'X-Requested-With': 'XMLHttpRequest',
          },
        ),
      );

      if (response.statusCode != 200) {
        throw NetworkException('获取座位分布图失败: HTTP ${response.statusCode}');
      }

      final jsonMap = _parseResponseMap(response.data, '获取座位分布图失败');
      final gridDataRaw = jsonMap['data'] is Map
          ? (jsonMap['data'] as Map).cast<String, dynamic>()
          : <String, dynamic>{};
      return LibrarySeatGridData.fromJson(gridDataRaw);
    } catch (e) {
      _logger.e('❌ fetchSeatGrid error: $e');
      rethrow;
    }
  }

  /// 查询指定时段已占用的座位号列表
  Future<Set<String>> fetchUsedSeats({
    required int roomId,
    required String startTime,
    required String endTime,
    required String day,
  }) async {
    await _ensureCookies();
    const url = '$officeBase/data/apps/seat/getusedseatnums';
    _logger.i(
        '📚 Fetching used seats for roomId=$roomId, $day $startTime-$endTime...');

    try {
      final response = await _dio.post(
        url,
        data: {
          'roomId': roomId,
          'startTime': startTime,
          'endTime': endTime,
          'day': day,
          'fidEnc': deptIdEnc,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'Referer':
                '$officeBase/front/third/apps/seat/select?deptIdEnc=$deptIdEnc&id=$roomId&day=$day&backLevel=2&fidEnc=$deptIdEnc',
            'X-Requested-With': 'XMLHttpRequest',
          },
        ),
      );

      if (response.statusCode != 200) {
        throw NetworkException('获取占用座位失败: HTTP ${response.statusCode}');
      }

      final jsonMap = _parseResponseMap(response.data, '获取占用座位失败');
      final usedSet = <String>{};
      final resData = jsonMap['data'] is Map
          ? (jsonMap['data'] as Map).cast<String, dynamic>()
          : <String, dynamic>{};
      final seatReserves = resData['seatReserves'] as List<dynamic>? ?? [];
      for (final item in seatReserves) {
        if (item is String) {
          usedSet.add(item);
        } else if (item is Map && item['seatNum'] != null) {
          usedSet.add(item['seatNum'].toString());
        }
      }
      return usedSet;
    } catch (e) {
      _logger.e('❌ fetchUsedSeats error: $e');
      return {};
    }
  }

  /// 提取页面 submit_enc 签名密钥
  Future<String> _fetchSubmitEnc({
    required int roomId,
    required String day,
  }) async {
    final pageUrl =
        '$officeBase/front/third/apps/seat/select?deptIdEnc=$deptIdEnc&id=$roomId&day=$day&backLevel=2&fidEnc=$deptIdEnc';
    _logger.d('🔍 Extracting submit_enc from $pageUrl...');

    try {
      final response = await _dio.get(
        pageUrl,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 15; Pixel 9) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Mobile Safari/537.36',
          },
        ),
      );

      final html = response.data.toString();
      final doc = html_parser.parse(html);
      final input = doc.querySelector('input#submit_enc');
      final value = input?.attributes['value'];

      if (value != null && value.isNotEmpty) {
        _logger.d('✅ Extracted submit_enc: $value');
        return value;
      }

      // 正则备选
      final reg = RegExp(r'id="submit_enc"\s+value="(.*?)"');
      final match = reg.firstMatch(html);
      if (match != null) {
        final encVal = match.group(1)!;
        _logger.d('✅ Extracted submit_enc via regex: $encVal');
        return encVal;
      }

      throw const AppException('无法从页面提取预约签名凭证');
    } catch (e) {
      _logger.e('❌ _fetchSubmitEnc error: $e');
      rethrow;
    }
  }

  /// 计算提交参数签名 (基于超星 submitVerify.min.js 逆向)
  String _generateEnc(Map<String, dynamic> params, String submitEnc) {
    final sortedKeys = params.keys.toList()..sort();
    final parts = <String>[];
    for (final k in sortedKeys) {
      parts.add('[$k=${params[k] ?? ''}]');
    }
    parts.add('[$submitEnc]');
    final raw = parts.join('');
    final enc = md5.convert(utf8.encode(raw)).toString();
    _logger.d('🔐 Generated enc: $enc from raw: $raw');
    return enc;
  }

  /// 提交座位预约
  Future<LibraryReserveModel> submitReservation({
    required int roomId,
    required String seatNum,
    required String day,
    required String startTime,
    required String endTime,
  }) async {
    await _ensureCookies();
    _logger.i(
        '🚀 Submitting reservation: roomId=$roomId, seatNum=$seatNum, day=$day, time=$startTime-$endTime...');

    try {
      // 1. 获取 submit_enc
      final submitEnc = await _fetchSubmitEnc(roomId: roomId, day: day);

      // 2. 组装参数并计算签名
      final paramObj = <String, dynamic>{
        'deptIdEnc': deptIdEnc,
        'roomId': roomId,
        'day': day,
        'startTime': startTime,
        'endTime': endTime,
        'seatNum': seatNum,
        'captcha': '',
        'wyToken': '',
      };

      final enc = _generateEnc(paramObj, submitEnc);

      // 3. 发送预约请求
      const submitUrl = '$officeBase/data/apps/seat/submit';
      final response = await _dio.post(
        submitUrl,
        data: {
          'deptIdEnc': deptIdEnc,
          'roomId': roomId,
          'startTime': startTime,
          'endTime': endTime,
          'day': day,
          'seatNum': seatNum,
          'captcha': '',
          'wyToken': '',
          'enc': enc,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'Referer':
                '$officeBase/front/third/apps/seat/select?deptIdEnc=$deptIdEnc&id=$roomId&day=$day&backLevel=2&fidEnc=$deptIdEnc',
            'X-Requested-With': 'XMLHttpRequest',
          },
        ),
      );

      if (response.statusCode != 200) {
        throw NetworkException('预约请求失败: HTTP ${response.statusCode}');
      }

      final jsonMap = _parseResponseMap(response.data, '预约失败，请稍后重试');
      final resData = jsonMap['data'] is Map
          ? (jsonMap['data'] as Map).cast<String, dynamic>()
          : <String, dynamic>{};
      final reserveData = resData['seatReserve'] is Map
          ? (resData['seatReserve'] as Map).cast<String, dynamic>()
          : null;

      if (reserveData == null || reserveData.isEmpty) {
        final message = jsonMap['msg']?.toString() ??
            jsonMap['message']?.toString() ??
            '预约失败，服务器未返回有效预约结果';
        throw AppException(message);
      }

      final reserve = LibraryReserveModel.fromJson(reserveData);
      if (reserve.id <= 0 && reserve.seatNum.isEmpty) {
        throw const AppException('预约失败，服务器未返回有效预约结果');
      }
      return reserve;
    } catch (e) {
      _logger.e('❌ submitReservation error: $e');
      rethrow;
    }
  }

  /// 取消预约
  Future<bool> cancelReservation(int reserveId) async {
    await _ensureCookies();
    final url = '$officeBase/data/apps/seat/cancel?id=$reserveId';
    _logger.i('🛑 Cancelling reservation: id=$reserveId...');

    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'Referer':
                '$officeBase/front/third/apps/seat/index?fidEnc=$deptIdEnc',
            'X-Requested-With': 'XMLHttpRequest',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final jsonMap = _parseResponseMap(response.data, '取消预约失败');
        return jsonMap['success'] == true;
      }
      return false;
    } catch (e) {
      _logger.e('❌ cancelReservation error: $e');
      rethrow;
    }
  }

  /// 签到座位
  Future<bool> signInSeat(LibraryReserveModel reserve) async {
    if (reserve.id <= 0 ||
        reserve.roomId <= 0 ||
        reserve.seatNum.trim().isEmpty) {
      throw const AppException('当前预约信息不完整，无法签到');
    }
    if (reserve.reserveStatus == ReserveStatus.inUse) {
      throw const AppException('当前预约已经签到');
    }
    if (reserve.reserveStatus != ReserveStatus.reserved &&
        reserve.reserveStatus != ReserveStatus.flexibleSign) {
      throw AppException('当前预约状态不支持签到: ${reserve.reserveStatus.label}');
    }

    await _ensureCookies();
    _logger.i(
      '📍 Direct sign-in: room=${reserve.roomId}, seat=${reserve.seatNum}, reserveId=${reserve.id}',
    );

    final pageUrl = _buildSeatCodePageUrl(
      roomId: reserve.roomId,
      seatNum: reserve.seatNum,
      reserveId: reserve.id,
    );

    try {
      final response = await _dio.get(
        '$officeBase/data/apps/seat/sign',
        queryParameters: {'id': reserve.id},
        options: Options(
          headers: {
            'Accept': 'application/json, text/javascript, */*; q=0.01',
            'Origin': officeBase,
            'Referer': pageUrl,
            'X-Requested-With': 'XMLHttpRequest',
          },
        ),
      );

      if (response.statusCode != 200) {
        throw NetworkException('签到请求失败: HTTP ${response.statusCode}');
      }

      _parseResponseMap(response.data, '签到失败，请稍后重试');
      _logger.i('✅ Seat signed in successfully');
      return true;
    } catch (e) {
      _logger.e('❌ signInSeat error: $e');
      rethrow;
    }
  }

  /// 退座。与取消预约是两个不同的业务接口。
  Future<bool> signBackSeat(LibraryReserveModel reserve,
      {String? objectId}) async {
    if (reserve.id <= 0) {
      throw const AppException('预约信息不完整，无法退座');
    }

    await _ensureCookies();
    _logger.i('🛑 Signing back seat: reserveId=${reserve.id}...');

    try {
      final params = <String, dynamic>{'id': reserve.id};
      if (objectId != null && objectId.isNotEmpty) {
        params['objectId'] = objectId;
      }

      // 官方页面通过 GET + query 参数调用该接口（operateData/getJSON）。
      final response = await _dio.get(
        '$officeBase/data/apps/seat/signback',
        queryParameters: params,
        options: Options(
          headers: {
            'Accept': 'application/json, text/javascript, */*; q=0.01',
            'Origin': officeBase,
            'Referer':
                '$officeBase/front/third/apps/seat/index?fidEnc=$deptIdEnc',
            'X-Requested-With': 'XMLHttpRequest',
          },
        ),
      );

      if (response.statusCode != 200) {
        throw NetworkException('退座请求失败: HTTP ${response.statusCode}');
      }

      _parseResponseMap(response.data, '退座失败，请稍后重试');
      _logger.i('✅ Seat signed back successfully');
      return true;
    } catch (e) {
      _logger.e('❌ signBackSeat error: $e');
      rethrow;
    }
  }

  String _buildSeatCodePageUrl({
    required int roomId,
    required String seatNum,
    required int reserveId,
  }) {
    final normalizedSeatNum = _normalizeSeatNum(seatNum);
    final paddedSeatNum = normalizedSeatNum.isEmpty
        ? ''
        : int.tryParse(normalizedSeatNum)?.toString().padLeft(3, '0') ??
            normalizedSeatNum;

    return Uri.parse('$officeBase/front/apps/seat/code').replace(
      queryParameters: {
        if (roomId > 0) 'id': roomId.toString(),
        if (normalizedSeatNum.isNotEmpty) 'seatNum': normalizedSeatNum,
        if (paddedSeatNum.isNotEmpty) 'num': paddedSeatNum,
        'reserveId': reserveId.toString(),
        if (roomId > 0) 'room': roomId.toString(),
        'signType': '1',
      },
    ).toString();
  }

  String _normalizeSeatNum(String seatNum) {
    final value = seatNum.trim();
    final parsed = int.tryParse(value);
    return parsed == null ? value : parsed.toString();
  }
}
