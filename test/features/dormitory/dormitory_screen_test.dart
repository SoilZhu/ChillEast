import 'package:ChillEast/features/dormitory/models/dormitory_info.dart';
import 'package:ChillEast/features/dormitory/screens/dormitory_screen.dart';
import 'package:ChillEast/features/dormitory/services/dormitory_service.dart';
import 'package:ChillEast/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeDormitoryService extends DormitoryService {
  final DormitoryInfo stubInfo;

  FakeDormitoryService(this.stubInfo);

  @override
  Future<DormitoryInfo?> getCachedDormitoryInfo() async => stubInfo;

  @override
  Future<DormitoryInfo> fetchDormitoryInfo({bool forceRefresh = false}) async =>
      stubInfo;
}

void main() {
  group('DormitoryScreen Widget Tests (MD2 Style)', () {
    testWidgets('Renders only 宿舍楼, 楼层, 宿舍, 床号 without web portal', (tester) async {
      const stubInfo = DormitoryInfo(
        isAssigned: true,
        building: '金岸1栋',
        floor: '第6层',
        room: '629',
        bed: '4',
        academicYear: '2026',
        termCode: '1',
        termName: '秋季学期',
        fields: [
          DormitoryField(code: 'ssl', label: '宿舍楼', value: '金岸1栋'),
          DormitoryField(code: 'lc', label: '楼层', value: '第6层'),
          DormitoryField(code: 'fj', label: '宿舍', value: '629'),
          DormitoryField(code: 'ch', label: '床号', value: '4'),
        ],
      );

      final fakeService = FakeDormitoryService(stubInfo);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dormitoryServiceProvider.overrideWithValue(fakeService),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('zh'),
            home: DormitoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Title
      expect(find.text('我的宿舍'), findsOneWidget);

      // The 4 required fields
      expect(find.text('宿舍楼'), findsOneWidget);
      expect(find.text('金岸1栋'), findsOneWidget);

      expect(find.text('楼层'), findsOneWidget);
      expect(find.text('第6层'), findsOneWidget);

      expect(find.text('宿舍'), findsOneWidget);
      expect(find.text('629'), findsOneWidget);

      expect(find.text('床号'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);

      // Verify no web portal or other non-requested items
      expect(find.text('学生公寓平台'), findsNothing);
      expect(find.text('秋季学期'), findsNothing);
      expect(find.text('2026'), findsNothing);
    });

    testWidgets('Adapts to dark mode properly', (tester) async {
      const stubInfo = DormitoryInfo(
        isAssigned: true,
        building: '金岸1栋',
        floor: '第6层',
        room: '629',
        bed: '4',
      );

      final fakeService = FakeDormitoryService(stubInfo);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dormitoryServiceProvider.overrideWithValue(fakeService),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: const DormitoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('我的宿舍'), findsOneWidget);
      expect(find.text('金岸1栋'), findsOneWidget);
      expect(find.text('第6层'), findsOneWidget);
      expect(find.text('629'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });
  });
}
