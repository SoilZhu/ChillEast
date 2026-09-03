import 'dart:async';
import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/cookie_manager.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/network/dio_client.dart';

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

  /// 授权并获取 OpenID 和 Cookie
  Future<String?> authenticate() async {
    _logger.i('🚀 Starting background authentication for Campus Card...');
    
    final completer = Completer<String?>();
    HeadlessInAppWebView? webView;

    try {
      webView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(AppConstants.campusCardUrl)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          userAgent: AppConstants.campusCardUA,
          loadsImagesAutomatically: false,
        ),
        onLoadStart: (controller, url) async {
          final urlString = url?.toString() ?? '';
          _logger.d('🔗 OAuth LoadStart: $urlString');
          
          if (urlString.contains('fin-serv.hunau.edu.cn/home/openHomePage')) {
            final uri = Uri.parse(urlString);
            final id = uri.queryParameters['openid'];
            if (id != null) {
              _openid = id;
              _logger.i('✅ Extracted OpenID: $_openid');
              
              // 同步 Cookie
              await AppCookieManager().syncMultiDomainCookiesFromWebView(urlString);
              if (!completer.isCompleted) completer.complete(_openid);
            }
          }
        },
        onLoadStop: (controller, url) async {
           final urlString = url?.toString() ?? '';
           _logger.d('🏁 OAuth LoadStop: $urlString');
           
           if (urlString.contains('openid=')) {
              final uri = Uri.parse(urlString);
              final id = uri.queryParameters['openid'];
              if (id != null && !completer.isCompleted) {
                _openid = id;
                _logger.i('✅ Extracted OpenID (onLoadStop): $_openid');
                await AppCookieManager().syncMultiDomainCookiesFromWebView(urlString);
                completer.complete(_openid);
              }
           }
        }
      );

      await webView.run();
      
      // 30秒超时
      final result = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _logger.e('❌ Campus Card Authentication timeout');
          return null;
        },
      );
      
      return result;
    } catch (e) {
      _logger.e('❌ Campus Card Authentication failed: $e');
      return null;
    } finally {
      webView?.dispose();
    }
  }

  /// 获取付款码详情 (Base64 和 PayCode)
  Future<Map<String, dynamic>> fetchPaymentCode({bool isRetry = false}) async {
    // 确保已授权
    if (_openid == null) {
      final authResult = await authenticate();
      if (authResult == null) throw Exception('授权失败，无法获取付款码');
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
            'Referer': 'https://fin-serv.hunau.edu.cn/home/openHomePage?openid=$_openid',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final html = response.data.toString();
        
        // ✨ 检测会话过期：如果 HTML 包含登录关键字且不包含支付码关键字
        if (((html.contains('cas/login') || html.contains('统一身份认证')) && !html.contains('id="qrcode"')) || 
            html.contains('资源受限') || html.contains('页面丢失')) {
          _logger.w('⚠️ Session expired or error page detected in fetchPaymentCode: ${html.contains('资源受限') ? '资源受限' : '会话过期'}');
          if (!isRetry) {
            _openid = null; // 清除无效的 OpenID
            await _clearDomainCookies(); // ✨ 清除该域名的 Cookie 强制重新授权
            return fetchPaymentCode(isRetry: true);
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
            return fetchPaymentCode(isRetry: true);
          }
          throw Exception('解析付款码页面失败');
        }

        return {
          'qrBase64': qrBase64,
          'paycode': paycode,
          'info': infoText ?? _cachedInfo?.toString(),
          'openid': _openid,
        };
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
            'Referer': 'https://fin-serv.hunau.edu.cn/home/openHomePage?openid=$_openid',
          },
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
            'https://fin-serv.hunau.edu.cn/home/openHomePage?openid=$_openid',
            options: Options(headers: {'User-Agent': AppConstants.campusCardUA}),
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
  Future<Map<String, dynamic>> queryOrderStatus(String paycode) async {
    if (_openid == null) throw Exception('未授权 (OpenID 为空)');
    
    final dio = DioClient().dio;
    const url = 'https://fin-serv.hunau.edu.cn/virtualcard/queryOrderStatus';
    
    try {
      final response = await dio.get(
        url,
        queryParameters: {
          'openid': _openid,
          'paycode': paycode,
          'connect_redirect': '1',
        },
        options: Options(
          headers: {
            'User-Agent': AppConstants.campusCardUA,
            'X-Requested-With': 'XMLHttpRequest',
            'Referer': 'https://fin-serv.hunau.edu.cn/virtualcard/openVirtualcard?openid=$_openid&displayflag=1&id=27',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        if (response.data is String) {
          return jsonDecode(response.data as String) as Map<String, dynamic>;
        }
        return response.data as Map<String, dynamic>;
      }
      
      throw Exception('查询状态失败: ${response.statusCode}');
    } catch (e) {
      _logger.e('❌ queryOrderStatus error: $e');
      rethrow;
    }
  }

  String getCampusCardHomeUrl() {
    if (_openid == null) return AppConstants.campusCardUrl;
    return 'https://fin-serv.hunau.edu.cn/home/openHomePage?openid=$_openid';
  }

  /// 清除该业务域名的所有 Cookie
  Future<void> _clearDomainCookies() async {
    try {
      _logger.i('🧹 Clearing fin-serv.hunau.edu.cn cookies...');
      final cookieManager = AppCookieManager();
      final dioCookieJar = cookieManager.dioCookieJar;
      
      // 1. 清除 Dio Cookie
      await dioCookieJar.delete(Uri.parse('https://fin-serv.hunau.edu.cn'));
      
      // 2. 清除 WebView Cookie
      final webViewCookieManager = CookieManager.instance();
      await webViewCookieManager.deleteCookies(url: WebUri('https://fin-serv.hunau.edu.cn'));
      
      _logger.i('✅ Domain cookies cleared');
    } catch (e) {
      _logger.w('⚠️ Failed to clear domain cookies: $e');
    }
  }
}
