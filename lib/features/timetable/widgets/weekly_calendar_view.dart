import 'package:flutter/material.dart';
import '../models/course_model.dart';
import '../models/course_reminder_rule.dart';
import '../services/course_reminder_storage.dart';
import '../utils/date_calculator.dart';
import '../utils/week_parser.dart';
import '../utils/course_color_utils.dart';
import 'course_reminder_dialog.dart';
import '../../../core/utils/l10n_extension.dart';

/// 周视图日历组件
class WeeklyCalendarView extends StatefulWidget {
  final List<CourseModel> courses;
  final DateTime firstWeekMonday;
  final bool showEndTime;
  final VoidCallback? onCourseColorChanged;

  const WeeklyCalendarView({
    super.key,
    required this.courses,
    required this.firstWeekMonday,
    this.showEndTime = false,
    this.onCourseColorChanged,
  });

  @override
  WeeklyCalendarViewState createState() => WeeklyCalendarViewState();
}

class WeeklyCalendarViewState extends State<WeeklyCalendarView> {
  late PageController _pageController;
  int _currentWeekNumber = 1;
  List<CourseReminderRule> _reminderRules = [];

  @override
  void initState() {
    super.initState();
    final initialWeek =
        DateCalculator.getCurrentWeekNumber(widget.firstWeekMonday);
    _currentWeekNumber = initialWeek.clamp(1, 20);
    _pageController = PageController(initialPage: _currentWeekNumber - 1);
    CourseColorUtils.syncCourses(widget.courses.map((c) => c.name));
    _loadReminderRules();
  }

