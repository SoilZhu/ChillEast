import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/cookie_manager.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/dkyw_crypto.dart';

final campusCardServiceProvider = Provider((ref) => CampusCardService());

enum PaymentMethod {
  wechat,
  alipay,
}

class CampusCardInfo {
  final String name;
  final String idserial;
  final String balance;
  final String? openid;

  CampusCardInfo({
    required this.name,
    required this.idserial,
    required this.balance,
    this.openid,
  });

  @override
  String toString() => 'CampusCardInfo(name: $name, idserial: $idserial, balance: $balance)';
}

class WeChatRechargeOrder {
  final String partnerjourno;
  final String mwebUrl;
  final String returnurl;
  final String? redirectUrl;
  final String? prepayId;

  WeChatRechargeOrder({
    required this.partnerjourno,
    required this.mwebUrl,
    required this.returnurl,
    this.redirectUrl,
    this.prepayId,
  });

  @override
  String toString() => 'WeChatRechargeOrder(partnerjourno: $partnerjourno, mwebUrl: $mwebUrl, returnurl: $returnurl)';
}

class WeChatPayStatusResult {
  final bool isSuccess;
  final bool isPending;
  final String? message;

  WeChatPayStatusResult({
    required this.isSuccess,
    required this.isPending,
    this.message,
  });

  @override
  String toString() => 'WeChatPayStatusResult(isSuccess: $isSuccess, isPending: $isPending, message: $message)';
}

class CampusCardService {
  final _logger = AppLogger.instance;
  
  String? _openid;
  String? get openid => _openid;
  
  CampusCardInfo? _cachedInfo;
  CampusCardInfo? get cachedInfo => _cachedInfo;

  // 付款码缓存：服务端 60s 刷新一次，这里 55s TTL，命中则秒开，
  // 后台再静默刷新（stale-while-revalidate）。
  Map<String, dynamic>? _cachedPaymentCode;
  DateTime? _paymentCodeFetchedAt;
  static const _paymentCodeTtl = Duration(seconds: 55);

  /// 55s 内有效的付款码缓存，命中可直接渲染首帧
  Map<String, dynamic>? getCachedPaymentCode() {
    final cache = _cachedPaymentCode;
    final at = _paymentCodeFetchedAt;
    if (cache == null || at == null) return null;
    if (DateTime.now().difference(at) > _paymentCodeTtl) return null;
    if (cache['openid'] != _openid) return null;
    return cache;
  }

  /// 缓存剩余有效秒数（用于恢复倒计时，避免旧码显示满 60s）
  int paymentCodeRemainingSeconds() {
    final at = _paymentCodeFetchedAt;
    if (_cachedPaymentCode == null || at == null) return 0;
    return (60 - DateTime.now().difference(at).inSeconds).clamp(0, 60);
  }

