import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
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
import '../../timetable/providers/timetable_status_provider.dart';
import '../../timetable/models/course_model.dart';
import '../../timetable/utils/date_calculator.dart';
import '../../timetable/utils/week_parser.dart';
import '../../homework/providers/homework_provider.dart';
import '../../homework/models/homework_model.dart';
import '../../exam/providers/exam_provider.dart';
import '../../exam/models/exam_schedule_model.dart';
import '../../exam/services/exam_storage.dart';
import '../../exam/screens/exam_screen.dart';
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
import '../../../core/services/home_widget_service.dart';
import '../../workspace/screens/campus_card_recharge_screen.dart';
import '../../workspace/screens/electricity_recharge_screen.dart';
import '../../workspace/providers/campus_card_cache_provider.dart';
import '../../workspace/providers/electricity_cache_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../workspace/services/campus_card_service.dart';
import '../../workspace/screens/vpn_converter_screen.dart';
import '../../dormitory/screens/dormitory_screen.dart';
import '../../library/models/library_models.dart';
import '../../library/providers/library_provider.dart';
import '../../library/screens/library_home_screen.dart';
import '../../campus_bus/screens/campus_bus_map_screen.dart';
import '../../../core/utils/date_format_utils.dart';
import '../../../core/network/cookie_manager.dart';
import '../utils/feed_sorter.dart';
import '../../../core/widgets/embedded_detail_pane.dart';

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
  // 小组件同步节流
  DateTime _lastWidgetSync = DateTime.fromMillisecondsSinceEpoch(0);
  Widget? _embeddedScreen;
  String? _selectedActionId;
  bool _isTransitioningToRoute = false;

  bool _canSplitScreen(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final orientation = MediaQuery.orientationOf(context);
    final isTabletOrLandscape = size.width >= 600 ||
        (orientation == Orientation.landscape && size.width >= 500);
    final pageWidth = isTabletOrLandscape ? (size.width - 76.0) : size.width;
    return pageWidth >= 600;
  }

  void _safeNavigate(BuildContext context, Widget screen, {String? id}) {
    if (_canSplitScreen(context)) {
      setState(() {
        _embeddedScreen = screen;
        _selectedActionId = id;
      });
      return;
    }

    Navigator.push(context, createSlideHorizontalRoute(screen));
  }

  @override
  void initState() {
    super.initState();
    _loadPreviewCourses();
    // 预热付款码：进 App 即后台拉一次 openVirtualcard，
    // 点进付款码页直接秒开（服务层 55s 缓存去重，未登录则静默跳过）。
    if (ref.read(authStateProvider).status == AuthStatus.authenticated) {
      final svc = ref.read(campusCardServiceProvider);
      Future(() async {
        try {
          await svc.fetchPaymentCode();
        } catch (_) {}
      });
    }
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

        if (icsContent != null) {
          final allCourses = IcsParser.parse(icsContent);

          final now = DateTime.now();
          // 如果晚上10点以后，则显示明天的课表
          final bool isAfter10PM = now.hour >= 22;
          final targetDate =
              isAfter10PM ? now.add(const Duration(days: 1)) : now;

          final dayOfWeek = targetDate.weekday; // 1=周一, 7=周日

          // 计算目标周次
          final firstWeekMonday = await storage.resolveFirstWeekMonday();
          final targetWeek = DateCalculator.getCurrentWeekNumber(
              firstWeekMonday, targetDate);

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

          if (!mounted) return;
          setState(() {
            _todayCourses = upcomingCourses;
            _isShowingTomorrow = isAfter10PM;
            _previewDate =
                DateTime(targetDate.year, targetDate.month, targetDate.day);
          });
        } else {
          if (mounted) {
            setState(() {
              _todayCourses = [];
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _todayCourses = [];
          });
        }
      }
    } catch (e) {
      // 静默失败
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTimetable = false;
        });
      }
      _syncWidgetsDebounced();
    }
  }

  /// 课表/作业就绪后同步桌面小组件（30 秒节流，失败静默）
  void _syncWidgetsDebounced() {
    final now = DateTime.now();
    if (now.difference(_lastWidgetSync).inSeconds < 30) return;
    _lastWidgetSync = now;
    unawaited(HomeWidgetService().syncWidgets());
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    // 监听全局课表状态刷新（云备份恢复/后台同步完成），立即重载预览课程
    ref.listen(timetableStatusProvider, (_, __) {
      if (mounted) {
        _loadPreviewCourses();
      }
    });

    // 作业后到时也同步一次小组件（与课表加载时的同步共用 30 秒节流）
    ref.listen(homeworkProvider, (previous, next) {
      next.whenData((list) {
        if (list.isNotEmpty && !_isLoadingTimetable && mounted) {
          _syncWidgetsDebounced();
        }
      });
    });

    final orderedSectionIds = () {
      final appearance = ref.watch(appearanceProvider);
      if (!appearance.feedAutoSort) {
        return appearance.feedItems
            .where((e) => e.isVisible)
            .map((e) => e.id)
            .toList();
      }

      final reserves =
          ref.watch(cachedLibraryReserveProvider).valueOrNull ?? [];
      final hasLibraryP0 =
          FeedSorter.checkLibraryP0(reserves: reserves);

      final leaves = ref.watch(leaveCacheProvider).valueOrNull ?? [];
      final hasLeaveP1 = FeedSorter.checkLeaveP1(leaves: leaves);

      final exams = ref.watch(examProvider).valueOrNull ?? [];
      final hasAgendaP2 = FeedSorter.checkAgendaP2(
        courses: _todayCourses,
        exams: exams,
        previewDate: _previewDate,
      );

      final homeworks =
          ref.watch(homeworkProvider).valueOrNull ?? [];
      final hasHomeworkP3 =
          FeedSorter.checkHomeworkP3(homeworks: homeworks);

      final eleState = ref.watch(electricityCacheProvider);
      final hasBalanceP4 = FeedSorter.checkBalanceP4(
        balances: eleState.balances,
        balanceInfo: eleState.balanceInfo,
      );

      return FeedSorter.sortFeedItems(
        autoSort: true,
        manualOrder: appearance.feedItems
            .where((e) => e.isVisible)
            .map((e) => e.id)
            .toList(),
        hasLibraryP0: hasLibraryP0,
        hasLeaveP1: hasLeaveP1,
        hasAgendaP2: hasAgendaP2,
        hasHomeworkP3: hasHomeworkP3,
        hasBalanceP4: hasBalanceP4,
      );
    }();

    final builtWidgets = <Widget>[];
    for (final sectionId in orderedSectionIds) {
      final widget = _buildFeedSection(sectionId, context, authState);
      if (_isNonEmptyWidget(widget)) {
        builtWidgets.add(widget);
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMultiColumn = constraints.maxWidth >= 600;

        if (!isMultiColumn && _embeddedScreen != null && !_isTransitioningToRoute) {
          _isTransitioningToRoute = true;
          final screenToOpen = _embeddedScreen!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _embeddedScreen = null;
              _selectedActionId = null;
              _isTransitioningToRoute = false;
            });
            Navigator.of(context).push(
              createSlideHorizontalRoute(screenToOpen),
            );
          });
        }

          if (isMultiColumn) {
            if (_embeddedScreen != null) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, result) {
                  if (didPop) return;
                  setState(() {
                    _embeddedScreen = null;
                    _selectedActionId = null;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              for (final w in builtWidgets) ...[
                                w,
                                const SizedBox(height: 16),
                              ],
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                      VerticalDivider(
                        width: 16,
                        thickness: 0.5,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0x1A000000),
                      ),
                      Expanded(
                        child: EmbeddedDetailPane(
                          key: ValueKey(
                              _selectedActionId ?? _embeddedScreen.runtimeType),
                          onClose: () {
                            setState(() {
                              _embeddedScreen = null;
                              _selectedActionId = null;
                            });
                            ref.read(campusCardCacheProvider.notifier).refresh();
                            ref.read(electricityCacheProvider.notifier).refresh();
                            ref.read(leaveCacheProvider.notifier).refresh();
                            ref.read(repairCacheProvider.notifier).refresh();
                            ref.read(questionnaireCacheProvider.notifier).refresh();
                          },
                          child: _embeddedScreen!,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final leftItems = <Widget>[];
            final rightItems = <Widget>[];
            for (int i = 0; i < builtWidgets.length; i++) {
              if (i.isEven) {
                leftItems.add(builtWidgets[i]);
              } else {
                rightItems.add(builtWidgets[i]);
              }
            }

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final w in leftItems) ...[
                                w,
                                const SizedBox(height: 16),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final w in rightItems) ...[
                                w,
                                const SizedBox(height: 16),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      for (final w in builtWidgets) ...[
                        w,
                        const SizedBox(height: 16),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
  }

  Widget _buildFeedSection(
      String sectionId, BuildContext context, AuthState authState) {
    switch (sectionId) {
      case 'feed_quick':
        return _buildQuickActions(context, authState);
      case 'feed_library':
        return _buildLibrarySeatCard(context);
      case 'feed_agenda':
        return _buildTodayTimetablePreview(context);
      case 'feed_homework':
        return _buildHomeworkSection(context);
      case 'feed_questionnaire':
        return _buildPendingQuestionnaires(context);
      case 'feed_leave':
        return _buildOngoingLeaves(context);
      case 'feed_repair':
        return _buildOngoingRepairs(context);
      case 'feed_balance':
        return _buildBalanceSection(context);
      default:
        return const SizedBox.shrink();
    }
  }

  bool _isNonEmptyWidget(Widget widget) {
    if (widget is SizedBox && widget.child == null) {
      return false;
    }
    return true;
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
      return _buildQuickGrid(
        context,
        items: displayItems,
        showMore: true,
        isDark: isDark,
        isLoggedIn: isLoggedIn,
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 页间隙 10px（与格内 crossAxisSpacing 一致），同时保证静止时
        // 卡片外沿与单页布局对齐：PageView 本体比父宽 10px（两侧各外溢 5px），
        // 每页内对称 Padding 5px 抵消。用 OverflowBox 实现外溢，避免负边距。
        LayoutBuilder(
          builder: (context, constraints) {
            const pageGap = 10.0;
            const halfGap = pageGap / 2;
            final viewWidth = constraints.maxWidth + pageGap;
            return SizedBox(
              height: gridHeight,
              child: OverflowBox(
                maxWidth: viewWidth,
                alignment: Alignment.center,
                child: SizedBox(
                  width: viewWidth,
                  height: gridHeight,
                  child: PageView.builder(
                    controller: _quickPageController,
                    itemCount: pageCount,
                    onPageChanged: (i) =>
                        setState(() => _quickPageIndex = i),
                    itemBuilder: (context, page) {
                      Widget grid;
                      if (page == 0) {
                        grid = _buildQuickGrid(
                          context,
                          items: firstPageItems,
                          showMore: true,
                          isDark: isDark,
                          isLoggedIn: isLoggedIn,
                        );
                      } else {
                        final start = (page - 1) * perPage;
                        final end =
                            (start + perPage).clamp(0, remaining.length);
                        grid = _buildQuickGrid(
                          context,
                          items: remaining.sublist(start, end),
                          showMore: false,
                          isDark: isDark,
                          isLoggedIn: isLoggedIn,
                        );
                      }
                      return Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: halfGap),
                        child: grid,
                      );
                    },
                  ),
                ),
              ),
            );
          },
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
          final isSelected = _selectedActionId == item.id;
          return _buildQuickActionCard(
            context,
            icon: item.icon,
            label: item.getLocalizedTitle(context),
            iconColor: item.color,
            isSelected: isSelected,
            isDark: isDark,
            onTap: () => _handleActionTap(context, item.id, isLoggedIn),
          );
        }
        // 更多 (第一页末尾固定占位)
        return _buildQuickActionCard(
          context,
          icon: Icons.grid_view_outlined,
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
            ? _safeNavigate(context, const PaymentCodeScreen(), id: id)
            : _showLoginDialog(context);
        break;
      case 'recharge':
        isLoggedIn
            ? _safeNavigate(context, const CampusCardRechargeScreen(), id: id)
            : _showLoginDialog(context);
        break;
      case 'ele_recharge':
        isLoggedIn
            ? _safeNavigate(context, const ElectricityRechargeScreen(), id: id)
            : _showLoginDialog(context);
        break;
      case 'library':
        isLoggedIn
            ? _safeNavigate(context, const LibraryHomeScreen(), id: id)
            : _showLoginDialog(context);
        break;
      case 'empty_classroom':
        isLoggedIn
            ? _safeNavigate(context, const ClassroomInquiryScreen(), id: id)
            : _showLoginDialog(context);
        break;
      case 'xgxt':
        isLoggedIn
            ? _safeNavigate(
                context,
                WebViewDetailScreen(
                  title: context.l10n.funcXgxt,
                  url: AppConstants.xgxtWapUrl,
                  showAppBar: false,
                  showWebBack: false,
                  appBarColor: const Color(0xFF3C8DBC),
                ),
                id: id,
              )
            : _showLoginDialog(context);
        break;
      case 'sunshine':
        isLoggedIn
            ? _safeNavigate(context, const SunshineScreen(), id: id)
            : _showLoginDialog(context);
        break;
      case 'questionnaire':
        isLoggedIn
            ? _safeNavigate(context, const QuestionnaireListScreen(), id: id)
            : _showLoginDialog(context);
        break;
      case 'leave':
        isLoggedIn
            ? _safeNavigate(context, const LeaveListScreen(), id: id)
            : _showLoginDialog(context);
        break;
      case 'repairs':
        isLoggedIn
            ? _safeNavigate(context, const RepairScreen(), id: id)
            : _showLoginDialog(context);
        break;
      case 'dormitory':
        isLoggedIn
            ? _safeNavigate(context, const DormitoryScreen(), id: id)
            : _showLoginDialog(context);
        break;
      case 'ehall':
        isLoggedIn
            ? _safeNavigate(
                context,
                WebViewDetailScreen(
                  title: context.l10n.funcEhall,
                  url: AppConstants.ehallUrl,
                  userAgent: AppConstants.ehallUA,
                  showAppBar: false,
                  showWebBack: false,
                  appBarColor: const Color(0xFF1E88E5),
                ),
                id: id,
              )
            : _showLoginDialog(context);
        break;
      case 'info_portal':
        isLoggedIn
            ? _safeNavigate(
                context,
                WebViewDetailScreen(
                  title: context.l10n.funcInfoPortal,
                  url: AppConstants.infoPortalUrl,
                  homeUrl: AppConstants.infoPortalUrl,
                  userAgent: AppConstants.infoPortalUA,
                  showAppBar: false,
                  showWebBack: false,
                  appBarColor: Colors.white,
                  allowExternalLinks: true,
                ),
                id: id,
              )
            : _showLoginDialog(context);
        break;
      case 'gym':
        isLoggedIn
            ? _safeNavigate(
                context,
                WebViewDetailScreen(
                  title: context.l10n.funcGym,
                  url: AppConstants.gymReservationUrl,
                  showWebBack: true,
                ),
                id: id,
              )
            : _showLoginDialog(context);
        break;
      case 'teaching_eval':
        isLoggedIn
            ? _safeNavigate(
                context,
                WebViewDetailScreen(
                  title: context.l10n.funcTeachingEval,
                  url: AppConstants.teachingEvalUrl,
                  showAppBar: false,
                  showWebBack: false,
                  appBarColor: Colors.white,
                ),
                id: id,
              )
            : _showLoginDialog(context);
        break;
      case 'score':
        isLoggedIn
            ? _safeNavigate(context, const ScoreScreen(), id: id)
            : _showLoginDialog(context);
        break;
      case 'exam':
        _safeNavigate(context, const ExamScreen(), id: id);
        break;
      case 'vpn':
        _safeNavigate(context, const VpnConverterScreen(), id: id);
        break;
      case 'campus_card':
        if (isLoggedIn) {
          await [Permission.camera, Permission.photos, Permission.storage]
              .request();
          final service = ref.read(campusCardServiceProvider);
          final url = service.getCampusCardHomeUrl();

          if (!context.mounted) return;
          _safeNavigate(
            context,
            WebViewDetailScreen(
              title: context.l10n.funcCampusCard,
              url: url,
              userAgent: AppConstants.campusCardUA,
              showWebBack: false,
              showAppBar: false,
              appBarColor: const Color(0xFF008268),
            ),
            id: id,
          );
        } else {
          _showLoginDialog(context);
        }
        break;
      case 'bus':
        _safeNavigate(context, const BusTrackingScreen(), id: id);
        break;
      case 'campus_bus_route':
        _safeNavigate(context, const CampusBusMapScreen(), id: id);
        break;
      case 'cs_bus':
        final hasPermission = await LocationHelper.requestPermission();
        if (hasPermission) {
          if (!context.mounted) return;
          _safeNavigate(
            context,
            WebViewDetailScreen(
              title: context.l10n.funcCsBus,
              url: AppConstants.changshaBusUrl,
              showWebBack: true,
              showAppBar: true,
              appBarColor: const Color(0xFFF4F4F4),
            ),
            id: id,
          );
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
    bool isSelected = false,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    const activeColor = Color(0xFF09C489);

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark
                ? activeColor.withValues(alpha: 0.15)
                : activeColor.withValues(alpha: 0.08))
            : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? activeColor
              : (isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : const Color(0xFFE0E0E0)),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
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
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? activeColor
                          : (isDark ? Colors.white : Colors.black87),
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
    final reserves = cachedReservesAsync.valueOrNull ?? [];
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
            _safeNavigate(
                context, const LibraryHomeScreen(), id: 'library');
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

    // 当天考试日程（只显示本学期的考试）
    final examAsync = ref.watch(examProvider);
    final dayExams = examAsync.maybeWhen(
      data: (list) {
        final items = list
            .where((e) =>
                !ExamStorage.isManualExamExpired(e) &&
                (e.isCurrentSemester() || e.isManual) &&
                e.time != null &&
                e.time!.year == _previewDate.year &&
                e.time!.month == _previewDate.month &&
                e.time!.day == _previewDate.day)
            .toList();
        items.sort(ExamScheduleModel.compareTime);
        return items;
      },
      orElse: () => <ExamScheduleModel>[],
    );

    if (!_isLoadingTimetable &&
        _todayCourses.isEmpty &&
        dayExams.isEmpty) {
      return const SizedBox.shrink();
    }

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
        else
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < dayExams.length; i++) ...[
                if (i > 0) const SizedBox(height: 4),
                _buildExamTask(dayExams[i]),
              ],
              for (int i = 0; i < _todayCourses.length; i++) ...[
                if (i > 0 || dayExams.isNotEmpty)
                  const SizedBox(height: 4),
                _buildCourseItem(_todayCourses[i]),
              ],
            ],
          ),
      ],
    );
  }

  /// 考试卡片（红色底 + 考试时间与地点，严格显示第一个出现的时间）
  Widget _buildExamTask(ExamScheduleModel item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeStr = item.time != null ? DateFormat('HH:mm').format(item.time!) : '';
    final location = item.location?.trim() ?? '';
    final timeLocation = location.isNotEmpty ? '$timeStr @ $location' : timeStr;

    final title = item.title.trim();
    final course = item.courseName.trim();
    final displayTitle = course.isNotEmpty
        ? (title.isNotEmpty && title != course ? '$course · $title' : course)
        : title;

    final showStatus = item.status.isNotEmpty &&
        item.status != '待考' &&
        item.status != context.l10n.examStatusPending;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (item.detailUrl.isNotEmpty) {
          Navigator.push(
            context,
            createSlideHorizontalRoute(
              WebViewDetailScreen(
                url: item.detailUrl,
                title: item.title,
              ),
            ),
          );
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF382326) : const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: const Color(0xFFE53935).withValues(alpha: isDark ? 0.3 : 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.quiz_outlined,
              size: 22,
              color: Color(0xFFE53935),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayTitle,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                            color: isDark ? Colors.white : const Color(0xFF2D3436),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (showStatus) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.status,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFE53935),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeLocation,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Colors.white70
                          : const Color(0xFF7F8C8D),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
            [
              timeRange,
              course.classroom.trim(),
            ].where((s) => s.isNotEmpty).join(' @ '),
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

  Widget _buildHomeworkSection(BuildContext context) {
    final homeworkAsync = ref.watch(homeworkProvider);
    final pending = homeworkAsync.maybeWhen(
      data: (list) {
        final items = list
            .where((h) => h.status == HomeworkStatus.pending)
            .toList();
        items.sort((a, b) {
          if (a.endTime == null && b.endTime == null) return 0;
          if (a.endTime == null) return 1;
          if (b.endTime == null) return -1;
          return a.endTime!.compareTo(b.endTime!);
        });
        return items;
      },
      orElse: () => <HomeworkModel>[],
    );

    if (pending.isEmpty) return const SizedBox.shrink();

    // 首页最多展示 3 条，其余进作业页看
    final display = pending.take(3).toList();
    final locale = Localizations.localeOf(context).toString();

    return _buildMergedSection(
      title: context.l10n.tabHomework,
      onMore: () => _navigateToTab(context, 2),
      items: display.map((item) {
        final String deadlineStr = item.endTime != null
            ? '${context.l10n.deadlinePrefix} ${formatMMMdHm(item.endTime!, locale)}'
            : context.l10n.noDeadline;
        final String timeInfo = item.courseName.isNotEmpty
            ? '${item.courseName} · $deadlineStr'
            : deadlineStr;

        return _buildSectionItem(
          onTap: () => _openHomeworkItem(context, item),
          child: _buildSectionRow(
            icon: Icons.assignment_outlined,
            iconColor: const Color(0xFFF39C12),
            title: item.title,
            time: timeInfo,
          ),
        );
      }).toList(),
    );
  }

  Future<void> _openHomeworkItem(
      BuildContext context, HomeworkModel item) async {
    if (item.isManual) {
      _navigateToTab(context, 2);
    } else if (item.dataUrl.isNotEmpty) {
      final auth = ref.read(authStateProvider);
      if (auth.status == AuthStatus.authenticating) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.homeworkLoggingInWait),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      await AppCookieManager().injectAllChaoxingCookies();
      if (context.mounted) {
        Navigator.push(
          context,
          createSlideHorizontalRoute(WebViewDetailScreen(
            title: context.l10n.homeworkDetail,
            url: item.dataUrl,
          )),
        );
      }
    } else {
      _navigateToTab(context, 2);
    }
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
    final pending = (cachedAsync.valueOrNull ?? [])
        .where((q) => !q.isSubmitted && !q.isExpired)
        .toList();
    if (pending.isEmpty) return const SizedBox.shrink();

    // 首页最多展示 3 条，其余进问卷页看
    final display = pending.take(3).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _buildMergedSection(
      title: context.l10n.pendingQuestionnaires,
      onMore: () {
        _safeNavigate(
            context, const QuestionnaireListScreen(), id: 'questionnaire');
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
    if (_canSplitScreen(context)) {
      _safeNavigate(
        context,
        QuestionnaireDetailScreen(item: item),
        id: 'questionnaire_${item.hashCode}',
      );
      return;
    }
    final changed = await Navigator.push<bool>(
      context,
      createSlideHorizontalRoute(QuestionnaireDetailScreen(item: item)),
    );
    if (changed == true && context.mounted) {
      ref.read(questionnaireCacheProvider.notifier).refresh();
    }
  }

  DateTime? _parseLeaveDate(String str) {
    if (str.isEmpty) return null;
    return DateTime.tryParse(str) ??
        DateTime.tryParse(str.replaceFirst(' ', 'T'));
  }

  bool _isOngoingLeave(LeaveRecord record) {
    final start = _parseLeaveDate(record.startTime);
    final end = _parseLeaveDate(record.endTime);
    if (start == null || end == null) return false;
    final now = DateTime.now();
    return start.isBefore(now) && end.isAfter(now);
  }

  bool _isLeaveWithin7Days(LeaveRecord record) {
    final start = _parseLeaveDate(record.startTime);
    final end = _parseLeaveDate(record.endTime);
    if (start == null) return false;
    final now = DateTime.now();

    // 如果当前时间已经过了请假的目标时间（结束时间），则不显示
    if (end != null && !end.isAfter(now)) {
      return false;
    }
    if (end == null && !start.isAfter(now)) {
      return false;
    }

    final sevenDaysLater = now.add(const Duration(days: 7));
    // 7天内即将开始或正在进行中
    return start.isBefore(sevenDaysLater);
  }

  bool _shouldDisplayLeave(LeaveRecord record) {
    // 待审核 (0) 和 审核中 (8)：展示 7 天内的
    if (record.auditStatus == '0' ||
        record.auditStatus == '8' ||
        record.auditStatusName == '待审核' ||
        record.auditStatusName == '审核中') {
      return _isLeaveWithin7Days(record);
    }
    // 驳回 / 不通过的不在首页展示
    if (record.auditResultName.contains('不通过') ||
        record.auditResultName.contains('驳回') ||
        record.auditResultName.contains('拒绝')) {
      return false;
    }
    // 已通过：保持现在的已通过展示（即进行中的请假）
    return _isOngoingLeave(record);
  }

  Widget _buildOngoingLeaves(BuildContext context) {
    final cachedAsync = ref.watch(leaveCacheProvider);
    final leaves = (cachedAsync.valueOrNull ?? []).where(_shouldDisplayLeave).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    if (leaves.isEmpty) return const SizedBox.shrink();

    final display = leaves.take(3).toList();

    return _buildMergedSection(
      title: context.l10n.funcLeave,
      onMore: () {
        _safeNavigate(context, const LeaveListScreen(), id: 'leave');
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
            status: record.getLocalizedStatus(context),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _openLeaveDetail(
      BuildContext context, LeaveRecord record) async {
    if (_canSplitScreen(context)) {
      _safeNavigate(
        context,
        LeaveDetailScreen(item: record),
        id: 'leave_${record.hashCode}',
      );
      return;
    }
    final changed = await Navigator.push<bool>(
      context,
      createSlideHorizontalRoute(LeaveDetailScreen(item: record)),
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
    final ongoing = cachedAsync.valueOrNull ?? [];
    if (ongoing.isEmpty) return const SizedBox.shrink();

    final display = ongoing.take(3).toList();

    return _buildMergedSection(
      title: context.l10n.repairWorkOrders,
      onMore: () {
        _safeNavigate(context, const RepairScreen(), id: 'repairs');
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
    if (_canSplitScreen(context)) {
      _safeNavigate(
        context,
        RepairDetailScreen(order: order),
        id: 'repair_${order.id}',
      );
      return;
    }
    await Navigator.push(
      context,
      createSlideHorizontalRoute(RepairDetailScreen(order: order)),
    );
    if (context.mounted) {
      ref.read(repairCacheProvider.notifier).refresh();
    }
  }

  Widget _buildBalanceCardItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String balanceText,
    required Color balanceColor,
    required VoidCallback onTap,
    required bool isDark,
    bool isSelected = false,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.08)
            : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary
              : (isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : const Color(0xFFE0E0E0)),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, size: 22, color: iconColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
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
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  balanceText,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: balanceColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatElectricityBalance(String rawBalance) {
    final val = double.tryParse(rawBalance);
    if (val != null) {
      return val.toStringAsFixed(2);
    }
    return rawBalance;
  }

  Widget _buildMergedElectricityCard({
    required BuildContext context,
    required List<int> roomSlots,
    required DormitoryElectricityState eleState,
    required bool isDark,
    bool isSelected = false,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.08)
            : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary
              : (isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : const Color(0xFFE0E0E0)),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int idx = 0; idx < roomSlots.length; idx++) ...[
                if (idx > 0) const SizedBox(height: 12),
                () {
                  final slot = roomSlots[idx];
                  final room = eleState.rooms[slot]!;
                  final roomDisplayName =
                      room.roomName.isNotEmpty ? room.roomName : room.roomId;
                  final eleTitle = room.areaName.isNotEmpty
                      ? room.areaName
                      : context.l10n.dormitoryElectricity;
                  final String eleSubtitle;
                  if (room.buildingName.isNotEmpty) {
                    eleSubtitle = room.buildingName.endsWith(roomDisplayName)
                        ? room.buildingName
                        : '${room.buildingName} $roomDisplayName';
                  } else {
                    eleSubtitle = roomDisplayName;
                  }

                  final balanceInfo = (slot < eleState.balances.length)
                      ? eleState.balances[slot]
                      : null;
                  final balanceText = balanceInfo != null
                      ? '¥${_formatElectricityBalance(balanceInfo.balance)}'
                      : (eleState.isLoading ? '...' : '¥--');

                  final double? eleBal = balanceInfo != null
                      ? double.tryParse(balanceInfo.balance)
                      : null;
                  final bool isLowBalance = eleBal != null && eleBal <= 10.0;
                  final Color eleBalanceColor = isLowBalance
                      ? const Color(0xFFE53935)
                      : (isDark ? Colors.white : const Color(0xFF202124));

                  return InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => _openElectricity(context, initialSlot: slot),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (idx == 0)
                            const Icon(
                              Icons.bolt_outlined,
                              size: 22,
                              color: Color(0xFFFF9800),
                            )
                          else
                            const SizedBox(width: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  eleTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF222222),
                                  ),
                                ),
                                if (eleSubtitle.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    eleSubtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? Colors.white60
                                          : Colors.black54,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            balanceText,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: eleBalanceColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceSection(BuildContext context) {
    final cachedCardAsync = ref.watch(campusCardCacheProvider);
    final cardInfo = cachedCardAsync.valueOrNull;

    final eleState = ref.watch(electricityCacheProvider);
    final hasAnyRoom = eleState.rooms.any((r) => r != null);

    final authState = ref.watch(authStateProvider);
    final isAuthenticated = authState.status == AuthStatus.authenticated;

    if (cardInfo == null && !hasAnyRoom && !isAuthenticated) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Widget> cards = [];

    // 1. 宿舍电费卡片（若保存了两个宿舍，合并为一个卡片，且只有一个电的 icon）
    final validRoomSlots = <int>[];
    for (int i = 0; i < eleState.rooms.length; i++) {
      if (eleState.rooms[i] != null) {
        validRoomSlots.add(i);
      }
    }

    if (validRoomSlots.length > 1) {
      final isEleSelected = validRoomSlots.any(
        (slot) => _selectedActionId == 'ele_recharge_$slot',
      );
      cards.add(
        _buildMergedElectricityCard(
          context: context,
          roomSlots: validRoomSlots,
          eleState: eleState,
          isDark: isDark,
          isSelected: isEleSelected,
        ),
      );
    } else if (validRoomSlots.length == 1) {
      final i = validRoomSlots.first;
      final room = eleState.rooms[i]!;
      final roomDisplayName =
          room.roomName.isNotEmpty ? room.roomName : room.roomId;
      final eleTitle =
          room.areaName.isNotEmpty ? room.areaName : context.l10n.dormitoryElectricity;
      final String eleSubtitle;
      if (room.buildingName.isNotEmpty) {
        eleSubtitle = room.buildingName.endsWith(roomDisplayName)
            ? room.buildingName
            : '${room.buildingName} $roomDisplayName';
      } else {
        eleSubtitle = roomDisplayName;
      }

      final balanceInfo = (i < eleState.balances.length) ? eleState.balances[i] : null;
      final balanceText = balanceInfo != null
          ? '¥${_formatElectricityBalance(balanceInfo.balance)}'
          : (eleState.isLoading ? '...' : '¥--');

      final double? eleBal = balanceInfo != null ? double.tryParse(balanceInfo.balance) : null;
      final bool isLowBalance = eleBal != null && eleBal <= 10.0;
      final Color eleBalanceColor = isLowBalance
          ? const Color(0xFFE53935)
          : (isDark ? Colors.white : const Color(0xFF202124));

      cards.add(
        _buildBalanceCardItem(
          icon: Icons.bolt_outlined,
          iconColor: const Color(0xFFFF9800),
          title: eleTitle,
          subtitle: eleSubtitle,
          balanceText: balanceText,
          balanceColor: eleBalanceColor,
          onTap: () => _openElectricity(context, initialSlot: i),
          isDark: isDark,
          isSelected: _selectedActionId == 'ele_recharge_$i',
        ),
      );
    }

    // 2. 校园卡卡片
    if (cardInfo != null || isAuthenticated) {
      final String cardSubtitle;
      final String balanceText;
      if (cardInfo != null) {
        if (cardInfo.name.isNotEmpty && cardInfo.idserial.isNotEmpty) {
          cardSubtitle = '${cardInfo.name} · ${cardInfo.idserial}';
        } else if (cardInfo.idserial.isNotEmpty) {
          cardSubtitle = cardInfo.idserial;
        } else {
          cardSubtitle = context.l10n.funcCampusCard;
        }
        balanceText = '¥${cardInfo.balance}';
      } else {
        cardSubtitle = context.l10n.campusCardRecharge;
        balanceText = cachedCardAsync.isLoading ? '...' : '¥--';
      }

      cards.add(
        _buildBalanceCardItem(
          icon: Icons.credit_card_outlined,
          iconColor: const Color(0xFF1677FF),
          title: context.l10n.funcCampusCard,
          subtitle: cardSubtitle,
          balanceText: balanceText,
          balanceColor: isDark ? Colors.white : const Color(0xFF202124),
          onTap: () => _openCampusCard(context),
          isDark: isDark,
          isSelected: _selectedActionId == 'campus_card',
        ),
      );
    }

    if (cards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          context.l10n.feedBalance,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          cards[i],
        ],
      ],
    );
  }

  Future<void> _openCampusCard(BuildContext context) async {
    if (_canSplitScreen(context)) {
      _safeNavigate(
        context,
        const CampusCardRechargeScreen(),
        id: 'campus_card',
      );
      return;
    }
    await Navigator.push(
      context,
      createSlideHorizontalRoute(const CampusCardRechargeScreen()),
    );
    if (context.mounted) {
      ref.read(campusCardCacheProvider.notifier).refresh();
    }
  }

  Future<void> _openElectricity(BuildContext context, {int initialSlot = 0}) async {
    if (_canSplitScreen(context)) {
      _safeNavigate(
        context,
        ElectricityRechargeScreen(initialSlot: initialSlot),
        id: 'ele_recharge_$initialSlot',
      );
      return;
    }
    await Navigator.push(
      context,
      createSlideHorizontalRoute(ElectricityRechargeScreen(initialSlot: initialSlot)),
    );
    if (context.mounted) {
      ref.read(electricityCacheProvider.notifier).refresh();
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
