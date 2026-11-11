import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../sunshine/screens/sunshine_screen.dart';
import '../../repairs/screens/repair_screen.dart';
import '../../questionnaire/screens/questionnaire_list_screen.dart';
import '../../leave/screens/leave_list_screen.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/state/auth_state.dart';
import '../../../core/utils/route_utils.dart';
import '../../auth/screens/login_screen.dart';
import '../../score/screens/score_screen.dart';
import '../../home/screens/bus_tracking_screen.dart';
import 'webview_detail_screen.dart';
import 'vpn_converter_screen.dart';
import 'classroom_inquiry_screen.dart';
import 'payment_code_screen.dart';
import 'campus_card_recharge_screen.dart';
import 'electricity_recharge_screen.dart';
import '../services/campus_card_service.dart';
import '../../profile/providers/appearance_provider.dart';
import '../../profile/models/appearance_state.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/location_helper.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../library/screens/library_home_screen.dart';
import '../../campus_bus/screens/campus_bus_map_screen.dart';
import '../../dormitory/screens/dormitory_screen.dart';
import '../../exam/screens/exam_screen.dart';
import '../../../core/widgets/embedded_detail_pane.dart';

/// 功能页 - 展示各种功能入口
class FunctionsScreen extends ConsumerStatefulWidget {
  const FunctionsScreen({super.key});

  @override
  ConsumerState<FunctionsScreen> createState() => _FunctionsScreenState();
}

class _FunctionsScreenState extends ConsumerState<FunctionsScreen> {
  bool _isNavigating = false;
  Widget? _embeddedScreen;
  String? _selectedFunctionId;
  bool _isTransitioningToRoute = false;

  @override
  void initState() {
    super.initState();
    // 预热付款码：功能页可见时后台拉一次 openVirtualcard，
    // 命中服务层 55s 缓存，点进付款码页直接秒开；失败静默忽略。
    // 缓存本身会去重，重复进页不会多打请求。
    final svc = ref.read(campusCardServiceProvider);
    Future(() async {
      try {
        await svc.fetchPaymentCode();
      } catch (_) {}
    });
  }

  bool _canSplitScreen() {
    final size = MediaQuery.sizeOf(context);
    final orientation = MediaQuery.orientationOf(context);
    final isTabletOrLandscape = size.width >= 600 ||
        (orientation == Orientation.landscape && size.width >= 500);
    final pageWidth = isTabletOrLandscape ? (size.width - 76.0) : size.width;
    return pageWidth >= 600;
  }

  void _safeNavigate(Widget screen, {String? id}) async {
    if (_isNavigating) return;

    if (_canSplitScreen()) {
      setState(() {
        _embeddedScreen = screen;
        _selectedFunctionId = id;
      });
      return;
    }

    setState(() => _isNavigating = true);

    await Navigator.push(
      context,
      createSlideHorizontalRoute(screen),
    );

    if (mounted) {
      setState(() => _isNavigating = false);
    }
  }

  void _showLoginDialog() {
    if (ref.read(authStateProvider).status == AuthStatus.authenticating) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.loggingInWait),
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isLoggedIn = authState.status == AuthStatus.authenticated;
    final appearance = ref.watch(appearanceProvider);
    final visibleItems =
        appearance.functionItems.where((item) => item.isVisible).toList();
    final hiddenGroups = appearance.hiddenFunctionGroups.toSet();
    final groupOrder = appearance.functionGroupOrder;

    // 按用户排好的分组顺序，只保留未隐藏且有可见成员的分组
    final orderedGroups = [
      for (final key in groupOrder)
        functionGroups.firstWhere(
          (g) => g.titleKey == key,
          orElse: () => functionGroups.first,
        ),
      for (final g in functionGroups)
        if (!groupOrder.contains(g.titleKey)) g,
    ];
    final visibleGroups = orderedGroups
        .where((group) => !hiddenGroups.contains(group.titleKey))
        .map((group) => (
              titleKey: group.titleKey,
              items: visibleItems
                  .where((item) => group.ids.contains(item.id))
                  .toList(),
            ))
        .where((group) => group.items.isNotEmpty)
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth >= 600;