  /// 授权并获取 OpenID（纯 HTTP，不再使用 WebView）
  ///
  /// 对齐 `debug/付款码/finserv授权.har`：整条链是纯 302 跳转，不需要执行 JS：
  /// `auth.chaoxing/authorize -> homecx/openCXOAuthPage -> homeCX/openHomePage?openid=..`。
  /// Dio 跟随跳转即可拿到 `openid`，会话 Cookie 由 Dio CookieJar 自动沉淀。
  /// 落到 `errorPage`（资源受限/页面丢失）即判失败，不提取上面的旧 openid。
  Future<String?> authenticate() async {
    _logger.i('🚀 Starting HTTP authentication for Campus Card...');
    try {
      final dio = DioClient().dio;

      // 诊断：超星登录态还在不在？auth 302 依赖 Chaoxing Cookie，
      // 为 0 基本就是登录过期，fin-serv 必回 errorPage。
      try {
        final chaoxingCookies = await AppCookieManager()
            .dioCookieJar
            .loadForRequest(Uri.parse('https://auth.chaoxing.com/'));
        _logger
            .d('🔗 Chaoxing cookies for auth: ${chaoxingCookies.length}');
      } catch (_) {}

      // 手动跟随 302（HAR 共 4 跳：auth.chaoxing -> http homecx ->
      // https homecx -> http homeCX -> https homeCX），逐跳打日志，
      // 才能定位到底哪一跳开始偏离 HAR。
      String? url = AppConstants.campusCardUrl;
      String? referer;
      Response? lastResponse;
      for (var step = 0; step < 10 && url != null; step++) {
        final response = await dio.get(
          url,
          options: Options(
            headers: {
              'User-Agent': AppConstants.campusCardUA,
              'Accept':
                  'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
              'Accept-Language': 'zh-CN,zh;q=0.9',
              'Upgrade-Insecure-Requests': '1',
              if (referer != null) 'Referer': referer,
            },
            followRedirects: false,
            maxRedirects: 0,
            responseType: ResponseType.plain,
            validateStatus: (status) => status != null && status < 500,
          ),
        );
        final status = response.statusCode ?? 0;
        final location = response.headers.value('location') ?? '';
        final setCookies = response.headers['set-cookie'] ?? [];
        final cookieNames = setCookies
            .map((c) => c.split(';').first.split('=').first.trim())
            .where((n) => n.isNotEmpty)
            .join(',');
        final bodyLen = response.data?.toString().length ?? 0;
        _logger.d(
            '🔗 auth step $step: $status $url -> ${location.isEmpty ? '(body $bodyLen chars)' : location} [set-cookie: ${cookieNames.isEmpty ? 'none' : cookieNames}]');
        lastResponse = response;
        if (status >= 300 && status < 400 && location.isNotEmpty) {
          referer = url;
          url = Uri.parse(url).resolve(location).toString();
          if (url.contains('errorPage')) {
            _logger.w('⚠️ HTTP auth hit errorPage at step $step: $url');
            return null;
          }
          continue;
        }
        url = null;
      }

      final finalUri = lastResponse?.realUri ?? Uri.parse('');
      final body = lastResponse?.data?.toString() ?? '';
      _logger.d('🔗 HTTP auth final URL: $finalUri');

      if (finalUri.path.contains('errorPage') ||
          body.contains('资源受限') ||
          body.contains('页面丢失')) {
        _logger.w('⚠️ HTTP auth landed on errorPage (resource limited)');
        return null;
      }

      String? openid = finalUri.queryParameters['openid'];
      openid ??= RegExp(r'openHomePage\?openid=([A-Za-z0-9]+)')
          .firstMatch(body)
          ?.group(1);
      openid ??= RegExp(r'''openid["'=:\s]+([A-Fa-f0-9]{32,})''')
          .firstMatch('$body $finalUri')
          ?.group(1);

      if (openid != null && openid.isNotEmpty) {
        _openid = openid;
        _logger.i('✅ HTTP auth extracted OpenID: $_openid');
        return _openid;
      }

      _logger.w('⚠️ HTTP auth: no openid in $finalUri');
      return null;
    } catch (e) {
      _logger.w('⚠️ HTTP auth error: $e');
      return null;
    }
  }

