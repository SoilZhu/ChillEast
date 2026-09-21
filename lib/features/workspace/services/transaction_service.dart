import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/dkyw_crypto.dart';
import 'campus_card_service.dart';
import '../models/transaction_model.dart';

final transactionServiceProvider =
    Provider((ref) => TransactionService(ref));

/// 校园卡流水查询
///
/// 抓包见 `查询流水.har`：
/// - 先 GET `openQueryCardSelfTrade?openid=..&displayflag=1&id=4` 建会话
///   (同电费 `openElePay` 的作用)
/// - 再 POST `queryCardSelfTradeList`，请求/响应体均为 `datajson` 动态 AES 加密
///
/// 认证与 Cookie 复用付款码的 [CampusCardService] (同电费做法)，
/// 加解密复用 [DkywCrypto]，不另起一套。
class TransactionService {
  final Ref _ref;
  final _logger = AppLogger.instance;

  TransactionService(this._ref);

  CampusCardService get _cardService =>
      _ref.read(campusCardServiceProvider);

  String _queryPageUrl(String openid) =>
      'https://fin-serv.hunau.edu.cn/selftrade/openQueryCardSelfTrade?openid=$openid&displayflag=1&id=4';

  /// 确保 OpenID + fin 域会话 (同电费 `_ensureAuthenticated`)
  Future<String?> _ensureAuthenticated({bool force = false}) async {
    if (force ||
        _cardService.openid == null ||
        _cardService.cachedInfo == null) {
      await _cardService.fetchRechargeInfo(isRetry: force);
    }

    final openid = _cardService.openid;
    if (openid == null) return null;

    // 访问流水查询页以设置 session/cookie
    final dio = DioClient().dio;
    try {
      await dio.get(
        _queryPageUrl(openid),
        options: Options(
          headers: {'User-Agent': AppConstants.campusCardUA},
        ),
      );
    } catch (e) {
      _logger.w('⚠️ openQueryCardSelfTrade initial call failed: $e');
    }

    return openid;
  }

  /// 查询流水，日期格式 `yyyy-MM-dd`，`tradeType` 取 [TransactionType.value]
  ///
  /// 服务端限制：起止间隔 ≤ 31 天，截止 ≤ 当天 (页面 JS 同款校验在 UI 层也做了一份)。
  Future<List<TransactionRecord>> queryTransactions({
    required String beginDate,
    required String endDate,
    required String tradeType,
    bool isRetry = false,
  }) async {
    final openid = await _ensureAuthenticated(force: isRetry);
    if (openid == null) throw Exception('授权失败');

    final dio = DioClient().dio;
    // 字段顺序与 querytrace.js 的 queryTrade() 保持一致
    final payload = <String, dynamic>{
      'beginDate': beginDate,
      'endDate': endDate,
      'tradeType': tradeType,
      'openid': openid,
    };

    final response = await dio.post(
      'https://fin-serv.hunau.edu.cn/selftrade/queryCardSelfTradeList',
      queryParameters: {
        'openid': openid,
        'connect_redirect': '1',
      },
      data: {'datajson': DkywCrypto.encryptPayload(payload)},
      options: Options(
        headers: {
          'User-Agent': AppConstants.campusCardUA,
          'Referer': _queryPageUrl(openid),
          'X-Requested-With': 'XMLHttpRequest',
          'Content-Type': 'application/json',
          'Accept': 'application/json, text/javascript, */*; q=0.01',
        },
      ),
    );

    final resData = DkywCrypto.decryptServerResponse(response.data);
    _logger.d('📥 queryCardSelfTradeList decrypted: $resData');

    if (resData is Map) {
      final msg = (resData['message'] ?? resData['msg'] ?? '').toString();
      // 会话过期时重登一次 (同电费 _post 的处理)
      if (!isRetry &&
          (msg.contains('openid无效') ||
              msg.contains('页面丢失') ||
              msg.contains('未登录') ||
              msg.contains('会话过期') ||
              msg.contains('资源受限'))) {
        _logger.w('⚠️ Token/OpenID expired in queryTransactions, re-authenticating...');
        return queryTransactions(
          beginDate: beginDate,
          endDate: endDate,
          tradeType: tradeType,
          isRetry: true,
        );
      }

      if (resData['success'] == true) {
        final resultData = resData['resultData'];
        List list;
        if (resultData is List) {
          list = resultData;
        } else if (resultData is Map) {
          // 兼容 resultData 为 Map 套 List 的情况
          final nested = resultData.values.whereType<List>().firstOrNull;
          if (nested == null) return [];
          list = nested;
        } else {
          return [];
        }
        return list
            .whereType<Map>()
            .map((e) => TransactionRecord.fromJson(
                Map<String, dynamic>.from(e)))
            .toList();
      }
      throw Exception(msg.isNotEmpty ? msg : '查询流水失败');
    }

    // HTML 会话过期页 (无 datajson) 时重登一次
    if (!isRetry) {
      final raw = response.data.toString();
      if (raw.contains('cas/login') ||
          raw.contains('统一身份认证') ||
          raw.contains('资源受限') ||
          raw.contains('页面丢失')) {
        _logger.w('⚠️ Session page expired in queryTransactions, re-authenticating...');
        return queryTransactions(
          beginDate: beginDate,
          endDate: endDate,
          tradeType: tradeType,
          isRetry: true,
        );
      }
    }

    throw Exception('查询流水失败：响应格式异常');
  }
}
