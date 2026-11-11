import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../utils/route_utils.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/campus_bus/screens/campus_bus_map_screen.dart';
import '../../features/dormitory/screens/dormitory_screen.dart';
import '../../features/exam/screens/exam_screen.dart';
import '../../features/home/screens/bus_tracking_screen.dart';
import '../../features/homework/screens/homework_screen.dart';
import '../../features/leave/screens/leave_apply_screen.dart';
import '../../features/leave/screens/leave_list_screen.dart';
import '../../features/library/screens/library_book_search_screen.dart';
import '../../features/library/screens/library_home_screen.dart';
import '../../features/notice/screens/notice_list_screen.dart';
import '../../features/profile/screens/about_screen.dart';
import '../../features/profile/screens/ai_memory_screen.dart';
import '../../features/profile/screens/ai_settings_screen.dart';
import '../../features/profile/screens/appearance_settings_screen.dart';
import '../../features/profile/screens/button_reorder_screen.dart';
import '../../features/profile/screens/data_sync_settings_screen.dart';
import '../../features/profile/screens/help_feedback_screen.dart';
import '../../features/profile/screens/language_settings_screen.dart';
import '../../features/profile/screens/notification_settings_screen.dart';
import '../../features/profile/screens/oss_licenses_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/settings_screen.dart';
import '../../features/profile/screens/timetable_settings_screen.dart';
import '../../features/profile/screens/timetable_subscription_screen.dart';
import '../../features/questionnaire/screens/questionnaire_list_screen.dart';
import '../../features/repairs/screens/repair_form_screen.dart';
import '../../features/repairs/screens/repair_screen.dart';
import '../../features/repairs/services/repair_service.dart';
import '../../features/score/screens/score_screen.dart';
import '../../features/sunshine/screens/sunshine_form_screen.dart';
import '../../features/sunshine/screens/sunshine_screen.dart';
import '../../features/timetable/screens/timetable_screen.dart';
import '../../features/workspace/screens/campus_card_recharge_screen.dart';
import '../../features/workspace/screens/classroom_inquiry_screen.dart';
import '../../features/workspace/screens/electricity_recharge_screen.dart';
import '../../features/workspace/screens/functions_screen.dart';
import '../../features/workspace/screens/payment_code_screen.dart';
import '../../features/workspace/screens/transaction_history_screen.dart';
import '../../features/workspace/screens/vpn_converter_screen.dart';
import '../../features/workspace/screens/webview_detail_screen.dart';
import '../../features/workspace/services/campus_card_service.dart';

/// 页面基本信息
class AppNavPageInfo {
  final String id;
  final String title;
  final String description;
  final bool isTab;
  final int? tabIndex;

  const AppNavPageInfo({
    required this.id,
    required this.title,
    required this.description,
    this.isTab = false,
    this.tabIndex,
  });
}

/// 全局应用页面导航管理器
class AppNavigator {
  /// 全局根 Navigator 键，绑定到 MaterialApp
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// 切换主页 Tab 的委托回调
  static void Function(int tabIndex)? onSwitchTab;

  /// 关闭 AI 交互模式 / 悬浮遮罩的委托回调
  static VoidCallback? onCloseAiMode;