  /// 获取付款码详情 (Base64 和 PayCode)
  ///
  /// [forceRefresh] 为 true 时跳过 55s 缓存（倒计时归零、手动点码刷新、
  /// 支付完成后重拉走这条）；首进页面传 false 以便缓存秒开。
  Future<Map<String, dynamic>> fetchPaymentCode(
      {bool isRetry = false, bool forceRefresh = false}) async {
    // 确保已授权
    final justAuthenticated = _openid == null;
    if (justAuthenticated) {
      final authResult = await authenticate();
      if (authResult == null) throw Exception('授权失败，无法获取付款码');
      // 刚建好会话后，先用 Dio 摸一下 openHomePage 把 fin-serv 会话预热起来，
      // 再打 openVirtualcard，否则大概率 errorPage/资源受限。
      try {
        await DioClient().dio.get(
          'https://fin-serv.hunau.edu.cn/homeCX/openHomePage?openid=$_openid&usertype=2',
          options: Options(
            headers: {'User-Agent': AppConstants.campusCardUA},
            responseType: ResponseType.plain,
            validateStatus: (status) => status != null && status < 500,
          ),
        );
      } catch (e) {
        _logger.w('⚠️ Session warmup failed (non-fatal): $e');
      }
    }

    // 55s 缓存命中则秒开（调用方后台再静默刷新）；重试/强制刷新跳过
    if (!isRetry && !forceRefresh) {
      final cached = getCachedPaymentCode();
      if (cached != null) {
        _logger.d('⚡ Payment code served from cache');
        return cached;
      }
    }

    final dio = DioClient().dio;
    final url = 'https://fin-serv.hunau.edu.cn/virtualcard/openVirtualcard?openid=$_openid&displayflag=1&id=27';
    
    _logger.i('📡 Fetching payment code from: $url (Retry: $isRetry)');
    
    try {
      final response = await dio.get(
        url,
        options: Options(
          headers: {
            'User-Agent': AppConstants.campusCardUA,
            'Referer':
                'https://fin-serv.hunau.edu.cn/homeCX/openHomePage?openid=$_openid&usertype=2',
          },
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final html = response.data.toString();
        // Dio 默认跟随 302：会话失效时最终会落到 errorPage（200 + 资源受限文案），
        // 必须连 realUri 一起判，否则仅查 body 容易漏。
        final landedOnErrorPage =
            response.realUri.path.contains('errorPage');
        final isResourceLimited =
            html.contains('资源受限') || html.contains('页面丢失');

        // ✨ 检测会话过期：如果 HTML 包含登录关键字且不包含支付码关键字
        if (((html.contains('cas/login') || html.contains('统一身份认证')) && !html.contains('id="qrcode"')) ||
            landedOnErrorPage ||
            isResourceLimited) {
          _logger.w('⚠️ Session expired or error page detected in fetchPaymentCode: ${isResourceLimited ? '资源受限' : landedOnErrorPage ? 'errorPage:${response.realUri}' : '会话过期'}');
          if (!isRetry) {
            _openid = null; // 清除无效的 OpenID
            _cachedPaymentCode = null; // 会话失效，旧码不可再用
            _paymentCodeFetchedAt = null;
            await _clearDomainCookies(); // ✨ 清除该域名的 Cookie 强制重新授权
            return fetchPaymentCode(isRetry: true);
          }
          // 重试一次仍是资源受限：服务端限流而非客户端 Cookie 问题，
          // 抛可读错误让 UI 直接展示，不再进通用“解析失败”。
          if (isResourceLimited || landedOnErrorPage) {
            throw Exception('资源受限，页面丢失，请稍后重试');
          }
        }

        // 1. 解析 Base64 二维码
        final qrMatch = RegExp(r'id="qrcode".*?src="data:image/png;base64,(.*?)"', dotAll: true).firstMatch(html);
        final qrBase64 = qrMatch?.group(1)?.replaceAll('\n', '').replaceAll('\r', '').trim();
        
        // 2. 解析 paycode (id="code")
        final codeMatch = RegExp(r'id="code"\s+value="(.*?)"').firstMatch(html);
        final paycode = codeMatch?.group(1);
        
        // 3. 解析用户信息 (加强版解析)
        // 尝试从不同的容器中解析姓名、学号和余额
        final infoMatch = RegExp(r'<p class="bdb">(.*?)<\/p>').firstMatch(html);
        final infoText = infoMatch?.group(1);
        
        if (infoText != null) {
          _parseAndCacheInfo(infoText);
        } else {
          // 备选解析方案
          _logger.d('🔍 Standard info text not found, trying deep scan...');
          _deepScanInfo(html);
        }

        if (qrBase64 == null || paycode == null) {
          _logger.e('❌ Failed to parse QR code or paycode from HTML');
          // 如果还是解析不到，且不是重试，则尝试重试一次
          if (!isRetry) {
            _openid = null;
            _cachedPaymentCode = null;
            _paymentCodeFetchedAt = null;
            return fetchPaymentCode(isRetry: true);
          }
          throw Exception('解析付款码页面失败');
        }

        final result = {
          'qrBase64': qrBase64,
          'paycode': paycode,
          'info': infoText ?? _cachedInfo?.toString(),
          'openid': _openid,
        };
        // 成功即缓存，供下次进页秒开（55s TTL，服务端 60s 刷新）
        _cachedPaymentCode = result;
        _paymentCodeFetchedAt = DateTime.now();
        return result;
      }
      
      throw Exception('网络请求失败: ${response.statusCode}');
    } catch (e) {
      _logger.e('❌ fetchPaymentCode error: $e');
      if (!isRetry && e.toString().contains('Exception')) {
         _logger.i('🔄 Retrying fetchPaymentCode due to error...');
         _openid = null;
         return fetchPaymentCode(isRetry: true);
      }
      rethrow;
    }
  }

  void _parseAndCacheInfo(String infoText) {
    try {
      _logger.d('🔍 Parsing info text: $infoText');
      // 兼容全角和半角冒号，以及可能的空格差异
      // 格式示例：朱天兆：202440800233 余额：21.00元
      final regExp = RegExp(r'([^：:\s]+)[：:]([0-9]+).*?余额[：:]([0-9.]+)');
      final match = regExp.firstMatch(infoText);
      
      if (match != null) {
        _cachedInfo = CampusCardInfo(
          name: match.group(1)!.trim(),
          idserial: match.group(2)!.trim(),
          balance: match.group(3)!.trim(),
          openid: _openid,
        );
        _logger.i('✅ Parsed Card Info: $_cachedInfo');
      } else {
        _logger.w('⚠️ Regex did not match info text: $infoText');
      }
    } catch (e) {
      _logger.w('⚠️ Error parsing info text: $e');
    }
  }

  /// 获取校园卡充值页信息（对齐付款码页面的实时余额刷新方式）
  Future<CampusCardInfo> fetchRechargeInfo({bool isRetry = false}) async {
    // 优先通过付款码页面 (openVirtualcard) 获取最新实时余额
    try {
      await fetchPaymentCode(isRetry: isRetry);
      if (_cachedInfo != null) {
        return _cachedInfo!;
      }
    } catch (e) {
      _logger.w('⚠️ fetchPaymentCode in fetchRechargeInfo error, fallback to openCardPay: $e');
    }

    if (_openid == null) {
      final authResult = await authenticate();
      if (authResult == null) throw Exception('授权失败');
    }

    final dio = DioClient().dio;
    final url = 'https://fin-serv.hunau.edu.cn/cardpay/openCardPay?openid=$_openid&displayflag=1&id=28';

    try {
      final response = await dio.get(
        url,
        options: Options(
          headers: {
            'User-Agent': AppConstants.campusCardUA,
            'Referer':
                'https://fin-serv.hunau.edu.cn/homeCX/openHomePage?openid=$_openid&usertype=2',
          },
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final html = response.data.toString();
        
        // ✨ 检测会话过期
        if (((html.contains('cas/login') || html.contains('统一身份认证')) && !html.contains('idserial')) || 
            html.contains('资源受限') || html.contains('页面丢失')) {
          _logger.w('⚠️ Session expired or error page detected in fetchRechargeInfo: ${html.contains('资源受限') ? '资源受限' : '会话过期'}');
          if (!isRetry) {
            _openid = null;
            await _clearDomainCookies();
            return fetchRechargeInfo(isRetry: true);
          }
        }

        // 尝试解析 <p class="bdb">
        final infoMatch = RegExp(r'<p class="bdb">(.*?)<\/p>').firstMatch(html);
        final infoText = infoMatch?.group(1);
        
        if (infoText != null) {
          _parseAndCacheInfo(infoText);
        }
        
        // ✨ 增强解析：如果余额还是不对或没拿到，尝试多维度扫描 HTML
        if (_cachedInfo == null || _cachedInfo!.balance == '0.00' || _cachedInfo!.balance.isEmpty) {
          _logger.d('📡 Performing deep scan for balance...');
          _deepScanInfo(html);
        }

        // 3. 如果还是没有满意的结果，尝试请求主页 (Home Page)
        if (_cachedInfo == null || _cachedInfo!.balance == '0.00' || _cachedInfo!.balance.isEmpty) {
          _logger.w('⚠️ Balance still missing, trying openHomePage...');
          final homeResponse = await dio.get(
            'https://fin-serv.hunau.edu.cn/homeCX/openHomePage?openid=$_openid&usertype=2',
            options: Options(
              headers: {'User-Agent': AppConstants.campusCardUA},
              responseType: ResponseType.plain,
              validateStatus: (status) => status != null && status < 500,
            ),
          );
          if (homeResponse.data != null) {
             _deepScanInfo(homeResponse.data.toString());
          }
        }

        // 4. 最后的回退：付款码页面
        if (_cachedInfo == null || _cachedInfo!.balance == '0.00' || _cachedInfo!.balance.isEmpty) {
          _logger.w('⚠️ Trying openVirtualcard as last resort...');
          await fetchPaymentCode(isRetry: isRetry);
        }
        
        if (_cachedInfo == null) {
          if (!isRetry) {
            _openid = null;
            return fetchRechargeInfo(isRetry: true);
          }
          throw Exception('无法获取卡片信息');
        }
        
        return _cachedInfo!;
      }
      throw Exception('网络请求失败: ${response.statusCode}');
    } catch (e) {
      _logger.e('❌ fetchRechargeInfo error: $e');
      if (!isRetry) {
         _openid = null;
         return fetchRechargeInfo(isRetry: true);
      }
      rethrow;
    }
  }

  void _deepScanInfo(String html) {
    try {
      // 1. 扫描 Input 域
      final nameMatch = RegExp(r'id="username"\s+value="([^"]+)"').firstMatch(html) ?? 
                        RegExp(r'name="username"\s+value="([^"]+)"').firstMatch(html);
      final idMatch = RegExp(r'id="idserial"\s+value="([^"]+)"').firstMatch(html) ??
                      RegExp(r'name="idserial"\s+value="([^"]+)"').firstMatch(html);
      
      // 2. 扫描余额显示 (支持多种格式)
      final balanceDeepMatch = RegExp(r'余额(?:<\/?[^>]+>|[：:\s])*([0-9]+\.[0-9]+)').firstMatch(html) ??
                               RegExp(r'([0-9]+\.[0-9]+)元').firstMatch(html);
      
      if (nameMatch != null && idMatch != null) {
        final name = nameMatch.group(1)!.trim();
        final idserial = idMatch.group(1)!.trim();
        final balance = balanceDeepMatch?.group(1) ?? _cachedInfo?.balance ?? '0.00';
        
        _cachedInfo = CampusCardInfo(
          name: name,
          idserial: idserial,
          balance: balance,
          openid: _openid,
        );
        _logger.i('✅ Deep scan success: $_cachedInfo');
      }
    } catch (e) {
      _logger.w('⚠️ Deep scan error: $e');
    }
  }

  /// 提交充值请求，获取支付宝跳转表单
  Future<String> getAlipayForm(double amount) async {
    if (_openid == null || _cachedInfo == null) {
      await fetchRechargeInfo();
    }

    final dio = DioClient().dio;
    const url = 'https://fin-serv.hunau.edu.cn/alipay/transferFromAlipay2Card';

    try {
      final response = await dio.post(
        url,
        data: {
          'txamt': amount.toStringAsFixed(0), // 可能是整数？HAR 中 txamt=1
          'payWay': '4',
          'openid': _openid,
          'idserial': _cachedInfo!.idserial,
          'username': _cachedInfo!.name,
          'disableidserialstart': '88,89',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'User-Agent': AppConstants.campusCardUA,
            'Referer': 'https://fin-serv.hunau.edu.cn/cardpay/openCardPay?openid=$_openid&displayflag=1&id=28',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        return response.data.toString();
      }
      throw Exception('充值请求失败: ${response.statusCode}');
    } catch (e) {
      _logger.e('❌ getAlipayForm error: $e');
      rethrow;
    }
  }

  /// 提交微信充值请求，获取微信充值订单信息 (含 mweb_url 等)
  Future<WeChatRechargeOrder> createWeChatOrder(double amount) async {
    if (_openid == null || _cachedInfo == null) {
      await fetchRechargeInfo();
    }

    final dio = DioClient().dio;

    // 1. 尝试记录用户最后一次选择的支付方式 (HAR 中 Entry 0/32)
    try {
      await dio.post(
        'https://fin-serv.hunau.edu.cn/myaccount/userlastbind?openid=$_openid&connect_redirect=1',
        data: {
          'payinfo': {'cardpayWay': '1'},
          'idserial': _cachedInfo!.idserial,
        },
        options: Options(
          contentType: Headers.jsonContentType,
          headers: {
            'User-Agent': AppConstants.campusCardUA,
            'Referer': 'https://fin-serv.hunau.edu.cn/cardpay/openCardPay?openid=$_openid',
            'X-Requested-With': 'XMLHttpRequest',
          },
        ),
      );
    } catch (e) {
      _logger.w('⚠️ userlastbind failed (non-fatal): $e');
    }

    // 2. 发起微信充值统一下单 (HAR 中 Entry 1/31)
    final url = 'https://fin-serv.hunau.edu.cn/wxpay/transferFromWx2Card?openid=$_openid&connect_redirect=1';
    try {
      final response = await dio.post(
        url,
        data: {
          'txamt': amount.toStringAsFixed(0),
          'payWay': '1',
          'openid': _openid,
          'idserial': _cachedInfo!.idserial,
          'tradetype': 'WAP',
        },
        options: Options(
          contentType: Headers.jsonContentType,
          headers: {
            'User-Agent': AppConstants.campusCardUA,
            'Referer': 'https://fin-serv.hunau.edu.cn/cardpay/openCardPay?openid=$_openid&displayflag=1&id=28',
            'X-Requested-With': 'XMLHttpRequest',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final dynamic respData = response.data is String ? jsonDecode(response.data as String) : response.data;
        if (respData is Map<String, dynamic>) {
          if (respData['success'] == true) {
            final resultData = respData['resultData'] as Map<String, dynamic>?;
            if (resultData != null && resultData['mweb_url'] != null) {
              var returnurl = resultData['returnurl']?.toString() ?? '';
              if (returnurl.contains('%')) {
                try {
                  returnurl = Uri.decodeComponent(returnurl);
                } catch (_) {}
              }
              if (returnurl.startsWith('http://')) {
                returnurl = returnurl.replaceFirst('http://', 'https://');
              }
              return WeChatRechargeOrder(
                partnerjourno: resultData['partnerjourno']?.toString() ?? '',
                mwebUrl: resultData['mweb_url'].toString(),
                returnurl: returnurl,
                redirectUrl: resultData['redirect_url']?.toString(),
                prepayId: resultData['prepay_id']?.toString(),
              );
            }
          }
          throw Exception(respData['message'] ?? '创建微信充值订单失败');
        }
      }
      throw Exception('微信充值请求失败: ${response.statusCode}');
    } catch (e) {
      _logger.e('❌ createWeChatOrder error: $e');
      rethrow;
    }
  }

  /// 从微信 H5 支付页 (mweb_url) 中提取 weixin://wap/pay?... 唤醒链接
  Future<String?> getWeChatDeepLink(String mwebUrl) async {
    final dio = DioClient().dio;
    try {
      final response = await dio.get(
        mwebUrl,
        options: Options(
          headers: {
            'Referer': 'https://fin-serv.hunau.edu.cn/',
            'User-Agent': AppConstants.campusCardUA,
          },
          responseType: ResponseType.plain,
        ),
      );
      if (response.statusCode == 200 && response.data != null) {
        final html = response.data.toString();
        // 匹配 weixin://wap/pay?...
        final match = RegExp(r'''(weixin://wap/pay\?[^"'\s<>\)]+)''').firstMatch(html);
        if (match != null) {
          final deepLink = match.group(1);
          _logger.i('✅ Extracted WeChat DeepLink: $deepLink');
          return deepLink;
        }
      }
    } catch (e) {
      _logger.w('⚠️ getWeChatDeepLink error: $e');
    }
    return null;
  }

  /// 查询微信充值订单状态 (HAR 中 queryWxWapPayStatus)
  Future<WeChatPayStatusResult> queryWeChatPayStatus({
    required String partnerjourno,
    required String returnurl,
  }) async {
    if (_openid == null) throw Exception('未授权 (OpenID 为空)');

    final dio = DioClient().dio;
    const url = 'https://fin-serv.hunau.edu.cn/wxpay/queryWxWapPayStatus';

    try {
      final response = await dio.get(
        url,
        queryParameters: {
          'partnerjourno': partnerjourno,
          'openid': _openid,
          'returnurl': returnurl,
        },
        options: Options(
          headers: {
            'User-Agent': AppConstants.campusCardUA,
            'Referer': 'https://fin-serv.hunau.edu.cn/cardpay/openCardPay?openid=$_openid',
          },
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 400,
        ),
      );

      final statusCode = response.statusCode ?? 200;
      final location = response.headers.value('location') ?? '';
      final realPath = response.realUri.path;
      final body = response.data.toString();

      _logger.d('🔍 queryWxWapPayStatus: status=$statusCode, location=$location, path=$realPath');

      // 1. 如果重定向到了 paySuccess（无论是 302 Header 中的 Location，还是已跟随跳转的 realPath）
      if (location.contains('paySuccess') || realPath.contains('paySuccess')) {
        _logger.i('🎉 WeChat Pay completed successfully! loc=$location, path=$realPath');
        return WeChatPayStatusResult(isSuccess: true, isPending: false);
      }

      // 2. 如果页面仍在查询中（待支付），明确返回 pending，绝对不能判定为成功
      if (body.contains('微信支付订单查询中') || body.contains('icon-wait.png')) {
        _logger.d('⏳ WeChat Pay status: still querying in progress...');
        return WeChatPayStatusResult(isSuccess: false, isPending: true);
      }

      // 3. 判断支付成功：页面明确展示充值/支付成功（且不含查询中、失败原因等）
      final isBodySuccess = (body.contains('支付成功') || body.contains('充值成功')) &&
          !body.contains('失败原因') &&
          !body.contains('static.css');

      if (isBodySuccess) {
        _logger.i('🎉 WeChat Pay completed successfully! realPath=$realPath');
        return WeChatPayStatusResult(isSuccess: true, isPending: false);
      }

      // 3. 提取失败原因（若有）
      final reasonMatch = RegExp(r'id="message"[^>]*>([^<]+)<\/p>').firstMatch(body);
      final reason = reasonMatch?.group(1)?.trim();

      if (reason != null && reason.isNotEmpty && reason != '微信支付订单查询中') {
        _logger.w('⚠️ WeChat Pay failed: $reason');
        return WeChatPayStatusResult(
          isSuccess: false,
          isPending: false,
          message: reason,
        );
      }

      return WeChatPayStatusResult(
        isSuccess: false,
        isPending: true,
      );
    } catch (e) {
      _logger.e('❌ queryWeChatPayStatus error: $e');
      return WeChatPayStatusResult(isSuccess: false, isPending: true, message: e.toString());
    }
  }

  /// 查询订单状态
  ///
  /// 对齐 HAR（`debug/付款码/付款码.har` entry 2-5）：
  /// 请求为 `GET queryOrderStatus?openid=..&connect_redirect=1&datajson=..`，
  /// 其中 `datajson = DkywCrypto.encryptPayload({'paycode': .., 'openid': ..})`；
  /// 响应为 `{"datajson": ".."}`，需 `DkywCrypto.decryptServerResponse` 解出
  /// `{"success": true, "resultData": {"status": "5/1/.."}}`。
  /// `status`: `1` 成功，`5` 未使用（空闲，继续轮询），其它按失败处理。
  Future<Map<String, dynamic>> queryOrderStatus(String paycode) async {
    if (_openid == null) throw Exception('未授权 (OpenID 为空)');

    final dio = DioClient().dio;
    const url = 'https://fin-serv.hunau.edu.cn/virtualcard/queryOrderStatus';
    final payload = {'paycode': paycode, 'openid': _openid};

    try {
      final response = await dio.get(
        url,
        queryParameters: {
          'openid': _openid,
          'connect_redirect': '1',
          'datajson': DkywCrypto.encryptPayload(payload),
        },
        options: Options(
          headers: {
            'User-Agent': AppConstants.campusCardUA,
            'X-Requested-With': 'XMLHttpRequest',
            'Accept': 'application/json, text/javascript, */*; q=0.01',
            'Referer': 'https://fin-serv.hunau.edu.cn/virtualcard/openVirtualcard?openid=$_openid&displayflag=1&id=27',
          },
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final decrypted =
            DkywCrypto.decryptServerResponse(response.data.toString());
        if (decrypted is Map<String, dynamic>) return decrypted;
        if (decrypted is Map) return Map<String, dynamic>.from(decrypted);
        // 兼容服务端直接返回明文 JSON 的情况
        if (response.data is Map) {
          return Map<String, dynamic>.from(response.data as Map);
        }
        throw Exception('查询状态失败：响应格式异常');
      }

      throw Exception('查询状态失败: ${response.statusCode}');
    } catch (e) {
      _logger.e('❌ queryOrderStatus error: $e');
      rethrow;
    }
  }

  String getCampusCardHomeUrl() {
    if (_openid == null) return AppConstants.campusCardUrl;
    return 'https://fin-serv.hunau.edu.cn/homeCX/openHomePage?openid=$_openid&usertype=2';
  }

  /// 清除该业务域名的所有 Cookie（纯 HTTP：只清 Dio jar）
  Future<void> _clearDomainCookies() async {
    try {
      _logger.i('🧹 Clearing fin-serv.hunau.edu.cn cookies...');
      final cookieManager = AppCookieManager();
      final dioCookieJar = cookieManager.dioCookieJar;

      await dioCookieJar.delete(Uri.parse('https://fin-serv.hunau.edu.cn'));

      _logger.i('✅ Domain cookies cleared');
    } catch (e) {
      _logger.w('⚠️ Failed to clear domain cookies: $e');
    }
  }
}
