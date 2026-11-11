import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../../../core/network/dio_client.dart';
import '../models/exam_schedule_model.dart';
import 'exam_storage.dart';

/// 考试详情解析结果
class ExamDetailInfo {
  /// 第一个出现的时间，一律视为开始时间
  final DateTime startTime;

  /// 第二个出现的时间，一律视为结束时间（若有）
  final DateTime? endTime;

  /// 第一个出现的时间（兼容原有 displayTime）
  DateTime get displayTime => startTime;

  /// 所有提取到的时间
  final List<DateTime> allTimes;

  /// 原始时间字符串列表
  final List<String> rawTimeStrs;
  final String? studentName;
  final String? studentId;

  ExamDetailInfo({
    DateTime? startTime,
    DateTime? displayTime,
    this.endTime,
    this.allTimes = const [],
    this.rawTimeStrs = const [],
    this.studentName,
    this.studentId,
  })  : assert(startTime != null || displayTime != null, 'Either startTime or displayTime must be provided'),
        startTime = (startTime ?? displayTime)!;
}

class ExamService {
  final Logger _logger = Logger();

  static const String examListUrl =
      'https://mooc1-api.chaoxing.com/exam-ans/exam/phone/examcode';
  static const String _hostPrefix = 'https://mooc1-api.chaoxing.com';

  /// 超星学习通移动客户端 UA（与实际手机抓包 HAR 保持 100% 一致）
  static const String mobileUA =
      'Mozilla/5.0 (Linux; Android 16; MEIZU 20 Build/BQ2A.251110.001-BP2A.250605.031.A3; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/155.0.8059.43 Mobile Safari/537.36 (schild:94342b5e107aeed65313b309549c3a02) (device:MEIZU 20) Language/zh_CN com.chaoxing.mobile/ChaoXingStudy_3_7.0.4_android_phone_10995_342 (@Kalimdor)_66634f1642df476caf21e176ce4751ba';

  /// 别名保持兼容
  static const String browserUA = mobileUA;

  static const Map<String, String> examListHeaders = {
    'Connection': 'keep-alive',
    'Upgrade-Insecure-Requests': '1',
    'User-Agent': mobileUA,
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/jxl,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
    'accept-language': 'zh_CN',
    'X-Requested-With': 'com.chaoxing.mobile',
    'Sec-Fetch-Site': 'none',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-User': '?1',
    'Sec-Fetch-Dest': 'document',
    'sec-ch-ua':
        '"Android WebView";v="155", "Chromium";v="155", "Not(A:Brand";v="24"',
    'sec-ch-ua-mobile': '?1',
    'sec-ch-ua-platform': '"Android"',
  };

  static const Map<String, String> examDetailHeaders = {
    'Connection': 'keep-alive',
    'Upgrade-Insecure-Requests': '1',
    'User-Agent': mobileUA,
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/jxl,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
    'accept-language': 'zh_CN',
    'X-Requested-With': 'com.chaoxing.mobile',
    'Referer': examListUrl,
    'Sec-Fetch-Site': 'same-origin',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-User': '?1',
    'Sec-Fetch-Dest': 'document',
    'sec-ch-ua':
        '"Android WebView";v="155", "Chromium";v="155", "Not(A:Brand";v="24"',
    'sec-ch-ua-mobile': '?1',
    'sec-ch-ua-platform': '"Android"',
  };

  /// 构造规范的 task-exam URL（补全 host、ut=s，保留 fragment）
  static String buildTaskExamUrl(String rawData) {
    var url = rawData.trim();
    if (!url.startsWith('http')) {
      url = url.startsWith('/') ? '$_hostPrefix$url' : '$_hostPrefix/$url';
    }
    // 保留 fragment（如 #INNER）
    final parts = url.split('#');
    var base = parts.first;
    final fragment = parts.length > 1 ? parts.sublist(1).join('#') : null;

    try {
      final uri = Uri.parse(base);
      if (!uri.queryParameters.containsKey('ut')) {
        final newParams = Map<String, String>.from(uri.queryParameters);
        newParams['ut'] = 's';
        base = uri.replace(queryParameters: newParams).toString();
      }
    } catch (_) {}
    return fragment != null ? '$base#$fragment' : base;
  }

