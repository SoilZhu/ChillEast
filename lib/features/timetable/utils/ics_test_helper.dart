import '../models/course_model.dart';
import 'ics_generator.dart';
import 'ics_parser.dart';
import 'package:logger/logger.dart';

/// ICS 测试工具
class IcsTestHelper {
  static final Logger _logger = Logger();
  
  /// 测试 ICS 生成和解析
  static void testIcsRoundTrip() {
    _logger.i('========== ICS Round-Trip Test ==========');
    
    // 创建测试课程
    final testCourses = [
      CourseModel(
        id: 'test1',
        name: '高等数学',
        teacher: '张老师',
        classroom: '教一楼101',
        weeks: '1-10(周)',
        periods: '1-2',
        dayOfWeek: 1, // 周一
        startPeriod: 1,
        endPeriod: 2,
      ),
      CourseModel(
        id: 'test2',
        name: '大学英语',
        teacher: '李老师',
        classroom: '教二楼203',
        weeks: '1,3,5,7,9(周)',
        periods: '3-4',
        dayOfWeek: 2, // 周二
        startPeriod: 3,
        endPeriod: 4,
      ),
      CourseModel(
        id: 'test3',
        name: '计算机基础',
        teacher: '王老师',
        classroom: '实验楼305',
        weeks: '1-8,10,12(周)',
        periods: '5-6',
        dayOfWeek: 3, // 周三
        startPeriod: 5,
        endPeriod: 6,
      ),
    ];
    
    final firstWeekMonday = DateTime(2025, 2, 24); // 2025年2月24日（周一）
    
    // 生成 ICS
    _logger.i('Generating ICS...');
    final icsContent = IcsGenerator.generate(testCourses, firstWeekMonday);
    _logger.i('ICS generated, length: ${icsContent.length}');
    
    // 打印前500个字符
    _logger.d('ICS preview:\n${icsContent.substring(0, icsContent.length > 500 ? 500 : icsContent.length)}');
    
    // 解析 ICS
    _logger.i('Parsing ICS...');
    final parsedCourses = IcsParser.parse(icsContent);
    _logger.i('Parsed ${parsedCourses.length} courses');
    
    // 对比
    _logger.i('\nOriginal courses:');
    for (final course in testCourses) {
      _logger.i('  - ${course.name}: ${course.weeks}, ${course.dayOfWeek}, ${course.startPeriod}-${course.endPeriod}');
    }
    
    _logger.i('\nParsed courses:');
    for (final course in parsedCourses) {
      _logger.i('  - ${course.name}: ${course.weeks}, ${course.dayOfWeek}, ${course.startPeriod}-${course.endPeriod}');
    }
    
    _logger.i('=========================================');
  }
}
