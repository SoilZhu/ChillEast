import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../sunshine/screens/sunshine_screen.dart';
import '../../questionnaire/screens/questionnaire_list_screen.dart';
import '../../leave/screens/leave_list_screen.dart';
import '../../../core/state/auth_state.dart';
import '../../auth/screens/login_screen.dart';
import '../../timetable/services/timetable_storage.dart';
import '../../timetable/utils/ics_parser.dart';
import '../../timetable/models/course_model.dart';
import '../../timetable/utils/date_calculator.dart';
import '../../timetable/utils/week_parser.dart';
import '../../../core/utils/location_helper.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../screens/bus_tracking_screen.dart';
import '../../score/screens/score_screen.dart';
import '../../workspace/screens/webview_detail_screen.dart';
import '../../timetable/utils/course_color_utils.dart';
import '../../../core/widgets/login_required_placeholder.dart';
import '../../workspace/screens/classroom_inquiry_screen.dart';
import '../../workspace/screens/payment_code_screen.dart';
import '../../../core/utils/route_utils.dart';
import '../../profile/providers/appearance_provider.dart';
import '../../profile/models/appearance_state.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../workspace/screens/campus_card_recharge_screen.dart';
import '../../workspace/screens/electricity_recharge_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../workspace/services/campus_card_service.dart';
import '../../workspace/screens/vpn_converter_screen.dart';
import '../../library/models/library_models.dart';
import '../../library/providers/library_provider.dart';
import '../../library/screens/library_home_screen.dart';


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
  
  @override
  void initState() {
    super.initState();
    _loadPreviewCourses();
  }
  
  /// 加载预览课程（晚上10点后展示明天，0点后恢复今天）
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
          // 如果晚上10点以后，则显示明天的课表
          final bool isAfter10PM = now.hour >= 22;
          final targetDate = isAfter10PM ? now.add(const Duration(days: 1)) : now;
          
          final dayOfWeek = targetDate.weekday; // 1=周一, 7=周日
          
          // 计算目标周次
          int targetWeek = 0;
          if (metadata != null && metadata['firstWeekMonday'] != null) {
            final firstWeekMonday = DateTime.parse(metadata['firstWeekMonday'] as String);
            targetWeek = DateCalculator.getCurrentWeekNumber(firstWeekMonday, targetDate);
          }
          
          // 筛选课程
          final previewCourses = allCourses.where((course) {
            if (course.dayOfWeek != dayOfWeek) return false;
            
            if (targetWeek > 0) {
              final courseWeeks = WeekParser.parseWeeks(course.weeks);
              return courseWeeks.contains(targetWeek);
            }
            return true;
          }).toList();
          
          // 只有在显示“今天”时，才根据当前时间过滤已结束的课
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
            // 明天的课表全量展示
            upcomingCourses.addAll(previewCourses);
          }
          
          // 按开始时间排序
          upcomingCourses.sort((a, b) => a.startPeriod.compareTo(b.startPeriod));
          
          setState(() {
            _todayCourses = upcomingCourses;
            _isShowingTomorrow = isAfter10PM;
          });
        }
      }
    } catch (e) {
      // 静默失败
    } finally {
      setState(() {
        _isLoadingTimetable = false;
      });
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
            // 快捷功能 (内部处理 horizontal padding，实现满屏滚动无白边)
            _buildQuickActions(context, authState),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  // 图书馆当天预约卡片（如果有缓存）
                  _buildLibrarySeatCard(context),
                  // 今日课表预览
                  _buildTodayTimetablePreview(context),
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
    final visibleItems = appearance.homeItems.where((item) => item.isVisible).toList();
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          ...visibleItems.map((item) => _buildQuickActionItem(
            context,
            icon: item.icon,
            label: item.getLocalizedTitle(context),
            iconColor: item.color,
            bgColor: isDark ? item.color.withOpacity(0.15) : item.color.withOpacity(0.08),
            onTap: () => _handleActionTap(context, item.id, isLoggedIn),
          )),
          // 8. 更多 (始终显示在最后)
          _buildQuickActionItem(
            context,
            icon: Icons.grid_view_rounded,
            label: context.l10n.more,
            iconColor: const Color(0xFFE6A334),
            bgColor: isDark ? const Color(0xFF2E271A) : const Color(0xFFFFF8E8),
            onTap: () => _navigateToTab(context, 4),
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
      case 'ele_recharge':
        isLoggedIn
            ? Navigator.push(context, createSlideUpRoute(const ElectricityRechargeScreen()))
            : _showLoginDialog(context);
        break;
      case 'library':
        isLoggedIn 
            ? Navigator.push(context, createSlideUpRoute(const LibraryHomeScreen()))
            : _showLoginDialog(context);
        break;
      case 'empty_classroom':
        isLoggedIn 
            ? Navigator.push(context, createSlideUpRoute(const ClassroomInquiryScreen()))
            : _showLoginDialog(context);
        break;
      case 'xgxt':
        isLoggedIn 
            ? Navigator.push(context, createSlideUpRoute(WebViewDetailScreen(
                title: context.l10n.funcXgxt,
                url: AppConstants.xgxtWapUrl,
                showAppBar: false,
                showWebBack: false,
                appBarColor: const Color(0xFF3C8DBC),
            )))
            : _showLoginDialog(context);
        break;
      case 'sunshine':
        isLoggedIn
            ? Navigator.push(context, createSlideUpRoute(const SunshineScreen()))
            : _showLoginDialog(context);
        break;
      case 'questionnaire':
        isLoggedIn
            ? Navigator.push(context, createSlideUpRoute(const QuestionnaireListScreen()))
            : _showLoginDialog(context);
        break;
      case 'leave':
        isLoggedIn
            ? Navigator.push(context, createSlideUpRoute(const LeaveListScreen()))
            : _showLoginDialog(context);
        break;
      case 'repairs':
        isLoggedIn 
            ? Navigator.push(context, createSlideUpRoute(WebViewDetailScreen(
                title: context.l10n.funcRepairs,
                url: AppConstants.repairsSsoUrl,
                userAgent: 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Mobile Safari/537.36',
                showWebBack: true,
                targetUrl: '/relax/mobile/index.html',
            )))
            : _showLoginDialog(context);
        break;
      case 'gym':
        isLoggedIn 
            ? Navigator.push(context, createSlideUpRoute(WebViewDetailScreen(
                title: context.l10n.funcGym,
                url: AppConstants.gymReservationUrl,
                showWebBack: true,
            )))
            : _showLoginDialog(context);
        break;
      case 'teaching_eval':
        isLoggedIn 
            ? Navigator.push(context, createSlideUpRoute(WebViewDetailScreen(
                title: context.l10n.funcTeachingEval,
                url: AppConstants.teachingEvalUrl,
                showAppBar: false,
                showWebBack: false,
                appBarColor: Colors.white,
            )))
            : _showLoginDialog(context);
        break;
      case 'score':
        isLoggedIn 
            ? Navigator.push(context, createSlideUpRoute(const ScoreScreen()))
            : _showLoginDialog(context);
        break;
      case 'vpn':
        Navigator.push(context, createSlideUpRoute(VpnConverterScreen()));
        break;
      case 'campus_card':
        if (isLoggedIn) {
          await [Permission.camera, Permission.photos, Permission.storage].request();
          final service = ref.read(campusCardServiceProvider);
          final url = service.getCampusCardHomeUrl();
          
          if (!context.mounted) return;
          Navigator.push(context, createSlideUpRoute(
            WebViewDetailScreen(
              title: context.l10n.funcCampusCard,
              url: url,
              userAgent: AppConstants.campusCardUA,
              showWebBack: false,
              showAppBar: false,
              appBarColor: const Color(0xFF008268),
            ),
          ));
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
          if (!context.mounted) return;
          Navigator.push(context, createSlideUpRoute(
            WebViewDetailScreen(
              title: context.l10n.funcCsBus,
              url: AppConstants.changshaBusUrl,
              showWebBack: true,
              showAppBar: true,
              appBarColor: const Color(0xFFF4F4F4),
            ),
          ));
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.needLocationForBus),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
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
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.grey[800],
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLibrarySeatCard(BuildContext context) {
    final cachedReservesAsync = ref.watch(cachedLibraryReserveProvider);
    final reserves = cachedReservesAsync.value ?? [];
    if (reserves.isEmpty) {
      return const SizedBox.shrink();
    }

    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final todayReserves = reserves.where((reserve) {
      return reserve.today == todayStr ||
          (reserve.startTime.year == now.year &&
              reserve.startTime.month == now.month &&
              reserve.startTime.day == now.day);
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (todayReserves.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.libraryReservation,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < todayReserves.length; i++) ...[
          _buildSingleLibrarySeatItem(context, todayReserves[i], isDark),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildSingleLibrarySeatItem(
      BuildContext context, LibraryReserveModel reserve, bool isDark) {
    final timeFormat = DateFormat('HH:mm');
    final timeRange =
        '${timeFormat.format(reserve.startTime)}-${timeFormat.format(reserve.endTime)}';
    final canSignBack = reserve.reserveStatus.canSignBack;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : const Color(0xFFE0E0E0),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () {
            Navigator.push(
                context, createSlideUpRoute(const LibraryHomeScreen()));
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. 座位与阅览室名称
                Text(
                  '${reserve.seatNum}@${reserve.fullRoomName}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF222222),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // 2. 时间与右下角操作按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      timeRange,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (!canSignBack)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  isDark ? Colors.white60 : Colors.black54,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () =>
                                _handleCancelLibraryReserve(context, reserve),
                            child: Text(context.l10n.cancel,
                                style: const TextStyle(fontSize: 13)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF09C489),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              minimumSize: const Size(0, 36),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            onPressed: () =>
                                _handleSignInLibraryReserve(context, reserve),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_outline_rounded,
                                    size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  context.l10n.signIn,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF4D4F),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          minimumSize: const Size(0, 36),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: () =>
                            _handleSignBackLibraryReserve(context, reserve),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.logout_rounded, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              context.l10n.signBack,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSignInLibraryReserve(
      BuildContext context, LibraryReserveModel reserve) async {
    final l10n = context.l10n;
    try {
      final success = await ref
          .read(cachedLibraryReserveProvider.notifier)
          .signInSeat(reserve);

      if (context.mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(l10n.signInSuccess),
              ],
            ),
            backgroundColor: const Color(0xFF09C489),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.signInFailed(_libraryErrorMessage(e))),
          ),
        );
      }
    }
  }

  Future<void> _handleSignBackLibraryReserve(
      BuildContext context, LibraryReserveModel reserve) async {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text(l10n.signBackConfirmTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Text(
          l10n.signBackConfirmContent(reserve.thirdLevelName, reserve.seatNum),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.white60 : Colors.black54,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.thinkAgain, style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D4F),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.confirmSignBack,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    try {
      final success = await ref
          .read(cachedLibraryReserveProvider.notifier)
          .signBackSeat(reserve);
      if (context.mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.signBackSuccess)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.signBackFailed(_libraryErrorMessage(e)))),
        );
      }
    }
  }

  String _libraryErrorMessage(Object error) {
    return error
        .toString()
        .replaceAll(RegExp(r'^.*?: '), '')
        .replaceAll(RegExp(r'\s*\(code:.*\)$'), '')
        .trim();
  }

  Future<void> _handleCancelLibraryReserve(
      BuildContext context, LibraryReserveModel reserve) async {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text(l10n.cancelReserveConfirmTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Text(l10n.cancelReserveConfirmContent(reserve.thirdLevelName, reserve.seatNum)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.white60 : Colors.black54,
              elevation: 0,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.thinkAgain, style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D4F),
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.confirmCancel,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        final success = await ref
            .read(cachedLibraryReserveProvider.notifier)
            .cancelReservation(reserve.id);
        if (context.mounted && success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.reserveCancelledSuccess)),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    l10n.cancelFailed(e.toString().replaceAll('Exception:', '').trim()))),
          );
        }
      }
    }
  }

  Widget _buildTodayTimetablePreview(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    if (authState.status == AuthStatus.unauthenticated && !authState.hasAccount) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isShowingTomorrow ? context.l10n.tomorrowTimetable : context.l10n.todayTimetable,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          LoginRequiredPlaceholder(
            title: context.l10n.timetableLoginRequiredTitle,
            message: context.l10n.timetableLoginRequiredMessage,
            icon: Icons.calendar_today_outlined,
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _isShowingTomorrow ? context.l10n.tomorrowTimetable : context.l10n.todayTimetable,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => _navigateToTab(context, 1),
              child: Text(context.l10n.viewAll),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        if (_isLoadingTimetable)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_todayCourses.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.grey[50],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                _isShowingTomorrow ? context.l10n.noCoursesTomorrow : context.l10n.noCoursesToday,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _todayCourses.length,
            separatorBuilder: (context, index) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final course = _todayCourses[index];
              return _buildCourseItem(course);
            },
          ),
      ],
    );
  }
  
  Widget _buildCourseItem(CourseModel course) {
    final baseColor = CourseColorUtils.getColorForCourse(course.name);
    final startTime = DateCalculator.getSectionTime(course.startPeriod)['start']!;
    final endTime = DateCalculator.getSectionTime(course.endPeriod)['end']!;
    
    final timeRange = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}-'
                      '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';

    return Container(
      width: double.infinity,
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            course.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '$timeRange @ ${course.classroom}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  void _navigateToTab(BuildContext context, int index) {
    if (widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(index);
    }
  }
  

  void _showLoginDialog(BuildContext context) {
    if (ref.read(authStateProvider).status == AuthStatus.authenticating) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.loggingInWait),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.push(context, LoginScreen.route());
  }
}