  /// 解析考试列表 HTML
  List<Map<String, String>> parseExamListHtml(String html) {
    final document = html_parser.parse(html);
    final List<dom.Element> listItems =
        document.querySelectorAll('ul.ks_list li, .ks_list li, li[data*="task-exam"]');

    final List<Map<String, String>> items = [];

    for (final li in listItems) {
      final rawData = li.attributes['data']?.trim() ?? '';
      if (rawData.isEmpty) continue;

      final dataUrl = buildTaskExamUrl(rawData);

      // 提取标题：优先 title 属性，其次 dt 标签文本，最后从 aria-label 中提取
      String title = li.attributes['title']?.trim() ?? '';
      if (title.isEmpty) {
        final dt = li.querySelector('dt');
        if (dt != null) {
          title = dt.text.trim();
        }
      }
      if (title.isEmpty) {
        final aria = li.querySelector('dl.ks_text')?.attributes['aria-label'] ?? '';
        final m = RegExp(r'考试名称[：:]\s*([^;]+)').firstMatch(aria);
        if (m != null) {
          title = m.group(1)?.trim() ?? '';
        }
      }

      // 提取状态（如 "已完成", "未交", "进行中" 等）
      final stateElem = li.querySelector('.ks_state');
      String status = stateElem?.text.trim() ?? '';
      if (status.isEmpty) {
        final aria = li.querySelector('dl.ks_text')?.attributes['aria-label'] ?? '';
        final m = RegExp(r'考试状态[：:]\s*([^;]+)').firstMatch(aria);
        if (m != null) {
          status = m.group(1)?.trim() ?? '';
        }
      }

      // 是否暂未开放
      final stopExam = li.attributes['data-stopexam']?.trim() ?? '0';

      // 提取唯一 ID：优先从 URL 中解析 taskrefId 或 examId
      String id = '';
      try {
        final uri = Uri.parse(dataUrl);
        id = uri.queryParameters['taskrefId'] ??
            uri.queryParameters['examId'] ??
            '';
      } catch (_) {}

      if (id.isEmpty) {
        id = dataUrl;
      }

      items.add({
        'id': id,
        'title': title,
        'dataUrl': dataUrl,
        'status': status,
        'stopExam': stopExam,
      });
    }

    return items;
  }

  /// 获取单个考试的详情页面 HTML 和最终 lookUrl
  ///
  /// 请求链路：
  /// 直接携带 Cookie 和浏览器 Headers 请求 task-exam（来自列表项中的 data 属性并追加 &ut=s），
  /// 自动跟随 302 重定向直达 look 试卷页面，获取最终 200 OK HTML。
  Future<({String html, String finalUrl})?> fetchExamDetailContent(
    String taskUrl, {
    Dio? dioClient,
  }) async {
    final client = dioClient ?? DioClient().dio;
    const headers = examDetailHeaders;

    try {
      // 直接带 cookie 请求 task-exam，自动跟随 302 重定向到 look 试卷页面
      final response = await client.get(
        taskUrl,
        options: Options(
          followRedirects: true,
          maxRedirects: 5,
          validateStatus: (status) => status != null && status < 500,
          headers: headers,
          responseType: ResponseType.plain,
        ),
      );

      if (response.statusCode == 200) {
        return (
          html: response.data.toString(),
          finalUrl: response.realUri.toString(),
        );
      }

      // 兼容兜底：若特定环境（如 mock/测试拦截器）阻止了底层自动重定向，则从 location 获取 lookUrl
      if (response.statusCode != null &&
          response.statusCode! >= 300 &&
          response.statusCode! < 400) {
        final location = response.headers.value('location');
        if (location != null && location.isNotEmpty) {
          var lookUrl = location.trim();
          if (!lookUrl.startsWith('http')) {
            lookUrl = lookUrl.startsWith('/')
                ? '$_hostPrefix$lookUrl'
                : '$_hostPrefix/$lookUrl';
          }
          final lookResp = await client.get(
            lookUrl,
            options: Options(
              followRedirects: true,
              headers: headers,
              responseType: ResponseType.plain,
              validateStatus: (status) => status != null && status < 500,
            ),
          );
          if (lookResp.statusCode == 200) {
            return (html: lookResp.data.toString(), finalUrl: lookUrl);
          }
        }
      }
    } catch (e) {
      _logger.w('Failed to fetch exam detail from $taskUrl: $e');
    }

    return null;
  }

  /// 排除页面中的 dynamicNowTime（超星试卷页面的顶部动态服务器时钟，避免被误提取为考试时间）
  static void excludeDynamicNowTime(dom.Document document) {
    document
        .querySelectorAll('#dynamicNowTime, .dynamicNowTime, .paper_time')
        .forEach((el) => el.remove());
  }

