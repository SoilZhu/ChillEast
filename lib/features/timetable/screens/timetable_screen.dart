import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../services/timetable_service.dart';
import '../services/timetable_storage.dart';
import '../models/course_model.dart';
import '../utils/ics_parser.dart';
import '../utils/date_calculator.dart';
import '../utils/week_parser.dart';
import '../utils/course_color_utils.dart';
import '../../../core/widgets/triangle_painter.dart';
import '../providers/timetable_status_provider.dart';
import '../providers/reminder_trigger_provider.dart';
import '../widgets/weekly_calendar_view.dart';
import '../widgets/download_timetable_screen.dart';
import '../widgets/empty_timetable_state.dart';
import '../../homework/providers/homework_provider.dart';
import '../../homework/models/homework_model.dart';
import '../../../core/state/auth_state.dart';
import '../../../core/widgets/login_required_placeholder.dart';
import 'package:logger/logger.dart';

/// 自定义次顶栏指示器：上圆下方
class MD2Indicator extends Decoration {
  final double indicatorHeight;
  final Color color;
  final double radius;

  const MD2Indicator({
    this.indicatorHeight = 4,
    required this.color,
    this.radius = 4,
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _MD2Painter(this, onChanged);
  }
}

class _MD2Painter extends BoxPainter {
  final MD2Indicator decoration;

  _MD2Painter(this.decoration, VoidCallback? onChanged) : super(onChanged);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    assert(configuration.size != null);

    final rect = Offset(offset.dx + 4, offset.dy + configuration.size!.height - decoration.indicatorHeight) & 
                 Size(configuration.size!.width - 8, decoration.indicatorHeight);
    
    final paint = Paint()
      ..color = decoration.color
      ..style = PaintingStyle.fill;

    // 上圆下方
    final rrect = RRect.fromLTRBAndCorners(
      rect.left,
      rect.top,
      rect.right,
      rect.bottom,
      topLeft: Radius.circular(decoration.radius),
      topRight: Radius.circular(decoration.radius),
    );

    canvas.drawRRect(rrect, paint);
  }
}

class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> with SingleTickerProviderStateMixin {
  final Logger _logger = Logger();
  final TimetableStorage _storage = TimetableStorage();
  late TabController _tabController;
  final ScrollController _agendaScrollController = ScrollController();
  final GlobalKey<WeeklyCalendarViewState> _weeklyKey = GlobalKey();
  
  List<CourseModel> _courses = [];
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _firstWeekMonday;
  bool _hasLocalTimetable = false;
  
