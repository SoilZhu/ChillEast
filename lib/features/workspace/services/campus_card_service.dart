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
        if ((html.contains('cas/login') || html.contains('统一身份认证')) && !html.contains('id="qrcode"')) {
          _logger.w('⚠️ Session expired detected in fetchPaymentCode');
          if (!isRetry) {
            _openid = null; // 清除无效的 OpenID
            return fetchPaymentCode(isRetry: true);
          }
        }

        // 1. 解析 Base64 二维码
        final qrMatch = RegExp(r'id="qrcode".*?src="data:image/png;base64,(.*?)"', dotAll: true).firstMatch(html);
        final qrBase64 = qrMatch?.group(1)?.replaceAll('\n', '')?.replaceAll('\r', '')?.trim();
        
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

  /// 获取校园卡充值页信息
  Future<CampusCardInfo> fetchRechargeInfo({bool isRetry = false}) async {
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
        if ((html.contains('cas/login') || html.contains('统一身份认证')) && !html.contains('idserial')) {
          _logger.w('⚠️ Session expired detected in fetchRechargeInfo');
          if (!isRetry) {
            _openid = null;
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
}
