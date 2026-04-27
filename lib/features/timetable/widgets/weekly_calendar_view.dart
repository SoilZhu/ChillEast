import 'package:flutter/material.dart';
import '../models/course_model.dart';
import '../utils/date_calculator.dart';
import '../utils/week_parser.dart';
import '../utils/course_color_utils.dart';

/// 周视图日历组件
class WeeklyCalendarView extends StatefulWidget {
  final List<CourseModel> courses;
  final DateTime firstWeekMonday;
  
  const WeeklyCalendarView({
    Key? key,
    required this.courses,
    required this.firstWeekMonday,
  }) : super(key: key);

  @override
  WeeklyCalendarViewState createState() => WeeklyCalendarViewState();
}

class WeeklyCalendarViewState extends State<WeeklyCalendarView> {
  late PageController _pageController;
  int _currentWeekNumber = 1; 
  
  @override
  void initState() {
    super.initState();
    final initialWeek = DateCalculator.getCurrentWeekNumber(widget.firstWeekMonday);
    _currentWeekNumber = initialWeek.clamp(1, 20);
    _pageController = PageController(initialPage: _currentWeekNumber - 1);
  }

  void jumpToToday() {
    final nowWeek = DateCalculator.getCurrentWeekNumber(widget.firstWeekMonday);
    _pageController.animateToPage(
      nowWeek.clamp(1, 20) - 1,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 判定是否全局无课 (20周都没有课程)
    if (widget.courses.isEmpty) {
      return Center(
        child: Text(
          '未获取到课表',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).hintColor.withOpacity(0.5),
          ),
        ),
      );
    }

    final weekMonday = DateCalculator.getWeekMonday(
      widget.firstWeekMonday,
      _currentWeekNumber,
    );
    final weekSunday = DateCalculator.getWeekSunday(
      widget.firstWeekMonday,
      _currentWeekNumber,
    );
    