  Future<void> _loadReminderRules() async {
    final rules = await CourseReminderStorage().readRules();
    if (mounted) {
      setState(() {
        _reminderRules = rules;
      });
    }
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
  void didUpdateWidget(WeeklyCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.courses != widget.courses ||
        oldWidget.firstWeekMonday != widget.firstWeekMonday ||
        oldWidget.showEndTime != widget.showEndTime) {
      CourseColorUtils.syncCourses(widget.courses.map((c) => c.name));
      _loadReminderRules();
      setState(() {});
    }
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
          context.l10n.noTimetableFound,
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
              final monday =
                  DateCalculator.getWeekMonday(widget.firstWeekMonday, weekNum);
              return _buildTimetableGrid(monday, weekNum);
            },
          ),
        ),
      ],
    );
  }

  /// 构建周导航栏
  Widget _buildWeekNavigation(
      int weekNumber, DateTime monday, DateTime sunday) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).appBarTheme.backgroundColor,
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Text(
            context.l10n.weekNumber(weekNumber),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : const Color(0xFF2D3436),
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
        final double totalHeight =
            totalBigSections * (sectionHeight + targetGap) + 40.0;

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
                      _buildFixedTimeAxis(
                          totalBigSections, sectionHeight, targetGap),

                      // 课程块
                      ..._buildFixedCourseBlocks(weekCourses, screenWidth,
                          sectionHeight, targetGap, weekNumber),
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
            mainAxisAlignment: widget.showEndTime
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.start,
            children: [
              Text(
                times[index][0],
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white54
                      : const Color(0xFF636E72),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (widget.showEndTime)
                Text(
                  times[index][1],
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white38
                        : const Color(0xFF9E9E9E),
                    fontWeight: FontWeight.w400,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  /// 冲突层级排序规则：
  /// 1. 有教室的比没教室的层级更高（后绘制，置于上层）
  /// 2. 时长更短的比时长更长的层级更高（后绘制，置于上层）
  /// 3. 兜底按 startPeriod 和 id 稳定排序
  static int compareCourseLayers(CourseModel a, CourseModel b) {
    // 1. 教室优先：有教室的比没教室的层级更高（排在后面，后绘制在顶层）
    final aHasRoom = a.classroom.trim().isNotEmpty;
    final bHasRoom = b.classroom.trim().isNotEmpty;
    if (aHasRoom != bHasRoom) {
      return aHasRoom ? 1 : -1;
    }

    // 2. 时长优先：时长更短的比时长更长的层级更高（排在后面，后绘制在顶层）
    final aDuration = a.endPeriod - a.startPeriod + 1;
    final bDuration = b.endPeriod - b.startPeriod + 1;
    if (aDuration != bDuration) {
      return bDuration.compareTo(aDuration); // 时长更长(值更大)在底层，时长更短在上层
    }

    // 3. 兜底稳定排序
    final startCompare = a.startPeriod.compareTo(b.startPeriod);
    if (startCompare != 0) return startCompare;
    return a.id.compareTo(b.id);
  }

  /// 判定两门课程是否存在时间重叠冲突（同一天且节次区间重叠）
  static bool areCoursesOverlapping(CourseModel a, CourseModel b) {
    if (a.dayOfWeek != b.dayOfWeek) return false;
    return a.startPeriod <= b.endPeriod && b.startPeriod <= a.endPeriod;
  }

  /// 构建固定的课程块
  List<Widget> _buildFixedCourseBlocks(
    List<CourseModel> courses,
    double screenWidth,
    double blockHeight,
    double gap,
    int weekNumber,
  ) {
    final blocks = <Widget>[];
    const timeColumnWidth = 55.0;
    final columnWidth = (screenWidth - timeColumnWidth) / 7.0;

    // 冲突课程都显示：按层级升序排序（底层先绘制，顶层后绘制置于上层）
    final sortedCourses = List<CourseModel>.from(courses)
      ..sort(compareCourseLayers);

    for (final course in sortedCourses) {
      final int bigSectionIndex = (course.startPeriod - 1) ~/ 2;
      final int periodDuration = (course.endPeriod - course.startPeriod + 1);
      final int bigSectionSpan = (periodDuration / 2).ceil();

      final top = bigSectionIndex * (blockHeight + gap);
      final height = bigSectionSpan * blockHeight + (bigSectionSpan - 1) * gap;

      final dayOffset = (course.dayOfWeek - 1) * columnWidth;
      final left = timeColumnWidth + dayOffset + (gap / 2);
      final width = columnWidth - gap;

      // 获取同时间段所有冲突课程
      final conflicts = sortedCourses
          .where((other) => areCoursesOverlapping(course, other))
          .toList();
      final hasConflict = conflicts.length > 1;

      blocks.add(
        Positioned(
          top: top,
          left: left,
          width: width,
          height: height,
          child: _buildCourseBlock(
            course,
            weekNumber: weekNumber,
            hasConflict: hasConflict,
            conflictingCourses: conflicts,
          ),
        ),
      );
    }
    return blocks;
  }

  /// 构建单个课程块
  Widget _buildCourseBlock(
    CourseModel course, {
    required int weekNumber,
    bool hasConflict = false,
    List<CourseModel>? conflictingCourses,
  }) {
    final color = _getCourseColor(course.name);
    final customRule = CourseReminderStorage.resolveEffectiveRule(
      rules: _reminderRules,
      courseName: course.name,
      week: weekNumber,
      dayOfWeek: course.dayOfWeek,
      startPeriod: course.startPeriod,
    );

    final weekdays = [
      context.l10n.weekdayMon,
      context.l10n.weekdayTue,
      context.l10n.weekdayWed,
      context.l10n.weekdayThu,
      context.l10n.weekdayFri,
      context.l10n.weekdaySat,
      context.l10n.weekdaySun,
    ];
    final weekdayStr = weekdays[(course.dayOfWeek - 1).clamp(0, 6)];
    final semanticLabel = StringBuffer()
      ..write(
          '$weekdayStr 第${course.startPeriod}至${course.endPeriod}节，${course.name}')
      ..write(course.classroom.isNotEmpty ? '，教室：${course.classroom}' : '')
      ..write(hasConflict ? context.l10n.a11yCourseConflict : '');

    return Semantics(
      button: true,
      label: semanticLabel.toString(),
      hint: context.l10n.a11yTapForCourseDetail,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => _showCourseDetail(
          course,
          weekNumber: weekNumber,
          conflictingCourses: conflictingCourses,
        ),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6), // 圆角 6px
            border: hasConflict
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 1.0,
                  )
                : null,
            boxShadow: hasConflict
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              Column(
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
              if (customRule != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(
                    customRule.isDisabled
                        ? Icons.notifications_off_rounded
                        : Icons.alarm_on_rounded,
                    size: 11,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              if (hasConflict)
                const Positioned(
                  bottom: 0,
                  right: 0,
                  child: Icon(
                    Icons.layers_rounded,
                    size: 10,
                    color: Colors.white70,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 显示课程详情
  void _showCourseDetail(
    CourseModel course, {
    required int weekNumber,
    List<CourseModel>? conflictingCourses,
  }) {
    final hasMultiple =
        conflictingCourses != null && conflictingCourses.length > 1;

    showDialog(
      context: context,
      builder: (dialogContext) {
        if (!hasMultiple) {
          return _SingleCourseDetailDialog(
            course: course,
            weekNumber: weekNumber,
            onColorChanged: () {
              setState(() {});
              widget.onCourseColorChanged?.call();
            },
            onReminderChanged: () {
              _loadReminderRules();
            },
          );
        }

        return _ConflictingCoursesDialog(
          initialCourse: course,
          courses: conflictingCourses,
          weekNumber: weekNumber,
          onColorChanged: () {
            setState(() {});
            widget.onCourseColorChanged?.call();
          },
          onReminderChanged: () {
            _loadReminderRules();
          },
        );
      },
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
    final weekdays = [
      context.l10n.weekdayMon,
      context.l10n.weekdayTue,
      context.l10n.weekdayWed,
      context.l10n.weekdayThu,
      context.l10n.weekdayFri,
      context.l10n.weekdaySat,
      context.l10n.weekdaySun,
    ];
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
            final isToday =
                '${date.year}-${date.month}-${date.day}' == todayStr;

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
                          : (Theme.of(context).brightness == Brightness.dark
                              ? Colors.white60
                              : const Color(0xFF636E72)),
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isToday
                          ? Theme.of(context).primaryColor
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 14,
                        color: isToday
                            ? Colors.white
                            : (Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : const Color(0xFF2D3436)),
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

/// 单门课程详情弹窗
class _SingleCourseDetailDialog extends StatefulWidget {
  final CourseModel course;
  final int weekNumber;
  final VoidCallback onColorChanged;
  final VoidCallback onReminderChanged;

  const _SingleCourseDetailDialog({
    required this.course,
    required this.weekNumber,
    required this.onColorChanged,
    required this.onReminderChanged,
  });

  @override
  State<_SingleCourseDetailDialog> createState() =>
      _SingleCourseDetailDialogState();
}

class _SingleCourseDetailDialogState extends State<_SingleCourseDetailDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.course.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow(context.l10n.teacher, widget.course.teacher),
          _buildDetailRow(context.l10n.classroom, widget.course.classroom),
          _buildDetailRow(
            context.l10n.weeksLabel,
            WeekParser.formatWeeksLocalized(
              context,
              WeekParser.parseWeeks(widget.course.weeks),
            ),
          ),
          _buildDetailRow(
            context.l10n.periodsLabel,
            context.l10n.periodsRange(
              widget.course.startPeriod,
              widget.course.endPeriod,
            ),
          ),
          _buildDetailRow(
            context.l10n.timeLabel,
            '${DateCalculator.getSectionTime(widget.course.startPeriod)['start']!.format(context)}-'
            '${DateCalculator.getSectionTime(widget.course.endPeriod)['end']!.format(context)}',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (reminderCtx) => CourseReminderDialog(
                course: widget.course,
                weekNumber: widget.weekNumber,
                onSaved: widget.onReminderChanged,
              ),
            );
          },
          child: Text(context.l10n.setReminder),
        ),
        TextButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (pickerContext) => _MaterialColorPickerDialog(
                courseName: widget.course.name,
                onColorChanged: () {
                  setState(() {});
                  widget.onColorChanged();
                },
              ),
            );
          },
          child: Text(context.l10n.changeColor),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.close),
        ),
      ],
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
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value.isEmpty ? context.l10n.unknown : value),
          ),
        ],
      ),
    );
  }
}

