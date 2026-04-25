import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import '../../../core/network/dio_client.dart';
import '../models/score_model.dart';
import '../../../core/exceptions/app_exceptions.dart';
import 'package:logger/logger.dart';

import '../../../core/constants/app_constants.dart';

class ScoreService {
  final Logger _logger = Logger();
  
  static const String scoreUrl = 
      '${AppConstants.portalBaseUrl}/pc/view/scoreIndex';

  /// 获取成绩数据
  Future<Map<String, dynamic>> fetchScores({String? xn, String? xq}) async {
    try {
      final queryParams = <String, String>{};
      if (xn != null) queryParams['xn'] = xn;
      if (xq != null) queryParams['xq'] = xq;

      _logger.i('Fetching scores for xn=$xn, xq=$xq...');
      
      final response = await DioClient().dio.get(
        scoreUrl,
        queryParameters: queryParams,
        options: Options(
          headers: {
            'Referer': '${AppConstants.portalBaseUrl}/pc/template/scoreIndex',
            'Host': 'portal.hunau.edu.cn',
          },
        ),
      );

      if (response.statusCode != 200) {
        throw NetworkException('获取成绩失败: HTTP ${response.statusCode}');
      }

      final htmlContent = response.data.toString();
      
      // ✨ 检查是否被重定向到了登录页
      if (htmlContent.contains('统一登录门户') || 
          htmlContent.contains('cas/login')) {
        _logger.w('⚠️ Session expired. Redirected to login page.');
        throw AuthException('会话已失效，请重新登录');
      }

      return _parseScoreHtml(htmlContent);
    } catch (e) {
      _logger.e('Error fetching scores: $e');
      rethrow;
    }
  }

  /// 解析 HTML 响应
  Map<String, dynamic> _parseScoreHtml(String html) {
    _logger.d('Parsing score HTML...');
    final document = html_parser.parse(html);
    
    // 1. 解析学期列表
    final semesterList = <SemesterModel>[];
    final semesterElements = document.querySelectorAll('.selectSemesterList li');
    
    for (var element in semesterElements) {
      final text = element.text.trim();
      final isActive = element.className.contains('active');
      
      // 提取 onclick 中的 xn 和 xq
      // onclick="... selXq('2025-2026','1') ..."
      final onclick = element.attributes['onclick'] ?? '';
      final regExp = RegExp(r"selXq\('([^']+)','([^']+)'\)");
      final match = regExp.firstMatch(onclick);
      
      if (match != null) {
        semesterList.add(SemesterModel(
          value: match.group(1)!,
          xq: match.group(2)!,
          name: text,
          isActive: isActive,
        ));
      }
    }

    // 2. 解析成绩列表
    final scoreList = <ScoreModel>[];
    final scoreElements = document.querySelectorAll('.subjectItem');
    
    for (var element in scoreElements) {
      final courseName = element.querySelector('.subjectName .line_slh')?.text.trim() ?? '未知课程';
      final scoreVal = element.querySelector('.subjectValue span')?.text.trim() ?? 'N/A';
      
      final id = element.attributes['id'];
      String? credit;
      String? pscj;
      String? cxbj;

      if (id != null) {
        // 从 hidden input 中获取更多元数据 (虽然 id 是 0, 1, 2...)
        credit = document.querySelector('#xf$id')?.attributes['value'];
        pscj = document.querySelector('#pscj$id')?.attributes['value'];
        cxbj = document.querySelector('#cxbj$id')?.attributes['value'];
        if (cxbj == "1") cxbj = "重修";
        else if (cxbj == "0") cxbj = "正常考试";
      }

      scoreList.add(ScoreModel(
        courseName: courseName,
        score: scoreVal,
        credit: credit,
        dailyScore: pscj,
        examType: cxbj,
      ));
    }

    _logger.i('Successfully parsed ${semesterList.length} semesters and ${scoreList.length} scores');
    
    return {
      'semesters': semesterList,
      'scores': scoreList,
    };
  }
}
