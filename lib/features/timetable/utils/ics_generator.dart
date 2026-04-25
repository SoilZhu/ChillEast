import '../models/course_model.dart';
import '../utils/date_calculator.dart';
import '../utils/week_parser.dart';
import 'ics_export_helper.dart';

/// ICS 文件生成器
class IcsGenerator {
  /// 生成 ICS 文件内容
  /// 
  /// [courses] 课程列表
  /// [firstWeekMonday] 本学期第一周的周一日期
  static String generate(List<CourseModel> courses, DateTime firstWeekMonday) {
    final buffer = StringBuffer();
    
    // ICS 文件头
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//Live@HUNAU//Timetable//CN');
    buffer.writeln('CALSCALE:GREGORIAN');
    buffer.writeln('METHOD:PUBLISH');
    buffer.writeln('X-WR-CALNAME:湖南农业大学课表');
    buffer.writeln('X-WR-TIMEZONE:Asia/Shanghai');
    
    // 为每个课程生成 VEVENT
    for (final course in courses) {
      _generateCourseEvents(buffer, course, firstWeekMonday);
    }
    
    // ICS 文件尾
    buffer.writeln('END:VCALENDAR');
    
    return buffer.toString();
  }
  
  /// 为单个课程生成事件
  static void _generateCourseEvents(
    StringBuffer buffer,
    CourseModel course,
    DateTime firstWeekMonday,
  ) {
    // 解析周次
    final weeks = WeekParser.parseWeeks(course.weeks);
    if (weeks.isEmpty) return;
    
    // 将周次分组：连续周使用 RRULE，离散周使用独立事件
    final weekGroups = _groupConsecutiveWeeks(weeks);
    
    for (final group in weekGroups) {
      if (group.length == 1) {
        // 单周：生成独立事件
        _generateSingleEvent(buffer, course, firstWeekMonday, group[0]);
      } else {
        // 连续周：使用 RRULE
        _generateRecurringEvent(buffer, course, firstWeekMonday, group);
      }
    }
  }
  
  /// 生成单次事件
  static void _generateSingleEvent(
    StringBuffer buffer,
    CourseModel course,
    DateTime firstWeekMonday,
    int weekNumber,
  ) {
    final date = DateCalculator.calculateDate(
      firstWeekMonday: firstWeekMonday,
      weekNumber: weekNumber,
      dayOfWeek: course.dayOfWeek,
    );
    
    final startTime = DateCalculator.getSectionTime(course.startPeriod)['start']!;
    final endTime = DateCalculator.getSectionTime(course.endPeriod)['end']!;
    
    final startDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      startTime.hour,
      startTime.minute,
    );
    
