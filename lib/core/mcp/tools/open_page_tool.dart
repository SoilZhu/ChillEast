import '../../services/app_navigator.dart';
import '../models/mcp_tool.dart';

typedef PageNavigationHandler = Future<bool> Function(
  String page, {
  Map<String, dynamic>? params,
});

/// MCP Tool: 打开应用具体页面或切换 Tab (open_page)
class OpenPageTool {
  static const String toolName = 'open_page';

  static McpTool create({
    PageNavigationHandler? navigationHandler,
    String toolName = toolName,
  }) {
    final handlerFunc = navigationHandler ?? AppNavigator.openPage;

    return McpTool(
      name: toolName,
      description: '打开应用内的具体页面或切换 Tab。\n'
          '支持页面包括：\n'
          '- 底部 Tab：home(首页), timetable(课表), homework(作业待办), notice(通知), functions(功能页)\n'
          '- 核心功能：score(成绩查询), exam(考试安排), empty_classroom(空教室), library(图书馆), library_search(图书检索), sunshine(阳光服务), sunshine_submit(提交阳光服务), questionnaire(学工问卷), leave(请假申请), leave_apply(提交请假), repairs(报修平台), repair_form(提交报修), payment_code(付款码), recharge(校园卡充值), electricity_recharge(电费充值), transactions(校园卡账单流水), dormitory(我的宿舍), bus(实时校车), campus_bus_route(校内公交线路), cs_bus(长沙实时公交), vpn(WebVPN转换), xgxt(学工系统), ehall(办事大厅), gym(场馆预约), physical_test(体测预约), teaching_eval(教评系统), info_portal(更多小程序), campus_card(一校通)\n'
          '- 系统与设置：settings(设置主页), notification_settings(通知提醒设置), timetable_settings(课表设置), appearance_settings(外观设置), language_settings(语言设置), ai_settings(AI助理设置), ai_memory(AI记忆管理), data_sync_settings(数据同步设置), widget_settings(桌面小组件设置), button_reorder(按键排序), timetable_subscription(课表日历订阅), about(关于), oss_licenses(开源声明), help_feedback(帮助与反馈), profile(个人中心), login(登录)',
      inputSchema: {
        'type': 'object',
        'properties': {
          'page': {
            'type': 'string',
            'description':
                '要打开的页面或 Tab 标识符（中文或英文标识均可）。例如："score"、"library"、"electricity_recharge"、"timetable_settings"、"notification_settings"、"timetable"、"settings"等。',
          },
          'params': {
            'type': 'object',
            'description': '可选附加参数。例如图书检索关键词 {"keyword": "高等数学"}。',
          },
        },
        'required': ['page'],
      },
      handler: (arguments) async {
        final rawPage = arguments['page']?.toString().trim() ?? '';
        if (rawPage.isEmpty) {
          return McpToolResult.error('未指定要打开的页面标识或名称');
        }

        final rawParams = arguments['params'];
        final params =
            rawParams is Map ? Map<String, dynamic>.from(rawParams) : null;

        final info = AppNavigator.getPageInfo(rawPage);
        if (info == null) {
          final allPages = AppNavigator.getAllPages()
              .map((p) => '${p.id}(${p.title})')
              .join('、');
          return McpToolResult.error(
            '未知页面: "$rawPage"。\n支持的页面标识包括：\n$allPages',
          );
        }

        final success = await handlerFunc(rawPage, params: params);
        if (!success) {
          return McpToolResult.error('打开「${info.title}」页面失败，请稍后重试');
        }

        return McpToolResult.json({
          'success': true,
          'page': info.id,
          'title': info.title,
          'isTab': info.isTab,
          'message': '已成功打开「${info.title}」页面',
        });
      },
    );
  }
}