  // 用于日程视图的全局列表
  List<MapEntry<DateTime, List<CourseModel>>> _agendaTimeline = [];
  int _todayIndex = -1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // 监听标签切换，回到日程页时自动跳转到今天
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabController.index == 0) {
        _scrollToToday();
      }
    });

    _loadLocalTimetable();
  }


  @override
  void dispose() {
    _tabController.dispose();
    _agendaScrollController.dispose();
    super.dispose();
  }
  
  Future<void> _loadLocalTimetable() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final hasTimetable = await _storage.hasLocalTimetable();
      if (hasTimetable) {
        final icsContent = await _storage.readTimetable();
        if (icsContent != null) {
          final courses = IcsParser.parse(icsContent);
          final metadata = await _storage.readMetadata();
          DateTime? firstWeekMonday;
          if (metadata != null && metadata['firstWeekMonday'] != null) {
            firstWeekMonday = DateTime.parse(metadata['firstWeekMonday']);
          }
          
          setState(() {
            _courses = courses;
            _hasLocalTimetable = true;
            _firstWeekMonday = firstWeekMonday;
            _isLoading = false;
            if (_firstWeekMonday != null) {
              _generateAgendaTimeline();
            }
          });

          // 如果在日程页且数据加载完成，直接跳转
          _scrollToToday();
        } else {
          setState(() { _hasLocalTimetable = false; _isLoading = false; });
        }
      } else {
        setState(() { _hasLocalTimetable = false; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _errorMessage = e.toString(); _isLoading = false; });
    }
  }

  /// 生成完整的日程时间轴（跨周）
  void _generateAgendaTimeline() {
    if (_courses.isEmpty || _firstWeekMonday == null) return;
    
    final Map<DateTime, List<CourseModel>> grouped = {};
    
    // 遍历 1 到 25 周（通常学期长度）
    for (int w = 1; w <= 25; w++) {
      for (int d = 1; d <= 7; d++) {
        final date = DateCalculator.calculateDate(
          firstWeekMonday: _firstWeekMonday!,
          weekNumber: w,
          dayOfWeek: d,
        );
        // 清除时间，只保留年月日用于比较
        final dayKey = DateTime(date.year, date.month, date.day);
        
        // 查找属于这周这一天的课程
        final dayCourses = _courses.where((c) {
          if (c.dayOfWeek != d) return false;
          final weeks = WeekParser.parseWeeks(c.weeks);
          return weeks.contains(w);
        }).toList();

        // 查找属于这天的作业
        final homeworkState = ref.read(homeworkProvider);
        final hasHomework = homeworkState.maybeWhen(
          data: (list) => list.any((h) => 
            h.status == HomeworkStatus.pending && 
            h.endTime != null && // 👈 只显示有截止时间的作业
            h.endTime?.year == dayKey.year && 
            h.endTime?.month == dayKey.month && 
            h.endTime?.day == dayKey.day
          ),
          orElse: () => false,
        );
        
        if (dayCourses.isNotEmpty || hasHomework) {
          dayCourses.sort((a, b) => a.startPeriod.compareTo(b.startPeriod));
          grouped[dayKey] = dayCourses;
        }
      }
    }

    final sortedEntries = grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    
    // 找到离今天最近的
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int closestIndex = -1;
    
    for (int i = 0; i < sortedEntries.length; i++) {
      if (!sortedEntries[i].key.isBefore(today)) {
        closestIndex = i;
        break;
      }
    }

    setState(() {
      _agendaTimeline = sortedEntries;
      _todayIndex = closestIndex;
    });
  }

  void _handleTodayClick() {
    if (_tabController.index == 0) {
      _scrollToToday();
    } else {
      _weeklyKey.currentState?.jumpToToday();
    }
  }

  void _scrollToToday() {
    if (_todayIndex <= 0 || !mounted) return;
    
    // 立即尝试跳转（如果已经有 clients）
    if (_agendaScrollController.hasClients) {
      _performScroll();
    }
    
    // 保底：在下一帧再次尝试（确保内容已渲染）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _agendaScrollController.hasClients) {
        _performScroll();
      }
    });
  }

  void _performScroll() {
    double offset = 0;
    for (int i = 0; i < _todayIndex; i++) {
      // 月份标题高度 (40px)
      if (i == 0 || _agendaTimeline[i].key.month != _agendaTimeline[i-1].key.month) {
        offset += 40.0;
      }
      final cardCount = _agendaTimeline[i].value.length;
      // 计算高度：单张卡片 72px (包括 12px margin), 区域底部间距 24px
      double sectionHeight = cardCount * 72.0 + 24.0;
      if (sectionHeight < 84) sectionHeight = 84;
      offset += sectionHeight;
    }
    _agendaScrollController.jumpTo(offset);
  }
  
  Future<void> _showDownloadDialog() async {
    final success = await Navigator.push<bool>(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const DownloadTimetableScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 0.1); // 从下方 10% 处开始
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;

          var slideTween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var fadeTween = Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));

          return FadeTransition(
            opacity: animation.drive(fadeTween),
            child: SlideTransition(
              position: animation.drive(slideTween),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
    
    if (success == true) {
      await _loadLocalTimetable();
      // 刷新全局课表状态
      ref.read(timetableStatusProvider.notifier).refresh();
      // 强制触发提醒气泡刷新逻辑
      ref.read(classReminderTriggerProvider.notifier).update((state) => state + 1);
    }
  }

  /// 分享课表
  Future<void> _shareTimetable() async {
    if (!_hasLocalTimetable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可分享的课表')),
      );
      return;
    }
    
    try {
      final filePath = await _storage.getTimetableFilePath();
      if (filePath == null) {
        throw Exception('课表文件不存在');
      }
      
      // 使用 share_plus 分享文件
      await Share.shareXFiles(
        [XFile(filePath)],
        text: '我的湖南农业大学课表',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 监听作业变化，同步刷新日程轴
    ref.listen(homeworkProvider, (_, __) {
      if (_courses.isNotEmpty && _firstWeekMonday != null) {
        _generateAgendaTimeline();
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildSubHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSubHeader() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              padding: EdgeInsets.zero,
              labelPadding: const EdgeInsets.symmetric(horizontal: 20),
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.grey[600],
              labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: Colors.transparent,
              indicator: MD2Indicator(
                color: Theme.of(context).primaryColor,
                indicatorHeight: 4,
                radius: 4,
              ),
              tabs: const [
                Tab(text: '日程'),
                Tab(text: '周'),
              ],
            ),
          ),
          // 💡 右侧操作按钮
          if (_hasLocalTimetable) ...[
            IconButton(
              icon: Icon(
                Icons.today_rounded, 
                size: 22, 
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF5F6368)
              ),
              onPressed: _handleTodayClick,
              tooltip: '回到今天',
            ),
            () {
              // 计算当前是否已经超过 20 周
              bool needsSync = false;
              if (_firstWeekMonday != null) {
                final currentWeek = DateCalculator.getCurrentWeekNumber(_firstWeekMonday!);
                if (currentWeek > 20) needsSync = true;
              }
              
              final downloadBtn = IconButton(
                icon: Icon(
                  Icons.download_rounded, 
                  size: 22, 
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF5F6368)
                ),
                onPressed: _showDownloadDialog,
                tooltip: needsSync ? '同步新学期的课表' : '导入新课表',
              );

              if (needsSync) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    downloadBtn,
                    Positioned(
                      top: 40, // 位于按钮下方
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 小尖尖 (向上)
                          CustomPaint(
                            size: const Size(10, 6),
                            painter: TrianglePainter(
                              color: isDark ? Colors.grey.withOpacity(0.4) : Colors.black54,
                            ),
                          ),
                          // 气泡主体
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey.withOpacity(0.4) : Colors.black54,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '同步新学期',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return downloadBtn;
            }(),
            IconButton(
              icon: Icon(
                Icons.share_rounded, 
                size: 20, 
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF5F6368)
              ),
              onPressed: _shareTimetable,
              tooltip: '分享课表',
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    final authState = ref.watch(authStateProvider);
    
    // 只有在完全没有本地账号信息时，才显示登录占位符
    if (authState.status == AuthStatus.unauthenticated && !authState.hasAccount) {
      return const LoginRequiredPlaceholder(
        title: '需要登录以查看课表',
        message: '登录后即可同步并查看您的个人课表信息',
      );
    }

    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) return _buildErrorState();
    if (!_hasLocalTimetable || _courses.isEmpty) {
      return EmptyTimetableState(onDownload: _showDownloadDialog);
    }
    if (_firstWeekMonday == null) return _buildMetadataMissingState();

    return TabBarView(
      controller: _tabController,
      children: [
        _buildAgendaView(),
        WeeklyCalendarView(
          key: _weeklyKey,
          courses: _courses,
          firstWeekMonday: _firstWeekMonday!,
        ),
      ],
    );
  }

  Widget _buildAgendaView() {
    if (_agendaTimeline.isEmpty) {
      return const Center(child: Text('本学期暂无课程安排'));
    }

    return ListView.builder(
      controller: _agendaScrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _agendaTimeline.length,
      itemBuilder: (context, index) {
        final entry = _agendaTimeline[index];
        final bool showMonth = index == 0 || entry.key.month != _agendaTimeline[index - 1].key.month;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showMonth) _buildMonthHeader(entry.key.month),
            _buildAgendaDaySection(entry.key, entry.value),
          ],
        );
      },
    );
  }

  Widget _buildMonthHeader(int month) {
    const months = ['一月', '二月', '三月', '四月', '五月', '六月', '七月', '八月', '九月', '十月', '十一月', '十二月'];
    return Container(
      height: 40,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(top: 0, left: 62, bottom: 12), // 顶部压缩实现字体上移，底部维持 12px 间距
      child: Text(
        months[month - 1],
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF202124),
          height: 1.0, // 紧凑行高进一步上移
        ),
      ),
    );
  }

  Widget _buildAgendaDaySection(DateTime date, List<CourseModel> courses) {
    const weekDays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final dayName = weekDays[date.weekday - 1];
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧日期栏
          SizedBox(
            width: 50,
            child: Column(
              children: [
                Text(dayName, style: TextStyle(
                  color: isToday 
                      ? Theme.of(context).primaryColor 
                      : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.grey[600]), 
                  fontSize: 13,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                )),
                const SizedBox(height: 4),
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: isToday ? Theme.of(context).primaryColor : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      color: isToday ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 右侧课程卡片列表
          Expanded(
            child: Column(
              children: [
                ..._buildDayHomeworkItems(date),
                ...courses.map((course) => _buildCourseAgendaCard(course)).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseAgendaCard(CourseModel course) {
    final baseColor = CourseColorUtils.getColorForCourse(course.name);
    
    final startTime = DateCalculator.getSectionTime(course.startPeriod)['start']!;
    final endTime = DateCalculator.getSectionTime(course.endPeriod)['end']!;
    final timeRange = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}-'
                      '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      height: 60, // 60 + 12 margin = 72 total
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(8), // 圆角调回 8px
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            course.name,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            '$timeRange, 【${course.classroom}】 ${course.teacher}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text('加载失败'),
          Text(_errorMessage!, style: TextStyle(color: Theme.of(context).hintColor), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _loadLocalTimetable, child: const Text('重试')),
      ]));
  }

  Widget _buildMetadataMissingState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.info_outline, size: 64, color: Colors.orange),
          const SizedBox(height: 16),
          const Text('课表信息不完整'),
          const Text('请重新下载课表'),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _showDownloadDialog, child: const Text('重新下载')),
      ]));
  }
  List<Widget> _buildDayHomeworkItems(DateTime date) {
    final homeworkState = ref.watch(homeworkProvider);
    return homeworkState.maybeWhen(
      data: (list) {
        final dayHomework = list.where((h) => 
          h.status == HomeworkStatus.pending &&
          h.endTime != null && // 👈 只显示有截止时间的作业
          h.endTime?.year == date.year && 
          h.endTime?.month == date.month && 
          h.endTime?.day == date.day
        ).toList();
        
        // 按截止时间升序排列 (时间小的排前面)
        dayHomework.sort((a, b) => a.endTime!.compareTo(b.endTime!));
        
        return dayHomework.map((h) => _buildHomeworkAgendaTask(h)).toList();
      },
      orElse: () => [],
    );
  }

  Widget _buildHomeworkAgendaTask(HomeworkModel item) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF3D3D29) : const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.assignment_late_outlined, size: 18, color: Color(0xFFF39C12)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF2D3436),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${item.courseName} · 截止时间 ${item.endTime != null ? DateFormat('HH:mm').format(item.endTime!) : "无截止时间"}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF7F8C8D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

