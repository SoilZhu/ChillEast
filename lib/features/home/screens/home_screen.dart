import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../sunshine/screens/sunshine_screen.dart';
import '../../repairs/screens/repair_screen.dart';
import '../../repairs/screens/repair_detail_screen.dart';
import '../../repairs/models/repair_models.dart';
import '../../repairs/providers/repair_cache_provider.dart';
import '../../questionnaire/screens/questionnaire_list_screen.dart';
import '../../questionnaire/screens/questionnaire_detail_screen.dart';
import '../../questionnaire/models/questionnaire_models.dart';
import '../../questionnaire/providers/questionnaire_cache_provider.dart';
import '../../leave/screens/leave_list_screen.dart';
import '../../leave/screens/leave_detail_screen.dart';
import '../../leave/models/leave_models.dart';
import '../../leave/providers/leave_cache_provider.dart';
import '../../../core/state/auth_state.dart';
import '../../auth/screens/login_screen.dart';
import '../../timetable/services/timetable_storage.dart';
import '../../timetable/utils/ics_parser.dart';
import '../../timetable/models/course_model.dart';
import '../../timetable/utils/date_calculator.dart';
import '../../timetable/utils/week_parser.dart';
import '../../homework/providers/homework_provider.dart';
import '../../homework/models/homework_model.dart';
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
import '../../campus_bus/screens/campus_bus_map_screen.dart';

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
  // 预览的目标日期（22 点后为明天），作业按此日期匹配截止时间
  DateTime _previewDate = DateTime.now();
  final PageController _quickPageController = PageController();
  int _quickPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadPreviewCourses();
  }

  @override
  void dispose() {
    _quickPageController.dispose();
    super.dispose();
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
          final targetDate =
              isAfter10PM ? now.add(const Duration(days: 1)) : now;

          final dayOfWeek = targetDate.weekday; // 1=周一, 7=周日

          // 计算目标周次
          int targetWeek = 0;
          if (metadata != null && metadata['firstWeekMonday'] != null) {
            final firstWeekMonday =
                DateTime.parse(metadata['firstWeekMonday'] as String);
            targetWeek = DateCalculator.getCurrentWeekNumber(
                firstWeekMonday, targetDate);
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
              final endTime =
                  DateCalculator.getSectionTime(course.endPeriod)['end'];
              if (endTime != null) {
                final endMinutes = endTime.hour * 60 + endTime.minute;
                final currentMinutes =
                    currentTime.hour * 60 + currentTime.minute;
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
          upcomingCourses
              .sort((a, b) => a.startPeriod.compareTo(b.startPeriod));

          setState(() {
            _todayCourses = upcomingCourses;
            _isShowingTomorrow = isAfter10PM;
            _previewDate =
                DateTime(targetDate.year, targetDate.month, targetDate.day);
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  // 信息流区块（顺序与显隐来自外观设置，可配置）
                  for (final section in ref
                      .watch(appearanceProvider)
                      .feedItems
                      .where((e) => e.isVisible))
                    switch (section.id) {
                      'feed_quick' => _buildQuickActions(context, authState),
                      'feed_library' => _buildLibrarySeatCard(context),
                      'feed_agenda' => _buildTodayTimetablePreview(context),
                      'feed_questionnaire' =>
                        _buildPendingQuestionnaires(context),
                      'feed_leave' => _buildOngoingLeaves(context),
                      'feed_repair' => _buildOngoingRepairs(context),
                      _ => const SizedBox.shrink(),
                    },
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
    final visibleItems =
        appearance.homeItems.where((item) => item.isVisible).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 单页可放 6 格；第一页固定为 5 个功能 + 更多
    if (visibleItems.length <= 5) {
      final displayItems = visibleItems.toList();
      return Padding(
        // 在信息流内渲染，横向内边距由父级提供
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: _buildQuickGrid(
          context,
          items: displayItems,
          showMore: true,
          isDark: isDark,
          isLoggedIn: isLoggedIn,
        ),
      );
    }

    // 多页：第一页 5 功能 + 更多，其余页每页最多 6 个功能
    final firstPageItems = visibleItems.take(5).toList();
    final remaining = visibleItems.skip(5).toList();
    const perPage = 6;
    final pageCount = 1 + (remaining.length / perPage).ceil();
    // 3 行固定高度，避免末页高度跳变：3*44 + 2*10
    const gridHeight = 3 * 44.0 + 2 * 10.0;

    // visibleItems 变化（如设置页增删）时，修正越界的页码
    if (_quickPageIndex >= pageCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _quickPageIndex = pageCount - 1);
      });
    }

    return Padding(
      // 在信息流内渲染，横向内边距由父级提供
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: gridHeight,
            child: PageView.builder(
              controller: _quickPageController,
              itemCount: pageCount,
              onPageChanged: (i) => setState(() => _quickPageIndex = i),
              itemBuilder: (context, page) {
                if (page == 0) {
                  return _buildQuickGrid(
                    context,
                    items: firstPageItems,
                    showMore: true,
                    isDark: isDark,
                    isLoggedIn: isLoggedIn,
                  );
                }
                final start = (page - 1) * perPage;
                final end = (start + perPage).clamp(0, remaining.length);
                return _buildQuickGrid(
                  context,
                  items: remaining.sublist(start, end),
                  showMore: false,
                  isDark: isDark,
                  isLoggedIn: isLoggedIn,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(pageCount, (i) {
              final active = i == _quickPageIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFF09C489)
                      : (isDark ? Colors.white24 : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickGrid(
    BuildContext context, {
    required List<FunctionItem> items,
    required bool showMore,
    required bool isDark,
    required bool isLoggedIn,
  }) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 44,
      ),
      itemCount: items.length + (showMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < items.length) {
          final item = items[index];
          return _buildQuickActionCard(
            context,
            icon: item.icon,
            label: item.getLocalizedTitle(context),
            iconColor: item.color,
            isDark: isDark,
            onTap: () => _handleActionTap(context, item.id, isLoggedIn),
          );
        }
        // 更多 (第一页末尾固定占位)
        return _buildQuickActionCard(
          context,
          icon: Icons.grid_view_rounded,
          label: context.l10n.more,
          iconColor: const Color(0xFFE6A334),
          isDark: isDark,
          onTap: () => _navigateToTab(context, 4),
        );
      },
    );
  }

  void _handleActionTap(
      BuildContext context, String id, bool isLoggedIn) async {
    switch (id) {
      case 'payment_code':
        isLoggedIn
            ? Navigator.push(
                context, createSlideUpRoute(const PaymentCodeScreen()))
            : _showLoginDialog(context);
        break;
      case 'recharge':
        isLoggedIn
            ? Navigator.push(
                context, createSlideUpRoute(const CampusCardRechargeScreen()))
            : _showLoginDialog(context);
        break;
      case 'ele_recharge':
        isLoggedIn
            ? Navigator.push(
                context, createSlideUpRoute(const ElectricityRechargeScreen()))
            : _showLoginDialog(context);
        break;
      case 'library':
        isLoggedIn
            ? Navigator.push(
                context, createSlideUpRoute(const LibraryHomeScreen()))
            : _showLoginDialog(context);
        break;
      case 'empty_classroom':
        isLoggedIn
            ? Navigator.push(
                context, createSlideUpRoute(const ClassroomInquiryScreen()))
            : _showLoginDialog(context);
        break;
      case 'xgxt':
        isLoggedIn
            ? Navigator.push(
                context,
                createSlideUpRoute(WebViewDetailScreen(
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
            ? Navigator.push(
                context, createSlideUpRoute(const SunshineScreen()))
            : _showLoginDialog(context);
        break;
      case 'questionnaire':
        isLoggedIn
            ? Navigator.push(
                context, createSlideUpRoute(const QuestionnaireListScreen()))
            : _showLoginDialog(context);
        break;
      case 'leave':
        isLoggedIn
            ? Navigator.push(
                context, createSlideUpRoute(const LeaveListScreen()))
            : _showLoginDialog(context);
        break;
      case 'repairs':
        isLoggedIn
            ? Navigator.push(context, createSlideUpRoute(const RepairScreen()))
            : _showLoginDialog(context);
        break;
      case 'gym':
        isLoggedIn
            ? Navigator.push(
                context,
                createSlideUpRoute(WebViewDetailScreen(
                  title: context.l10n.funcGym,
                  url: AppConstants.gymReservationUrl,
                  showWebBack: true,
                )))
            : _showLoginDialog(context);
        break;
      case 'teaching_eval':
        isLoggedIn
            ? Navigator.push(
                context,
                createSlideUpRoute(WebViewDetailScreen(
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
          await [Permission.camera, Permission.photos, Permission.storage]
              .request();
          final service = ref.read(campusCardServiceProvider);
          final url = service.getCampusCardHomeUrl();

          if (!context.mounted) return;
          Navigator.push(
              context,
              createSlideUpRoute(
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
      case 'campus_bus_route':
        Navigator.push(context, createSlideUpRoute(const CampusBusMapScreen()));
        break;
      case 'cs_bus':
        final hasPermission = await LocationHelper.requestPermission();
        if (hasPermission) {
          if (!context.mounted) return;
          Navigator.push(
              context,
              createSlideUpRoute(
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

  Widget _buildQuickActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color iconColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
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
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: iconColor,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
        const SizedBox(height: 12),
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.local_library_outlined,
                  size: 22,
                  color: isDark ? Colors.white70 : Colors.grey[600],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. 座位与阅览室名称
                      Text(
                        '${reserve.seatNum}@${reserve.fullRoomName}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? Colors.white : const Color(0xFF222222),
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
                                    foregroundColor: isDark
                                        ? Colors.white60
                                        : Colors.black54,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () => _handleCancelLibraryReserve(
                                      context, reserve),
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
                                  onPressed: () => _handleSignInLibraryReserve(
                                      context, reserve),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                          Icons.check_circle_outline_rounded,
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
                              onPressed: () => _handleSignBackLibraryReserve(
                                  context, reserve),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.logout_rounded, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    context.l10n.signBack,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
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
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
        title: Text(l10n.cancelReserveConfirmTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Text(l10n.cancelReserveConfirmContent(
            reserve.thirdLevelName, reserve.seatNum)),
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
                content: Text(l10n.cancelFailed(
                    e.toString().replaceAll('Exception:', '').trim()))),
          );
        }
      }
    }
  }

  Widget _buildTodayTimetablePreview(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    if (authState.status == AuthStatus.unauthenticated &&
        !authState.hasAccount) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isShowingTomorrow
                ? context.l10n.tomorrowAgenda
                : context.l10n.todayAgenda,
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

    // 当天待办作业（截止时间为预览日期），排在课程前面，日程页同款
    final homeworkAsync = ref.watch(homeworkProvider);
    final dayHomework = homeworkAsync.maybeWhen(
      data: (list) {
        final items = list
            .where((h) =>
                h.status == HomeworkStatus.pending &&
                h.endTime != null &&
                h.endTime!.year == _previewDate.year &&
                h.endTime!.month == _previewDate.month &&
                h.endTime!.day == _previewDate.day)
            .toList();
        items.sort((a, b) => a.endTime!.compareTo(b.endTime!));
        return items;
      },
      orElse: () => <HomeworkModel>[],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _isShowingTomorrow
                  ? context.l10n.tomorrowAgenda
                  : context.l10n.todayAgenda,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            GestureDetector(
              onTap: () => _navigateToTab(context, 1),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white54
                      : Colors.grey,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingTimetable)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_todayCourses.isEmpty && dayHomework.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E1E1E)
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                _isShowingTomorrow
                    ? context.l10n.noCoursesTomorrow
                    : context.l10n.noCoursesToday,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ),
          )
        else
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < dayHomework.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _buildHomeworkTask(dayHomework[i]),
              ],
              for (int i = 0; i < _todayCourses.length; i++) ...[
                if (i > 0 || dayHomework.isNotEmpty) const SizedBox(height: 12),
                _buildCourseItem(_todayCourses[i]),
              ],
            ],
          ),
      ],
    );
  }

  /// 日程页同款作业卡片（黄色底 + 截止时间）
  Widget _buildHomeworkTask(HomeworkModel item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3D3D29) : const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Icon(Icons.assignment_late_outlined,
              size: 22, color: Color(0xFFF39C12)),
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
                    height: 1.2,
                    color: isDark ? Colors.white : const Color(0xFF2D3436),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.courseName} · ${context.l10n.deadlinePrefix} ${item.endTime != null ? DateFormat('HH:mm').format(item.endTime!) : context.l10n.noDeadline}',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    color: isDark ? Colors.white70 : const Color(0xFF7F8C8D),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseItem(CourseModel course) {
    final baseColor = CourseColorUtils.getColorForCourse(course.name);
    final startTime =
        DateCalculator.getSectionTime(course.startPeriod)['start']!;
    final endTime = DateCalculator.getSectionTime(course.endPeriod)['end']!;

    final timeRange =
        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}-'
        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';

    return Container(
      width: double.infinity,
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.history_edu,
            color: Colors.white,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
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
          ),
        ],
      ),
    );
  }

  /// 首页通用合并大卡片区块：标题 + > + 一张大卡（条目无分割线）
  Widget _buildMergedSection({
    required String title,
    required VoidCallback onMore,
    required List<Widget> items,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            GestureDetector(
              onTap: onMore,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: isDark ? Colors.white54 : Colors.grey,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
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
            borderRadius: BorderRadius.circular(6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 16),
                  items[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 卡片内条目行：左侧图标（与标题顶部对齐）+ 标题 + 时间（+ 可选状态行）
  Widget _buildSectionRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String time,
    String status = '',
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: iconColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF222222),
                ),
              ),
              if (time.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  time,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
              if (status.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 条目水波纹包装（保留独立点击）
  Widget _buildSectionItem({
    required VoidCallback onTap,
    required Widget child,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: child,
      ),
    );
  }

  Widget _buildPendingQuestionnaires(BuildContext context) {
    final cachedAsync = ref.watch(questionnaireCacheProvider);
    final pending = (cachedAsync.value ?? [])
        .where((q) => !q.isSubmitted && !q.isExpired)
        .toList();
    if (pending.isEmpty) return const SizedBox.shrink();

    // 首页最多展示 3 条，其余进问卷页看
    final display = pending.take(3).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _buildMergedSection(
      title: context.l10n.pendingQuestionnaires,
      onMore: () {
        Navigator.push(
            context, createSlideUpRoute(const QuestionnaireListScreen()));
      },
      items: display
          .map((item) => _buildSectionItem(
                onTap: () => _openQuestionnaireDetail(context, item),
                child: _buildSectionRow(
                  icon: Icons.assignment_outlined,
                  iconColor: isDark
                      ? const Color(0xFF81C784)
                      : const Color(0xFF2E7D32),
                  title: item.title.isEmpty
                      ? context.l10n.unnamedQuestionnaire
                      : item.title,
                  time: item.timeRange,
                ),
              ))
          .toList(),
    );
  }

  Future<void> _openQuestionnaireDetail(
      BuildContext context, QuestionnaireItem item) async {
    final changed = await Navigator.push<bool>(
      context,
      createSlideUpRoute(QuestionnaireDetailScreen(item: item)),
    );
    if (changed == true && context.mounted) {
      ref.read(questionnaireCacheProvider.notifier).refresh();
    }
  }

  bool _isOngoingLeave(LeaveRecord record) {
    final start = DateTime.tryParse(record.startTime);
    final end = DateTime.tryParse(record.endTime);
    if (start == null || end == null) return false;
    final now = DateTime.now();
    return start.isBefore(now) && end.isAfter(now);
  }

  Widget _buildOngoingLeaves(BuildContext context) {
    final cachedAsync = ref.watch(leaveCacheProvider);
    final ongoing = (cachedAsync.value ?? []).where(_isOngoingLeave).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    if (ongoing.isEmpty) return const SizedBox.shrink();

    final display = ongoing.take(3).toList();

    return _buildMergedSection(
      title: context.l10n.funcLeave,
      onMore: () {
        Navigator.push(
            context, createSlideUpRoute(const LeaveListScreen()));
      },
      items: display.map((record) {
        final duration = record.getLocalizedDuration(context);
        final title = duration.isNotEmpty
            ? '${record.typeName} · $duration'
            : (record.typeName.isEmpty
                ? context.l10n.leaveApplication
                : record.typeName);
        return _buildSectionItem(
          onTap: () => _openLeaveDetail(context, record),
          child: _buildSectionRow(
            icon: Icons.event_note_outlined,
            iconColor: const Color(0xFF009688),
            title: title,
            time: record.timeRange,
          ),
        );
      }).toList(),
    );
  }

  Future<void> _openLeaveDetail(
      BuildContext context, LeaveRecord record) async {
    final changed = await Navigator.push<bool>(
      context,
      createSlideUpRoute(LeaveDetailScreen(item: record)),
    );
    if (changed == true && context.mounted) {
      ref.read(leaveCacheProvider.notifier).refresh();
    }
  }

  String _repairDateLabel(RepairOrder order) {
    final createdAt = order.createdAt;
    if (createdAt == null) return '';
    final m = createdAt.month.toString().padLeft(2, '0');
    final d = createdAt.day.toString().padLeft(2, '0');
    return '${createdAt.year}/$m/$d';
  }

  Widget _buildOngoingRepairs(BuildContext context) {
    final cachedAsync = ref.watch(repairCacheProvider);
    final ongoing = cachedAsync.value ?? [];
    if (ongoing.isEmpty) return const SizedBox.shrink();

    final display = ongoing.take(3).toList();

    return _buildMergedSection(
      title: context.l10n.repairWorkOrders,
      onMore: () {
        Navigator.push(context, createSlideUpRoute(const RepairScreen()));
      },
      items: display
          .map((order) => _buildSectionItem(
                onTap: () => _openRepairDetail(context, order),
                child: _buildSectionRow(
                  icon: Icons.handyman_outlined,
                  iconColor: Colors.blueGrey,
                  title: order.title.isEmpty
                      ? context.l10n.repairsUnnamedOrder
                      : order.title,
                  time: _repairDateLabel(order),
                  status: order.status,
                ),
              ))
          .toList(),
    );
  }

  Future<void> _openRepairDetail(
      BuildContext context, RepairOrder order) async {
    await Navigator.push(
      context,
      createSlideUpRoute(RepairDetailScreen(order: order)),
    );
    if (context.mounted) {
      ref.read(repairCacheProvider.notifier).refresh();
    }
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