        if (!isLargeScreen &&
            _embeddedScreen != null &&
            !_isTransitioningToRoute) {
          _isTransitioningToRoute = true;
          final screenToOpen = _embeddedScreen!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _embeddedScreen = null;
              _selectedFunctionId = null;
              _isTransitioningToRoute = false;
            });
            Navigator.of(context).push(
              createSlideHorizontalRoute(screenToOpen),
            );
          });
        }

        final listContent =
            _buildFunctionsList(context, visibleGroups, isLoggedIn);

        if (isLargeScreen && _embeddedScreen != null) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              setState(() {
                _embeddedScreen = null;
                _selectedFunctionId = null;
              });
            },
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: listContent,
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 0.5,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0x1A000000),
                ),
                Expanded(
                  flex: 1,
                  child: EmbeddedDetailPane(
                    key: ValueKey(
                        _selectedFunctionId ?? _embeddedScreen.runtimeType),
                    onClose: () {
                      setState(() {
                        _embeddedScreen = null;
                        _selectedFunctionId = null;
                      });
                    },
                    child: _embeddedScreen!,
                  ),
                ),
              ],
            ),
          );
        }

        return listContent;
      },
    );
  }

  Widget _buildFunctionsList(
    BuildContext context,
    List<({List<FunctionItem> items, String titleKey})> visibleGroups,
    bool isLoggedIn,
  ) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int gi = 0; gi < visibleGroups.length; gi++) ...[
              if (gi > 0) const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  functionGroupTitle(context, visibleGroups[gi].titleKey),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : Colors.grey[700],
                  ),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 240,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent: 52,
                ),
                itemCount: visibleGroups[gi].items.length,
                itemBuilder: (context, index) {
                  final item = visibleGroups[gi].items[index];
                  final isSelected = _selectedFunctionId == item.id;
                  return _buildFunctionGridCard(
                    context,
                    title: item.getLocalizedTitle(context),
                    icon: item.icon,
                    color: item.color,
                    isSelected: isSelected,
                    onTap: () =>
                        _handleFunctionTap(context, item.id, isLoggedIn),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _handleFunctionTap(
      BuildContext context, String id, bool isLoggedIn) async {
    switch (id) {
      case 'payment_code':
        isLoggedIn
            ? _safeNavigate(const PaymentCodeScreen(), id: id)
            : _showLoginDialog();
        break;
      case 'recharge':
        isLoggedIn
            ? _safeNavigate(const CampusCardRechargeScreen(), id: id)
            : _showLoginDialog();
        break;
      case 'ele_recharge':
        isLoggedIn
            ? _safeNavigate(const ElectricityRechargeScreen(), id: id)
            : _showLoginDialog();
        break;
      case 'library':
        isLoggedIn
            ? _safeNavigate(const LibraryHomeScreen(), id: id)
            : _showLoginDialog();
        break;
      case 'empty_classroom':
        isLoggedIn
            ? _safeNavigate(const ClassroomInquiryScreen(), id: id)
            : _showLoginDialog();
        break;
      case 'sunshine':
        isLoggedIn
            ? _safeNavigate(const SunshineScreen(), id: id)
            : _showLoginDialog();
        break;
      case 'questionnaire':
        isLoggedIn
            ? _safeNavigate(const QuestionnaireListScreen(), id: id)
            : _showLoginDialog();
        break;
      case 'leave':
        isLoggedIn
            ? _safeNavigate(const LeaveListScreen(), id: id)
            : _showLoginDialog();
        break;
      case 'repairs':
        isLoggedIn
            ? _safeNavigate(
                const RepairScreen(),
                id: id,
              )
            : _showLoginDialog();
        break;
      case 'dormitory':
        isLoggedIn
            ? _safeNavigate(const DormitoryScreen(), id: id)
            : _showLoginDialog();
        break;
      case 'gym':
        isLoggedIn
            ? _safeNavigate(
                WebViewDetailScreen(
                  title: context.l10n.funcGym,
                  url: AppConstants.gymReservationUrl,
                  showWebBack: true,
                ),
                id: id,
              )
            : _showLoginDialog();
        break;
      case 'physical_test':
        isLoggedIn
            ? _safeNavigate(
                WebViewDetailScreen(
                  title: context.l10n.funcPhysicalTest,
                  url: AppConstants.physicalTestReservationUrl,
                  showWebBack: true,
                ),
                id: id,
              )
            : _showLoginDialog();
        break;
      case 'ehall':
        isLoggedIn
            ? _safeNavigate(
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
            : _showLoginDialog();
        break;
      case 'info_portal':
        isLoggedIn
            ? _safeNavigate(
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
            : _showLoginDialog();
        break;
      case 'xgxt':
        isLoggedIn
            ? _safeNavigate(
                WebViewDetailScreen(
                  title: context.l10n.funcXgxt,
                  url: AppConstants.xgxtWapUrl,
                  showAppBar: false,
                  showWebBack: false,
                  appBarColor: const Color(0xFF3C8DBC),
                ),
                id: id,
              )
            : _showLoginDialog();
        break;
      case 'teaching_eval':
        isLoggedIn
            ? _safeNavigate(
                WebViewDetailScreen(
                  title: context.l10n.funcEvaluation,
                  url: AppConstants.teachingEvalUrl,
                  showAppBar: false,
                  showWebBack: false,
                  appBarColor: Colors.white,
                ),
                id: id,
              )
            : _showLoginDialog();
        break;
      case 'score':
        isLoggedIn
            ? _safeNavigate(const ScoreScreen(), id: id)
            : _showLoginDialog();
        break;
      case 'exam':
        _safeNavigate(const ExamScreen(), id: id);
        break;
      case 'vpn':
        _safeNavigate(const VpnConverterScreen(), id: id);
        break;
      case 'campus_card':
        if (isLoggedIn) {
          final campusCardTitle = context.l10n.funcCampusCard;
          await [Permission.camera, Permission.photos, Permission.storage]
              .request();
          final service = ref.read(campusCardServiceProvider);
          final url = service.getCampusCardHomeUrl();

          if (!mounted) return;
          _safeNavigate(
            WebViewDetailScreen(
              title: campusCardTitle,
              url: url,
              userAgent: AppConstants.campusCardUA,
              showWebBack: false,
              showAppBar: false,
              appBarColor: const Color(0xFF008268),
            ),
            id: id,
          );
        } else {
          _showLoginDialog();
        }
        break;
      case 'bus':
        _safeNavigate(const BusTrackingScreen(), id: id);
        break;
      case 'campus_bus_route':
        _safeNavigate(const CampusBusMapScreen(), id: id);
        break;
      case 'cs_bus':
        final csBusTitle = context.l10n.funcCsBus;
        final needLocationMsg = context.l10n.needLocationForBus;
        final hasPermission = await LocationHelper.requestPermission();
        if (!mounted) return;
        if (hasPermission) {
          _safeNavigate(
            WebViewDetailScreen(
              title: csBusTitle,
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
                content: Text(needLocationMsg),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
        break;
    }
  }

  /// 构建网格样式的功能项（与首页快捷功能同款）
  Widget _buildFunctionGridCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
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
}
