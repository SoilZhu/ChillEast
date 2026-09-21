import 'package:flutter/material.dart';
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
  Future<void> pumpMenuOpener(WidgetTester tester) async {
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

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('停课'));
      await tester.pumpAndSettle();
      expect(find.text('指定节次'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('加课'));
      await tester.pumpAndSettle();
      expect(find.text('添加课程'), findsOneWidget);
      // 注：“我的调整”弹窗依赖真实磁盘存储，widget 环境不覆盖，
      // 其空态文案“还没有任何调整”仅做静态确认。
    });
  });
}
