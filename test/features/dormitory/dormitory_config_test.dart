import 'package:ChillEast/core/constants/app_constants.dart';
import 'package:ChillEast/core/services/home_widget_service.dart';
import 'package:ChillEast/features/profile/models/appearance_state.dart';
import 'package:ChillEast/features/profile/providers/appearance_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Dormitory Configuration & Registration Tests', () {
    test('AppConstants dormitory URLs and UA are correctly configured', () {
      expect(AppConstants.dormitoryOAuthUrl,
          contains('auth.chaoxing.com/connect/oauth2/authorize'));
      expect(AppConstants.dormitoryOAuthUrl,
          contains('redirect_uri=https%3A%2F%2Fgy.hunau.edu.cn'));
      expect(AppConstants.dormitoryBedUrl,
          contains('gy.hunau.edu.cn/wap/menu/gygl/ssap/client/stu/wyDorm'));
      expect(AppConstants.dormitoryWelcomeUrl,
          equals('https://gy.hunau.edu.cn/wap/main/welcome'));
      expect(AppConstants.dormitoryUA, contains('ChaoXingStudy'));
    });

    test('groupLife includes dormitory in functionGroups', () {
      final lifeGroup =
          functionGroups.firstWhere((g) => g.titleKey == 'groupLife');
      expect(lifeGroup.ids, contains('dormitory'));
    });

    test('AppearanceNotifier masterPool contains dormitory with correct attributes',
        () {
      final item =
          AppearanceNotifier.masterPool.firstWhere((i) => i.id == 'dormitory');
      expect(item.label, equals('我的宿舍'));
      expect(item.icon, equals(Icons.hotel_outlined));
      expect(item.color, equals(const Color(0xFF5C6BC0)));
    });

    test('HomeWidgetService includes dormitory id, emoji and color', () {
      expect(HomeWidgetService.allFunctionIds, contains('dormitory'));
      expect(HomeWidgetService.functionEmoji['dormitory'], equals('🛏️'));
      expect(HomeWidgetService.functionColors['dormitory'], equals(0xFF5C6BC0));
    });
  });
}
