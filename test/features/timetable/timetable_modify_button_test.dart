import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/features/timetable/models/course_model.dart';
import 'package:ChillEast/features/timetable/widgets/timetable_rule_dialogs.dart';

const _testCourses = [
  CourseModel(
    id: 'c1',
    name: '高等数学',
    teacher: '张老师',
    classroom: '十教南101',
    weeks: '1-16(周)',
    periods: '01-02',
    dayOfWeek: 1,
    startPeriod: 1,
    endPeriod: 2,
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late io.Directory tempDir;

  setUpAll(() async {
    tempDir = await io.Directory.systemTemp.createTemp('modify-button-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => tempDir.path);
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  Future<void> pumpMenuOpener(WidgetTester tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => tempDir.path);

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => TimetableRuleDialogs.showActionMenu(
                context: ctx,
                currentCourses: _testCourses,
                firstWeekMonday: DateTime(2026, 9, 7),
                onRuleApplied: () {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('Adjust timetable menu copy', () {
    testWidgets('shows header and 4 concise options', (tester) async {
      await pumpMenuOpener(tester);

      expect(find.text('调课'), findsOneWidget);
      expect(find.text('停课'), findsOneWidget);
      expect(find.text('加课'), findsOneWidget);
      expect(find.text('我的调整'), findsOneWidget);
      // 无标题、无箭头、无底框，图标为彩色圆
      expect(find.text('调整课表'), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });

    testWidgets('each option opens the matching dialog', (tester) async {
      await pumpMenuOpener(tester);

      await tester.tap(find.text('调课'));
      await tester.pumpAndSettle();
      expect(find.text('调一节'), findsOneWidget);
      expect(find.text('调一天'), findsOneWidget);

      // 切换到“调一天”模式
      await tester.tap(find.text('调一天'));
      await tester.pumpAndSettle();

      // 验证包含《复制》《平移》《对调》三个选项，且不再有旧开关“两天对调”
      expect(find.text('两天对调'), findsNothing);
      expect(find.text('复制'), findsOneWidget);
      expect(find.text('平移'), findsOneWidget);
      expect(find.text('对调'), findsOneWidget);

      // 默认平移
      expect(find.text('只把课挪过去，原日期的课不保留，目标日原本的课会被覆盖'), findsOneWidget);

      // 切换到复制
      await tester.tap(find.text('复制'));
      await tester.pumpAndSettle();
      expect(find.text('原日期的课保留，目标日原本的课会被覆盖'), findsOneWidget);

      // 切换到对调
      await tester.tap(find.text('对调'));
      await tester.pumpAndSettle();
      expect(find.text('两天的课程互相交换'), findsOneWidget);

      // 测试周次选择后再选择星期，周次不会跳回
      // 1. 打开原周次下拉菜单并选择第5周
      await tester.tap(find.widgetWithText(DropdownButtonFormField<int>, '原周次'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('第5周').last);
      await tester.pumpAndSettle();

      // 2. 打开原星期下拉菜单并选择周二
      await tester.tap(find.widgetWithText(DropdownButtonFormField<int>, '原星期'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('周二').last);
      await tester.pumpAndSettle();

      // 3. 验证原周次仍然保持为第5周，没有跳回去
      final sourceWeekDropdown = tester.widget<DropdownButtonFormField<int>>(
        find.widgetWithText(DropdownButtonFormField<int>, '原周次'),
      );
      expect(sourceWeekDropdown.initialValue, equals(5));

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('停课'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(DropdownButtonFormField<int>, '起始周'), findsOneWidget);
      expect(find.widgetWithText(DropdownButtonFormField<int>, '结束周'), findsOneWidget);
      expect(find.widgetWithText(DropdownButtonFormField<int>, '星期'), findsNWidgets(2));
      expect(find.text('指定节次'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('加课'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
    });

    testWidgets('all four dialogs have consistent width', (tester) async {
      await pumpMenuOpener(tester);

      // 1. 调课弹窗
      await tester.tap(find.text('调课'));
      await tester.pumpAndSettle();
      final rescheduleWidth = tester.getSize(find.byType(AlertDialog)).width;
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // 2. 停课弹窗
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('停课'));
      await tester.pumpAndSettle();
      final suspensionWidth = tester.getSize(find.byType(AlertDialog)).width;
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // 3. 加课弹窗
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('加课'));
      await tester.pumpAndSettle();
      final customCourseWidth = tester.getSize(find.byType(AlertDialog)).width;
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // 4. 我的调整弹窗
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => TimetableRuleDialogs.showRulesListDialog(
                  context: ctx,
                  onRuleApplied: () {},
                ),
                child: const Text('open_rules'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open_rules'));
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      final rulesListWidth = tester.getSize(find.byType(AlertDialog)).width;
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();

      // 验证四者宽度完全一致
      expect(suspensionWidth, equals(rescheduleWidth));
      expect(customCourseWidth, equals(rescheduleWidth));
      expect(rulesListWidth, equals(rescheduleWidth));
    });
  });
}