/// 冲突课程浏览弹窗：支持在同时间段多门重叠课程之间切换查看详情
class _ConflictingCoursesDialog extends StatefulWidget {
  final CourseModel initialCourse;
  final List<CourseModel> courses;
  final int weekNumber;
  final VoidCallback onColorChanged;
  final VoidCallback onReminderChanged;

  const _ConflictingCoursesDialog({
    required this.initialCourse,
    required this.courses,
    required this.weekNumber,
    required this.onColorChanged,
    required this.onReminderChanged,
  });

  @override
  State<_ConflictingCoursesDialog> createState() =>
      _ConflictingCoursesDialogState();
}

class _ConflictingCoursesDialogState extends State<_ConflictingCoursesDialog> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    final idx = widget.courses.indexOf(widget.initialCourse);
    _selectedIndex = idx >= 0 ? idx : 0;
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.courses[_selectedIndex];

    return AlertDialog(
      title: Text(
        current.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.courses.length > 1) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(widget.courses.length, (i) {
                  final c = widget.courses[i];
                  final isSel = i == _selectedIndex;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6, bottom: 8),
                    child: ChoiceChip(
                      label: Text(
                        c.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSel ? Colors.white : null,
                        ),
                      ),
                      selected: isSel,
                      selectedColor: Theme.of(context).primaryColor,
                      onSelected: (_) => setState(() => _selectedIndex = i),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),
          ],
          _buildRow(context.l10n.teacher, current.teacher),
          _buildRow(context.l10n.classroom, current.classroom),
          _buildRow(
            context.l10n.weeksLabel,
            WeekParser.formatWeeksLocalized(
              context,
              WeekParser.parseWeeks(current.weeks),
            ),
          ),
          _buildRow(
            context.l10n.periodsLabel,
            context.l10n.periodsRange(current.startPeriod, current.endPeriod),
          ),
          _buildRow(
            context.l10n.timeLabel,
            '${DateCalculator.getSectionTime(current.startPeriod)['start']!.format(context)}-'
            '${DateCalculator.getSectionTime(current.endPeriod)['end']!.format(context)}',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (reminderCtx) => CourseReminderDialog(
                course: current,
                weekNumber: widget.weekNumber,
                onSaved: widget.onReminderChanged,
              ),
            );
          },
          child: Text(context.l10n.setReminder),
        ),
        TextButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (pickerContext) => _MaterialColorPickerDialog(
                courseName: current.name,
                onColorChanged: () {
                  setState(() {});
                  widget.onColorChanged();
                },
              ),
            );
          },
          child: Text(context.l10n.changeColor),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.close),
        ),
      ],
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value.isEmpty ? context.l10n.unknown : value),
          ),
        ],
      ),
    );
  }
}

