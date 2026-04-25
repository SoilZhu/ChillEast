import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../models/course_model.dart';
import '../parsers/timetable_html_parser.dart';
import '../utils/ics_generator.dart';
import '../services/timetable_storage.dart';
import '../../../core/utils/secure_storage_helper.dart';
import 'package:logger/logger.dart';

class TimetableService {
  final Logger _logger = Logger();
  
  /// 获取课表 HTML (新 WebVPN 登录与抓取逻辑)
  Future<String> fetchTimetableHtml(String semester) async {
    try {
      _logger.i('📅 ========== 开始获取课表 (WebVPN 模式) ==========');
      
      // 1. 获取凭据
      final storage = SecureStorageHelper();
      final username = await storage.getUsername();
      final password = await storage.getPassword();
      
      if (username == null || password == null) {
        throw AuthException('请先登录以保存凭据');
      }

      final completer = Completer<String>();
      bool completed = false;
      bool loginInjected = false;
      bool syncTriggered = false;
      
      // 2. (已优化) 不再执行全局清理，以保护已登录系统的 SSO 会话
      final cookieManager = CookieManager.instance();
      // await cookieManager.deleteAllCookies(); // 👈 这一行是导致其他系统退出的元凶，现已注释
      _logger.d('🚀 Starting fetch without clearing global cookies (preserves SSO)...');
      
      _logger.d('🚀 Initializing isolated HeadlessInAppWebView...');
      
      final headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri('https://webvpn.hunau.edu.cn/http/77777776706e697374686562657374210d1f5a65ff61eaeb37a91a55f196cb76ec58c7'),
        ),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          useHybridComposition: true,
          mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
          userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        ),
        onLoadStart: (controller, url) async {
          _logger.d('🔄 Loading: $url');
        },
        onLoadStop: (controller, url) async {
          if (completed) return;
          final urlString = url?.toString() ?? '';
          _logger.d('🏁 Loaded: $urlString');

          // 3. 检测是否在登录页并进行注入
          if ((urlString.contains('/cas/login') || urlString.contains('sso.hunau.edu.cn')) && !loginInjected) {
            _logger.i('🔑 SSO Login page detected, injecting credentials...');
            
            // 等待页面加载（特别是 iframe）
            await Future.delayed(const Duration(seconds: 2));
            
            final jsUsername = jsonEncode(username);
            final jsPassword = jsonEncode(password);
            
            final injectionResult = await controller.evaluateJavascript(source: '''
              (async function() {
                const sleep = (ms) => new Promise(r => setTimeout(r, ms));
                
                for (let i = 0; i < 15; i++) {
                  console.log('Attempting injection ' + (i+1));
                  
                  const queryInFrames = (selector) => {
                    let el = document.querySelector(selector);
                    if (el) return el;
                    const frames = document.querySelectorAll('iframe');
                    for (let f of frames) {
                      try {
                        let doc = f.contentDocument || f.contentWindow.document;
                        let e = doc.querySelector(selector);
                        if (e) return e;
                      } catch (err) {}
                    }
                    return null;
                  };

                  const userInput = queryInFrames('input.email-username') || queryInFrames('input[name="username"]');
                  const passInput = queryInFrames('input[name="authcode"]') || queryInFrames('input[type="password"]');
                  const loginBtn = queryInFrames('button.exeActionBtn') || queryInFrames('.login-btn');

                  if (userInput && passInput && loginBtn) {
                    userInput.value = $jsUsername;
                    passInput.value = $jsPassword;
                    console.log('Fields filled, clicking login...');
                    loginBtn.click();
                    return 'INJECTED_AND_CLICKED';
                  }
                  await sleep(1000);
                }
                return 'NOT_FOUND';
              })();
            ''');
            
            _logger.d('💉 Injection result: $injectionResult');
            if (injectionResult == 'INJECTED_AND_CLICKED') {
              loginInjected = true;
            }
          }

          // 4. 成功判定：URL 包含 /fusion/ 且 Cookie 包含 wengine_vpn_ticket
          if (urlString.contains('/fusion/') && !syncTriggered) {
             final cookies = await cookieManager.getCookies(url: url!);
             final hasTicket = cookies.any((c) => c.name == 'wengine_vpn_ticketwebvpn_hunau_edu_cn');
             
             if (hasTicket) {
                _logger.i('✅ WebVPN Login Success! Detected ticket cookie.');
                syncTriggered = true;
                
                _logger.i('💡 Reached Fusion portal, waiting for tokens to settle...');
                await Future.delayed(const Duration(seconds: 2));
                
                // 5. 带着 Cookie 访问同步 URL 建立教务会话
                _logger.i('🔄 Step 2: Triggering JWXT session sync...');
                await controller.loadUrl(urlRequest: URLRequest(
                  url: WebUri('https://webvpn.hunau.edu.cn/wengine-vpn/cookie?method=get&host=jwxt.hunau.edu.cn&scheme=http&path=/sso.jsp'),
                ));
             }
          }
          
          // 5. 判定同步接口是否已加载完成
          if (urlString.contains('wengine-vpn/cookie')) {
             _logger.i('💡 Cookie sync done, activating JWXT session via SSO...');
             // 针对教务系统，访问完同步接口后，必须访问其根目录的 sso.jsp 入口才能激活 Session
             await controller.loadUrl(urlRequest: URLRequest(
               url: WebUri('https://webvpn.hunau.edu.cn/http/77777776706e6973746865626573742117075065b065b1ed23b25545bb868160e0/sso.jsp'),
             ));
             return;
          }

          // 6. 判定是否卡在 sso.jsp（Headless 模式下 JS 自动跳转可能失效）
          if (urlString.contains('sso.jsp')) {
             _logger.i('💡 SSO entry reached, forcing JS redirection to framework...');
             // 尝试用 JS 触发跳转，防止某些环境下的自动重定向失效
             await controller.evaluateJavascript(source: "window.location.href = 'framework/xsMainV.jsp';");
             
             // 保底逻辑：3秒后如果还没动，手动 loadUrl
             await Future.delayed(const Duration(seconds: 3));
             var currentUrl = await controller.getUrl();
             if (currentUrl != null && currentUrl.toString().contains('sso.jsp')) {
                _logger.i('💡 SSO still stuck after 3s, manual loadUrl to framework...');
                await controller.loadUrl(urlRequest: URLRequest(
                  url: WebUri('https://webvpn.hunau.edu.cn/http/77777776706e6973746865626573742117075065b065b1ed23b25545bb868160e0/jsxsd/framework/xsMainV.jsp'),
                ));
             }
             return;
          }

          // 7. 判定是否已通过同步并到达教务系统主框架（此时 Session 才真正激活）
          if (!urlString.contains('wengine-vpn/cookie') && !urlString.contains('sso.jsp') &&
              (urlString.contains('framework') || urlString.contains('xsMain'))) {
             
             _logger.i('🚀 JWXT session reached framework, waiting 6s for backend stabilization...');
             
             // 延长等待时间到 6 秒，确保 Session 在教务系统后端完全同步
             await Future.delayed(const Duration(seconds: 6));
             
             // 跳转到最终课表页面
             _logger.i('🚀 Navigating to final timetable URL...');
             await controller.loadUrl(urlRequest: URLRequest(
               url: WebUri('https://webvpn.hunau.edu.cn/http/77777776706e6973746865626573742117075065b065b1ed23b25545bb868160e0/jsxsd/xskb/xskb_list.do?xnxq01id=$semester'),
             ));
          }
          
          // 8. 判定是否到达最终课表页面
          if (urlString.contains('xskb_list.do')) {
            _logger.i('📍 Arrived at timetable page, starting extraction loop...');
            
            // 尝试多次抓取，直到内容符合预期
            for (int attempt = 1; attempt <= 10; attempt++) {
              await Future.delayed(const Duration(seconds: 2));
              
              try {
                final htmlStr = (await controller.getHtml()) ?? '';
                _logger.d('🔍 Extraction attempt $attempt/10, length: ${htmlStr.length}');
                
                // 检查关键标识，确保课表已加载
                if (htmlStr.contains('timetable') || htmlStr.contains('kbcontent') || htmlStr.contains('节次')) {
                  _logger.i('✅ Timetable content successfully fetched! (Length: ${htmlStr.length})');
                  completed = true;
                  completer.complete(htmlStr);
                  return;
                } else if (htmlStr.contains('flag1":2') || htmlStr.contains('请先登录') || htmlStr.contains('请重新登录')) {
                  _logger.w('⚠️ Session not ready yet. Reloading page... (Attempt $attempt)');
                  // 强制刷新页面以唤醒 Session
                  await controller.reload();
                } 
              } catch (e) {
                _logger.e('Failed to extract HTML in attempt $attempt: $e');
              }
            }
            
            if (!completed) {
              _logger.e('❌ Failed after 10 attempts.');
              completed = true;
              completer.completeError(NetworkException('页面加载失败或 Session 激活超时，请稍后重试'));
            }
          }
        },
        onReceivedError: (controller, request, error) {
          _logger.e('❌ WebView error: ${error.description} (URL: ${request.url})');
          if (!completed && request.isForMainFrame == true) {
            completed = true;
            completer.completeError(NetworkException('加载失败: ${error.description}'));
          }
        },
      );

      await headlessWebView.run();
      
      try {
        final result = await completer.future.timeout(
          const Duration(seconds: 120),
          onTimeout: () => throw TimeoutException('获取课表超时'),
        );
        return result;
      } finally {
        await headlessWebView.dispose();
      }
      
    } catch (e) {
      _logger.e('Failed to fetch timetable: $e');
      rethrow;
    }
  }

  
  /// 解析课表 HTML 为课程列表
  List<CourseModel> parseTimetable(String htmlContent) {
    try {
      return TimetableHtmlParser.parseTimetable(htmlContent);
    } catch (e) {
      _logger.e('Failed to parse timetable: $e');
      if (e is ParseException) {
        rethrow;
      }
      throw ParseException('课表解析失败: $e');
    }
  }
  
  /// 获取并解析课表
  Future<List<CourseModel>> getTimetable(String semester) async {
    final html = await fetchTimetableHtml(semester);
    return parseTimetable(html);
  }
  
  /// 执行 CAS SSO 重定向链（复用登录时的 WebVPN Cookie）
  /// 
  /// 根据 HAR 文件分析的完整流程：
  /// 0. 同步 WebVPN Cookie（告诉 WebVPN 我们要访问教务系统）
  /// 1. CAS Login → 返回 Service Ticket (ST)
  /// 2. sso.jsp?ticket=ST → 验证 ST，重定向到 sso.jsp
  /// 3. sso.jsp → 生成 ticket1，重定向到 LoginToXk
  /// 4. LoginToXk?ticket1 → 验证 ticket1，重定向到 xsMainV.jsp
  /// 5. xsMainV.jsp → 会话建立完成
  Future<void> _performCasSsoRedirectChain() async {
    try {
      _logger.d('Starting CAS SSO redirect chain...');
      
      // Step 0: 同步 WebVPN Cookie（关键步骤！）
      _logger.d('Step 0: Syncing WebVPN cookie for jwxt system...');
      await DioClient().dio.get(
        AppConstants.jwxtCookieSyncUrl,
        options: Options(
          headers: {
            'Accept': '*/*',
          },
        ),
      );
      _logger.d('WebVPN cookie synced');
      
      // Step 1: 访问 CAS login，获取 Service Ticket
      _logger.d('Step 1: Requesting CAS login for Service Ticket...');
      final casResponse = await DioClient().dio.get(
        AppConstants.casLoginUrl,
        queryParameters: {
          'service': AppConstants.casServiceForJwxt,
        },
        options: Options(
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
          headers: {
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Referer': AppConstants.jwxtSsoUrl,  // CAS 需要 Referer 验证
          },
        ),
      );
      
      if (casResponse.statusCode != 302) {
        throw NetworkException('CAS 登录失败: HTTP ${casResponse.statusCode}');
      }
      
      // 从 Location 头提取 Service Ticket
      final location = casResponse.headers['location']?.first;
      if (location == null || !location.contains('ticket=')) {
        throw NetworkException('未获取到 CAS Service Ticket');
      }
      
      final ticketMatch = RegExp(r'ticket=([^&]+)').firstMatch(location);
      final serviceTicket = ticketMatch?.group(1);
      if (serviceTicket == null) {
        throw NetworkException('解析 CAS Service Ticket 失败');
      }
      
      _logger.d('Got CAS Service Ticket: ${serviceTicket.substring(0, 20)}...');
      
      // Step 2: 使用 ST 访问 sso.jsp，验证 Ticket
      _logger.d('Step 2: Validating Service Ticket via sso.jsp...');
      final ssoWithTicketUrl = '${AppConstants.jwxtSsoUrl}?ticket=$serviceTicket';
      final ssoResponse = await DioClient().dio.get(
        ssoWithTicketUrl,
        options: Options(
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
          headers: {
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          },
        ),
      );
      
      if (ssoResponse.statusCode != 302) {
        throw NetworkException('SSO Ticket 验证失败: HTTP ${ssoResponse.statusCode}');
      }
      
      _logger.d('Service Ticket validated');
      
      // Step 3: 访问 sso.jsp（无参数），获取 ticket1
      _logger.d('Step 3: Getting ticket1 from sso.jsp...');
      final ssoCleanResponse = await DioClient().dio.get(
        AppConstants.jwxtSsoUrl,
        options: Options(
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
          headers: {
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          },
        ),
      );
      
      if (ssoCleanResponse.statusCode != 302) {
        throw NetworkException('sso.jsp 重定向失败: HTTP ${ssoCleanResponse.statusCode}');
      }
      
      final ssoLocation = ssoCleanResponse.headers['location']?.first;
      if (ssoLocation == null || !ssoLocation.contains('ticket1=')) {
        throw NetworkException('未获取到 ticket1');
      }
      
      final ticket1Match = RegExp(r'ticket1=([^&]+)').firstMatch(ssoLocation);
      final ticket1 = ticket1Match?.group(1);
      if (ticket1 == null) {
        throw NetworkException('解析 ticket1 失败');
      }
      
      _logger.d('Got ticket1: ${ticket1.substring(0, 20)}...');
      
      // Step 4: 使用 ticket1 访问 LoginToXk
      _logger.d('Step 4: Validating ticket1 via LoginToXk...');
      final loginToXkUrl = '${AppConstants.jwxtBaseUrl}/jsxsd/xk/LoginToXk?method=jwxt&ticket1=$ticket1';
      final loginResponse = await DioClient().dio.get(
        loginToXkUrl,
        options: Options(
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
          headers: {
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          },
        ),
      );
      
      if (loginResponse.statusCode != 302) {
        throw NetworkException('LoginToXk 验证失败: HTTP ${loginResponse.statusCode}');
      }
      
      _logger.d('ticket1 validated');
      
      // Step 5: 访问学生主页 xsMainV.jsp，完成会话建立
      _logger.d('Step 5: Loading student homepage...');
      final mainPageUrl = '${AppConstants.jwxtBaseUrl}/jsxsd/framework/xsMainV.jsp';
      final mainPageResponse = await DioClient().dio.get(
        mainPageUrl,
        options: Options(
          headers: {
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          },
        ),
      );
      
      if (mainPageResponse.statusCode != 200) {
        throw NetworkException('学生主页加载失败: HTTP ${mainPageResponse.statusCode}');
      }
      
      _logger.d('Student homepage loaded, session established');
      
    } catch (e) {
      _logger.e('CAS SSO redirect chain failed: $e');
      throw NetworkException('CAS SSO 重定向失败: $e');
    }
  }
  
  /// 下载并保存课表
  /// 
  /// [semester] 学期
  /// [firstWeekMonday] 第一周周一日期
  Future<void> downloadAndSaveTimetable({
    required String semester,
    required DateTime firstWeekMonday,
  }) async {
    try {
      _logger.i('Downloading timetable for semester: $semester');
      
      // 1. 获取 HTML
      final html = await fetchTimetableHtml(semester);
      
      // 2. 解析 HTML
      final courses = TimetableHtmlParser.parseTimetable(html);
      _logger.i('Parsed ${courses.length} courses');
      
      if (courses.isEmpty) {
        throw ParseException('未解析到任何课程');
      }
      
      // 3. 生成 ICS
      final icsContent = IcsGenerator.generate(courses, firstWeekMonday);
      
      // 4. 保存 ICS 文件与课程 JSON
      final storage = TimetableStorage();
      await storage.saveTimetable(icsContent);
      await storage.saveCourseList(courses);
      
      // 5. 保存元数据（学期和第一周周一）
      await storage.saveMetadata(
        semester: semester,
        firstWeekMonday: firstWeekMonday,
      );
      
      _logger.i('Timetable and metadata saved successfully');
    } catch (e) {
      _logger.e('Failed to download and save timetable: $e');
      rethrow;
    }
  }
}