  /// 页面清单
  static const Map<String, AppNavPageInfo> pages = {
    // 底部 Tab
    'home': AppNavPageInfo(
      id: 'home',
      title: '首页',
      description: '应用首页与快速功能入口',
      isTab: true,
      tabIndex: 0,
    ),
    'timetable': AppNavPageInfo(
      id: 'timetable',
      title: '课表',
      description: '个人课表与日程总览',
      isTab: true,
      tabIndex: 1,
    ),
    'homework': AppNavPageInfo(
      id: 'homework',
      title: '作业待办',
      description: '作业列表与个人待办事项',
      isTab: true,
      tabIndex: 2,
    ),
    'notice': AppNavPageInfo(
      id: 'notice',
      title: '校园通知',
      description: '学校通知公告与消息列表',
      isTab: true,
      tabIndex: 3,
    ),
    'functions': AppNavPageInfo(
      id: 'functions',
      title: '功能页',
      description: '全部校园功能与服务工作台',
      isTab: true,
      tabIndex: 4,
    ),

    // 核心业务功能
    'score': AppNavPageInfo(
      id: 'score',
      title: '成绩查询',
      description: '学期成绩与学分绩点查询',
    ),
    'exam': AppNavPageInfo(
      id: 'exam',
      title: '考试安排',
      description: '期末/期中考试日程、考场与座位查询',
    ),
    'empty_classroom': AppNavPageInfo(
      id: 'empty_classroom',
      title: '空教室查询',
      description: '各教学楼空闲教室与自习教室查询',
    ),
    'library': AppNavPageInfo(
      id: 'library',
      title: '图书馆',
      description: '图书馆主页与座位预约',
    ),
    'library_search': AppNavPageInfo(
      id: 'library_search',
      title: '图书检索',
      description: '馆藏图书检索与借阅详情查询',
    ),
    'sunshine': AppNavPageInfo(
      id: 'sunshine',
      title: '阳光服务',
      description: '阳光服务诉求反馈与回复进度查看',
    ),
    'sunshine_submit': AppNavPageInfo(
      id: 'sunshine_submit',
      title: '提交阳光服务',
      description: '向学校提交阳光服务信访与诉求',
    ),
    'questionnaire': AppNavPageInfo(
      id: 'questionnaire',
      title: '学工问卷',
      description: '学工系统各类问卷调查与假期去向统计',
    ),
    'leave': AppNavPageInfo(
      id: 'leave',
      title: '请假申请',
      description: '学工请假记录与审批进度',
    ),
    'leave_apply': AppNavPageInfo(
      id: 'leave_apply',
      title: '提交请假',
      description: '在线填写提交新的请假申请单',
    ),
    'repairs': AppNavPageInfo(
      id: 'repairs',
      title: '报修平台',
      description: '校园设施与后勤网络报修工单列表',
    ),
    'repair_form': AppNavPageInfo(
      id: 'repair_form',
      title: '提交报修',
      description: '在线发起新的后勤或网络报修单',
    ),
    'payment_code': AppNavPageInfo(
      id: 'payment_code',
      title: '校园卡付款码',
      description: '一卡通食堂消费与商户付款码',
    ),
    'recharge': AppNavPageInfo(
      id: 'recharge',
      title: '校园卡充值',
      description: '一卡通余额微信/支付宝在线充值',
    ),
    'electricity_recharge': AppNavPageInfo(
      id: 'electricity_recharge',
      title: '电费充值',
      description: '学生宿舍电费查询与购电充值',
    ),
    'transactions': AppNavPageInfo(
      id: 'transactions',
      title: '校园卡账单流水',
      description: '校园一卡通近期消费流水与历史账单',
    ),
    'dormitory': AppNavPageInfo(
      id: 'dormitory',
      title: '我的宿舍',
      description: '学生宿舍楼栋、房号与床位信息',
    ),
    'bus': AppNavPageInfo(
      id: 'bus',
      title: '实时校车',
      description: '校园巴士实时位置与发车班次追踪',
    ),
    'campus_bus_route': AppNavPageInfo(
      id: 'campus_bus_route',
      title: '校内公交线路',
      description: '校内公交线路图与停靠站点',
    ),
    'cs_bus': AppNavPageInfo(
      id: 'cs_bus',
      title: '长沙实时公交',
      description: '长沙市区公共交通与公交车实时到站',
    ),
    'vpn': AppNavPageInfo(
      id: 'vpn',
      title: 'WebVPN转换',
      description: '校外内网资源 WebVPN 链接转换器',
    ),
    'xgxt': AppNavPageInfo(
      id: 'xgxt',
      title: '学工系统',
      description: '湖南农大学工系统移动端',
    ),
    'ehall': AppNavPageInfo(
      id: 'ehall',
      title: '办事大厅',
      description: '学校网上综合办事大厅',
    ),
    'gym': AppNavPageInfo(
      id: 'gym',
      title: '场馆预约',
      description: '校园体育场馆与运动场地预约',
    ),
    'physical_test': AppNavPageInfo(
      id: 'physical_test',
      title: '体测预约',
      description: '学生体质健康测试预约系统',
    ),
    'teaching_eval': AppNavPageInfo(
      id: 'teaching_eval',
      title: '教评系统',
      description: '学期教师教学质量评价系统',
    ),
    'info_portal': AppNavPageInfo(
      id: 'info_portal',
      title: '更多小程序',
      description: '校园综合应用与微服务集合',
    ),
    'campus_card': AppNavPageInfo(
      id: 'campus_card',
      title: '一校通',
      description: '校园卡综合服务门户网站',
    ),

    // 设置与个人
    'settings': AppNavPageInfo(
      id: 'settings',
      title: '设置主页',
      description: '应用系统设置总览',
    ),
    'notification_settings': AppNavPageInfo(
      id: 'notification_settings',
      title: '通知提醒设置',
      description: '上课提醒、作业提醒与实况通知配置',
    ),
    'timetable_settings': AppNavPageInfo(
      id: 'timetable_settings',
      title: '课表设置',
      description: '课表自动同步与开学第一周周一指定',
    ),
    'appearance_settings': AppNavPageInfo(
      id: 'appearance_settings',
      title: '外观设置',
      description: '界面布局、首页按键与功能模块自定义',
    ),
    'language_settings': AppNavPageInfo(
      id: 'language_settings',
      title: '语言设置',
      description: '多语言与方言切换',
    ),
    'ai_settings': AppNavPageInfo(
      id: 'ai_settings',
      title: 'AI 助理设置',
      description: '大模型端点、API Key 与模型参数配置',
    ),
    'ai_memory': AppNavPageInfo(
      id: 'ai_memory',
      title: 'AI 记忆管理',
      description: '查看与管理 AI 沉淀的用户长期记忆',
    ),
    'data_sync_settings': AppNavPageInfo(
      id: 'data_sync_settings',
      title: '数据同步设置',
      description: '云端数据备份与恢复',
    ),
    'widget_settings': AppNavPageInfo(
      id: 'widget_settings',
      title: '桌面小组件设置',
      description: '桌面 Widget 快捷功能排序与配置',
    ),
    'button_reorder': AppNavPageInfo(
      id: 'button_reorder',
      title: '功能按键排序',
      description: '首页常用功能入口顺序调整',
    ),
    'timetable_subscription': AppNavPageInfo(
      id: 'timetable_subscription',
      title: '课表日历订阅',
      description: '课表 ICS 云端日历订阅链接管理',
    ),
    'about': AppNavPageInfo(
      id: 'about',
      title: '关于自在东湖',
      description: '应用版本信息、作者与项目简介',
    ),
    'oss_licenses': AppNavPageInfo(
      id: 'oss_licenses',
      title: '开源声明',
      description: '第三方开源组件许可证声明',
    ),
    'help_feedback': AppNavPageInfo(
      id: 'help_feedback',
      title: '帮助与反馈',
      description: '使用帮助、问题反馈与联系作者',
    ),
    'profile': AppNavPageInfo(
      id: 'profile',
      title: '个人中心',
      description: '个人资料与账户页面',
    ),
    'login': AppNavPageInfo(
      id: 'login',
      title: '登录',
      description: '统一身份认证登录界面',
    ),
  };

