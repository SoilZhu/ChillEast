import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:intl/intl.dart';
import '../../../core/network/dio_client.dart';
import '../models/homework_model.dart';
import 'package:logger/logger.dart';

class HomeworkService {
  final Logger _logger = Logger();
  static const String _homeworkUrl = 'https://mooc1-api.chaoxing.com/mooc-ans/work/stu-work';

  /// 抓取并同步最新的作业（带着 Cookie 直接爬取 HTML）
  Future<List<HomeworkModel>> fetchHomeworkList(String studentId) async {
    try {
      _logger.i('📝 Fetching homework list from HTML for: $studentId');
      
      final response = await DioClient().dio.get(_homeworkUrl);
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch homework: ${response.statusCode}');
      }

      final document = html_parser.parse(response.data);
      final List<dom.Element> listItems = document.querySelectorAll('li[onclick^="goTask"]');
      
      List<HomeworkModel> results = [];
      final now = DateTime.now();

      for (var li in listItems) {
        try {
          final dataUrl = li.attributes['data'] ?? '';
          final imgPath = li.querySelector('.spanImg img')?.attributes['src'] ?? '';
          final isGray = imgPath.contains('task-work-gray.png');
          
          final contentDiv = li.querySelector('div[role="option"]');
          if (contentDiv == null) continue;

          final title = contentDiv.querySelector('p')?.text.trim() ?? '';
          final statusText = contentDiv.querySelector('span.status')?.text.trim() ?? 
                            contentDiv.querySelectorAll('span').firstWhere((e) => !e.attributes.containsKey('class'), orElse: () => dom.Element.tag('span')).text.trim();
          
          // 找到课程名和剩余时间
          String courseName = '';
          String remainTimeStr = '';
          
          final spans = contentDiv.querySelectorAll('span');
          for (var span in spans) {
            final text = span.text.trim();
            if (text.startsWith('《') && text.endsWith('》')) {
              courseName = text;
            } else if (text.contains('剩余') || text.contains('小时') || text.contains('分钟')) {
              remainTimeStr = text;
            }
          }

          // 核心判断逻辑
          // 1. 状态不是“未提交” -> 已完成
          // 2. 状态是“未提交” + task-work.png + 有时间 -> 未完成
          // 3. 状态是“未提交” + (task-work-gray.png 或 无时间) -> 存档
          
          HomeworkStatus status;
          if (statusText != '未提交') {
            status = HomeworkStatus.completed;
          } else {
            if (!isGray && remainTimeStr.isNotEmpty) {
              status = HomeworkStatus.pending;
            } else {
              status = HomeworkStatus.archived;
            }
          }

          // 解析时间：剩余194小时34分钟 -> DateTime
          DateTime? endTime;
          if (remainTimeStr.isNotEmpty) {
            endTime = _parseRemainTime(remainTimeStr, now);
          }

          // 生成 ID (使用 dataUrl 的 hash 或者直接使用 dataUrl)
          final id = dataUrl.isNotEmpty ? dataUrl : '$courseName|$title';

          // 转换 URL 格式
          final finalUrl = _transformDataUrl(dataUrl);

          results.add(HomeworkModel(
            id: id,
            courseName: courseName,
            title: title,
            endTime: endTime,
            status: status,
            studentId: studentId,
            rawTimeStr: remainTimeStr,
            dataUrl: finalUrl,
          ));
        } catch (e) {
          _logger.w('Failed to parse single homework item: $e');
        }
      }

      return results;
    } catch (e) {
      _logger.e('❌ Fetch homework failed: $e');
      rethrow;
    }
  }

  /// 将安卓端的特殊跳转 URL 转换为手机网页版 URL
  /// 原: https://mooc1-api.chaoxing.com/mooc-ans/android/mtaskmsgspecial?taskrefId=51740957&msgId=0&courseId=261566913&userId=342380530&clazzId=142140293&type=work&enc_task=642d4dfcd6c101ee5f32b86ec2212f91
  /// 现: https://mooc1-api.chaoxing.com/mooc-ans/work/phone/task-work?taskrefId=51740957&courseId=261566913&classId=142140293&ut=s
  String _transformDataUrl(String url) {
    if (url.isEmpty) return '';
    try {
      final uri = Uri.parse(url);
      final taskrefId = uri.queryParameters['taskrefId'];
      final courseId = uri.queryParameters['courseId'];
      final classId = uri.queryParameters['clazzId']; // 注意这里是 clazzId -> classId

      if (taskrefId != null && courseId != null && classId != null) {
        return 'https://mooc1-api.chaoxing.com/mooc-ans/work/phone/task-work?taskrefId=$taskrefId&courseId=$courseId&classId=$classId&ut=s';
      }
      return url;
    } catch (e) {
      return url;
    }
  }

  /// 解析“剩余X小时Y分钟”或“剩余X分钟”或“剩余X天Y小时”
  DateTime? _parseRemainTime(String str, DateTime now) {
    try {
      final clean = str.replaceFirst('剩余', '');
      int totalMinutes = 0;

      final dayMatch = RegExp(r'(\d+)天').firstMatch(clean);
      final hourMatch = RegExp(r'(\d+)小时').firstMatch(clean);
      final minuteMatch = RegExp(r'(\d+)分钟').firstMatch(clean);

      if (dayMatch != null) {
        totalMinutes += int.parse(dayMatch.group(1)!) * 24 * 60;
      }
      if (hourMatch != null) {
        totalMinutes += int.parse(hourMatch.group(1)!) * 60;
      }
      if (minuteMatch != null) {
        totalMinutes += int.parse(minuteMatch.group(1)!);
      }

      if (totalMinutes == 0) return null;
      // 用户要求总分钟数 +1
      return now.add(Duration(minutes: totalMinutes + 1));
    } catch (e) {
      return null;
    }
  }
}
