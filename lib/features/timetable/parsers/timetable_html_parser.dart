import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import '../models/course_model.dart';
import '../utils/week_parser.dart';
import '../../../core/exceptions/app_exceptions.dart';
import 'package:logger/logger.dart';

class TimetableHtmlParser {
  static final Logger _logger = Logger();
  
  /// 解析课表 HTML
  static List<CourseModel> parseTimetable(String htmlContent) {
    try {
      final document = html_parser.parse(htmlContent);
      final courses = <CourseModel>[];
      
      _logger.d('HTML content length: ${htmlContent.length}');
      
      // 定位 timetable 表格
      dom.Element? table = document.querySelector('table#timetable');
      if (table == null) {
        _logger.w('Table #timetable not found, trying alternative selectors...');
        // 尝试其他可能的选择器
        table = document.querySelector('table') ?? 
                document.querySelector('.kbtable') ??
                document.querySelector('[class*="timetable"]');
        if (table != null) {
          _logger.i('Found table using alternative selector');
        } else {
          throw ParseException('未找到课表表格');
        }
      }
      
      // 遍历每一行(每个大节)
      final rows = table.querySelectorAll('tr');
      _logger.d('Found ${rows.length} rows in table');
      
      for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
        final row = rows[rowIndex];
        final cells = row.querySelectorAll('td');
        
        // 遍历每一天(列)
        for (var dayIndex = 0; dayIndex < cells.length; dayIndex++) {
          final cell = cells[dayIndex];
          final dayOfWeek = dayIndex + 1; // 1=周一
          
          // 提取隐藏的详细课程信息 (kbcontent)
          final hiddenDivs = cell.querySelectorAll('div.kbcontent');
          
          if (hiddenDivs.isNotEmpty) {
            _logger.d('Row $rowIndex, Day $dayOfWeek: Found ${hiddenDivs.length} course divs');
          }
          
          for (final div in hiddenDivs) {
            final courseId = div.id;
            if (courseId.isEmpty) {
              _logger.w('Course div has empty ID, skipping');
              continue;
            }
            
            // 解析 ID: {courseId}-{day}-{slot}
            final idParts = courseId.split('-');
            if (idParts.length < 3) {
              _logger.w('Invalid course ID format: $courseId');
              continue;
            }
            
            final slot = int.tryParse(idParts.last);
            if (slot == null) {
              _logger.w('Failed to parse slot from ID: $courseId');
              continue;
            }
            
            // 🔑 关键修复：检查是否包含多个课程（用 ---------------------- 分隔）
            final divHtml = div.innerHtml;
            final courseBlocks = divHtml.split(RegExp(r'-{5,}<br>'));
            
            if (courseBlocks.length > 1) {
              _logger.d('  ⚠️ Found ${courseBlocks.length} merged courses in one div! Splitting...');
            }
            
            // 分别解析每个课程块
            for (int blockIndex = 0; blockIndex < courseBlocks.length; blockIndex++) {
              final blockHtml = courseBlocks[blockIndex].trim();
              if (blockHtml.isEmpty || blockHtml == '&nbsp;') continue;
              
              // 为每个课程块生成唯一 ID
              final blockId = courseBlocks.length > 1 
                ? '${courseId}_block${blockIndex + 1}' 
                : courseId;
              
              // 创建临时 div 来解析这个课程块
              final tempDiv = dom.Element.html('<div>$blockHtml</div>');
              
              // 提取课程名称
              final courseName = _extractCourseName(tempDiv);
              if (courseName.isEmpty || courseName == '\u00a0') {
                _logger.w('Empty course name for ID: $blockId');
                continue;
              }
              
              // 提取教师
              final teacher = _extractFontText(tempDiv, '教师');
              
              // 提取周次和节次
              final weekPeriodText = _extractFontText(tempDiv, '周次(节次)');
              final (weeks, periods) = _parseWeeksAndPeriods(weekPeriodText);
              
              if (weeks.isEmpty) {
                _logger.w('Empty weeks for course: $courseName (ID: $blockId)');
              }
              
              // 提取教室
              final classroom = _extractFontText(tempDiv, '教室');
              
              // 计算起始和结束节次
              final (startPeriod, endPeriod) = _calculatePeriods(slot, periods);
              
              courses.add(CourseModel(
                id: blockId,
                name: courseName,
                teacher: teacher,
                classroom: classroom,
                weeks: weeks,
                periods: periods,
                dayOfWeek: dayOfWeek,
                startPeriod: startPeriod,
                endPeriod: endPeriod,
              ));
            }
          }
        }
      }
      
      _logger.i('✅ Successfully parsed ${courses.length} courses from timetable');
      return courses;
      
    } catch (e, stackTrace) {
      _logger.e('❌ Failed to parse timetable HTML: $e');
      _logger.e('Stack trace: $stackTrace');
      if (e is ParseException) {
        rethrow;
      }
      throw ParseException('课表 HTML 解析失败: $e');
    }
  }
  
  /// 提取课程名称
  static String _extractCourseName(dom.Element div) {
    // 🔑 关键修复：同时支持 <br/> 和 <br> 两种格式
    final innerHtml = div.innerHtml;
    
    // 尝试查找 <br/> 或 <br>
    final brSlashIndex = innerHtml.indexOf('<br/>');
    final brIndex = innerHtml.indexOf('<br>');
    
    int firstBrIndex = -1;
    if (brSlashIndex >= 0 && brIndex >= 0) {
      // 两种都存在，取较小的
      firstBrIndex = brSlashIndex < brIndex ? brSlashIndex : brIndex;
    } else if (brSlashIndex >= 0) {
      firstBrIndex = brSlashIndex;
    } else if (brIndex >= 0) {
      firstBrIndex = brIndex;
    }
    
    if (firstBrIndex > 0) {
      return innerHtml.substring(0, firstBrIndex).trim();
    }
    
    // 如果没有 <br>,返回所有文本
    return div.text.trim();
  }
  
  /// 提取 font 标签中的文本
  static String _extractFontText(dom.Element div, String title) {
    final fonts = div.querySelectorAll('font');
    for (final font in fonts) {
      if (font.attributes['title'] == title) {
        return font.text.trim();
      }
    }
    return '';
  }
  
  /// 解析周次和节次字符串
  static (String, String) _parseWeeksAndPeriods(String text) {
    // 支持的格式：
    // "1-16(周)[01-02节]"
    // "1,3,5,7,9(周)[03-04节]"
    // "1-10,12-14(周)[05-06节]"
    // "1-8,10,12(周)[07-08节]"
    
    // 提取周次部分（支持所有格式）
    final weekMatch = RegExp(r'([\d,\-]+)\(周\)').firstMatch(text);
    final periodMatch = RegExp(r'\[(\d+(?:-\d+)?(?:-\d+)*(?:-\d+)*)节\]').firstMatch(text);
    
    String weeks = '';
    if (weekMatch != null) {
      weeks = '${weekMatch.group(1)}(周)';
    }
    
    String periods = '';
    if (periodMatch != null) {
      periods = periodMatch.group(1)!;
    }
    
    return (weeks, periods);
  }
  
  /// 计算起始和结束节次
  static (int, int) _calculatePeriods(int slot, String periods) {
    // slot: 1=第一大节(01-02节), 2=第二大节(03-04节)...
    // periods: "01-02" 或 "01-02-03-04"
    
    if (periods.isNotEmpty) {
      final parts = periods.split('-');
      if (parts.length >= 2) {
        final start = int.tryParse(parts.first) ?? 1;
        final end = int.tryParse(parts.last) ?? 2;
        return (start, end);
      }
    }
    
    // 默认根据 slot 推算
    final start = (slot - 1) * 2 + 1;
    return (start, start + 1);
  }
}