/// 基于 https://materialui.co/colors 规范的课程颜色选择弹窗
class _MaterialColorPickerDialog extends StatelessWidget {
  final String courseName;
  final VoidCallback onColorChanged;

  const _MaterialColorPickerDialog({
    required this.courseName,
    required this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currentColor = CourseColorUtils.getColorForCourse(courseName);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.palette, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.selectCourseColor,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.55,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.start,
                    children: CourseColorUtils.materialColorItems.map((item) {
                      final isCurrent =
                          item.color.toARGB32() == currentColor.toARGB32();
                      final occupyingCourse =
                          CourseColorUtils.getCourseUsingColor(
                        item.color,
                        excludeCourse: courseName,
                      );

                      return InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () async {
                          final conflict = occupyingCourse;
                          await CourseColorUtils.setCourseColor(
                            courseName,
                            item.color,
                          );
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                          onColorChanged();
                          if (conflict != null && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.l10n.colorSwappedNotice(conflict),
                                ),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        child: Tooltip(
                          message: occupyingCourse != null
                              ? '${item.family} ${item.shade} ($occupyingCourse)'
                              : '${item.family} ${item.shade}',
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: item.color,
                              shape: BoxShape.circle,
                            ),
                            child: isCurrent
                                ? const Icon(
                                    Icons.check,
                                    size: 24,
                                    color: Colors.white,
                                  )
                                : (occupyingCourse != null
                                    ? Center(
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: 0.85),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      )
                                    : null),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.close),
        ),
      ],
    );
  }
}