    final endDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      endTime.hour,
      endTime.minute,
    );
    
    buffer.writeln('BEGIN:VEVENT');
    buffer.writeln('UID:${_generateUid(course, weekNumber)}');
    buffer.writeln('DTSTAMP:${_formatDateTime(DateTime.now().toUtc())}');
    buffer.writeln('DTSTART:${_formatDateTime(startDateTime)}');
    buffer.writeln('DTEND:${_formatDateTime(endDateTime)}');
    buffer.writeln('SUMMARY:${course.name}');
    buffer.writeln('LOCATION:${course.classroom ?? '未知教室'}');
    buffer.writeln('DESCRIPTION:${_generateDescription(course, weekNumber)}');
    buffer.writeln('STATUS:CONFIRMED');
    buffer.writeln('SEQUENCE:0');
    buffer.writeln('BEGIN:VALARM');
    buffer.writeln('TRIGGER:-PT15M');
    buffer.writeln('ACTION:DISPLAY');
    buffer.writeln('DESCRIPTION:课程提醒');
    buffer.writeln('END:VALARM');
    buffer.writeln('END:VEVENT');
  }
  
  /// 生成重复事件
  static void _generateRecurringEvent(
    StringBuffer buffer,
    CourseModel course,
    DateTime firstWeekMonday,
    List<int> weeks,
  ) {
    final firstWeek = weeks.first;
    final date = DateCalculator.calculateDate(
      firstWeekMonday: firstWeekMonday,
      weekNumber: firstWeek,
      dayOfWeek: course.dayOfWeek,
    );
    
    final startTime = DateCalculator.getSectionTime(course.startPeriod)['start']!;
    final endTime = DateCalculator.getSectionTime(course.endPeriod)['end']!;
    
    final startDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      startTime.hour,
      startTime.minute,
    );
    
    final endDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      endTime.hour,
      endTime.minute,
    );
    
    buffer.writeln('BEGIN:VEVENT');
    buffer.writeln('UID:${_generateUid(course, firstWeek)}-${weeks.length}');
    buffer.writeln('DTSTAMP:${_formatDateTime(DateTime.now().toUtc())}');
    buffer.writeln('DTSTART:${_formatDateTime(startDateTime)}');
    buffer.writeln('DTEND:${_formatDateTime(endDateTime)}');
    buffer.writeln('RRULE:FREQ=WEEKLY;COUNT=${weeks.length}');
    buffer.writeln('SUMMARY:${course.name}');
    buffer.writeln('LOCATION:${course.classroom ?? '未知教室'}');
    buffer.writeln('DESCRIPTION:${_generateDescription(course, weeks.first, weeks.last)}');
    buffer.writeln('STATUS:CONFIRMED');
    buffer.writeln('SEQUENCE:0');
    buffer.writeln('BEGIN:VALARM');
    buffer.writeln('TRIGGER:-PT15M');
    buffer.writeln('ACTION:DISPLAY');
    buffer.writeln('DESCRIPTION:课程提醒');
    buffer.writeln('END:VALARM');
    buffer.writeln('END:VEVENT');
  }
  
  /// 将周次列表分组为连续序列
  static List<List<int>> _groupConsecutiveWeeks(List<int> weeks) {
    if (weeks.isEmpty) return [];
    
    final groups = <List<int>>[];
    List<int> currentGroup = [weeks[0]];
    
    for (int i = 1; i < weeks.length; i++) {
      if (weeks[i] == weeks[i - 1] + 1) {
        // 连续
        currentGroup.add(weeks[i]);
      } else {
        // 不连续，开始新组
        groups.add(currentGroup);
        currentGroup = [weeks[i]];
      }
    }
    
    // 添加最后一组
    groups.add(currentGroup);
    
    return groups;
  }
  
  /// 生成唯一 ID
  static String _generateUid(CourseModel course, int weekNumber) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'course-${course.hashCode}-w$weekNumber-$timestamp@hunau.edu.cn';
  }
  
  /// 格式化日期时间为 ICS 格式
  static String _formatDateTime(DateTime dateTime) {
    // ICS 格式：YYYYMMDDTHHmmSS
    return '${dateTime.year}'
        '${_padZero(dateTime.month)}'
        '${_padZero(dateTime.day)}T'
        '${_padZero(dateTime.hour)}'
        '${_padZero(dateTime.minute)}'
        '${_padZero(dateTime.second)}';
  }
  
  /// 生成课程描述
  static String _generateDescription(
    CourseModel course,
    int startWeek, [
    int? endWeek,
  ]) {
    final buffer = StringBuffer();
    
    if (course.teacher != null && course.teacher!.isNotEmpty) {
      buffer.writeln('教师：${course.teacher}');
    }
    
    if (endWeek != null) {
      buffer.writeln('周次：第$startWeek-${endWeek}周');
    } else {
      buffer.writeln('周次：第$startWeek周');
    }
    
    if (course.classroom != null && course.classroom!.isNotEmpty) {
      buffer.writeln('教室：${course.classroom}');
    }
    
    return buffer.toString().trim();
  }
  
  /// 补零
  static String _padZero(int number) {
    return number.toString().padLeft(2, '0');
  }
  
  /// 生成 ICS 文件内容（旧接口，保持兼容）
  @Deprecated('Use generate() instead')
  static Future<String> generateIcsContent(
    List<CourseModel> courses,
    DateTime firstWeekMonday,
  ) async {
    return generate(courses, firstWeekMonday);
  }
  
  /// 保存并分享 ICS 文件（旧接口，保持兼容）
  @Deprecated('Use TimetableStorage and Share directly')
  static Future<void> saveAndShareIcs(String icsContent, String filename) async {
    await IcsExportHelper.saveAndShareIcs(icsContent, filename);
  }
}
