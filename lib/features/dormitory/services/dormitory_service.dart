import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/exceptions/app_exceptions.dart';
import '../../../../core/network/cookie_manager.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/dormitory_info.dart';

final dormitoryServiceProvider = Provider((ref) => DormitoryService());

class DormitoryService {
  final _logger = AppLogger.instance;
  static const String _cacheKey = 'cached_dormitory_info_v1';
  static const int _maxRedirects = 10;

  bool _isRedirect(int? status) =>
      status == 301 ||
      status == 302 ||
      status == 303 ||
      status == 307 ||
      status == 308;

  /// 读取本地缓存的宿舍信息（秒开）
  Future<DormitoryInfo?> getCachedDormitoryInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_cacheKey);
      if (jsonStr == null || jsonStr.isEmpty) return null;
      final map = json.decode(jsonStr) as Map<String, dynamic>;
      return DormitoryInfo.fromJson(map);
    } catch (e) {
      _logger.w('⚠️ Failed to load cached dormitory info: $e');
      return null;
    }
  }

  /// 缓存宿舍数据
  Future<void> saveCachedDormitoryInfo(DormitoryInfo info) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, json.encode(info.toJson()));
    } catch (e) {
      _logger.w('⚠️ Failed to save dormitory info cache: $e');
    }
  }

  /// 清除缓存
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
    } catch (_) {}
  }

  /// 执行超星 OAuth -> 学生公寓管理平台 (gy.hunau.edu.cn) 会话建立流程
  ///
  /// HAR 流程：
  /// Hop 0: auth.chaoxing.com/connect/oauth2/authorize?... -> 302 带 code
  /// Hop 1: gy.hunau.edu.cn/app/content/main/sitemap?... -> 302 换取 JSESSIONID 并跳转 welcome
  /// Hop 2: http://gy.hunau.edu.cn/wap/main/welcome -> 307 HttpsUpgrade
  /// Hop 3: https://gy.hunau.edu.cn/wap/main/welcome -> 200 成功落点
  Future<bool> authenticate() async {
    _logger.i('🚀 Starting authentication for Dormitory platform...');
    try {
      final dio = DioClient().dio;

      // 诊断：检查是否有超星 Cookie
      try {
        final chaoxingCookies = await AppCookieManager()
            .dioCookieJar
            .loadForRequest(Uri.parse('https://auth.chaoxing.com/'));
        _logger.d('🔗 Chaoxing cookies for dorm auth: ${chaoxingCookies.length}');
      } catch (_) {}

      String? currentUrl = AppConstants.dormitoryOAuthUrl;
      String? referer;
      Response? lastResponse;

      for (var hop = 0; hop < _maxRedirects && currentUrl != null; hop++) {
        final response = await dio.get(
          currentUrl,
          options: Options(
            headers: {
              'User-Agent': AppConstants.dormitoryUA,
              'Accept':
                  'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
              'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
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
        final bodyStr = response.data?.toString() ?? '';
        _logger.d('🔗 Dorm auth hop $hop: $status $currentUrl -> $location');
        lastResponse = response;

        // 如果在超星授权页面未重定向，说明超星登录态已失效，回显了登录网页
        if (hop == 0 && status == 200 && (bodyStr.contains('passport2') || bodyStr.contains('login'))) {
          throw const NetworkException('超星统一认证已过期，请重新登录');
        }

        if (_isRedirect(status) && location.isNotEmpty) {
          referer = currentUrl;
          var nextUri = Uri.parse(currentUrl).resolve(location);
          // 若为 http://gy.hunau.edu.cn，直接升为 https
          if (nextUri.scheme == 'http' && nextUri.host == 'gy.hunau.edu.cn') {
            nextUri = nextUri.replace(scheme: 'https');
          }
          currentUrl = nextUri.toString();
          continue;
        }

        // 走到 200 且到达 welcome 或 gy 域名，说明会话建立成功
        if (status == 200) {
          break;
        }

        currentUrl = null;
      }

      final finalUri = lastResponse?.realUri ?? Uri.parse('');
      _logger.i('✅ Dorm auth finished at: $finalUri (status: ${lastResponse?.statusCode})');
      return true;
    } catch (e) {
      _logger.w('⚠️ Dorm auth failed: $e');
      if (e is AppException) rethrow;
      throw NetworkException('宿舍平台认证失败: $e');
    }
  }

  /// 获取我的宿舍/床位信息
  Future<DormitoryInfo> fetchDormitoryInfo({bool forceRefresh = false}) async {
    _logger.i('🛏️ Fetching dormitory info (forceRefresh=$forceRefresh)...');
    final dio = DioClient().dio;

    // 如果不是强制刷新，尝试直接带现有 JSESSIONID 探测拉取
    if (!forceRefresh) {
      try {
        final res = await _requestBedHtml(dio);
        if (_isBedHtmlValid(res)) {
          final info = DormitoryInfo.fromHtml(res.data.toString());
          await saveCachedDormitoryInfo(info);
          return info;
        }
      } catch (e) {
        _logger.d('Direct fetch failed, will authenticate: $e');
      }
    }

    // 重新执行授权认证
    await authenticate();

    // 认证后再次拉取床位信息
    final res = await _requestBedHtml(dio);
    if (!_isBedHtmlValid(res)) {
      throw const NetworkException('未能获取到宿舍床位信息，页面返回异常');
    }

    final info = DormitoryInfo.fromHtml(res.data.toString());
    await saveCachedDormitoryInfo(info);
    _logger.i('✅ Dormitory info fetched successfully: ${info.fullAddress}');
    return info;
  }

  Future<Response> _requestBedHtml(Dio dio) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final url = '${AppConstants.dormitoryBedUrl}?_t_s_=$timestamp';
    return await dio.get(
      url,
      options: Options(
        headers: {
          'User-Agent': AppConstants.dormitoryUA,
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          'Referer': AppConstants.dormitoryWelcomeUrl,
        },
        followRedirects: false,
        validateStatus: (status) => status != null && status < 500,
        responseType: ResponseType.plain,
      ),
    );
  }

  bool _isBedHtmlValid(Response response) {
    if (response.statusCode != 200) return false;
    final content = response.data?.toString() ?? '';
    // 页面若包含床位相关标识或脚本
    return content.contains('我的床位') ||
        content.contains('createRow') ||
        content.contains('SFSchCalendar') ||
        content.contains('wyDorm');
  }
}