  /// 别名与中文词汇映射
  static const Map<String, String> _aliases = {
    // 首页
    'homepage': 'home',
    'main': 'home',
    'index': 'home',
    '首页': 'home',
    '主页': 'home',

    // 课表
    'schedule': 'timetable',
    'agenda': 'timetable',
    'course': 'timetable',
    'courses': 'timetable',
    '课表': 'timetable',
    '课程表': 'timetable',
    '查课表': 'timetable',

    // 作业
    'todo': 'homework',
    'todos': 'homework',
    'task': 'homework',
    'tasks': 'homework',
    '作业': 'homework',
    '待办': 'homework',
    '作业待办': 'homework',
    '做作业': 'homework',

    // 通知
    'notices': 'notice',
    'message': 'notice',
    'messages': 'notice',
    'notification': 'notice',
    'notifications': 'notice',
    '通知': 'notice',
    '消息': 'notice',
    '校园通知': 'notice',

    // 功能
    'workspace': 'functions',
    'function': 'functions',
    'tools': 'functions',
    'services': 'functions',
    '功能': 'functions',
    '功能页': 'functions',
    '工作台': 'functions',
    '服务': 'functions',

    // 核心业务
    'grades': 'score',
    'grade': 'score',
    'scores': 'score',
    '成绩': 'score',
    '查成绩': 'score',
    '成绩查询': 'score',

    'exams': 'exam',
    'exam_schedule': 'exam',
    '考试': 'exam',
    '考试安排': 'exam',
    '考试日程': 'exam',

    'classroom': 'empty_classroom',
    'classrooms': 'empty_classroom',
    'empty_classrooms': 'empty_classroom',
    '空教室': 'empty_classroom',
    '空教室查询': 'empty_classroom',
    '自习室': 'empty_classroom',

    'library_home': 'library',
    '图书馆': 'library',
    '图书': 'library',
    '借阅': 'library',
    '图书馆预约': 'library',

    'search_books': 'library_search',
    'book_search': 'library_search',
    'query_books': 'library_search',
    '图书检索': 'library_search',
    '查书': 'library_search',
    '搜索图书': 'library_search',

    'sunshine_service': 'sunshine',
    '阳光服务': 'sunshine',
    '阳光': 'sunshine',
    '诉求反馈': 'sunshine',
    '校长信箱': 'sunshine',

    'sunshine_form': 'sunshine_submit',
    '提交阳光服务': 'sunshine_submit',
    '提交诉求': 'sunshine_submit',
    '反馈诉求': 'sunshine_submit',
    '写信': 'sunshine_submit',

    'questionnaires': 'questionnaire',
    '问卷': 'questionnaire',
    '学工问卷': 'questionnaire',
    '问卷调查': 'questionnaire',

    'leaves': 'leave',
    '请假': 'leave',
    '请假申请': 'leave',
    '请假列表': 'leave',
    '假条': 'leave',

    'leave_form': 'leave_apply',
    '申请请假': 'leave_apply',
    '提交请假': 'leave_apply',
    '请假单': 'leave_apply',

    'repair': 'repairs',
    '报修': 'repairs',
    '报修平台': 'repairs',
    '后勤报修': 'repairs',
    '网络报修': 'repairs',

    '新建报修': 'repair_form',
    '提交报修': 'repair_form',
    '发起报修': 'repair_form',
    '我要报修': 'repair_form',

    'pay_code': 'payment_code',
    '付款码': 'payment_code',
    '校园码': 'payment_code',
    '乘车码': 'payment_code',
    '消费码': 'payment_code',

    'card_recharge': 'recharge',
    'campus_card_recharge': 'recharge',
    '充值': 'recharge',
    '校园卡充值': 'recharge',
    '一卡通充值': 'recharge',

    'ele_recharge': 'electricity_recharge',
    'electricity': 'electricity_recharge',
    '电费': 'electricity_recharge',
    '电费充值': 'electricity_recharge',
    '充电费': 'electricity_recharge',
    '宿舍电费': 'electricity_recharge',

    'transaction_history': 'transactions',
    'card_transactions': 'transactions',
    'bill': 'transactions',
    'bills': 'transactions',
    '校园卡账单': 'transactions',
    '校园卡流水': 'transactions',
    '一卡通账单': 'transactions',
    '流水': 'transactions',
    '消费记录': 'transactions',

    'my_dormitory': 'dormitory',
    '我的宿舍': 'dormitory',
    '宿舍': 'dormitory',
    '寝室': 'dormitory',

    'campus_bus': 'bus',
    '校车': 'bus',
    '实时校车': 'bus',
    '校园巴士': 'bus',

    'bus_route': 'campus_bus_route',
    '校内公交': 'campus_bus_route',
    '校内公交线路': 'campus_bus_route',
    '校车线路': 'campus_bus_route',

    'changsha_bus': 'cs_bus',
    '长沙公交': 'cs_bus',
    '长沙实时公交': 'cs_bus',
    '市公交': 'cs_bus',

    'webvpn': 'vpn',
    'vpn转换': 'vpn',
    'webvpn转换': 'vpn',

    '学工': 'xgxt',
    '学工系统': 'xgxt',

    '办事大厅': 'ehall',
    '一网通办': 'ehall',
    '网上办事大厅': 'ehall',

    '场馆': 'gym',
    '场馆预约': 'gym',
    '体育馆': 'gym',

    '体测': 'physical_test',
    '体测预约': 'physical_test',
    '体质测试': 'physical_test',
    '体测系统': 'physical_test',

    '教评': 'teaching_eval',
    '评教': 'teaching_eval',
    '教评系统': 'teaching_eval',

    '小程序': 'info_portal',
    '更多小程序': 'info_portal',

    '一校通': 'campus_card',
    '校园卡网站': 'campus_card',

    // 设置与个人
    'setting': 'settings',
    '设置': 'settings',
    '设置主页': 'settings',
    '系统设置': 'settings',

    'reminder_settings': 'notification_settings',
    '通知设置': 'notification_settings',
    '提醒设置': 'notification_settings',
    '课程提醒设置': 'notification_settings',

    '课表设置': 'timetable_settings',
    '课表同步设置': 'timetable_settings',

    'theme_settings': 'appearance_settings',
    '外观设置': 'appearance_settings',
    '主题设置': 'appearance_settings',
    '界面设置': 'appearance_settings',

    'language': 'language_settings',
    '语言设置': 'language_settings',
    '多语言设置': 'language_settings',
    '语言': 'language_settings',

    'agent_settings': 'ai_settings',
    'ai设置': 'ai_settings',
    'ai助理设置': 'ai_settings',
    'agent设置': 'ai_settings',
    '助理设置': 'ai_settings',

    'memory_settings': 'ai_memory',
    'ai记忆': 'ai_memory',
    '记忆管理': 'ai_memory',
    'ai记忆管理': 'ai_memory',
    '长期记忆': 'ai_memory',

    'sync_settings': 'data_sync_settings',
    'backup_settings': 'data_sync_settings',
    '数据同步': 'data_sync_settings',
    '数据同步设置': 'data_sync_settings',
    '云同步': 'data_sync_settings',
    '备份设置': 'data_sync_settings',

    'widget': 'widget_settings',
    '小组件设置': 'widget_settings',
    '桌面小组件': 'widget_settings',
    '桌面小组件设置': 'widget_settings',

    'reorder': 'button_reorder',
    '按键排序': 'button_reorder',
    '功能排序': 'button_reorder',
    '快捷按键': 'button_reorder',

    'subscription': 'timetable_subscription',
    '课表订阅': 'timetable_subscription',
    '日历订阅': 'timetable_subscription',
    '课表日历订阅': 'timetable_subscription',

    '关于': 'about',
    '关于我们': 'about',
    '关于自在东湖': 'about',

    'licenses': 'oss_licenses',
    '开源': 'oss_licenses',
    '开源声明': 'oss_licenses',
    '开源协议': 'oss_licenses',

    'feedback': 'help_feedback',
    '帮助': 'help_feedback',
    '反馈': 'help_feedback',
    '帮助与反馈': 'help_feedback',

    'mine': 'profile',
    'user': 'profile',
    '我的': 'profile',
    '个人主页': 'profile',
    '个人中心': 'profile',

    '登录': 'login',
    '重新登录': 'login',
    '切换账号': 'login',
  };

