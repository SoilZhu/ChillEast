import 'package:ChillEast/core/constants/app_constants.dart';
import 'package:ChillEast/core/services/home_widget_service.dart';
import 'package:ChillEast/features/profile/models/appearance_state.dart';
import 'package:ChillEast/features/profile/providers/appearance_provider.dart';
import 'package:ChillEast/features/workspace/screens/webview_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Ehall Constants & Configuration Tests', () {
    test('AppConstants ehallUrl & ehallUA are correctly configured', () {
      expect(AppConstants.ehallUrl, contains('auth.chaoxing.com/connect/oauth2/authorize'));
      expect(AppConstants.ehallUrl, contains('redirect_uri=https%3A%2F%2Fehall.hunau.edu.cn'));
      expect(AppConstants.ehallUA, contains('ChaoXingStudy'));
    });

    test('Appearance models include ehall in groupMiniApps', () {
      final miniAppGroup = functionGroups.firstWhere((g) => g.titleKey == 'groupMiniApps');
      expect(miniAppGroup.ids, contains('ehall'));
    });

    test('AppearanceNotifier masterPool contains ehall with correct attributes', () {
      final ehallItem = AppearanceNotifier.masterPool.firstWhere((item) => item.id == 'ehall');
      expect(ehallItem.label, equals('办事大厅'));
      expect(ehallItem.icon, equals(Icons.account_balance_outlined));
      expect(ehallItem.color, equals(const Color(0xFF1E88E5)));
    });

    test('HomeWidgetService includes ehall emoji and color mapping', () {
      expect(HomeWidgetService.functionEmoji['ehall'], equals('🏛️'));
      expect(HomeWidgetService.functionColors['ehall'], equals(0xFF1E88E5));
      expect(HomeWidgetService.allFunctionIds, contains('ehall'));
    });
  });

  group('Ehall WebView Integration Tests', () {
    test('WebViewDetailScreen is instantiated with ehall configuration', () {
      const screen = WebViewDetailScreen(
        title: '办事大厅',
        url: AppConstants.ehallUrl,
        userAgent: AppConstants.ehallUA,
        showAppBar: false,
        showWebBack: false,
        appBarColor: Color(0xFF1E88E5),
      );
      expect(screen.title, equals('办事大厅'));
      expect(screen.url, equals(AppConstants.ehallUrl));
      expect(screen.userAgent, equals(AppConstants.ehallUA));
      expect(screen.showAppBar, isFalse);
      expect(screen.showWebBack, isFalse);
      expect(screen.appBarColor, equals(const Color(0xFF1E88E5)));
    });
  });
}
