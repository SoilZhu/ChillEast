import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/app_logger.dart';
import 'campus_card_service.dart';
import '../models/electricity_model.dart';

final electricityServiceProvider = Provider((ref) => ElectricityService(ref));

class ElectricityService {
  final Ref _ref;
  final _logger = AppLogger.instance;
  final String _factoryCode = 'E013';

  ElectricityService(this._ref);

  CampusCardService get _cardService => _ref.read(campusCardServiceProvider);

  /// 初始化电费环境 (确保 OpenID 和 Cookie)
  Future<String?> _ensureAuthenticated() async {
    if (_cardService.openid == null || _cardService.cachedInfo == null) {
      await _cardService.fetchRechargeInfo();
    }
    
    final openid = _cardService.openid;
    if (openid == null) return null;

    // 访问 openElePay 以设置 session/cookie
    final dio = DioClient().dio;
    try {
      await dio.get(
        'https://fin-serv.hunau.edu.cn/elepay/openElePay',
        queryParameters: {
          'openid': openid,
          'displayflag': '1',
          'id': '30',
        },
        options: Options(
          headers: {'User-Agent': AppConstants.campusCardUA},
        ),
      );
    } catch (e) {
      _logger.w('⚠️ openElePay initial call failed: $e');
    }
    
    return openid;
  }

