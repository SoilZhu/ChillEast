import '../models/course_model.dart';
import 'package:logger/logger.dart';

/// ICS 文件解析器
class IcsParser {
  static final Logger _logger = Logger();
  /// 解析 ICS 文件内容为课程列表
  static List<CourseModel> parse(String icsContent) {
    final courses = <CourseModel>[];
    
    _logger.d('Parsing ICS content, length: ${icsContent.length}');
    
    // 分割出每个 VEVENT
    final events = _extractEvents(icsContent);
    _logger.d('Found ${events.length} VEVENT blocks');
    
    for (int i = 0; i < events.length; i++) {
      final eventCourses = _parseEvent(events[i]);
      if (eventCourses != null && eventCourses.isNotEmpty) {
        courses.addAll(eventCourses);
      } else {
        _logger.w('Failed to parse event $i');
      }
    }
    
    _logger.i('Successfully parsed ${courses.length} courses from ICS');
    return courses;
  }
  
  /// 提取所有 VEVENT 块
  static List<String> _extractEvents(String icsContent) {
    final events = <String>[];
    
    // 使用正则表达式更可靠地提取 VEVENT
    final eventRegex = RegExp(
      r'BEGIN:VEVENT\s*([\s\S]*?)\s*END:VEVENT',
      multiLine: true,
      dotAll: true,
    );
    
    final matches = eventRegex.allMatches(icsContent);
    _logger.d('Regex found ${matches.length} VEVENT matches');
    
    for (final match in matches) {
      final eventContent = match.group(0);
      if (eventContent != null && eventContent.isNotEmpty) {
        events.add(eventContent);
      }
    }
    
    return events;
  }
  
  /// 解析单个 VEVENT
  /// 如果事件有 RRULE，会展开成多个课程实例
  static List<CourseModel>? _parseEvent(String event) {
    try {
      final lines = event.split('\n');
      
      String? summary;
      String? location;
      final descriptionLines = <String>[];
      String? dtstart;
      String? dtend;
      String? rrule;
      
      bool inDescription = false;
      
      for (final line in lines) {
        final trimmed = line.trim();
        
        if (trimmed.startsWith('SUMMARY:')) {
          summary = trimmed.substring(8);
          inDescription = false;
        } else if (trimmed.startsWith('LOCATION:')) {
          location = trimmed.substring(9);
          inDescription = false;
        } else if (trimmed.startsWith('DESCRIPTION:')) {
          // 开始收集 DESCRIPTION 的多行内容
          final firstLine = trimmed.substring(12);
          if (firstLine.isNotEmpty) {
            descriptionLines.add(firstLine);
          }
          inDescription = true;
        } else if (trimmed.startsWith('DTSTART:')) {
          dtstart = trimmed.substring(8);
          inDescription = false;
        } else if (trimmed.startsWith('DTEND:')) {
          dtend = trimmed.substring(6);
          inDescription = false;
        } else if (trimmed.startsWith('RRULE:')) {
          rrule = trimmed.substring(6);
          inDescription = false;
        } else if (trimmed.startsWith('STATUS:') || 
                   trimmed.startsWith('SEQUENCE:') ||
                   trimmed.startsWith('BEGIN:') ||
                   trimmed.startsWith('END:')) {
          // 遇到其他字段，停止收集 DESCRIPTION
          inDescription = false;
        } else if (inDescription && trimmed.isNotEmpty) {
          // 继续收集 DESCRIPTION 的后续行
          descriptionLines.add(trimmed);
        }
      }
      
      // 合并 DESCRIPTION 的所有行
      final description = descriptionLines.isEmpty ? null : descriptionLines.join('\n');
      
      if (summary == null || dtstart == null) {
        _logger.w('Missing summary or dtstart. Summary: $summary, DTSTART: $dtstart');
        return null;
      }
      
      // 从 DTSTART 解析日期和时间
      final startDate = _parseIcsDateTime(dtstart);
      if (startDate == null) {
        _logger.w('Failed to parse DTSTART: $dtstart');
        return null;
      }
      
      // 计算星期几
      final dayOfWeek = startDate.weekday; // 1=Monday, 7=Sunday
      
      // 从时间推算节次
      final startPeriod = _timeToPeriod(startDate.hour, startDate.minute);
      final endPeriod = dtend != null 
          ? _timeToPeriodFromEnd(dtend, startDate)
          : startPeriod;
      
      // 从描述中提取周次信息
      String weeks = '1';
      String teacher = '';
      
      if (description != null) {
        final weekMatch = RegExp(r'周次[：:]\s*第([\d,\-]+)周').firstMatch(description);
        if (weekMatch != null) {
          weeks = '${weekMatch.group(1)}(周)';
        }
        
        final teacherMatch = RegExp(r'教师[：:]\s*(.+)').firstMatch(description);
        if (teacherMatch != null) {
          teacher = teacherMatch.group(1)!.trim();
        }
      } else if (rrule != null) {
        // 如果没有 description 但有 RRULE，无法准确推断周次
        // 只能假设从第1周开始（这是一个fallback）
        final countMatch = RegExp(r'COUNT=(\d+)').firstMatch(rrule);
        if (countMatch != null) {
          final count = int.tryParse(countMatch.group(1)!);
          if (count != null && count > 0) {
            weeks = count == 1 ? '1(周)' : '1-$count(周)';
          }
        }
      }
      
      // 生成唯一 ID
      final id = '${startDate.millisecondsSinceEpoch}_$dayOfWeek';
      
      return [CourseModel(
        id: id,
        name: summary,
        teacher: teacher,
        classroom: location ?? '',
        weeks: weeks,
        periods: '$startPeriod-$endPeriod',
        dayOfWeek: dayOfWeek,
        startPeriod: startPeriod,
        endPeriod: endPeriod,
      )];
    } catch (e) {
      return null;
    }
  }
  
