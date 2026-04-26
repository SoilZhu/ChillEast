import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../../profile/screens/settings_screen.dart';
import '../../../core/utils/location_helper.dart';
import 'package:permission_handler/permission_handler.dart';

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
    await Navigator.push(context, createSlideUpRoute(screen));
    if (mounted) setState(() => _isNavigating = false);
  }

  void _showLoginDialog() {
    if (ref.read(authStateProvider).status == AuthStatus.authenticating) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正在登录，请稍候...'), behavior: SnackBarBehavior.floating),
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
    final visibleItems = appearance.functionItems.where((item) => item.isVisible).toList();

    // 分类映射
    const categoryMap = {
      '校卡服务': ['payment_code', 'recharge', 'ele_recharge', 'campus_card'],
      '学习教务': ['score', 'empty_classroom', 'library', 'xgxt', 'teaching_eval'],
      '校园生活': ['repairs', 'gym', 'bus', 'cs_bus'],
      '网络工具': ['vpn', 'settings'],
    };

    final Map<String, List<dynamic>> groupedItems = {
      '校卡服务': [], '学习教务': [], '校园生活': [], '网络工具': [], '其他功能': [],
    };

    for (var item in visibleItems) {
      bool found = false;
      for (var entry in categoryMap.entries) {
        if (entry.value.contains(item.id)) {
          groupedItems[entry.key]!.add(item);
          found = true;
          break;
        }
      }
      if (!found) groupedItems['其他功能']!.add(item);
    }

    final List<Widget> categoryWidgets = [];
    for (var entry in groupedItems.entries) {
      if (entry.value.isNotEmpty) {
        categoryWidgets.add(
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: true,
              title: Text(
                entry.key,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              children: entry.value.map((item) {
                return _buildFunctionListItem(
                  context,
                  title: item.label,
                  icon: item.icon,
                  color: item.color,
                  onTap: () => _handleFunctionTap(context, item.id, isLoggedIn),
                );
              }).toList(),
            ),
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              ...categoryWidgets,
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _handleFunctionTap(BuildContext context, String id, bool isLoggedIn) async {
    switch (id) {
      case 'payment_code':
        isLoggedIn ? _safeNavigate(const PaymentCodeScreen()) : _showLoginDialog();
        break;
      case 'recharge':
        isLoggedIn ? _safeNavigate(const CampusCardRechargeScreen()) : _showLoginDialog();
        break;
      case 'ele_recharge':
        isLoggedIn ? _safeNavigate(const ElectricityRechargeScreen()) : _showLoginDialog();
        break;
      case 'library':
        if (isLoggedIn) {
          final status = await Permission.camera.request();
          if (status.isGranted) {
            _safeNavigate(const WebViewDetailScreen(title: '图书馆', url: AppConstants.libraryUrl, showWebBack: true));
          }
        } else {
          _showLoginDialog();
        }
        break;
      case 'empty_classroom':
        isLoggedIn ? _safeNavigate(const ClassroomInquiryScreen()) : _showLoginDialog();
        break;
      case 'repairs':
        isLoggedIn ? _safeNavigate(const WebViewDetailScreen(title: '报修平台', url: AppConstants.repairsSsoUrl, targetUrl: '/relax/mobile/index.html', showWebBack: true)) : _showLoginDialog();
        break;
      case 'gym':
        isLoggedIn ? _safeNavigate(const WebViewDetailScreen(title: '场馆预约', url: AppConstants.gymReservationUrl, showWebBack: true)) : _showLoginDialog();
        break;
      case 'xgxt':
        isLoggedIn ? _safeNavigate(const WebViewDetailScreen(title: '学工系统', url: AppConstants.xgxtWapUrl, showAppBar: false, showWebBack: false, appBarColor: Color(0xFF3C8DBC))) : _showLoginDialog();
        break;
      case 'teaching_eval':
        isLoggedIn ? _safeNavigate(const WebViewDetailScreen(title: '教评系统', url: AppConstants.teachingEvalUrl, showAppBar: false, showWebBack: false, appBarColor: Colors.white)) : _showLoginDialog();
        break;
      case 'score':
        isLoggedIn ? _safeNavigate(const ScoreScreen()) : _showLoginDialog();
        break;
      case 'vpn':
        _safeNavigate(const VpnConverterScreen());
        break;
      case 'settings':
        _safeNavigate(const SettingsScreen());
        break;
      case 'campus_card':
        if (isLoggedIn) {
          await [Permission.camera, Permission.photos, Permission.storage].request();
          final service = ref.read(campusCardServiceProvider);
          _safeNavigate(WebViewDetailScreen(title: '校园卡', url: service.getCampusCardHomeUrl(), userAgent: AppConstants.campusCardUA, showWebBack: false, showAppBar: false, appBarColor: const Color(0xFF008268)));
        } else {
          _showLoginDialog();
        }
        break;
      case 'bus':
        _safeNavigate(const BusTrackingScreen());
        break;
      case 'cs_bus':
        final hasPermission = await LocationHelper.requestPermission();
        if (hasPermission) {
          _safeNavigate(const WebViewDetailScreen(title: '长沙实时公交', url: AppConstants.changshaBusUrl, showWebBack: true, showAppBar: true, appBarColor: Color(0xFFF4F4F4)));
        }
        break;
    }
  }

  Widget _buildFunctionListItem(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: 16),
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400)),
            const Spacer(),
            Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}