  /// 获取校区列表
  Future<List<ElectricityArea>> getAreas() async {
    final openid = await _ensureAuthenticated();
    if (openid == null) throw Exception('授权失败');

    final dio = DioClient().dio;
    try {
      final response = await dio.post(
        'https://fin-serv.hunau.edu.cn/channel/getXiaoQuList',
        queryParameters: {
          'openid': openid,
          'connect_redirect': '1',
        },
        data: {'factorycode': _factoryCode},
        options: Options(
          headers: {
            'User-Agent': AppConstants.campusCardUA,
            'X-Requested-With': 'XMLHttpRequest',
          },
        ),
      );

      if (response.data != null) {
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        final List list;
        if (data is List) {
          list = data;
        } else if (data is Map && data.containsKey('resultData') && data['resultData'] is Map && data['resultData'].containsKey('schoolList')) {
          list = data['resultData']['schoolList'];
        } else if (data is Map && data.containsKey('resultData') && data['resultData'] is List) {
          list = data['resultData'];
        } else if (data is Map && data.containsKey('data') && data['data'] is List) {
          list = data['data'];
        } else {
          _logger.w('Unexpected response format for getAreas: $data');
          return [];
        }
        
        return list.map((e) => ElectricityArea.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      _logger.e('❌ getAreas failed: $e');
      rethrow;
    }
  }

  /// 获取楼栋列表
  Future<List<ElectricityBuilding>> getBuildings(String areaName) async {
    final openid = _cardService.openid;
    if (openid == null) throw Exception('未授权');

    final dio = DioClient().dio;
    try {
      final response = await dio.post(
        'https://fin-serv.hunau.edu.cn/channel/queryBuildingList',
        queryParameters: {
          'openid': openid,
          'connect_redirect': '1',
        },
        data: {
          'factorycode': _factoryCode,
          'schoolid': areaName,
        },
        options: Options(
          headers: {
            'User-Agent': AppConstants.campusCardUA,
            'X-Requested-With': 'XMLHttpRequest',
          },
        ),
      );

      if (response.data != null) {
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        final List list;
        if (data is List) {
          list = data;
        } else if (data is Map && data.containsKey('resultData') && data['resultData'] is Map && (data['resultData'].containsKey('buildingList') || data['resultData'].containsKey('buildinglist'))) {
          list = data['resultData']['buildingList'] ?? data['resultData']['buildinglist'];
        } else if (data is Map && data.containsKey('resultData') && data['resultData'] is List) {
          list = data['resultData'];
        } else if (data is Map && data.containsKey('data') && data['data'] is List) {
          list = data['data'];
        } else {
          _logger.w('Unexpected response format for getBuildings: $data');
          return [];
        }
        
        return list.map((e) => ElectricityBuilding.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      _logger.e('❌ getBuildings failed: $e');
      rethrow;
    }
  }

  /// 获取房间列表
  Future<List<ElectricityRoom>> getRooms(String areaName, String buildingName) async {
    final openid = _cardService.openid;
    if (openid == null) throw Exception('未授权');

    final dio = DioClient().dio;
    try {
      final response = await dio.post(
        'https://fin-serv.hunau.edu.cn/channel/queryRoomList',
        queryParameters: {
          'openid': openid,
          'connect_redirect': '1',
        },
        data: {
          'factorycode': _factoryCode,
          'schoolid': areaName,
          'buildingid': buildingName,
        },
        options: Options(
          headers: {
            'User-Agent': AppConstants.campusCardUA,
            'X-Requested-With': 'XMLHttpRequest',
          },
        ),
      );

      if (response.data != null) {
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        final List list;
        if (data is List) {
          list = data;
        } else if (data is Map && data.containsKey('resultData') && data['resultData'] is Map && (data['resultData'].containsKey('roomList') || data['resultData'].containsKey('roomlist'))) {
          list = data['resultData']['roomList'] ?? data['resultData']['roomlist'];
        } else if (data is Map && data.containsKey('resultData') && data['resultData'] is List) {
          list = data['resultData'];
        } else if (data is Map && data.containsKey('data') && data['data'] is List) {
          list = data['data'];
        } else {
          _logger.w('Unexpected response format for getRooms: $data');
          return [];
        }
        
        return list.map((e) => ElectricityRoom.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      _logger.e('❌ getRooms failed: $e');
      rethrow;
    }
  }

  /// 获取电费余额
  Future<ElectricityBalanceInfo> getBalance({
    required String areaName,
    required String buildingName,
    required String roomId,
    required String mertype,
  }) async {
    final openid = _cardService.openid;
    if (openid == null) throw Exception('未授权');

    final dio = DioClient().dio;
    try {
      final response = await dio.post(
        'https://fin-serv.hunau.edu.cn/channel/queryEleAccDetail',
        queryParameters: {
          'openid': openid,
          'connect_redirect': '1',
        },
        data: {
          'schoolid': areaName,
          'buildingid': buildingName,
          'roomid': roomId,
          'mertype': mertype,
          'factorycode': _factoryCode,
        },
        options: Options(
          headers: {
            'User-Agent': AppConstants.campusCardUA,
            'X-Requested-With': 'XMLHttpRequest',
          },
        ),
      );

      if (response.data != null) {
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        final Map<String, dynamic> result;
        if (data is Map && data.containsKey('resultData') && data['resultData'] is Map) {
          result = data['resultData'];
        } else if (data is Map<String, dynamic>) {
          result = data;
        } else {
          throw Exception('Unexpected response format for getBalance');
        }
        return ElectricityBalanceInfo.fromJson(result);
      }
      throw Exception('无法获取余额数据');
    } catch (e) {
      _logger.e('❌ getBalance failed: $e');
      rethrow;
    }
  }

  /// 执行充值 (校园卡支付)
  Future<bool> recharge({
    required String areaName,
    required String buildingName,
    required String roomId,
    required String mertype,
    required double amount,
  }) async {
    final openid = _cardService.openid;
    final cardInfo = _cardService.cachedInfo;
    if (openid == null || cardInfo == null) throw Exception('未授权或卡信息缺失');

    final dio = DioClient().dio;
    try {
      // 1. 绑定/记录最后使用的房间 (根据 HAR 结构)
      await dio.post(
        'https://fin-serv.hunau.edu.cn/myaccount/userlastbind',
        queryParameters: {
          'openid': openid,
          'connect_redirect': '1',
        },
        data: {
          'payinfo': {'elepayWay': '2'}, 
          'eleinfo': {
            'schoolid': areaName,
            'buildingid': buildingName,
            'roomid': roomId,
            'factorycode': _factoryCode,
            // 注意：HAR 中 userlastbind 的 eleinfo 并不包含 mertype
          },
          'idserial': cardInfo.idserial,
        },
        options: Options(
          headers: {
            'User-Agent': AppConstants.campusCardUA,
            'X-Requested-With': 'XMLHttpRequest',
          },
        ),
      );

      // 2. 发起预交易 (根据 HAR 结构)
      final response = await dio.post(
        'https://fin-serv.hunau.edu.cn/elepay/createPreThirdTrade',
        queryParameters: {
          'openid': openid,
          'connect_redirect': '1',
        },
        data: {
          'payamt': amount.toStringAsFixed(0),
          'openid': openid,
          'idserial': cardInfo.idserial,
          'factorycode': _factoryCode,
          'buildingid': buildingName,
          'roomid': roomId,
          'schoolid': areaName,
          'payWay': '2',
          'mertype': mertype,
        },
        options: Options(
          headers: {
            'User-Agent': AppConstants.campusCardUA,
            'X-Requested-With': 'XMLHttpRequest',
          },
        ),
      );

      if (response.data != null) {
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      _logger.e('❌ recharge failed: $e');
      rethrow;
    }
  }
}