  /// 解析 ICS 日期时间格式
  static DateTime? _parseIcsDateTime(String dateTimeStr) {
    try {
      // 格式：YYYYMMDDTHHmmSS
      if (dateTimeStr.length < 15) return null;
      
      final year = int.parse(dateTimeStr.substring(0, 4));
      final month = int.parse(dateTimeStr.substring(4, 6));
      final day = int.parse(dateTimeStr.substring(6, 8));
      final hour = int.parse(dateTimeStr.substring(9, 11));
      final minute = int.parse(dateTimeStr.substring(11, 13));
      
      return DateTime(year, month, day, hour, minute);
    } catch (e) {
      return null;
    }
  }
  
  /// 根据时间转换为节次
  static int _timeToPeriod(int hour, int minute) {
    final timeInMinutes = hour * 60 + minute;
    
    // 节次时间表
    const periodTimes = [
      (start: 480, end: 525, period: 1),   // 08:00-08:45
      (start: 535, end: 580, period: 2),   // 08:55-09:40
      (start: 605, end: 650, period: 3),   // 10:05-10:50
      (start: 660, end: 705, period: 4),   // 11:00-11:45
      (start: 870, end: 915, period: 5),   // 14:30-15:15
      (start: 925, end: 970, period: 6),   // 15:25-16:10
      (start: 995, end: 1040, period: 7),  // 16:35-17:20
      (start: 1050, end: 1095, period: 8), // 17:30-18:15
      (start: 1170, end: 1215, period: 9), // 19:30-20:15
      (start: 1225, end: 1270, period: 10),// 20:25-21:10
      (start: 1280, end: 1325, period: 11),// 21:20-22:05
      (start: 1335, end: 1380, period: 12),// 22:15-23:00
    ];
    
    for (final pt in periodTimes) {
      if (timeInMinutes >= pt.start && timeInMinutes <= pt.end) {
        return pt.period;
      }
    }
    
    // 默认返回第1节
    return 1;
  }
  
  /// 从结束时间推算结束节次
  static int _timeToPeriodFromEnd(String dtend, DateTime startDate) {
    try {
      final endDate = _parseIcsDateTime(dtend);
      if (endDate == null) return 1;
      
      return _timeToPeriod(endDate.hour, endDate.minute);
    } catch (e) {
      return 1;
    }
  }
}
