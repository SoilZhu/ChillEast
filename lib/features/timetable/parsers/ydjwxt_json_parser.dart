import 'package:logger/logger.dart';
import '../models/course_model.dart';
import '../../../../core/utils/app_logger.dart';

class YdjwxtJsonParser {
  static final Logger _logger = AppLogger.instance;

  /// 从 JSON 中提取第一周周一的日期
  static DateTime? extractFirstWeekMonday(Map<String, dynamic> json) {
    try {
      final data = json['data'];
      if (data == null || data is! List || data.isEmpty) return null;
      
      final dateList = data[0]['date'];
      if (dateList == null || dateList is! List || dateList.isEmpty) return null;
      
      // 找到星期一 (xqid == "1")
      final mondayInfo = dateList.firstWhere(
        (d) => d['xqid']?.toString() == '1',
        orElse: () => dateList.first,
      );
      
      final mxrq = mondayInfo['mxrq']?.toString();
      final zc = int.tryParse(mondayInfo['zc']?.toString() ?? '');
      
      if (mxrq != null && zc != null) {
        final date = DateTime.parse(mxrq);
        // 计算第一周周一：当前周一日期 - (当前周次 - 1) * 7天
        return date.subtract(Duration(days: (zc - 1) * 7));
      }
    } catch (e) {
      _logger.e('Failed to extract first week Monday from JSON: $e');
    }
    return null;
  }

  /// 解析单周的 JSON 数据
  static List<CourseModel> parseWeekJson(Map<String, dynamic> json) {
    final courses = <CourseModel>[];
    
    try {
      final data = json['data'];
      if (data == null || data is! List || data.isEmpty) {
        return courses;
      }

      final coursesList = data[0]['courses'];
      if (coursesList == null || coursesList is! List) {
        return courses;
      }

      for (final item in coursesList) {
        final courseName = item['courseName']?.toString() ?? '';
        if (courseName.isEmpty) continue;

        final teacher = item['teacherName']?.toString() ?? '';
        final classroom = item['classroomName']?.toString() ?? '';
        final dayOfWeek = int.tryParse(item['weekDay']?.toString() ?? '') ?? 0;
        
        // 解析节次 (例如 "10304" -> Day 1, 03-04节)
        final classTime = item['classTime']?.toString() ?? '';
        int startPeriod = 0;
        int endPeriod = 0;
        String periods = '';

        if (classTime.length >= 5) {
          startPeriod = int.tryParse(classTime.substring(1, 3)) ?? 0;
          endPeriod = int.tryParse(classTime.substring(3, 5)) ?? 0;
          periods = '${startPeriod.toString().padLeft(2, '0')}-${endPeriod.toString().padLeft(2, '0')}';
        } else {
          // 备选解析方案：weekNoteDetail (例如 "103,104")
          final weekNoteDetail = item['weekNoteDetail']?.toString() ?? '';
          final parts = weekNoteDetail.split(',');
          if (parts.length >= 2) {
            startPeriod = int.tryParse(parts.first.substring(1)) ?? 0;
            endPeriod = int.tryParse(parts.last.substring(1)) ?? 0;
            periods = '${startPeriod.toString().padLeft(2, '0')}-${endPeriod.toString().padLeft(2, '0')}';
          }
        }

        final weeksStr = item['classWeek']?.toString() ?? '';
        final id = item['jx0408id']?.toString() ?? '${courseName}_${dayOfWeek}_$startPeriod';

        courses.add(CourseModel(
          id: id,
          name: courseName,
          teacher: teacher,
          classroom: classroom,
          weeks: weeksStr.contains('(周)') ? weeksStr : '$weeksStr(周)',
          periods: periods,
          dayOfWeek: dayOfWeek == 0 ? 7 : dayOfWeek, // 0 可能是周日？教务系统常用 0 代表周日
          startPeriod: startPeriod,
          endPeriod: endPeriod,
        ));
      }
    } catch (e) {
      _logger.e('Failed to parse YDJWXT week JSON: $e');
    }

    return courses;
  }

  /// 合并 20 周的数据并去重
  static List<CourseModel> mergeWeeks(List<List<CourseModel>> allWeeksData) {
    // 使用唯一的课程标识作为 Key
    // 标识：课程名 + 老师 + 教室 + 星期 + 节次
    final mergedMap = <String, CourseModel>{};
    
    for (final weekCourses in allWeeksData) {
      for (final course in weekCourses) {
        final key = '${course.name}_${course.teacher}_${course.dayOfWeek}_${course.periods}_${course.classroom}';
        
        if (!mergedMap.containsKey(key)) {
          mergedMap[key] = course;
        } else {
          // 如果已存在，理论上 weeks 字段应该是相同的，因为 ydjwxt 返回的是课程的完整周次范围
          // 但为了保险，我们可以合并周次字符串（如果不同的话）
          // 不过根据目前的 JSON 结构，ydjwxt 返回的 classWeek 是 "1-10" 这种全局范围
        }
      }
    }
    
    return mergedMap.values.toList();
  }
}