    return Column(
      children: [
        // 顶部导航栏
        _buildWeekNavigation(_currentWeekNumber, weekMonday, weekSunday),
        
        // 课表网格 (仅允许 1-20 周)
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: 20,
            onPageChanged: (page) {
              setState(() {
                _currentWeekNumber = page + 1;
              });
            },
            itemBuilder: (context, index) {
              final weekNum = index + 1;
              final monday = DateCalculator.getWeekMonday(widget.firstWeekMonday, weekNum);
              return _buildTimetableGrid(monday, weekNum);
            },
          ),
        ),
      ],
    );
  }
  
  /// 构建周导航栏
  Widget _buildWeekNavigation(int weekNumber, DateTime monday, DateTime sunday) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).appBarTheme.backgroundColor,
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Text(
            '第$weekNumber周',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF2D3436),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
  
  /// 构建课表网格
  Widget _buildTimetableGrid(DateTime weekMonday, int weekNumber) {
    // 获取本周的课程
    final weekCourses = _getCoursesForWeek(weekNumber);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        const timeColumnWidth = 55.0;
        // 定义大节固定高度和间距
        const double sectionHeight = 100.0;
        const double targetGap = 4.0;
        const int totalBigSections = 6;
        final double totalHeight = totalBigSections * (sectionHeight + targetGap) + 40.0;
        
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: screenWidth,
              minHeight: totalHeight,
            ),
            child: Column(
              children: [
                // 星期标题行
                _buildWeekdayHeader(screenWidth, weekMonday),
                
                // 时间轴和课程
                SizedBox(
                  height: totalHeight - 40,
                  width: screenWidth,
                  child: Stack(
                    children: [
                      // 左侧时间轴 (起止时间显示)
                      _buildFixedTimeAxis(totalBigSections, sectionHeight, targetGap),
                      
                      // 课程块
                      ..._buildFixedCourseBlocks(weekCourses, screenWidth, sectionHeight, targetGap),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 构建固定的大节时间轴（显示起止时间，对齐卡片边缘）
  Widget _buildFixedTimeAxis(int totalSections, double height, double gap) {
    const times = [
      ['08:00', '09:40'],
      ['10:05', '11:45'],
      ['14:30', '16:10'],
      ['16:35', '18:15'],
      ['19:30', '21:10'],
      ['21:20', '23:00'],
    ];

    return Column(
      children: List.generate(totalSections, (index) {
        return Container(
          height: height,
          width: 55,
          margin: EdgeInsets.only(bottom: gap),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(times[index][0], style: TextStyle(fontSize: 11, color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF636E72), fontWeight: FontWeight.w500)),
            ],
          ),
        );
      }),
    );
  }

  /// 构建固定的课程块
  List<Widget> _buildFixedCourseBlocks(List<CourseModel> courses, double screenWidth, double blockHeight, double gap) {
    final blocks = <Widget>[];
    const timeColumnWidth = 55.0;
    final columnWidth = (screenWidth - timeColumnWidth) / 7.0;

    for (final course in courses) {
      final int bigSectionIndex = (course.startPeriod - 1) ~/ 2;
      final int periodDuration = (course.endPeriod - course.startPeriod + 1);
      final int bigSectionSpan = (periodDuration / 2).ceil();

      final top = bigSectionIndex * (blockHeight + gap);
      final height = bigSectionSpan * blockHeight + (bigSectionSpan - 1) * gap;
      
      final dayOffset = (course.dayOfWeek - 1) * columnWidth;
      final left = timeColumnWidth + dayOffset + (gap / 2);
      final width = columnWidth - gap;

      blocks.add(
        Positioned(
          top: top,
          left: left,
          width: width,
          height: height,
          child: _buildCourseBlock(course),
        ),
      );
    }
    return blocks;
  }
  
  /// 构建单个课程块
  Widget _buildCourseBlock(CourseModel course) {
    final color = _getCourseColor(course.name);
    return GestureDetector(
      onTap: () => _showCourseDetail(course),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6), // 圆角 6px
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              course.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            if (course.classroom.isNotEmpty)
              Text(
                course.classroom,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  height: 1.1,
                ),
                maxLines: 3, // 支持 3 行显示
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
  
  /// 显示课程详情
  void _showCourseDetail(CourseModel course) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(course.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('教师', course.teacher),
            _buildDetailRow('教室', course.classroom),
            _buildDetailRow('周次', WeekParser.formatWeeks(
              WeekParser.parseWeeks(course.weeks),
            )),
            _buildDetailRow(
              '节次',
              '${course.startPeriod}-${course.endPeriod}节',
            ),
            _buildDetailRow(
              '时间',
              '${DateCalculator.getSectionTime(course.startPeriod)['start']!.format(context)}-'
              '${DateCalculator.getSectionTime(course.endPeriod)['end']!.format(context)}',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value.isEmpty ? '未知' : value),
          ),
        ],
      ),
    );
  }
  
  /// 获取本周的课程
  List<CourseModel> _getCoursesForWeek(int weekNumber) {
    return widget.courses.where((course) {
      final weeks = WeekParser.parseWeeks(course.weeks);
      return weeks.contains(weekNumber);
    }).toList();
  }
  
  /// 根据课程名称生成颜色
  Color _getCourseColor(String courseName) {
    return CourseColorUtils.getColorForCourse(courseName);
  }

  /// 构建星期标题
  Widget _buildWeekdayHeader(double screenWidth, DateTime weekMonday) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month}-${now.day}';

    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Theme.of(context).appBarTheme.backgroundColor,
      ),
      child: Row(
        children: [
          // 左侧留空（对应时间轴宽度）
          const SizedBox(width: 55),
          ...List.generate(7, (index) {
            final date = weekMonday.add(Duration(days: index));
            final isToday = '${date.year}-${date.month}-${date.day}' == todayStr;
            
            return Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    weekdays[index],
                    style: TextStyle(
                      fontSize: 12,
                      color: isToday 
                          ? Theme.of(context).primaryColor 
                          : (Theme.of(context).brightness == Brightness.dark ? Colors.white60 : const Color(0xFF636E72)),
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isToday ? Theme.of(context).primaryColor : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 14,
                        color: isToday ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF2D3436)),
                        fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
