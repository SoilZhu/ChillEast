import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/dio_client.dart';
import '../models/exam_schedule_model.dart';

/// 考试详情解析结果
class ExamDetailInfo {
  /// 第一个出现的时间（日程显示的主时间）
  final DateTime displayTime;
  /// 所有提取到的时间
  final List<DateTime> allTimes;
  /// 原始时间字符串列表
  final List<String> rawTimeStrs;
  final String? studentName;
  final String? studentId;

  ExamDetailInfo({
    required this.displayTime,
    this.allTimes = const [],
    this.rawTimeStrs = const [],
    this.studentName,
    this.studentId,
  });
}

class ExamService {
  final Logger _logger = Logger();

  static const String examListUrl =
      'https://mooc1-api.chaoxing.com/exam-ans/exam/phone/examcode?';
  static const String _hostPrefix = 'https://mooc1-api.chaoxing.com';

  /// 解析考试列表 HTML
  List<Map<String, String>> parseExamListHtml(String html) {
    final document = html_parser.parse(html);
    final List<dom.Element> listItems =
        document.querySelectorAll('ul.ks_list li, .ks_list li, li[data*="task-exam"]');

    final List<Map<String, String>> items = [];

    for (final li in listItems) {
      final rawData = li.attributes['data']?.trim() ?? '';
      if (rawData.isEmpty) continue;

      final dataUrl = rawData.startsWith('http')
          ? rawData
          : (rawData.startsWith('/') ? '$_hostPrefix$rawData' : '$_hostPrefix/$rawData');

      // 提取标题：优先 title 属性，其次 dt 标签文本
      String title = li.attributes['title']?.trim() ?? '';
      if (title.isEmpty) {
        final dt = li.querySelector('dt');
        if (dt != null) {
          title = dt.text.trim();
        }
      }

      // 提取状态（如 "已完成", "未交", "进行中" 等）
      final stateElem = li.querySelector('.ks_state');
      final status = stateElem?.text.trim() ?? '';

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
      });
    }

    return items;
  }

  /// 解析包含 <div id="watermark-wrapper" class="watermark-wrapper"></div> 的考试详情 HTML
  /// 
  /// 规则：
  /// 提取 watermark 区域里的所有时间，均可添加到日程中缓存；
  /// 时间严格显示为第一个出现的时间（displayTime = allTimes.first）。
  ExamDetailInfo? parseExamDetailHtml(String html) {
    final document = html_parser.parse(html);

    // 1. 查找 watermark-wrapper 容器
    final dom.Element? wmElement = document.querySelector(
      '#watermark-wrapper, .watermark-wrapper',
    );

    // 寻找信息包含块：通常是 watermark 所在父容器 (div.result_gray_div 等)
    dom.Element? targetContainer = wmElement?.parent;
    // 兼容兜底：如果没找到 watermark-wrapper，尝试找 result_gray_div
    targetContainer ??= document.querySelector('.result_gray_div');

    if (targetContainer == null) {
      return null;
    }

    // 2. 提取文本内容
    final containerText = targetContainer.text;

    // 3. 正则提取日期时间：如 2026-05-10 17:00 或 2026-05-10 17:00:00
    final timePattern = RegExp(r'\b\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}(?::\d{2})?\b');
    final matches = timePattern.allMatches(containerText);

    final List<String> rawTimeStrs = [];
    final List<DateTime> allTimes = [];

    for (final m in matches) {
      final str = m.group(0)!;
      final parsed = _parseDateTimeString(str);
      if (parsed != null) {
        rawTimeStrs.add(str);
        allTimes.add(parsed);
      }
    }

    if (allTimes.isEmpty) {
      return null;
    }

    // 4. 时间显示为第一个出现的时间
    final DateTime displayTime = allTimes.first;

    // 5. 提取姓名和学号（可选展示）
    String? studentName;
    String? studentId;
    final nameMatch = RegExp(r'姓名[：:]\s*([^\s<]+)').firstMatch(containerText);
    if (nameMatch != null) {
      studentName = nameMatch.group(1)?.trim();
    }
    final idMatch = RegExp(r'学号[：:]\s*([^\s<]+)').firstMatch(containerText);
    if (idMatch != null) {
      studentId = idMatch.group(1)?.trim();
    }

    return ExamDetailInfo(
      displayTime: displayTime,
      allTimes: allTimes,
      rawTimeStrs: rawTimeStrs,
      studentName: studentName,
      studentId: studentId,
    );
  }

  /// 抓取考试日程（全部加入日程，并利用已缓存数据避免重复请求）
  Future<List<ExamScheduleModel>> fetchExams({
    List<ExamScheduleModel>? cachedExams,
  }) async {
    try {
      _logger.i('📝 Fetching exam list from $examListUrl');

      final response = await DioClient().dio.get(
        examListUrl,
        options: Options(
          headers: {
            'User-Agent': AppConstants.campusCardUA,
          },
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch exam list: ${response.statusCode}');
      }

      final items = parseExamListHtml(response.data.toString());
      _logger.i('📋 Found ${items.length} exams in exam list');

      final Map<String, ExamScheduleModel> cachedMap = {
        for (final e in cachedExams ?? <ExamScheduleModel>[]) e.id: e,
      };

      final List<ExamScheduleModel> examResults = [];
      final List<Map<String, String>> pendingItems = [];

      for (final item in items) {
        final id = item['id'] ?? '';
        final cached = cachedMap[id];
        // 如果已有缓存且已有时间，优先复用已缓存数据
        if (cached != null && cached.allTimes.isNotEmpty) {
          // 如果列表上的状态更新了，同步更新状态
          final newStatus = item['status'] ?? '';
          if (newStatus.isNotEmpty && newStatus != cached.status) {
            examResults.add(cached.copyWith(status: newStatus));
          } else {
            examResults.add(cached);
          }
        } else {
          pendingItems.add(item);
        }
      }

      // 控制并发拉取新条目的详情（每批 5 个）
      const batchSize = 5;
      for (int i = 0; i < pendingItems.length; i += batchSize) {
        final batch = pendingItems.skip(i).take(batchSize).toList();
        await Future.wait(
          batch.map((item) async {
            final id = item['id'] ?? '';
            final title = item['title'] ?? '';
            final dataUrl = item['dataUrl'] ?? '';
            final status = item['status'] ?? '';

            try {
              final detailResp = await DioClient().dio.get(
                dataUrl,
                options: Options(
                  headers: {
                    'User-Agent': AppConstants.campusCardUA,
                  },
                ),
              );

              if (detailResp.statusCode == 200) {
                final detailInfo = parseExamDetailHtml(detailResp.data.toString());

                if (detailInfo != null) {
                  examResults.add(
                    ExamScheduleModel(
                      id: id,
                      title: title,
                      time: detailInfo.displayTime,
                      allTimes: detailInfo.allTimes,
                      rawTimeStrs: detailInfo.rawTimeStrs,
                      detailUrl: dataUrl,
                      status: status,
                      studentName: detailInfo.studentName,
                      studentId: detailInfo.studentId,
                      createdAt: DateTime.now(),
                    ),
                  );
                }
              }
            } catch (e) {
              _logger.w('Failed to fetch detail for exam $title ($id): $e');
            }
          }),
        );
      }

      // 按时间升序排序（时间早的在前面，符合日程时间轴顺序）
      examResults.sort((a, b) => a.time.compareTo(b.time));

      _logger.i('✅ Processed ${examResults.length} exams in schedule');
      return examResults;
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
  DateTime? _parseDateTimeString(String str) {
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
}