  /// 解析包含 <div id="watermark-wrapper" class="watermark-wrapper"></div> 的考试详情 HTML
  /// 
  /// 规则：
  /// 严格在 watermark-wrapper 紧邻的 <div style="position:relative;z-index:100"> 区域提取：
  /// - 领取时间 ➔ 开始时间 (startTime)
  /// - 提交时间 ➔ 结束时间 (endTime)
  /// - 姓名、学号等学生信息
  /// - 额外排除页面上的 dynamicNowTime 动态时间
  ExamDetailInfo? parseExamDetailHtml(String html) {
    final document = html_parser.parse(html);

    // 0. 明确排除 dynamicNowTime（超星试卷页面的顶部动态服务器时钟）
    excludeDynamicNowTime(document);

    // 1. 定位 watermark-wrapper 元素
    final dom.Element? wmElement = document.querySelector(
      '#watermark-wrapper, .watermark-wrapper',
    );

    // 2. 严格定位其同级或父容器下的 <div style="position:relative;z-index:100"> 详情信息块
    dom.Element? targetContainer;

    if (wmElement != null) {
      // 优先从同一父容器下的后续兄弟节点寻找含有 z-index:100 的 div
      var sibling = wmElement.nextElementSibling;
      while (sibling != null) {
        final style = sibling.attributes['style'] ?? '';
        if (style.replaceAll(' ', '').contains('z-index:100') ||
            style.contains('z-index')) {
          targetContainer = sibling;
          break;
        }
        sibling = sibling.nextElementSibling;
      }

      // 若未在同级兄弟节点找到，在父容器内部寻找
      if (targetContainer == null && wmElement.parent != null) {
        targetContainer = wmElement.parent!.querySelector(
          'div[style*="z-index:100"], div[style*="z-index: 100"], div[style*="z-index"]',
        );
      }
    }

    // 兜底定位：查找页面上 z-index 为 100 的 div
    targetContainer ??= document.querySelector(
      'div[style*="z-index:100"], div[style*="z-index: 100"]',
    );

    final String containerText = targetContainer?.text ?? '';
    // 若未定位到容器，搜索范围使用去除 dynamicNowTime 后的文档文本，绝不使用含 dynamicNowTime 的原始 html
    final String searchScope =
        containerText.isNotEmpty ? containerText : (document.body?.text ?? '');

    // 3. 严格针对“领取时间”和“提交时间”进行提取
    // 兼容可能存在的 HTML 标签和 span.din.font16
    final startMatch = RegExp(
      r'领取时间[：:]\s*(?:<[^>]+>\s*)*(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}(?::\d{2})?)',
    ).firstMatch(searchScope);

    final endMatch = RegExp(
      r'提交时间[：:]\s*(?:<[^>]+>\s*)*(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}(?::\d{2})?)',
    ).firstMatch(searchScope);

    DateTime? startTime;
    DateTime? endTime;
    final List<String> rawTimeStrs = [];
    final List<DateTime> allTimes = [];

    if (startMatch != null) {
      final sStr = startMatch.group(1)!;
      final parsed = _parseDateTimeString(sStr);
      if (parsed != null) {
        startTime = parsed;
        rawTimeStrs.add(sStr);
        allTimes.add(parsed);
      }
    }

    if (endMatch != null) {
      final eStr = endMatch.group(1)!;
      final parsed = _parseDateTimeString(eStr);
      if (parsed != null) {
        endTime = parsed;
        rawTimeStrs.add(eStr);
        allTimes.add(parsed);
      }
    }

    // 顺序提取兜底：若未识别到“领取时间/提交时间”文字，但容器内有时间，以第一/第二个出现的时间作为开始/结束时间
    if (startTime == null && targetContainer != null) {
      final timePattern = RegExp(r'\b\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}(?::\d{2})?\b');
      final matches = timePattern.allMatches(targetContainer.text);
      for (final m in matches) {
        final str = m.group(0)!;
        final parsed = _parseDateTimeString(str);
        if (parsed != null) {
          rawTimeStrs.add(str);
          allTimes.add(parsed);
        }
      }
      if (allTimes.isNotEmpty) {
        startTime = allTimes.first;
        endTime = allTimes.length > 1 ? allTimes[1] : null;
      }
    }

    if (startTime == null) {
      return null;
    }

    // 4. 提取姓名和学号
    String? studentName;
    String? studentId;
    final nameMatch = RegExp(r'姓名[：:]\s*([^\s<]+)').firstMatch(searchScope);
    if (nameMatch != null) {
      studentName = nameMatch.group(1)?.trim();
    }
    final idMatch = RegExp(r'学号[：:]\s*([^\s<]+)').firstMatch(searchScope);
    if (idMatch != null) {
      studentId = idMatch.group(1)?.trim();
    }

    return ExamDetailInfo(
      startTime: startTime,
      endTime: endTime,
      allTimes: allTimes,
      rawTimeStrs: rawTimeStrs,
      studentName: studentName,
      studentId: studentId,
    );
  }

  /// 判断考试状态是否属于“未完成”或“待开始”
  static bool isPendingOrUnfinished(String status) {
    final s = status.trim();
    if (s.isEmpty) return false;
    // 明确排除已完成、已结束的考试状态
    if (s == '已完成' ||
        s == '已结束' ||
        s.contains('已完成') ||
        s.contains('已结束')) {
      return false;
    }
    return s == '未开始' ||
        s == '进行中' ||
        s == '未交' ||
        s == '待考' ||
        s == '待考试' ||
        s == '考试中' ||
        s.contains('未开始') ||
        s.contains('进行') ||
        s.contains('待考') ||
        s.contains('未交');
  }

