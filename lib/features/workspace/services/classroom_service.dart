import 'package:html/parser.dart' as html_parser;
import '../../../core/network/dio_client.dart';
import '../models/classroom_model.dart';
import 'package:logger/logger.dart';

class ClassroomService {
  final _logger = Logger();
  static const String _indexUrl = 'https://portal.hunau.edu.cn/pc/view/kxClassRoomIndex';
  static const String _queryUrl = 'https://portal.hunau.edu.cn/pc/view/refreshKxClassRoom';

  /// 获取查询选项 (从 HTML 解析)
  Future<ClassroomInquiryOptions> fetchOptions() async {
    try {
      final response = await DioClient().dio.get(_indexUrl);
      final document = html_parser.parse(response.data);

      // 1. 解析教学楼
      final buildings = document
          .querySelectorAll('#jxlCondition a')
          .map((e) => e.text.trim())
          .toList();

      // 2. 解析节次
      final sections = document
          .querySelectorAll('#jcCondition a')
          .map((e) => e.text.trim())
          .toList();

      // 3. 解析周次
      final weeks = document
          .querySelectorAll('#zcCondition a')
          .map((e) => e.text.trim())
          .toList();

      // 4. 解析星期
      final days = document.querySelectorAll('#weekCondition a').map((e) {
        return {
          'label': e.text.trim(),
          'value': e.attributes['data-value'] ?? '',
        };
      }).toList();

      return ClassroomInquiryOptions(
        buildings: buildings,
        sections: sections,
        weeks: weeks,
        days: days,
      );
    } catch (e) {
      _logger.e('❌ Fetch classroom options failed: $e');
      rethrow;
    }
  }

  /// 执行空教室查询
  Future<List<ClassroomModel>> queryClassrooms({
    required String building,
    required String week, // 周次
    required String jc,   // 节次
    required String day,  // 星期 value
  }) async {
    try {
      final response = await DioClient().dio.get(
        _queryUrl,
        queryParameters: {
          'jxl': building,
          'week': day, // 注意：接口参数名可能有点反直觉，从抓包看 week 参数传的是星期几
          'jc': jc,
          'zc': week, // 注意：接口参数名 zc 传的是第几周
        },
        options: DioClient.getOptions(
          referer: _indexUrl,
          isXmlHttpRequest: true,
        ),
      );

      final List<dynamic> data = response.data['data'] ?? [];
      return data.map((json) => ClassroomModel.fromJson(json)).toList();
    } catch (e) {
      _logger.e('❌ Query classrooms failed: $e');
      rethrow;
    }
  }
}
