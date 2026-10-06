import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/state/auth_state.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/location_helper.dart';
import '../../../core/utils/route_utils.dart';
import '../../auth/screens/login_screen.dart';
import '../../campus_bus/screens/campus_bus_map_screen.dart';
import '../../home/screens/bus_tracking_screen.dart';
import '../../leave/screens/leave_list_screen.dart';
import '../../library/screens/library_home_screen.dart';
import '../../questionnaire/screens/questionnaire_list_screen.dart';
import '../../repairs/screens/repair_screen.dart';
import '../../score/screens/score_screen.dart';
import '../../sunshine/screens/sunshine_screen.dart';
import '../../workspace/screens/classroom_inquiry_screen.dart';
import '../../workspace/screens/campus_card_recharge_screen.dart';
import '../../workspace/screens/electricity_recharge_screen.dart';
import '../../workspace/screens/payment_code_screen.dart';
import '../../workspace/screens/vpn_converter_screen.dart';
import '../../workspace/screens/webview_detail_screen.dart';
import '../../workspace/services/campus_card_service.dart';
import '../../dormitory/screens/dormitory_screen.dart';

/// 小组件快捷入口路由：与首页快捷功能同款跳转逻辑，供桌面小组件点击复用。
Future<void> openFunctionById(
  BuildContext context,
  WidgetRef ref,
  String id,
) async {
  final authState = ref.read(authStateProvider);
  final isLoggedIn = authState.status == AuthStatus.authenticated;

  switch (id) {
    case 'payment_code':
      isLoggedIn
          ? Navigator.push(
              context, createSlideUpRoute(const PaymentCodeScreen()))
          : _showLoginDialog(context, ref);
      break;
    case 'recharge':
      isLoggedIn
          ? Navigator.push(
              context, createSlideUpRoute(const CampusCardRechargeScreen()))
          : _showLoginDialog(context, ref);
      break;
    case 'ele_recharge':
      isLoggedIn
          ? Navigator.push(
              context, createSlideUpRoute(const ElectricityRechargeScreen()))
          : _showLoginDialog(context, ref);
      break;
    case 'library':
      isLoggedIn
          ? Navigator.push(
              context, createSlideUpRoute(const LibraryHomeScreen()))
          : _showLoginDialog(context, ref);
      break;
    case 'empty_classroom':
      isLoggedIn
          ? Navigator.push(
              context, createSlideUpRoute(const ClassroomInquiryScreen()))
          : _showLoginDialog(context, ref);
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
          : _showLoginDialog(context, ref);
      break;
    case 'sunshine':
      isLoggedIn
          ? Navigator.push(
              context, createSlideUpRoute(const SunshineScreen()))
          : _showLoginDialog(context, ref);
      break;
    case 'questionnaire':
      isLoggedIn
          ? Navigator.push(
              context, createSlideUpRoute(const QuestionnaireListScreen()))
          : _showLoginDialog(context, ref);
      break;
    case 'leave':
      isLoggedIn
          ? Navigator.push(
              context, createSlideUpRoute(const LeaveListScreen()))
          : _showLoginDialog(context, ref);
      break;
    case 'repairs':
      isLoggedIn
          ? Navigator.push(context, createSlideUpRoute(const RepairScreen()))
          : _showLoginDialog(context, ref);
      break;
    case 'dormitory':
      isLoggedIn
          ? Navigator.push(
              context, createSlideUpRoute(const DormitoryScreen()))
          : _showLoginDialog(context, ref);
      break;
    case 'ehall':
      isLoggedIn
          ? Navigator.push(
              context,
              createSlideUpRoute(WebViewDetailScreen(
                title: context.l10n.funcEhall,
                url: AppConstants.ehallUrl,
                userAgent: AppConstants.ehallUA,
                showAppBar: false,
                showWebBack: false,
                appBarColor: const Color(0xFF1E88E5),
              )))
          : _showLoginDialog(context, ref);
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
          : _showLoginDialog(context, ref);
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
          : _showLoginDialog(context, ref);
      break;
    case 'score':
      isLoggedIn
          ? Navigator.push(context, createSlideUpRoute(const ScoreScreen()))
          : _showLoginDialog(context, ref);
      break;
    case 'vpn':
      Navigator.push(context, createSlideUpRoute(const VpnConverterScreen()));
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
        _showLoginDialog(context, ref);
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

void _showLoginDialog(BuildContext context, WidgetRef ref) {
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
