import 'package:ChillEast/core/constants/app_constants.dart';
import 'package:ChillEast/core/services/home_widget_service.dart';
import 'package:ChillEast/features/profile/models/appearance_state.dart';
import 'package:ChillEast/features/profile/providers/appearance_provider.dart';
import 'package:ChillEast/features/workspace/screens/webview_detail_screen.dart';
import 'package:ChillEast/features/workspace/utils/info_portal_theme.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Info Portal Constants & Configuration Tests', () {
    test('AppConstants infoPortalUrl & infoPortalUA are correctly configured', () {
      expect(AppConstants.infoPortalUrl, equals('https://portal.hunau.edu.cn/ydd/microService2/toApps2'));
      expect(AppConstants.portalAppsUrl, equals('https://portal.hunau.edu.cn/ydd/microService2/toApps2'));
      expect(AppConstants.infoPortalUA, equals(AppConstants.campusCardUA));
    });

    test('Appearance models include info_portal in groupMiniApps', () {
      final miniAppGroup = functionGroups.firstWhere((g) => g.titleKey == 'groupMiniApps');
      expect(miniAppGroup.ids, contains('info_portal'));
    });

    test('AppearanceNotifier masterPool contains info_portal with correct attributes', () {
      final portalItem = AppearanceNotifier.masterPool.firstWhere((item) => item.id == 'info_portal');
      expect(portalItem.label, equals('更多小程序'));
      expect(portalItem.icon, equals(Icons.public_outlined));
      expect(portalItem.color, equals(const Color(0xFF1976D2)));
    });

    test('HomeWidgetService includes info_portal emoji, color, and allFunctionIds mapping', () {
      expect(HomeWidgetService.functionEmoji['info_portal'], equals('🌐'));
      expect(HomeWidgetService.functionColors['info_portal'], equals(0xFF1976D2));
      expect(HomeWidgetService.allFunctionIds, contains('info_portal'));
    });
  });

  group('Info Portal WebView Integration Tests', () {
    test('WebViewDetailScreen is instantiated with info_portal configuration', () {
      const screen = WebViewDetailScreen(
        title: '更多小程序',
        url: AppConstants.infoPortalUrl,
        homeUrl: AppConstants.infoPortalUrl,
        userAgent: AppConstants.infoPortalUA,
        showAppBar: false,
        showWebBack: false,
        appBarColor: Colors.white,
      );
      expect(screen.title, equals('更多小程序'));
      expect(screen.url, equals(AppConstants.infoPortalUrl));
      expect(screen.homeUrl, equals(AppConstants.infoPortalUrl));
      expect(screen.userAgent, equals(AppConstants.infoPortalUA));
      expect(screen.userAgent, equals(AppConstants.campusCardUA));
      expect(screen.showAppBar, isFalse);
      expect(screen.showWebBack, isFalse);
      expect(screen.appBarColor, equals(Colors.white));
    });

    test('WebViewDetailScreen.isToApps2Url correctly distinguishes info portal home vs subpages', () {
      // 首页精准匹配
      expect(WebViewDetailScreen.isToApps2Url(AppConstants.infoPortalUrl), isTrue);
      // 带 query 参数仍判定为首页
      expect(WebViewDetailScreen.isToApps2Url('https://portal.hunau.edu.cn/ydd/microService2/toApps2?ticket=ST-123456'), isTrue);
      // 带 hash 锚点仍判定为首页
      expect(WebViewDetailScreen.isToApps2Url('https://portal.hunau.edu.cn/ydd/microService2/toApps2#/home'), isTrue);
      // 带末尾斜杠仍判定为首页
      expect(WebViewDetailScreen.isToApps2Url('https://portal.hunau.edu.cn/ydd/microService2/toApps2/'), isTrue);

      // 其他微服务 / 子页面必须判定为非首页 (以触发左上角 [返回 | 首页] 胶囊)
      expect(WebViewDetailScreen.isToApps2Url('https://portal.hunau.edu.cn/ydd/microService2/toOtherApp'), isFalse);
      expect(WebViewDetailScreen.isToApps2Url('https://portal.hunau.edu.cn/ydd/microService/salary'), isFalse);
      expect(WebViewDetailScreen.isToApps2Url('https://xgxt.hunau.edu.cn/wap/main/welcome'), isFalse);
      expect(WebViewDetailScreen.isToApps2Url(null), isFalse);
      expect(WebViewDetailScreen.isToApps2Url(''), isFalse);
    });

    test('WebViewDetailScreen.resolveUserAgent accurately simulates campus card UA for info portal', () {
      // 显式指定 infoPortalUA 时，解析结果必须为 campusCardUA
      final resolvedWithExplicitUA = WebViewDetailScreen.resolveUserAgent(
        userAgent: AppConstants.infoPortalUA,
        url: AppConstants.infoPortalUrl,
      );
      expect(resolvedWithExplicitUA, equals(AppConstants.campusCardUA));

      // 未显式指定 userAgent 时，目标是 portal.hunau.edu.cn 也自动模拟为 campusCardUA
      final resolvedWithPortalUrl = WebViewDetailScreen.resolveUserAgent(
        url: AppConstants.infoPortalUrl,
      );
      expect(resolvedWithPortalUrl, equals(AppConstants.campusCardUA));

      // 校园卡页面未显式指定 userAgent 时，同样自动模拟为 campusCardUA
      final resolvedWithCampusCardUrl = WebViewDetailScreen.resolveUserAgent(
        url: AppConstants.campusCardUrl,
      );
      expect(resolvedWithCampusCardUrl, equals(AppConstants.campusCardUA));
    });
  });

  group('Info Portal MD2 Theme & Script Tests', () {
    test('InfoPortalTheme provides valid MD2 CSS with color tokens and component styling', () {
      expect(InfoPortalTheme.md2Css, isNotEmpty);
      expect(InfoPortalTheme.md2Css, contains('--md-primary: #09C489'));
      expect(InfoPortalTheme.md2Css, contains('.centerSearchBox'));
      expect(InfoPortalTheme.md2Css, contains('.applicationBox'));
      expect(InfoPortalTheme.md2Css, contains('.list'));
      expect(InfoPortalTheme.md2Css, contains('.item'));
      expect(InfoPortalTheme.md2Css, contains('.md2-ripple'));
      expect(InfoPortalTheme.md2Css, contains('.md2-fallback-icon'));
      expect(InfoPortalTheme.md2Css, contains('.md2-empty-state'));
      expect(InfoPortalTheme.md2Css, contains('grid-template-columns: repeat(2, 1fr)'));
      expect(InfoPortalTheme.md2Css, contains('height: 52px'));
      expect(InfoPortalTheme.md2Css, contains('border-radius: 8px'));
      expect(InfoPortalTheme.md2Css, contains('display: none !important;'));
      // 验证 CSS 中隐藏重合微服务选择器
      expect(InfoPortalTheme.md2Css, contains('6336614')); // 学工系统
      expect(InfoPortalTheme.md2Css, contains('4311705')); // 办事大厅
      expect(InfoPortalTheme.md2Css, contains('4311769')); // 成绩查询
    });

    test('InfoPortalTheme provides MD2 JS adapter with search filtering, hidden apps, and category rename', () {
      expect(InfoPortalTheme.md2Js, isNotEmpty);
      expect(InfoPortalTheme.md2Js, contains('MutationObserver'));
      expect(InfoPortalTheme.md2Js, contains('setupSearchEnhancement'));
      expect(InfoPortalTheme.md2Js, contains('setupImageFallback'));
      expect(InfoPortalTheme.md2Js, contains('attachRipple'));
      expect(InfoPortalTheme.md2Js, contains('filterApps'));
      // 验证 JS 中 HIDDEN_APPS 列表
      expect(InfoPortalTheme.md2Js, contains('学工系统'));
      expect(InfoPortalTheme.md2Js, contains('本科生公寓'));
      expect(InfoPortalTheme.md2Js, contains('办事大厅'));
      expect(InfoPortalTheme.md2Js, contains('教学评价平台'));
      expect(InfoPortalTheme.md2Js, contains('综合报修平台'));
      expect(InfoPortalTheme.md2Js, contains('成绩查询'));
      expect(InfoPortalTheme.md2Js, contains('课表查询'));
      expect(InfoPortalTheme.md2Js, contains('体育馆预约'));
      expect(InfoPortalTheme.md2Js, contains('馆藏查询'));
      expect(InfoPortalTheme.md2Js, contains('借阅记录'));
      // 验证“三方服务”改名为“校方服务”
      expect(InfoPortalTheme.md2Js, contains('三方服务'));
      expect(InfoPortalTheme.md2Js, contains('校方服务'));
    });

    test('InfoPortalTheme userScripts has CSS and JS injections configured', () {
      final scripts = InfoPortalTheme.userScripts;
      expect(scripts.length, equals(2));
      expect(scripts.first.injectionTime, equals(UserScriptInjectionTime.AT_DOCUMENT_START));
      expect(scripts.last.injectionTime, equals(UserScriptInjectionTime.AT_DOCUMENT_END));
    });
  });
}
