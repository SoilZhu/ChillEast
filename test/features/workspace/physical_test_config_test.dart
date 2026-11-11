import 'package:ChillEast/core/constants/app_constants.dart';
import 'package:ChillEast/core/mcp/tools/open_page_tool.dart';
import 'package:ChillEast/core/services/app_navigator.dart';
import 'package:ChillEast/core/services/home_widget_service.dart';
import 'package:ChillEast/features/profile/models/appearance_state.dart';
import 'package:ChillEast/features/profile/providers/appearance_provider.dart';
import 'package:ChillEast/features/workspace/screens/webview_detail_screen.dart';
import 'package:ChillEast/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Physical Test Constants & Configuration Tests', () {
    test(
        'AppConstants physicalTestReservationUrl and physicalTestUrl are configured correctly',
        () {
      expect(
        AppConstants.physicalTestReservationUrl,
        equals('http://ndtzcs.hunau.edu.cn/wxlogin?method=login'),
      );
      expect(
        AppConstants.physicalTestUrl,
        equals(AppConstants.physicalTestReservationUrl),
      );
    });

    test('Appearance models include physical_test in groupMiniApps', () {
      final miniAppGroup =
          functionGroups.firstWhere((g) => g.titleKey == 'groupMiniApps');
      expect(miniAppGroup.ids, contains('physical_test'));
    });

    test(
        'AppearanceNotifier masterPool contains physical_test with correct attributes',
        () {
      final item = AppearanceNotifier.masterPool
          .firstWhere((i) => i.id == 'physical_test');
      expect(item.label, equals('体测预约'));
      expect(item.icon, equals(Icons.directions_run_outlined));
      expect(item.color, equals(const Color(0xFFFF5722)));
    });

    test(
        'HomeWidgetService includes physical_test emoji, color, and allFunctionIds mapping',
        () {
      expect(HomeWidgetService.allFunctionIds, contains('physical_test'));
      expect(HomeWidgetService.functionEmoji['physical_test'], equals('🏃'));
      expect(HomeWidgetService.functionColors['physical_test'],
          equals(0xFFFF5722));
    });
  });

  group('Physical Test AppNavigator & MCP Tests', () {
    test('AppNavigator registers physical_test page info and aliases', () {
      final pageInfo = AppNavigator.getPageInfo('physical_test');
      expect(pageInfo, isNotNull);
      expect(pageInfo!.title, equals('体测预约'));

      expect(AppNavigator.normalizePageId('体测'), equals('physical_test'));
      expect(AppNavigator.normalizePageId('体测预约'), equals('physical_test'));
      expect(AppNavigator.normalizePageId('体质测试'), equals('physical_test'));
    });

    test('AppNavigator builds correct WebViewDetailScreen for physical_test',
        () {
      final widget = AppNavigator.createScreenWidget('physical_test');
      expect(widget, isA<WebViewDetailScreen>());
      final webView = widget as WebViewDetailScreen;
      expect(webView.title, equals('体测预约'));
      expect(webView.url, equals(AppConstants.physicalTestReservationUrl));
      expect(webView.showWebBack, isTrue);
    });

    test('OpenPageTool MCP tool description and handler support physical_test',
        () async {
      final tool = OpenPageTool.create();
      expect(tool.description, contains('physical_test(体测预约)'));

      String? openedPage;
      final mockTool = OpenPageTool.create(
        navigationHandler: (page, {params}) async {
          openedPage = page;
          return true;
        },
      );

      final result = await mockTool.execute({'page': '体测预约'});
      expect(result.isError, isFalse);
      expect(openedPage, equals('体测预约'));
      final text = result.content.first.text ?? '';
      expect(text, contains('体测预约'));
      expect(text, contains('physical_test'));
    });
  });

  group('Physical Test Localization & UI Tests', () {
    testWidgets(
        'FunctionItemLocalization resolves localized title for physical_test',
        (tester) async {
      late String resolvedZh;
      late String resolvedEn;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Builder(
            builder: (context) {
              const item = FunctionItem(
                id: 'physical_test',
                label: '体测预约',
                icon: Icons.directions_run_outlined,
                color: Color(0xFFFF5722),
              );
              resolvedZh = item.getLocalizedTitle(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolvedZh, equals('体测预约'));

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              const item = FunctionItem(
                id: 'physical_test',
                label: '体测预约',
                icon: Icons.directions_run_outlined,
                color: Color(0xFFFF5722),
              );
              resolvedEn = item.getLocalizedTitle(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolvedEn, equals('Physical Test Booking'));
    });
  });
}
