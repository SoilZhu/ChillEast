import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/state/auth_state.dart';
import '../../../core/utils/coordinate_converter.dart';
import '../../../core/utils/location_helper.dart';
import '../../../core/utils/route_utils.dart';
import '../../../core/widgets/login_required_placeholder.dart';
import '../../auth/screens/login_screen.dart';
import '../../profile/providers/appearance_provider.dart';
import '../../profile/screens/settings_screen.dart';
import '../../score/screens/score_screen.dart';
import '../../timetable/models/course_model.dart';
import '../../timetable/services/timetable_storage.dart';
import '../../timetable/utils/course_color_utils.dart';
import '../../timetable/utils/date_calculator.dart';
import '../../timetable/utils/ics_parser.dart';
import '../../timetable/utils/week_parser.dart';
import '../../workspace/screens/campus_card_recharge_screen.dart';
import '../../workspace/screens/classroom_inquiry_screen.dart';
import '../../workspace/screens/payment_code_screen.dart';
import '../../workspace/screens/vpn_converter_screen.dart';
import '../../workspace/screens/webview_detail_screen.dart';
import '../../workspace/services/campus_card_service.dart';
import '../screens/bus_tracking_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final Function(int)? onNavigateToTab;

  const HomeScreen({super.key, this.onNavigateToTab});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<CourseModel> _todayCourses = [];
  bool _isLoadingTimetable = false;
  bool _isShowingTomorrow = false;

  DateTime? _firstWeekMonday;
  int _currentWeek = 0;
  int _totalWeeks = 20;
  int _elapsedDays = 0;
  int _remainingDays = 0;
  int _progressPercent = 0;

  @override
  void initState() {
    super.initState();
    _loadPreviewCourses();
    _loadSemesterProgress();
  }

  void _navigateToTab(BuildContext context, int index) {
    if (widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(index);
    }
  }

  void _showLoginDialog(BuildContext context) {
    if (ref.read(authStateProvider).status == AuthStatus.authenticating) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正在登录，请稍候...'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const LoginScreen(),
    );
  }

  Future<void> _loadPreviewCourses() async {
    setState(() {
      _isLoadingTimetable = true;
    });

    try {
      final storage = TimetableStorage();
      final hasTimetable = await storage.hasLocalTimetable();

      if (hasTimetable) {
        final icsContent = await storage.readTimetable();
        final metadata = await storage.readMetadata();

        if (icsContent != null) {
          final allCourses = IcsParser.parse(icsContent);

          final now = DateTime.now();
          final bool isAfter10PM = now.hour >= 22;
          final targetDate = isAfter10PM ? now.add(const Duration(days: 1)) : now;
          final dayOfWeek = targetDate.weekday;

          int targetWeek = 0;
          if (metadata != null && metadata['firstWeekMonday'] != null) {
            final firstWeekMonday = DateTime.parse(metadata['firstWeekMonday'] as String);
            targetWeek = DateCalculator.getCurrentWeekNumber(firstWeekMonday, targetDate);
          }

          final previewCourses = allCourses.where((course) {
            if (course.dayOfWeek != dayOfWeek) return false;
            if (targetWeek > 0) {
              final courseWeeks = WeekParser.parseWeeks(course.weeks);
              return courseWeeks.contains(targetWeek);
            }
            return true;
          }).toList();

          final upcomingCourses = <CourseModel>[];
          if (!isAfter10PM) {
            final currentTime = TimeOfDay.fromDateTime(now);
            for (final course in previewCourses) {
              final endTime = DateCalculator.getSectionTime(course.endPeriod)['end'];
              if (endTime != null) {
                final endMinutes = endTime.hour * 60 + endTime.minute;
                final currentMinutes = currentTime.hour * 60 + currentTime.minute;
                if (endMinutes > currentMinutes) {
                  upcomingCourses.add(course);
                }
              }
            }
          } else {
            upcomingCourses.addAll(previewCourses);
          }

          upcomingCourses.sort((a, b) => a.startPeriod.compareTo(b.startPeriod));

          if (mounted) {
            setState(() {
              _todayCourses = upcomingCourses;
              _isShowingTomorrow = isAfter10PM;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('加载预览课程失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTimetable = false;
        });
      }
    }
  }

  Future<void> _loadSemesterProgress() async {
    try {
      final storage = TimetableStorage();
      final metadata = await storage.readMetadata();
      final icsContent = await storage.readTimetable();

      if (metadata != null && metadata['firstWeekMonday'] != null) {
        final firstWeekMonday = DateTime.parse(metadata['firstWeekMonday'] as String);
        final now = DateTime.now();

        final startDate = DateTime(firstWeekMonday.year, firstWeekMonday.month, firstWeekMonday.day);
        final currentDate = DateTime(now.year, now.month, now.day);

        int elapsedDays = currentDate.difference(startDate).inDays + 1;
        if (elapsedDays < 0) elapsedDays = 0;

        final currentWeek = DateCalculator.getCurrentWeekNumber(firstWeekMonday, now);

        int totalWeeks = 20;
        if (icsContent != null) {
          final courses = IcsParser.parse(icsContent);
          int maxWeek = 20;
          for (final course in courses) {
            final weeks = WeekParser.parseWeeks(course.weeks);
            if (weeks.isNotEmpty) {
              final courseMaxWeek = weeks.reduce((curr, next) => curr > next ? curr : next);
              if (courseMaxWeek > maxWeek) {
                maxWeek = courseMaxWeek;
              }
            }
          }
          totalWeeks = maxWeek;
        }

        final totalDays = totalWeeks * 7;
        int remainingDays = totalDays - elapsedDays;
        if (remainingDays < 0) remainingDays = 0;

        int progressPercent = 0;
        if (totalDays > 0) {
          progressPercent = (elapsedDays / totalDays * 100).clamp(0, 100).toInt();
        }

        if (mounted) {
          setState(() {
            _firstWeekMonday = firstWeekMonday;
            _currentWeek = currentWeek <= 0 ? 1 : currentWeek;
            _totalWeeks = totalWeeks;
            _elapsedDays = elapsedDays;
            _remainingDays = remainingDays;
            _progressPercent = progressPercent;
          });
        }
      }
    } catch (e) {
      debugPrint('加载学期进度失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildQuickActions(context, authState),
            if (_firstWeekMonday != null) _buildSemesterProgress(context),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _buildTodayTimetablePreview(context, authState),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, AuthState authState) {
    final isLoggedIn = authState.status == AuthStatus.authenticated;
    final appearance = ref.watch(appearanceProvider);
    final visibleItems = appearance.homeItems.where((item) => item.isVisible).take(4).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '快捷访问',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ...visibleItems.map(
                (item) => _buildQuickActionItem(
                  context,
                  icon: item.icon,
                  label: item.label,
                  iconColor: item.color,
                  bgColor: isDark ? item.color.withOpacity(0.15) : item.color.withOpacity(0.08),
                  onTap: () => _handleActionTap(context, item.id, isLoggedIn),
                ),
              ),
              for (int i = 0; i < 4 - visibleItems.length; i++) const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSemesterProgress(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '学期进度',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                '第 $_currentWeek 周 / 共 $_totalWeeks 周',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '已开学 $_elapsedDays 天',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    Text(
                      '剩余 $_remainingDays 天',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    minHeight: 12,
                    value: (_progressPercent / 100).clamp(0.0, 1.0),
                    backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '当前进度 $_progressPercent%',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayTimetablePreview(BuildContext context, AuthState authState) {
    final isLoggedIn = authState.status == AuthStatus.authenticated;

    if (!isLoggedIn) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.12)),
        ),
        child: const SizedBox(
          height: 220,
          child: LoginRequiredPlaceholder(
            title: '登录后查看课表',
            message: '登录后可展示今日课程与学期进度信息',
            padding: EdgeInsets.all(20),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isShowingTomorrow ? '明日课表' : '今日课表',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                tooltip: '刷新',
                onPressed: _loadPreviewCourses,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (_isLoadingTimetable)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
            )
          else if (_todayCourses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                _isShowingTomorrow ? '明天暂无课程安排' : '今天暂无后续课程',
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
          else
            ..._todayCourses.take(3).map((course) => _buildCoursePreviewItem(context, course)),
        ],
      ),
    );
  }

  Widget _buildCoursePreviewItem(BuildContext context, CourseModel course) {
    final color = CourseColorUtils.getColorForCourse(course.name);
    final start = DateCalculator.getSectionTime(course.startPeriod)['start'];
    final end = DateCalculator.getSectionTime(course.endPeriod)['end'];

    final timeText = start != null && end != null
        ? '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')} - ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}'
        : '第${course.startPeriod}-${course.endPeriod}节';

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '${course.classroom} · $timeText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleActionTap(BuildContext context, String id, bool isLoggedIn) async {
    switch (id) {
      case 'payment_code':
        isLoggedIn
            ? Navigator.push(context, createSlideUpRoute(const PaymentCodeScreen()))
            : _showLoginDialog(context);
        break;
      case 'recharge':
        isLoggedIn
            ? Navigator.push(context, createSlideUpRoute(const CampusCardRechargeScreen()))
            : _showLoginDialog(context);
        break;
      case 'library':
        if (isLoggedIn) {
          final status = await Permission.camera.request();
          if (status.isGranted) {
            Navigator.push(
              context,
              createSlideUpRoute(
                const WebViewDetailScreen(
                  title: '图书馆',
                  url: AppConstants.libraryUrl,
                  showWebBack: true,
                ),
              ),
            );
          } else if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('需要相机权限以完成扫码')),
            );
          }
        } else {
          _showLoginDialog(context);
        }
        break;
      case 'empty_classroom':
        isLoggedIn
            ? Navigator.push(context, createSlideUpRoute(const ClassroomInquiryScreen()))
            : _showLoginDialog(context);
        break;
      case 'xgxt':
        isLoggedIn
            ? Navigator.push(
                context,
                createSlideUpRoute(
                  const WebViewDetailScreen(
                    title: '学工系统',
                    url: AppConstants.xgxtWapUrl,
                    showAppBar: false,
                    showWebBack: false,
                    appBarColor: Color(0xFF3C8DBC),
                  ),
                ),
              )
            : _showLoginDialog(context);
        break;
      case 'repairs':
        isLoggedIn
            ? Navigator.push(
                context,
                createSlideUpRoute(
                  const WebViewDetailScreen(
                    title: '报修平台',
                    url: AppConstants.repairsSsoUrl,
                    userAgent:
                        'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Mobile Safari/537.36',
                    showWebBack: true,
                    targetUrl: '/relax/mobile/index.html',
                  ),
                ),
              )
            : _showLoginDialog(context);
        break;
      case 'gym':
        isLoggedIn
            ? Navigator.push(
                context,
                createSlideUpRoute(
                  const WebViewDetailScreen(
                    title: '场馆预约',
                    url: AppConstants.gymReservationUrl,
                    showWebBack: true,
                  ),
                ),
              )
            : _showLoginDialog(context);
        break;
      case 'teaching_eval':
        isLoggedIn
            ? Navigator.push(
                context,
                createSlideUpRoute(
                  const WebViewDetailScreen(
                    title: '教评系统',
                    url: AppConstants.teachingEvalUrl,
                    showAppBar: false,
                    showWebBack: false,
                    appBarColor: Colors.white,
                  ),
                ),
              )
            : _showLoginDialog(context);
        break;
      case 'score':
        isLoggedIn
            ? Navigator.push(context, createSlideUpRoute(const ScoreScreen()))
            : _showLoginDialog(context);
        break;
      case 'vpn':
        Navigator.push(context, createSlideUpRoute(const VpnConverterScreen()));
        break;
      case 'campus_card':
        if (isLoggedIn) {
          await [Permission.camera, Permission.photos, Permission.storage].request();
          final service = ref.read(campusCardServiceProvider);
          final url = service.getCampusCardHomeUrl();

          Navigator.push(
            context,
            createSlideUpRoute(
              WebViewDetailScreen(
                title: '校园卡',
                url: url,
                userAgent: AppConstants.campusCardUA,
                showWebBack: false,
                showAppBar: false,
                appBarColor: const Color(0xFF008268),
              ),
            ),
          );
        } else {
          _showLoginDialog(context);
        }
        break;
      case 'bus':
        Navigator.push(context, createSlideUpRoute(const BusTrackingScreen()));
        break;
      case 'cs_bus':
        final hasPermission = await LocationHelper.requestPermission();
        if (hasPermission) {
          final location = await LocationHelper.getCurrentPosition();
          final converted = location != null
              ? CoordinateConverter.wgs84ToGcj02(location.latitude, location.longitude)
              : null;
          final busUrl = converted == null
              ? AppConstants.changshaBusUrl
              : '${AppConstants.changshaBusUrl}?lat=${converted[0]}&lng=${converted[1]}';

          Navigator.push(
            context,
            createSlideUpRoute(
              WebViewDetailScreen(
                title: '长沙实时公交',
                url: busUrl,
                showWebBack: true,
                showAppBar: true,
                appBarColor: const Color(0xFFF4F4F4),
              ),
            ),
          );
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('需要定位权限以显示附近的实时公交'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        break;
      case 'settings':
        Navigator.push(context, createSlideUpRoute(const SettingsScreen()));
        break;
      case 'more':
        _navigateToTab(context, 4);
        break;
    }
  }

  Widget _buildQuickActionItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 26,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.grey[800],
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
