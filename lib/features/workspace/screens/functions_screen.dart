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
import 'workspace_screen.dart';
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

/// 功能页 - 展示各种功能入口
class FunctionsScreen extends ConsumerStatefulWidget {
  const FunctionsScreen({super.key});

  @override
  ConsumerState<FunctionsScreen> createState() => _FunctionsScreenState();
}

class _FunctionsScreenState extends ConsumerState<FunctionsScreen> {
  bool _isNavigating = false;

  void _safeNavigate(Widget screen) async {
    if (_isNavigating) return;
    
    setState(() => _isNavigating = true);
    
    await Navigator.push(
      context,
      createSlideUpRoute(screen),
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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
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
                        color:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.white70
                                : Colors.grey[700],
                      ),
                    ),
                  ),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      mainAxisExtent: 52,
                    ),
                    itemCount: visibleGroups[gi].items.length,
                    itemBuilder: (context, index) {
                      final item = visibleGroups[gi].items[index];
                      return _buildFunctionGridCard(
                        context,
                        title: item.getLocalizedTitle(context),
                        icon: item.icon,
                        color: item.color,
                        onTap: () =>
                            _handleFunctionTap(context, item.id, isLoggedIn),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleFunctionTap(BuildContext context, String id, bool isLoggedIn) async {
    switch (id) {
      case 'payment_code':
        isLoggedIn 
            ? _safeNavigate(const PaymentCodeScreen())
            : _showLoginDialog();
        break;
      case 'recharge':
        isLoggedIn 
            ? _safeNavigate(const CampusCardRechargeScreen())
            : _showLoginDialog();
        break;
      case 'ele_recharge':
        isLoggedIn 
            ? _safeNavigate(const ElectricityRechargeScreen())
            : _showLoginDialog();
        break;
      case 'library':
        isLoggedIn 
            ? _safeNavigate(const LibraryHomeScreen())
            : _showLoginDialog();
        break;
      case 'empty_classroom':
        isLoggedIn 
            ? _safeNavigate(const ClassroomInquiryScreen())
            : _showLoginDialog();
        break;
      case 'sunshine':
        isLoggedIn
            ? _safeNavigate(const SunshineScreen())
            : _showLoginDialog();
        break;
      case 'questionnaire':
        isLoggedIn
            ? _safeNavigate(const QuestionnaireListScreen())
            : _showLoginDialog();
        break;
      case 'leave':
        isLoggedIn
            ? _safeNavigate(const LeaveListScreen())
            : _showLoginDialog();
        break;
      case 'repairs':
        isLoggedIn 
            ? _safeNavigate(
                const RepairScreen(),
              )
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
              )
            : _showLoginDialog();
        break;
      case 'score':
        isLoggedIn 
            ? _safeNavigate(const ScoreScreen())
            : _showLoginDialog();
        break;
      case 'vpn':
        _safeNavigate(const VpnConverterScreen());
        break;
      case 'campus_card':
        if (isLoggedIn) {
          await [Permission.camera, Permission.photos, Permission.storage].request();
          final service = ref.read(campusCardServiceProvider);
          final url = service.getCampusCardHomeUrl();
          
          if (!mounted) return;
          _safeNavigate(
            WebViewDetailScreen(
              title: context.l10n.funcCampusCard,
              url: url,
              userAgent: AppConstants.campusCardUA,
              showWebBack: false,
              showAppBar: false,
              appBarColor: const Color(0xFF008268),
            ),
          );
        } else {
          _showLoginDialog();
        }
        break;
      case 'bus':
        _safeNavigate(const BusTrackingScreen());
        break;
      case 'campus_bus_route':
        _safeNavigate(const CampusBusMapScreen());
        break;
      case 'cs_bus':
        final hasPermission = await LocationHelper.requestPermission();
        if (!mounted) return;
        if (hasPermission) {
          _safeNavigate(
            WebViewDetailScreen(
              title: context.l10n.funcCsBus,
              url: AppConstants.changshaBusUrl,
              showWebBack: true,
              showAppBar: true,
              appBarColor: const Color(0xFFF4F4F4),
            ),
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

  /// 构建网格样式的功能项（与首页快捷功能同款）
  Widget _buildFunctionGridCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
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
}
