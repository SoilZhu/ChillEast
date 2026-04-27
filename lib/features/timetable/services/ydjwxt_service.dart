import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/cookie_manager.dart';
import '../../../core/utils/app_logger.dart';
import '../models/course_model.dart';
import '../parsers/ydjwxt_json_parser.dart';
import '../services/timetable_storage.dart';
import '../utils/ics_generator.dart';

class YdjwxtService {
  final _logger = AppLogger.instance;
  String? _token;

  /// 全自动同步课表
  /// 
  /// [onProgress] 进度回调
  /// [firstWeekMonday] 本学期第一周周一 (可选，若不传则从 API 自动解析)
  Future<void> syncTimetable({
    required Function(String progress) onProgress,
    DateTime? firstWeekMonday,
  }) async {
    try {
      _logger.i('🚀 Starting automatic timetable sync (YDJWXT)...');
      
      // 1. 获取 Token
      onProgress('正在进行身份验证...');
      _token = await _authenticate();
      
      if (_token == null) {
        throw Exception('身份验证失败，未能获取 Token。请确保已在首页登录。');
      }
      
      _logger.i('✅ Token acquired, starting data fetch...');

      // 2. 预检：确定第一周周一的日期 (如果外部未提供)
      DateTime? calculatedFirstWeekMonday = firstWeekMonday;
      
      if (calculatedFirstWeekMonday == null) {
        onProgress('正在校准学期时间...');
        // 随便请求一周的数据（例如第一周）来获取日期参考
        final rawJson = await _fetchRawWeekJson(1);
        calculatedFirstWeekMonday = YdjwxtJsonParser.extractFirstWeekMonday(rawJson);
        _logger.i('📅 Automatically calculated firstWeekMonday: $calculatedFirstWeekMonday');
      }

      if (calculatedFirstWeekMonday == null) {
        // 如果 API 解析失败，尝试从本地读取作为兜底
        final metadata = await TimetableStorage().readMetadata();
        if (metadata != null && metadata['firstWeekMonday'] != null) {
          calculatedFirstWeekMonday = DateTime.parse(metadata['firstWeekMonday']);
          _logger.i('📅 Using cached firstWeekMonday as fallback: $calculatedFirstWeekMonday');
        } else {
          // 最后的最后，使用系统月份猜测 (兜底中的兜底)
          calculatedFirstWeekMonday = _guessFirstWeekMonday();
          _logger.w('📅 Using guessed firstWeekMonday: $calculatedFirstWeekMonday');
        }
      }

      // 3. 并发获取 1-20 周的数据
      onProgress('正在同步全学期课表...');
      final fetchTasks = <Future<Map<String, dynamic>>>[];
      for (int i = 1; i <= 20; i++) {
        fetchTasks.add(_fetchRawWeekJson(i));
      }
      
      final results = await Future.wait(fetchTasks);
      
      final allWeeksData = <List<CourseModel>>[];
      for (var rawJson in results) {
        final weekData = YdjwxtJsonParser.parseWeekJson(rawJson);
        allWeeksData.add(weekData);
      }
      
      // 4. 解析与合并
      onProgress('正在整理课程数据...');
      final mergedCourses = YdjwxtJsonParser.mergeWeeks(allWeeksData);
      _logger.i('✨ Total unique courses merged: ${mergedCourses.length}');
      
      if (mergedCourses.isEmpty) {
        throw Exception('未能获取到有效的课程数据，请确认本学期是否有课。');
      }

      // 5. 生成并保存结果
      onProgress('正在保存到本地...');
      
      // 生成 ICS
      final icsContent = IcsGenerator.generate(mergedCourses, calculatedFirstWeekMonday);
      
      // 保存
      final storage = TimetableStorage();
      await storage.saveTimetable(icsContent);
      await storage.saveCourseList(mergedCourses);
      
      // 保存元数据
      await storage.saveMetadata(
        semester: AppConstants.defaultSemester,
        firstWeekMonday: calculatedFirstWeekMonday,
      );
      
      onProgress('同步成功！已更新 ${mergedCourses.length} 门课程');
      _logger.i('🎉 YDJWXT Sync Completed successfully.');
      
    } catch (e) {
      _logger.e('❌ YDJWXT sync failed: $e');
      rethrow;
    }
  }

  /// 猜测开学日期 (兜底逻辑)
  DateTime _guessFirstWeekMonday() {
    final now = DateTime.now();
    DateTime guess;
    if (now.month >= 8 || now.month <= 1) {
      guess = DateTime(now.month <= 1 ? now.year - 1 : now.year, 9, 1);
    } else {
      guess = DateTime(now.year, 2, 17);
    }
    // 归一化到周一
    while (guess.weekday != DateTime.monday) {
      guess = guess.add(const Duration(days: 1));
    }
    return guess;
  }

  /// 身份验证并提取 Token
  Future<String?> _authenticate() async {
    final completer = Completer<String?>();
    HeadlessInAppWebView? webView;
    Timer? timeoutTimer;

    try {
      await AppCookieManager().injectAllChaoxingCookies();

      webView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(AppConstants.ydjwxtOAuthUrl)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          userAgent: AppConstants.ydjwxtUA,
          useShouldInterceptRequest: true,
        ),
        onLoadStop: (controller, url) async {
          final token = await controller.evaluateJavascript(source: '''
            (function() {
              return localStorage.getItem('token') || 
                     sessionStorage.getItem('token') || 
                     localStorage.getItem('access_token') || '';
            })()
          ''');
          if (token != null && token.toString().isNotEmpty && token.toString().length > 20) {
            if (!completer.isCompleted) completer.complete(token.toString());
          }
        },
        shouldInterceptRequest: (controller, request) async {
          final headers = request.headers;
          if (headers != null) {
            final token = headers['token'] ?? headers['Token'] ?? headers['authorization'] ?? headers['Authorization'];
            if (token != null && token.isNotEmpty && token.length > 20) {
              if (!token.startsWith('Basic') && !token.startsWith('Bearer ')) {
                 if (!completer.isCompleted) completer.complete(token);
              } else if (token.startsWith('Bearer ')) {
                 final cleanToken = token.replaceFirst('Bearer ', '');
                 if (!completer.isCompleted) completer.complete(cleanToken);
              }
            }
          }
          return null;
        }
      );

      await webView.run();
      timeoutTimer = Timer(const Duration(seconds: 45), () {
        if (!completer.isCompleted) completer.completeError(TimeoutException('身份验证超时'));
      });

      return await completer.future;
    } catch (e) {
      _logger.e('Authentication error: $e');
      return null;
    } finally {
      timeoutTimer?.cancel();
      webView?.dispose();
    }
  }

  /// 获取单周课表原始 JSON
  Future<Map<String, dynamic>> _fetchRawWeekJson(int week) async {
    if (_token == null) throw Exception('Token is null');
    
    final dio = DioClient().dio;
    final url = '${AppConstants.ydjwxtApiUrl}?week=$week&kbjcmsid=';
    
    final response = await dio.post(
      url,
      options: Options(
        headers: {
          'token': _token,
          'User-Agent': AppConstants.ydjwxtUA,
          'Referer': 'https://ydjwxt.hunau.edu.cn/hnnydx/',
          'Accept': 'application/json, text/plain, */*',
          'Origin': 'https://ydjwxt.hunau.edu.cn',
          'Content-Type': 'application/json',
        },
      ),
    );

    if (response.statusCode == 200 && response.data != null) {
      final rawData = response.data;
      if (rawData is Map<String, dynamic>) {
        return rawData;
      }
    }
    
    throw Exception('HTTP ${response.statusCode} while fetching week $week');
  }
}
