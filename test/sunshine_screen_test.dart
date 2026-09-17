import 'package:ChillEast/features/sunshine/models/sunshine_models.dart';
import 'package:ChillEast/features/sunshine/screens/sunshine_form_screen.dart';
import 'package:ChillEast/features/sunshine/screens/sunshine_screen.dart';
import 'package:ChillEast/features/sunshine/services/sunshine_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSunshineService extends SunshineService {
  int submissions = 0;
  bool fail = false;
  String result = '1';
  @override
  Future<SunshineStatistics> fetchStatistics() async {
    if (fail) throw const SunshineException('测试加载失败');
    return const SunshineStatistics('10', '2', '8');
  }

  @override
  Future<List<SunshineLetter>> fetchLetters() async {
    if (fail) throw const SunshineException('测试加载失败');
    return [
      SunshineLetter.fromJson(
          {'Title': '测试咨询', 'Status': '1', 'CirDepName': '测试单位'}),
      SunshineLetter.fromJson({'Title': '测试建议', 'Status': '2'}),
    ];
  }
  @override
  Future<SunshineFormData> fetchForm() async => const SunshineFormData(
        SunshineIdentity('test-card', '测试用户', '13800000000', ''),
        [SunshineDepartment('2', '测试单位')],
      );
  @override
  Future<String> submit(
      {required SunshineIdentity identity,
      required SunshineDepartment department,
      required String type,
      required String title,
      required String content,
      required String phone,
      required String email,
      required String finishTime}) async {
    submissions++;
    return result;
  }
}

void main() {
  Future<void> mount(
      WidgetTester tester, FakeSunshineService service, Widget screen,
      {bool dark = false}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [sunshineServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
          theme: ThemeData(
              useMaterial3: true,
              brightness: dark ? Brightness.dark : Brightness.light),
          home: screen),
    ));
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    testWidgets('dashboard filters letters (${dark ? 'dark' : 'light'})',
        (tester) async {
      await mount(tester, FakeSunshineService(), const SunshineScreen(),
          dark: dark);
      expect(find.text('填写诉求'), findsOneWidget);
      expect(find.text('近期公开诉求'), findsOneWidget);
      expect(find.text('测试咨询'), findsOneWidget);
      expect(find.text('测试建议'), findsOneWidget);
      await tester.tap(find.widgetWithText(InkWell, '已办结'));
      await tester.pumpAndSettle();
      expect(find.text('测试咨询'), findsNothing);
      expect(find.text('测试建议'), findsOneWidget);
      await tester.tap(find.widgetWithText(InkWell, '办理中'));
      await tester.pumpAndSettle();
      expect(find.text('测试咨询'), findsOneWidget);
      expect(find.text('测试建议'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('dashboard error is retryable', (tester) async {
    final service = FakeSunshineService()..fail = true;
    await mount(tester, service, const SunshineScreen());
    expect(find.text('测试加载失败'), findsOneWidget);
    service.fail = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('测试咨询'), findsOneWidget);
  });

  testWidgets('form validates, confirms, and locks an uncertain submission',
      (tester) async {
    final service = FakeSunshineService()..result = 'unknown';
    await mount(tester, service, const SunshineFormScreen());
    await tester.tap(find.byType(DropdownButtonFormField<SunshineDepartment>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('测试单位').last);
    await tester.pumpAndSettle();
    final title = find.widgetWithText(TextFormField, '主题 *');
    final content = find.widgetWithText(TextFormField, '内容 *');
    await tester.ensureVisible(title);
    await tester.enterText(title, '测试主题');
    await tester.ensureVisible(content);
    await tester.enterText(content, '测试内容');
    await tester.scrollUntilVisible(find.byType(Checkbox), 250,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable))
            .first);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pumpAndSettle();
    final submitBtn = find.widgetWithText(ElevatedButton, '提交');
    await tester.ensureVisible(submitBtn);
    await tester.pumpAndSettle();
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();
    expect(service.submissions, 0);
    expect(find.text('确认提交诉求'), findsOneWidget);
    await tester.tap(find.text('确认提交'));
    await tester.pumpAndSettle();
    expect(service.submissions, 1);
    expect(find.textContaining('暂时无法确认'), findsOneWidget);
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    expect(tester.widget<ElevatedButton>(submitBtn).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}
