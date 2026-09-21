import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/dkyw_crypto.dart';
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
  Future<String?> _ensureAuthenticated({bool force = false}) async {
    if (force || _cardService.openid == null || _cardService.cachedInfo == null) {
      await _cardService.fetchRechargeInfo(isRetry: force);
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

  /// 发送带 DKYW 动态 AES 加解密的 POST 请求
  Future<dynamic> _post(String url, Map<String, dynamic> payload, {bool isRetry = false}) async {
    if (_cardService.openid == null) {
      await _ensureAuthenticated();
    }
    final openid = _cardService.openid;
    if (openid == null) throw Exception('未授权');

    final dio = DioClient().dio;
    final encryptedDatajson = DkywCrypto.encryptPayload(payload);

    final response = await dio.post(
      url,
      queryParameters: {
        'openid': openid,
        'connect_redirect': '1',
      },
      data: {'datajson': encryptedDatajson},
      options: Options(
        headers: {
          'User-Agent': AppConstants.campusCardUA,
          'X-Requested-With': 'XMLHttpRequest',
          'Content-Type': 'application/json',
          'Accept': 'application/json, text/javascript, */*; q=0.01',
        },
      ),
    );

    final resData = DkywCrypto.decryptServerResponse(response.data);
    _logger.d('📥 _post ($url) decrypted: $resData');

    // 检查是否 session 过期或 openid 无效
    if (resData is Map) {
      final msg = (resData['message'] ?? resData['msg'] ?? '').toString();
      if (!isRetry && (msg.contains('openid无效') || msg.contains('页面丢失') || msg.contains('未登录') || msg.contains('会话过期') || msg.contains('资源受限'))) {
        _logger.w('⚠️ Token/OpenID expired in _post, re-authenticating...');
        await _ensureAuthenticated(force: true);
        return _post(url, payload, isRetry: true);
      }
    }

    return resData;
  }

  /// 获取校区列表
  Future<List<ElectricityArea>> getAreas() async {
    final openid = await _ensureAuthenticated();
    if (openid == null) throw Exception('授权失败');

    try {
      final data = await _post(
        'https://fin-serv.hunau.edu.cn/channel/getXiaoQuList',
        {'factorycode': _factoryCode},
      );

      if (data != null) {
        final List list;
        if (data is List) {
          list = data;
        } else if (data is Map && data.containsKey('resultData') && data['resultData'] is Map && (data['resultData'].containsKey('schoolList') || data['resultData'].containsKey('schoollist'))) {
          list = data['resultData']['schoolList'] ?? data['resultData']['schoollist'];
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
    if (_cardService.openid == null) {
      await _ensureAuthenticated();
    }
    final openid = _cardService.openid;
    if (openid == null) throw Exception('未授权');

    try {
      final data = await _post(
        'https://fin-serv.hunau.edu.cn/channel/queryBuildingList',
        {
          'factorycode': _factoryCode,
          'schoolid': areaName,
        },
      );

      if (data != null) {
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
    if (_cardService.openid == null) {
      await _ensureAuthenticated();
    }
    final openid = _cardService.openid;
    if (openid == null) throw Exception('未授权');

    try {
      final data = await _post(
        'https://fin-serv.hunau.edu.cn/channel/queryRoomList',
        {
          'factorycode': _factoryCode,
          'schoolid': areaName,
          'buildingid': buildingName,
        },
      );

      if (data != null) {
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
    if (_cardService.openid == null) {
      await _ensureAuthenticated();
    }
    final openid = _cardService.openid;
    if (openid == null) throw Exception('未授权');

    try {
      final data = await _post(
        'https://fin-serv.hunau.edu.cn/channel/queryEleAccDetail',
        {
          'schoolid': areaName,
          'buildingid': buildingName,
          'roomid': roomId,
          'mertype': mertype,
          'factorycode': _factoryCode,
        },
      );

      if (data != null) {
        if (data is Map && data['success'] == false) {
          final msg = data['message'] ?? data['msg'] ?? '获取电费余额失败';
          throw Exception(msg);
        }

        final Map<String, dynamic> result;
        if (data is Map && data.containsKey('resultData') && data['resultData'] is Map) {
          result = Map<String, dynamic>.from(data['resultData']);
        } else if (data is Map<String, dynamic>) {
          result = data;
        } else if (data is Map) {
          result = Map<String, dynamic>.from(data);
        } else {
          throw Exception('Unexpected response format for getBalance: $data');
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
    String? roomName,
    required String mertype,
    required double amount,
  }) async {
    if (_cardService.openid == null || _cardService.cachedInfo == null) {
      await _cardService.fetchRechargeInfo();
    }
    final openid = _cardService.openid;
    final cardInfo = _cardService.cachedInfo;
    if (openid == null || cardInfo == null) throw Exception('未授权或卡信息缺失');

    try {
      // 1. 绑定/记录最后使用的房间 (根据 HAR 结构)
      await _post(
        'https://fin-serv.hunau.edu.cn/myaccount/userlastbind',
        {
          'payinfo': {'elepayWay': '2'}, 
          'eleinfo': {
            'schoolid': areaName,
            'buildingid': buildingName,
            'roomid': roomId,
            'factorycode': _factoryCode,
          },
          'idserial': cardInfo.idserial,
        },
      );

      // 2. 发起预交易 (根据 HAR 结构)
      final data = await _post(
        'https://fin-serv.hunau.edu.cn/elepay/createPreThirdTrade',
        {
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
      );

      _logger.i('📥 createPreThirdTrade decrypted response: $data');
      if (data != null && data is Map) {
        final success = data['success'] == true ||
            data['success'] == 'true' ||
            data['code'] == '0' ||
            data['code'] == 0 ||
            (data.containsKey('resultData') && data['resultData'] != null);
        _logger.i('⚡ recharge evaluated success: $success');
        if (success) {
          String effectiveRoomName = (roomName != null && roomName.isNotEmpty) ? roomName : '';
          if (effectiveRoomName.isEmpty) {
            final oldSaved = await getSavedRoom();
            if (oldSaved != null && oldSaved.roomId == roomId && oldSaved.roomName.isNotEmpty && oldSaved.roomName != roomId) {
              effectiveRoomName = oldSaved.roomName;
            } else {
              effectiveRoomName = roomId;
            }
          }
          await saveSavedRoom(
            SavedElectricityRoom(
              areaName: areaName,
              buildingName: buildingName,
              roomId: roomId,
              roomName: effectiveRoomName,
              mertype: mertype,
            ),
          );
        } else {
          final msg = data['message'] ?? data['msg'];
          if (msg != null && msg.toString().isNotEmpty) {
            _logger.w('⚠️ recharge returned failure: $msg');
            throw Exception(msg.toString());
          }
        }
        return success;
      }
      return false;
    } catch (e) {
      _logger.e('❌ recharge failed: $e');
      rethrow;
    }
  }

  static const String _savedRoomKey = 'saved_electricity_room';

  /// 获取上次保存/选择的宿舍房间
  Future<SavedElectricityRoom?> getSavedRoom() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_savedRoomKey);
      if (raw != null && raw.isNotEmpty) {
        final data = jsonDecode(raw);
        if (data is Map<String, dynamic>) {
          return SavedElectricityRoom.fromJson(data);
        } else if (data is Map) {
          return SavedElectricityRoom.fromJson(Map<String, dynamic>.from(data));
        }
      }
    } catch (e) {
      _logger.w('Failed to get saved electricity room: $e');
    }
    return null;
  }

  /// 保存当前选择的宿舍房间
  Future<void> saveSavedRoom(SavedElectricityRoom room) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_savedRoomKey, jsonEncode(room.toJson()));
      _logger.d('💾 Saved electricity room: ${room.areaName} - ${room.buildingName} - ${room.roomName}');
    } catch (e) {
      _logger.w('Failed to save electricity room: $e');
    }
  }

  /// 清除保存的宿舍房间 (例如退出登录时)
  Future<void> clearSavedRoom() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_savedRoomKey);
      _logger.d('🧹 Cleared saved electricity room');
    } catch (e) {
      _logger.w('Failed to clear saved electricity room: $e');
    }
  }
}
