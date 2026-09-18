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
          {'ID': '12708', 'Title': '测试咨询', 'Status': '1', 'CirDepName': '测试单位'}),
      SunshineLetter.fromJson({'ID': '12692', 'Title': '测试建议', 'Status': '2'}),
    ];
  }

  SunshineTicketDetail? ticketDetailOverride;

  @override
  Future<SunshineTicketDetail> fetchTicketDetail(String id) async {
    if (fail) throw const SunshineException('测试加载失败');
    if (ticketDetailOverride != null) return ticketDetailOverride!;
    return SunshineTicketDetail(
      id: id,
      title: '巴士司机的驾驶素质',
      submitter: '郑',
      rawSubmitter: '郑天塬',
      expectedDepartment: '后勤保障中心',
      handlingDepartment: '保卫工作部、保卫处',
      finishTime: '2026-09-14',
      jieTime: '2026-09-16',
      wanTime: '2026-09-14',
      status: '2',
      content: '投诉9月10日11:50/11:55，修业广场偏金岸宿舍方向...',
      remark: '学校保卫工作部根据校园交通车考评管理办法，已对校园交通车负责人进行约谈...',
      type: '咨询',
    );
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
      await tester.tap(find.widgetWithText(InkWell, '已办结').first);
      await tester.pumpAndSettle();
      expect(find.text('测试咨询'), findsNothing);
      expect(find.text('测试建议'), findsOneWidget);
      await tester.tap(find.widgetWithText(InkWell, '办理中').first);
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

  testWidgets('tap letter card opens detail screen with submitter surname masked and clean UI',
      (tester) async {
    final service = FakeSunshineService();
    await mount(tester, service, const SunshineScreen());

    expect(find.text('测试建议'), findsOneWidget);

    // 点击诉求卡片
    await tester.tap(find.text('测试建议'));
    await tester.pumpAndSettle();

    // 验证进入诉求详情页
    expect(find.text('诉求详情'), findsOneWidget);
    expect(find.text('巴士司机的驾驶素质'), findsOneWidget);
    expect(find.text('已办结'), findsOneWidget);

    // 去掉《工单》两个字，只保留 #12692
    expect(find.text('#12692'), findsOneWidget);
    expect(find.textContaining('工单 #'), findsNothing);

    // 验证提交人只保留到姓（显示“郑”，不显示全名“郑天塬”）
    expect(find.text('郑'), findsOneWidget);
    expect(find.text('郑天塬'), findsNothing);

    // 验证流转信息与内容展示
    expect(find.text('后勤保障中心'), findsOneWidget);
    expect(find.text('保卫工作部、保卫处'), findsOneWidget);
    expect(find.textContaining('投诉9月10日11:50/11:55'), findsOneWidget);
    expect(find.textContaining('学校保卫工作部根据校园交通车考评管理办法'), findsOneWidget);

    // 流转信息无分割线 Divider
    expect(find.byType(Divider), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets('detail screen hides remark section when remark is empty',
      (tester) async {
    final service = FakeSunshineService()
      ..ticketDetailOverride = const SunshineTicketDetail(
        id: '12711',
        title: '军训服发放',
        submitter: '王',
        rawSubmitter: '王壹琢',
        expectedDepartment: '学生工作部、武装部',
        handlingDepartment: '学生工作部、武装部',
        finishTime: '2026-09-17',
        jieTime: '2026-09-18',
        status: '1',
        content: '已缴费无条子 处理慢 补交之后仍然要排长队...',
        remark: '',
        type: '建议',
      );
    await mount(tester, service, const SunshineScreen());

    // 点击未办结工单
    await tester.tap(find.text('测试咨询'));
    await tester.pumpAndSettle();

    expect(find.text('诉求详情'), findsOneWidget);
    expect(find.text('军训服发放'), findsOneWidget);
    expect(find.text('#12711'), findsOneWidget);
    expect(find.text('王'), findsOneWidget);
    expect(find.text('诉求内容'), findsOneWidget);

    // 如果没有处理结果就不显示
    expect(find.text('处理结果'), findsNothing);

    expect(tester.takeException(), isNull);
  });
}
