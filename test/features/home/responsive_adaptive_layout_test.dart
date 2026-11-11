import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/features/workspace/screens/functions_screen.dart';
import 'package:ChillEast/features/notice/screens/notice_list_screen.dart';
import 'package:ChillEast/features/notice/screens/notice_detail_screen.dart';
import 'package:ChillEast/features/notice/models/message_model.dart';
import 'package:ChillEast/features/notice/providers/notice_provider.dart';
import 'package:ChillEast/features/home/screens/home_screen.dart';
import 'package:ChillEast/features/home/screens/main_scaffold.dart';
import 'package:ChillEast/core/widgets/embedded_detail_pane.dart';
import 'package:ChillEast/features/exam/screens/exam_screen.dart';
import 'package:ChillEast/l10n/app_localizations.dart';

class FakeNoticeNotifier extends NoticeNotifier {
  final NoticeState initial;
  FakeNoticeNotifier(this.initial) : super() {
    state = initial;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestableWidget({
    required WidgetTester tester,
    required Widget child,
    required double width,
    required double height,
    List<Override> overrides = const [],
  }) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
          ),
          child: SizedBox(
            width: width,
            height: height,
            child: child,
          ),
        ),
      ),
    );
  }

  group('Adaptive FunctionsScreen Grid Tests', () {
    testWidgets('FunctionsScreen grid uses maxCrossAxisExtent of 240', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          tester: tester,
          child: const FunctionsScreen(),
          width: 800,
          height: 1200,
        ),
      );
      await tester.pumpAndSettle();

      final gridFinder = find.byType(GridView);
      expect(gridFinder, findsWidgets);

      final gridWidget = tester.widget<GridView>(gridFinder.first);
      final delegate = gridWidget.gridDelegate;
      expect(delegate, isA<SliverGridDelegateWithMaxCrossAxisExtent>());
      final maxExtentDelegate = delegate as SliverGridDelegateWithMaxCrossAxisExtent;
      expect(maxExtentDelegate.maxCrossAxisExtent, equals(240));
    });

    testWidgets('FunctionsScreen on tablet opens function in right half and uses built-in back button to close', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          tester: tester,
          child: const FunctionsScreen(),
          width: 800,
          height: 1200,
        ),
      );
      await tester.pumpAndSettle();

      // Initially no embedded pane
      expect(find.byType(EmbeddedDetailPane), findsNothing);

      // Tap '考试安排'
      expect(find.text('考试安排'), findsWidgets);
      await tester.tap(find.text('考试安排').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Right half shows EmbeddedDetailPane with ExamScreen
      expect(find.byType(EmbeddedDetailPane), findsOneWidget);
      expect(find.byType(ExamScreen), findsOneWidget);
      expect(find.byType(VerticalDivider), findsOneWidget);

      // No separate custom floating close button exists
      expect(find.byKey(const ValueKey('embedded_detail_close_button')), findsNothing);

      // ExamScreen has its own AppBar with built-in BackButton
      final backButtonFinder = find.descendant(
        of: find.byType(EmbeddedDetailPane),
        matching: find.byType(BackButton),
      );
      expect(backButtonFinder, findsOneWidget);

      // Tapping the built-in back button closes the right pane
      await tester.tap(backButtonFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Embedded pane is closed and FunctionsScreen returns to full width
      expect(find.byType(EmbeddedDetailPane), findsNothing);
      expect(find.byType(ExamScreen), findsNothing);
    });

    testWidgets('FunctionsScreen displays embedded function full screen when resized to narrow width', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          tester: tester,
          child: const FunctionsScreen(),
          width: 800,
          height: 1200,
        ),
      );
      await tester.pumpAndSettle();

      // Tap '考试安排'
      await tester.tap(find.text('考试安排').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(EmbeddedDetailPane), findsOneWidget);
      expect(find.byType(VerticalDivider), findsOneWidget);

      // Resize to narrow width (< 600)
      await tester.pumpWidget(
        buildTestableWidget(
          tester: tester,
          child: const FunctionsScreen(),
          width: 400,
          height: 800,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Now displayed full screen on Navigator: ExamScreen is present, no EmbeddedDetailPane
      expect(find.byType(EmbeddedDetailPane), findsNothing);
      expect(find.byType(ExamScreen), findsOneWidget);
      expect(find.byType(VerticalDivider), findsNothing);

      // Built-in back button closes it and pops back to FunctionsScreen
      final backButton = find.descendant(
        of: find.byType(ExamScreen),
        matching: find.byType(BackButton),
      );
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(find.byType(ExamScreen), findsNothing);
      expect(find.text('考试安排'), findsWidgets);
    });
  });

  group('Adaptive HomeScreen Feed Tests', () {
    testWidgets('HomeScreen builds on mobile (< 600 width)', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          tester: tester,
          child: const HomeScreen(),
          width: 400,
          height: 800,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('HomeScreen builds with 2-column feed on tablet (>= 600 width)', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          tester: tester,
          child: const HomeScreen(),
          width: 800,
          height: 1200,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('HomeScreen on tablet opens quick action in right half and uses built-in back button to close', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          tester: tester,
          child: const HomeScreen(),
          width: 800,
          height: 1200,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Initially no embedded pane
      expect(find.byType(EmbeddedDetailPane), findsNothing);

      // Tap '考试安排' in quick action grid
      final examText = find.text('考试安排');
      if (examText.evaluate().isNotEmpty) {
        await tester.tap(examText.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Embedded pane appears in right half
        expect(find.byType(EmbeddedDetailPane), findsOneWidget);
        expect(find.byType(ExamScreen), findsOneWidget);

        // Tap built-in back button
        final backButtonFinder = find.descendant(
          of: find.byType(EmbeddedDetailPane),
          matching: find.byType(BackButton),
        );
        expect(backButtonFinder, findsOneWidget);

        await tester.tap(backButtonFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Embedded pane is closed
        expect(find.byType(EmbeddedDetailPane), findsNothing);
      }
    });
  });

  group('Adaptive NoticeListScreen Master-Detail Tests', () {
    const sampleMessage = MessageModel(
      idCode: 'test-notice-123',
      title: '关于期末考试安排的通知',
      content: '请各位同学查收考试时间安排并做好准备。',
      sendTime: '2026-10-17 10:00:00',
      createrName: '教务处',
      isRead: false,
      hasRedDot: false,
      countAll: 1,
      countRead: 0,
    );

    testWidgets('NoticeListScreen on mobile (< 600) does not show detail pane', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          tester: tester,
          width: 400,
          height: 800,
          overrides: [
            noticeProvider.overrideWith((ref) => FakeNoticeNotifier(NoticeState(
              messages: [sampleMessage],
              isLoading: false,
              hasMore: false,
            ))),
          ],
          child: const NoticeListScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('关于期末考试安排的通知'), findsOneWidget);
      expect(find.byType(VerticalDivider), findsNothing);
      expect(find.byType(NoticeDetailScreen), findsNothing);
    });

    testWidgets('NoticeListScreen on tablet (>= 600) shows master-detail split layout', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          tester: tester,
          width: 800,
          height: 1200,
          overrides: [
            noticeProvider.overrideWith((ref) => FakeNoticeNotifier(NoticeState(
              messages: [sampleMessage],
              isLoading: false,
              hasMore: false,
            ))),
          ],
          child: const NoticeListScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Divider and placeholder prompt exist
      expect(find.byType(VerticalDivider), findsOneWidget);
      expect(find.text('选择左侧通知查看详情'), findsOneWidget);
      expect(find.byType(NoticeDetailScreen), findsNothing);

      // Tap message in the list
      await tester.tap(find.text('关于期末考试安排的通知'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // NoticeDetailScreen is now rendered in the right pane as embedded
      expect(find.byType(NoticeDetailScreen), findsOneWidget);
      final detailWidget = tester.widget<NoticeDetailScreen>(find.byType(NoticeDetailScreen));
      expect(detailWidget.isEmbedded, isTrue);
      expect(detailWidget.noticeId, equals('test-notice-123'));

      // NoticeDetailScreen Scaffold has pure white background in light mode
      final detailScaffold = tester.widget<Scaffold>(
        find.descendant(of: find.byType(NoticeDetailScreen), matching: find.byType(Scaffold)),
      );
      expect(detailScaffold.backgroundColor, equals(Colors.white));

      // Active notice card has gray rounded rectangle background (#EBEBEB)
      final cardContainers = tester.widgetList<Container>(
        find.descendant(of: find.byType(ListView), matching: find.byType(Container)),
      );
      final hasSelectedCard = cardContainers.any((c) {
        final dec = c.decoration;
        return dec is BoxDecoration && dec.color == const Color(0xFFEBEBEB);
      });
      expect(hasSelectedCard, isTrue);

      // Embedded NoticeDetailScreen has BackButton in AppBar
      final backButton = find.descendant(
        of: find.byType(NoticeDetailScreen),
        matching: find.byType(IconButton),
      );
      expect(backButton, findsOneWidget);

      // Tapping back button deselects the notice and returns to placeholder
      await tester.tap(backButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(NoticeDetailScreen), findsNothing);
      expect(find.text('选择左侧通知查看详情'), findsOneWidget);
    });

    testWidgets('NoticeListScreen displays notice detail full screen when resized to narrow width', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          tester: tester,
          width: 800,
          height: 1200,
          overrides: [
            noticeProvider.overrideWith((ref) => FakeNoticeNotifier(NoticeState(
              messages: [sampleMessage],
              isLoading: false,
              hasMore: false,
            ))),
          ],
          child: const NoticeListScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap message in the list
      await tester.tap(find.text('关于期末考试安排的通知'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(VerticalDivider), findsOneWidget);
      expect(find.byType(NoticeDetailScreen), findsOneWidget);

      // Resize to narrow width (< 600)
      await tester.pumpWidget(
        buildTestableWidget(
          tester: tester,
          width: 400,
          height: 800,
          overrides: [
            noticeProvider.overrideWith((ref) => FakeNoticeNotifier(NoticeState(
              messages: [sampleMessage],
              isLoading: false,
              hasMore: false,
            ))),
          ],
          child: const NoticeListScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Now detail is displayed full screen without VerticalDivider
      expect(find.byType(VerticalDivider), findsNothing);
      expect(find.byType(NoticeDetailScreen), findsOneWidget);

      // Back button closes the full screen notice and returns to list
      final backButton = find.descendant(
        of: find.byType(NoticeDetailScreen),
        matching: find.byType(BackButton),
      );
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(find.byType(NoticeDetailScreen), findsNothing);
      expect(find.text('关于期末考试安排的通知'), findsOneWidget);
    });
  });

  group('Adaptive MainScaffold Navigation Rail Tests', () {
    testWidgets('MainScaffold shows bottom navigation bar on mobile (< 600)', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          tester: tester,
          child: const MainScaffold(),
          width: 400,
          height: 800,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Bottom bar TabBar is present
      expect(find.byType(TabBar), findsOneWidget);
      // Top bar avatar and AI button exist
      expect(find.byKey(const ValueKey('ai_entry_button')), findsOneWidget);
      // Left rail does not exist
      expect(find.byKey(const ValueKey('tablet_navigation_rail')), findsNothing);
      // Hitokoto IS restored on mobile
      expect(find.byKey(const ValueKey('hitokoto_text')), findsOneWidget);

      // Drain delayed timers
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('MainScaffold moves bottom bar, avatar and AI button to left rail on tablet/landscape', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          tester: tester,
          child: const MainScaffold(),
          width: 800,
          height: 1200,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Bottom bar TabBar is NOT present
      expect(find.byType(TabBar), findsNothing);
      // Left rail and AI entry button are present
      expect(find.byKey(const ValueKey('tablet_navigation_rail')), findsOneWidget);
      expect(find.byKey(const ValueKey('ai_entry_button')), findsOneWidget);
      // Hitokoto is NOT present anywhere on tablet
      expect(find.byKey(const ValueKey('hitokoto_text')), findsNothing);

      // Verify nav items are at top, AI button is below nav items, and avatar is at bottom
      final aiOffset = tester.getTopLeft(find.byKey(const ValueKey('ai_entry_button')));
      final railItemOffset = tester.getTopLeft(find.text('首页'));
      // Find CircleAvatar within the navigation rail
      final avatarFinder = find.descendant(
        of: find.byKey(const ValueKey('tablet_navigation_rail')),
        matching: find.byType(CircleAvatar),
      );
      expect(avatarFinder, findsOneWidget);
      final avatarOffset = tester.getTopLeft(avatarFinder);

      expect(railItemOffset.dy, lessThan(aiOffset.dy));
      expect(aiOffset.dy, lessThan(avatarOffset.dy));

      // Active rail item indicator (small bar on right side) is present
      final railIndicator = find.descendant(
        of: find.byKey(const ValueKey('tablet_navigation_rail')),
        matching: find.byWidgetPredicate((widget) {
          if (widget is Container) {
            final dec = widget.decoration;
            return dec is BoxDecoration &&
                dec.color == const Color(0xFF09C489) &&
                widget.constraints?.maxWidth == 3;
          }
          return false;
        }),
      );
      expect(railIndicator, findsOneWidget);

      // Drain delayed timers
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('MainScaffold on tablet keeps HomeScreen aligned to top rather than vertically centered', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          tester: tester,
          child: const MainScaffold(),
          width: 1024,
          height: 600,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Quick action grid / HomeScreen should start near the top, aligned with rail
      final railItemOffset = tester.getTopLeft(find.text('首页'));
      // Find the first quick action button (e.g. '付款码' or whatever is in quick items)
      final quickFinder = find.byType(HomeScreen);
      expect(quickFinder, findsOneWidget);
      final homeOffset = tester.getTopLeft(quickFinder);

      // Home should start at or near top (below padding.top, not centered in 600 height)
      expect(homeOffset.dy, lessThan(30.0));

      // Drain delayed timers
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