  /// 规格化页面标识
  static String? normalizePageId(String input) {
    final trimmed = input.trim().toLowerCase();
    if (pages.containsKey(trimmed)) return trimmed;
    if (_aliases.containsKey(trimmed)) return _aliases[trimmed];

    // 去除“页面”、“界面”、“列表”等常见中文后缀尝试二次匹配
    String cleanZh = trimmed
        .replaceAll('页面', '')
        .replaceAll('界面', '')
        .replaceAll('列表', '')
        .trim();
    if (cleanZh.isNotEmpty && _aliases.containsKey(cleanZh)) {
      return _aliases[cleanZh];
    }

    return null;
  }

  /// 获取页面信息
  static AppNavPageInfo? getPageInfo(String page) {
    final id = normalizePageId(page);
    return id != null ? pages[id] : null;
  }

  /// 获取所有可用页面列表
  static List<AppNavPageInfo> getAllPages() => pages.values.toList();

  /// 实例化对应页面的 Widget
  static Widget? createScreenWidget(String pageId,
      [Map<String, dynamic>? params]) {
    switch (pageId) {
      case 'home':
        return null;
      case 'timetable':
        return const TimetableScreen();
      case 'homework':
        return const HomeworkScreen();
      case 'notice':
        return const NoticeListScreen();
      case 'functions':
        return const FunctionsScreen();
      case 'score':
        return const ScoreScreen();
      case 'exam':
        return const ExamScreen();
      case 'empty_classroom':
        return const ClassroomInquiryScreen();
      case 'library':
        return const LibraryHomeScreen();
      case 'library_search':
        final keyword = params?['keyword'] as String?;
        return LibraryBookSearchScreen(initialKeyword: keyword);
      case 'sunshine':
        return const SunshineScreen();
      case 'sunshine_submit':
        return const SunshineFormScreen();
      case 'questionnaire':
        return const QuestionnaireListScreen();
      case 'leave':
        return const LeaveListScreen();
      case 'leave_apply':
        return const LeaveApplyScreen();
      case 'repairs':
        return const RepairScreen();
      case 'repair_form':
        return RepairFormScreen(catalog: RepairService.catalogs.first);
      case 'payment_code':
        return const PaymentCodeScreen();
      case 'recharge':
        return const CampusCardRechargeScreen();
      case 'electricity_recharge':
        return const ElectricityRechargeScreen();
      case 'transactions':
        return const TransactionHistoryScreen();
      case 'dormitory':
        return const DormitoryScreen();
      case 'bus':
        return const BusTrackingScreen();
      case 'campus_bus_route':
        return const CampusBusMapScreen();
      case 'cs_bus':
        return const WebViewDetailScreen(
          title: '长沙实时公交',
          url: AppConstants.changshaBusUrl,
          showWebBack: true,
          showAppBar: true,
          appBarColor: Color(0xFFF4F4F4),
        );
      case 'vpn':
        return const VpnConverterScreen();
      case 'xgxt':
        return const WebViewDetailScreen(
          title: '学工系统',
          url: AppConstants.xgxtWapUrl,
          showAppBar: false,
          showWebBack: false,
          appBarColor: Color(0xFF3C8DBC),
        );
      case 'ehall':
        return const WebViewDetailScreen(
          title: '办事大厅',
          url: AppConstants.ehallUrl,
          userAgent: AppConstants.ehallUA,
          showAppBar: false,
          showWebBack: false,
          appBarColor: Color(0xFF1E88E5),
        );
      case 'gym':
        return const WebViewDetailScreen(
          title: '场馆预约',
          url: AppConstants.gymReservationUrl,
          showWebBack: true,
        );
      case 'physical_test':
        return const WebViewDetailScreen(
          title: '体测预约',
          url: AppConstants.physicalTestReservationUrl,
          showWebBack: true,
        );
      case 'teaching_eval':
        return const WebViewDetailScreen(
          title: '教评系统',
          url: AppConstants.teachingEvalUrl,
          showAppBar: false,
          showWebBack: false,
          appBarColor: Colors.white,
        );
      case 'info_portal':
        return const WebViewDetailScreen(
          title: '更多小程序',
          url: AppConstants.infoPortalUrl,
          homeUrl: AppConstants.infoPortalUrl,
          userAgent: AppConstants.infoPortalUA,
          showAppBar: false,
          showWebBack: false,
          appBarColor: Colors.white,
          allowExternalLinks: true,
        );
      case 'campus_card':
        final url = CampusCardService().getCampusCardHomeUrl();
        return WebViewDetailScreen(
          title: '一校通',
          url: url,
          userAgent: AppConstants.campusCardUA,
          showWebBack: false,
          showAppBar: false,
          appBarColor: const Color(0xFF008268),
        );
      case 'settings':
        return const SettingsScreen();
      case 'notification_settings':
        return const NotificationSettingsScreen();
      case 'timetable_settings':
        return const TimetableSettingsScreen();
      case 'appearance_settings':
        return const AppearanceSettingsScreen();
      case 'language_settings':
        return const LanguageSettingsScreen();
      case 'ai_settings':
        return const AiSettingsScreen();
      case 'ai_memory':
        return const AiMemoryScreen();
      case 'data_sync_settings':
        return const DataSyncSettingsScreen();
      case 'widget_settings':
        return const ButtonReorderScreen(
          title: '桌面小组件设置',
          listType: 'widget',
        );
      case 'button_reorder':
        return const ButtonReorderScreen(
          title: '首页按键排序',
          listType: 'home',
        );
      case 'timetable_subscription':
        return const TimetableSubscriptionScreen();
      case 'about':
        return const AboutScreen();
      case 'oss_licenses':
        return const OssLicensesScreen();
      case 'help_feedback':
        return const HelpFeedbackScreen();
      case 'profile':
        return const ProfileScreen();
      case 'login':
        return const LoginScreen();
      default:
        return null;
    }
  }

  /// 执行打开页面逻辑
  static Future<bool> openPage(
    String page, {
    Map<String, dynamic>? params,
  }) async {
    final pageId = normalizePageId(page);
    if (pageId == null) return false;

    final info = pages[pageId];
    if (info == null) return false;

    // 1. 关闭 AI 模式悬浮层
    onCloseAiMode?.call();

    // 2. Tab 页面切换
    if (info.isTab && info.tabIndex != null) {
      final nav = navigatorKey.currentState;
      if (nav != null && nav.canPop()) {
        nav.popUntil((route) => route.isFirst);
      }
      onSwitchTab?.call(info.tabIndex!);
      return true;
    }

    // 3. 子页面推入
    final context = navigatorKey.currentContext;
    if (context != null) {
      final widget = createScreenWidget(pageId, params);
      if (widget != null) {
        Navigator.of(context).push(createSlideHorizontalRoute(widget));
        return true;
      }
    }

    // 环境中可能没有活动渲染 Context（如离线运行或单元测试），返回标识解析成功
    return true;
  }
}