  /// 兼容别名
  static bool isNotStartedOrInProgress(String status) =>
      isPendingOrUnfinished(status);

  /// 抓取考试日程（强行从超星云端同步，仅获取和储存未完成与待开始的考试）
  Future<List<ExamScheduleModel>> fetchExams({
    List<ExamScheduleModel>? cachedExams,
    Dio? dioClient,
  }) async {
    final client = dioClient ?? DioClient().dio;
    try {
      _logger.i('📝 Fetching exam list from $examListUrl');

      final response = await client.get(
        examListUrl,
        options: Options(
          headers: examListHeaders,
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final realUriStr = response.realUri.toString();
      if (realUriStr.contains('antispider') || response.statusCode == 202) {
        throw Exception('触发了超星安全验证');
      }

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch exam list: ${response.statusCode}');
      }

      final items = parseExamListHtml(response.data.toString());
      _logger.i('📋 Found ${items.length} exams in total from cloud');

      // 仅获取和储存“未完成”（进行中、未交）和“待开始”（未开始、待考）的考试
      // 已完成/已结束的历史考试直接忽略，不拉取详情，也不存入本地数据库
      final targetItems = items.where((item) {
        final status = item['status'] ?? '';
        return isPendingOrUnfinished(status);
      }).toList();

      _logger.i('🎯 Filtered ${targetItems.length} pending/unfinished exams to sync');

      final List<ExamScheduleModel> examResults = [];
      int fetchedDetailCount = 0;

      for (int i = 0; i < targetItems.length; i++) {
        final item = targetItems[i];
        final id = item['id'] ?? '';
        final title = item['title'] ?? '';
        final taskUrl = item['dataUrl'] ?? '';
        final status = item['status'] ?? '';

        if (fetchedDetailCount > 0) {
          await Future.delayed(const Duration(milliseconds: 350));
        }
        fetchedDetailCount++;

        try {
          final contentResult =
              await fetchExamDetailContent(taskUrl, dioClient: client);
          if (contentResult != null) {
            final detailInfo = parseExamDetailHtml(contentResult.html);
            if (detailInfo != null) {
              examResults.add(
                ExamScheduleModel(
                  id: id,
                  title: title,
                  time: detailInfo.startTime,
                  endTime: detailInfo.endTime,
                  allTimes: detailInfo.allTimes,
                  rawTimeStrs: detailInfo.rawTimeStrs,
                  detailUrl: contentResult.finalUrl,
                  status: status,
                  studentName: detailInfo.studentName,
                  studentId: detailInfo.studentId,
                  createdAt: DateTime.now(),
                ),
              );
              continue;
            } else {
              _logger.i('ℹ️ 详情页未提取到时间，作为未定时间考试入库: $title ($id)');
            }
          }
        } catch (e) {
          _logger.w('Failed to fetch detail for exam $title ($id): $e');
        }

        // 如果的确没有提取到时间，直接作为未定时间的考试显示在考试安排里，不需要有时间
        examResults.add(
          ExamScheduleModel(
            id: id,
            title: title,
            time: null,
            detailUrl: taskUrl,
            status: status,
            createdAt: DateTime.now(),
          ),
        );
      }

      // 始终只储存开始时间是今天以及今天之后日期的考试（无时间的考试直接保留）
      final validResults = ExamStorage.filterUpcomingAndToday(examResults);
      validResults.sort(ExamScheduleModel.compareTime);

      _logger.i('✅ Successfully synced ${validResults.length} exams from cloud');
      return validResults;
    } catch (e) {
      _logger.e('❌ Fetch exams failed: $e');
      rethrow;
    }
  }

  /// 兼容接口：委托给 fetchExams
  Future<List<ExamScheduleModel>> fetchUpcomingExams({
    List<ExamScheduleModel>? cachedExams,
    Set<String>? cachedExpiredIds,
    DateTime? referenceTime,
  }) =>
      fetchExams(cachedExams: cachedExams);

  /// 日期时间字符串解析
  static DateTime? parseDateTimeString(String str) {
    final clean = str.trim();
    try {
      return DateFormat('yyyy-MM-dd HH:mm:ss').parse(clean);
    } catch (_) {
      try {
        return DateFormat('yyyy-MM-dd HH:mm').parse(clean);
      } catch (_) {
        try {
          return DateTime.tryParse(clean.replaceFirst(' ', 'T'));
        } catch (_) {
          return null;
        }
      }
    }
  }

  DateTime? _parseDateTimeString(String str) => parseDateTimeString(str);
}
