import 'package:dio/dio.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/services/ydjwxt_auth_service.dart';
import '../../../core/utils/app_logger.dart';
import '../models/score_model.dart';

class ScoreService {
  final _logger = AppLogger.instance;
  final _authService = YdjwxtAuthService();

  /// 获取学期列表
  Future<List<SemesterModel>> fetchSemesterList({bool isRetry = false}) async {
    try {
      final token = await _authService.getToken(forceRefresh: isRetry);
      final dio = DioClient().dio;

      _logger.i('Fetching semester list from YDJWXT...');
      final response = await dio.post(
        AppConstants.ydjwxtSemesterListUrl,
        options: Options(
          headers: {
            'token': token,
            'User-Agent': AppConstants.ydjwxtUA,
            'Referer': 'https://ydjwxt.hunau.edu.cn/hnnydx/',
            'Accept': 'application/json, text/plain, */*',
            'Origin': 'https://ydjwxt.hunau.edu.cn',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final code = data['code']?.toString();
          if (code == '1') {
            final list = data['data'] as List? ?? [];
            final semesters = list.map((item) {
              final map = item as Map<String, dynamic>;
              final id = map['semesterId']?.toString() ?? '';
              final name = map['semesterName']?.toString() ?? id;
              final isdqxq = map['isdqxq']?.toString() == '1';
              return SemesterModel(
                id: id,
                name: name,
                isActive: isdqxq,
              );
            }).toList();
            _logger.i('Successfully fetched ${semesters.length} semesters from YDJWXT');
            return semesters;
          } else if (!isRetry && _isAuthError(code, data['Msg']?.toString())) {
            _logger.w('Token expired or invalid in semesterList, retrying with fresh token...');
            return fetchSemesterList(isRetry: true);
          } else {
            throw AppException(data['Msg']?.toString() ?? '获取学期列表失败');
          }
        }
      }

      throw NetworkException('获取学期列表失败: HTTP ${response.statusCode}');
    } catch (e) {
      if (!isRetry && e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
        _logger.w('HTTP 401/403 in semesterList, retrying with fresh token...');
        return fetchSemesterList(isRetry: true);
      }
      _logger.e('Error fetching semester list: $e');
      rethrow;
    }
  }

  /// 获取指定学期的成绩列表
  Future<List<ScoreModel>> fetchScores({required String semester, bool isRetry = false}) async {
    try {
      final token = await _authService.getToken(forceRefresh: isRetry);
      final dio = DioClient().dio;

      _logger.i('Fetching scores for semester=$semester from YDJWXT...');
      final response = await dio.post(
        AppConstants.ydjwxtScoreUrl,
        queryParameters: {
          'semester': semester,
          'type': '1',
        },
        options: Options(
          headers: {
            'token': token,
            'User-Agent': AppConstants.ydjwxtUA,
            'Referer': 'https://ydjwxt.hunau.edu.cn/hnnydx/',
            'Accept': 'application/json, text/plain, */*',
            'Origin': 'https://ydjwxt.hunau.edu.cn',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final code = data['code']?.toString();
          if (code == '1') {
            final rawList = data['data'] as List? ?? [];
            if (rawList.isEmpty) return [];

            final firstStudent = rawList.first as Map<String, dynamic>? ?? {};
            final achievements = firstStudent['achievement'] as List? ?? [];

            final scores = achievements.map((item) {
              final map = item as Map<String, dynamic>;
              return ScoreModel(
                courseName: map['courseName']?.toString() ?? '未知课程',
                score: map['fraction']?.toString() ?? 'N/A',
                credit: map['credit']?.toString(),
                examType: map['examinationNature']?.toString() ?? '正常考试',
                curriculumAttributes: map['curriculumAttributes']?.toString(),
                courseNature: map['courseNature']?.toString(),
                courseCode: map['kcbh']?.toString(),
                id: map['cj0708id']?.toString(),
              );
            }).toList();

            _logger.i('Successfully parsed ${scores.length} scores for semester $semester');
            return scores;
          } else if (!isRetry && _isAuthError(code, data['Msg']?.toString())) {
            _logger.w('Token expired or invalid in fetchScores, retrying with fresh token...');
            return fetchScores(semester: semester, isRetry: true);
          } else {
            throw AppException(data['Msg']?.toString() ?? '获取成绩失败');
          }
        }
      }

      throw NetworkException('获取成绩失败: HTTP ${response.statusCode}');
    } catch (e) {
      if (!isRetry && e is DioException && (e.response?.statusCode == 401 || e.response?.statusCode == 403)) {
        _logger.w('HTTP 401/403 in fetchScores, retrying with fresh token...');
        return fetchScores(semester: semester, isRetry: true);
      }
      _logger.e('Error fetching scores: $e');
      rethrow;
    }
  }

  bool _isAuthError(String? code, String? msg) {
    if (code == '401' || code == '-1' || code == '0') return true;
    if (msg != null && (msg.contains('登录') || msg.contains('token') || msg.contains('Token') || msg.contains('失效'))) {
      return true;
    }
    return false;
  }
}
