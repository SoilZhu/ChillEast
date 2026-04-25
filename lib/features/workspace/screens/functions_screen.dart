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
import '../../../core/utils/location_helper.dart';
import 'package:permission_handler/permission_handler.dart';

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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isLoggedIn = authState.status == AuthStatus.authenticated;
    final appearance = ref.watch(appearanceProvider);
    final visibleItems = appearance.functionItems.where((item) => item.isVisible).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              
              // 功能列表
              ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: visibleItems.length,
                itemBuilder: (context, index) {
                  final item = visibleItems[index];
                  return _buildFunctionListItem(
                    context,
                    title: item.label,
                    icon: item.icon,
                    color: item.color ?? Colors.blue,
                    onTap: () => _handleFunctionTap(context, item.id, isLoggedIn),
                  );
                },
              ),
            ],
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
        if (isLoggedIn) {
          final status = await Permission.camera.request();
          if (status.isGranted) {
            _safeNavigate(
              const WebViewDetailScreen(
                title: '图书馆',
                url: AppConstants.libraryUrl,
                showWebBack: true,
              ),
            );
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('需要相机权限以完成扫码')),
              );
            }
          }
        } else {
          _showLoginDialog();
        }
        break;
      case 'empty_classroom':
        isLoggedIn 
            ? _safeNavigate(const ClassroomInquiryScreen())
            : _showLoginDialog();
        break;
      case 'repairs':
        isLoggedIn 
            ? _safeNavigate(
                const WebViewDetailScreen(
                  title: '报修平台',
                  url: AppConstants.repairsSsoUrl,
                  userAgent: 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Mobile Safari/537.36',
                  showWebBack: true,
                  targetUrl: '/relax/mobile/index.html',
                ),
              )
            : _showLoginDialog();
        break;
      case 'gym':
        isLoggedIn 
            ? _safeNavigate(
                const WebViewDetailScreen(
                  title: '场馆预约',
                  url: AppConstants.gymReservationUrl,
                  showWebBack: true,
                ),
              )
            : _showLoginDialog();
        break;
      case 'xgxt':
        isLoggedIn 
            ? _safeNavigate(
                const WebViewDetailScreen(
                  title: '学工系统',
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
                const WebViewDetailScreen(
                  title: '教评系统',
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
          
          _safeNavigate(
            WebViewDetailScreen(
              title: '校园卡',
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
      case 'cs_bus':
        final hasPermission = await LocationHelper.requestPermission();
        if (hasPermission) {
          _safeNavigate(
            const WebViewDetailScreen(
              title: '长沙实时公交',
              url: AppConstants.changshaBusUrl,
              showWebBack: true,
              showAppBar: true,
              appBarColor: const Color(0xFFF4F4F4),
            ),
          );
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('需要定位权限以显示附近的实时公交'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
        break;
    }
  }

  /// 构建列表样式的功能项
  Widget _buildFunctionListItem(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            // 圆形图标背景 (缩小型)
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 22,
                color: color,
              ),
            ),
            const SizedBox(width: 16),
            // 功能名称 (缩小型)
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF202124),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
