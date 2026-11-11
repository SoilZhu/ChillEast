import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/features/exam/models/exam_schedule_model.dart';
import 'package:ChillEast/features/exam/providers/exam_provider.dart';
import 'package:ChillEast/features/exam/services/exam_storage.dart';
import 'package:ChillEast/features/exam/screens/exam_screen.dart';
import 'package:ChillEast/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ExamStorage & Provider Tests', () {
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp('exam_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('ExamStorage persists and restores exam list correctly', () async {
      final storage = ExamStorage(baseDirectory: tempDir);
      final futureDate = DateTime.now().add(const Duration(days: 10));
      final exams = [
        ExamScheduleModel(
          id: '10762596',
          title: '补考试题',
          time: futureDate,
          allTimes: [
            futureDate,
            futureDate.add(const Duration(minutes: 30)),
          ],
          rawTimeStrs: [
            DateFormat('yyyy-MM-dd HH:mm').format(futureDate),
            DateFormat('yyyy-MM-dd HH:mm').format(futureDate.add(const Duration(minutes: 30))),
          ],
          status: '已完成',
        ),
      ];

      await storage.saveExamList(exams);
      final loaded = await storage.readExamList();
      expect(loaded.length, equals(1));
      expect(loaded.first.id, equals('10762596'));
      expect(loaded.first.title, equals('补考试题'));
      // 时间显示为第一个出现的时间
      expect(loaded.first.time, equals(futureDate));

      // 验证过期 ID 集合存储
      await storage.saveExpiredExamIds({'10762596', '9473825'});
      final expired = await storage.readExpiredExamIds();
      expect(expired, contains('10762596'));
      expect(expired, contains('9473825'));

      // 验证删除
      await storage.deleteExamList();
      final afterDelete = await storage.readExamList();
      expect(afterDelete, isEmpty);
    });

    test('ExamScheduleModel supports manual exams, location and remarks', () async {
      final storage = ExamStorage(baseDirectory: tempDir);
      final exam = ExamScheduleModel(
        id: 'manual_123456',
        title: '大学英语期末口语考试',
        courseName: '大学英语',
        time: DateTime(2026, 11, 20, 14, 30),
        status: '待考',
        isManual: true,
        location: '文科楼402',
        remarks: '自带准考证和学生证',
      );

      await storage.saveExamList([exam]);
      final loaded = await storage.readExamList();
      expect(loaded.length, equals(1));
      expect(loaded.first.isManual, isTrue);
      expect(loaded.first.location, equals('文科楼402'));
      expect(loaded.first.remarks, equals('自带准考证和学生证'));
      expect(loaded.first.courseName, equals('大学英语'));
    });

    testWidgets('Renders upcoming exam card with first occurrence time', (tester) async {
      final mockExam = ExamScheduleModel(
        id: '9473825',
        title: '26年春形策期末考试',
        time: DateTime(2026, 5, 10, 17, 0),
        allTimes: [
          DateTime(2026, 5, 10, 17, 0),
          DateTime(2026, 5, 10, 23, 59),
        ],
        rawTimeStrs: ['2026-05-10 17:00', '2026-05-10 23:59'],
        status: '未交',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            examProvider.overrideWith((ref) => _MockExamNotifier(ref, [mockExam])),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  final timeStr = DateFormat('HH:mm').format(mockExam.time!);
                  return Column(
                    children: [
                      Text(mockExam.title),
                      Text('考试时间: $timeStr'),
                      Text(mockExam.status),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('26年春形策期末考试'), findsOneWidget);
      expect(find.text('考试时间: 17:00'), findsOneWidget);
      expect(find.text('未交'), findsOneWidget);
    });

    testWidgets('ExamScreen renders AppBar with plus button and shows exam cards', (tester) async {
      final mockExam = ExamScheduleModel(
        id: 'manual_999',
        title: '编译原理期末考',
        courseName: '编译原理',
        time: DateTime.now().add(const Duration(days: 3)),
        status: '待考',
        isManual: true,
        location: '计算机楼B201',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            examProvider.overrideWith((ref) => _MockExamNotifier(ref, [mockExam])),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('zh'),
            home: ExamScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证标题与加号按钮
      expect(find.text('考试安排'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);

      // 验证考试卡片内容（不再显示“手动添加”、“待考”标签与“X天后/X小时后”相对时间标签）
      expect(find.text('编译原理'), findsOneWidget);
      expect(find.text('编译原理期末考'), findsOneWidget);
      expect(find.text('计算机楼B201'), findsOneWidget);
      expect(find.text('手动添加'), findsNothing);
      expect(find.text('待考'), findsNothing);
      expect(find.text('3天后'), findsNothing);
      expect(find.textContaining('小时后'), findsNothing);

      // 点击加号打开添加考试弹窗
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      expect(find.text('添加考试'), findsOneWidget);
      expect(find.text('所属课程'), findsOneWidget);
      expect(find.text('考试名称'), findsOneWidget);
    });

    testWidgets('Refresh error renders small card above exam schedule instead of full screen error', (tester) async {
      final mockExam = ExamScheduleModel(
        id: 'exam_err_1',
        title: '期末考',
        courseName: '高等数学',
        time: DateTime.now().add(const Duration(days: 2)),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            examProvider.overrideWith(
              (ref) => _MockExamNotifier(
                ref,
                [mockExam],
                errorMessage: '网络连接超时，请检查网络设置',
              ),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('zh'),
            home: ExamScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 小卡片显示在上方（已去掉重试按钮，保留关闭按钮）
      expect(find.text('网络连接超时，请检查网络设置'), findsOneWidget);
      expect(find.text('重试'), findsNothing);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);

      // 下方的考试卡片依然正常展示，没有被全屏报错阻断
      expect(find.text('高等数学'), findsOneWidget);
      expect(find.text('期末考'), findsOneWidget);

      // 点击关闭图标，小卡片消失，考试卡片依然保留
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('网络连接超时，请检查网络设置'), findsNothing);
      expect(find.text('高等数学'), findsOneWidget);
    });

    test('Only exams with start time today or in the future are stored', () async {
      final storage = ExamStorage(baseDirectory: tempDir);
      final now = DateTime.now();
      final todayExam = ExamScheduleModel(
        id: 'manual_today',
        title: '今天考试',
        time: DateTime(now.year, now.month, now.day, 14, 0),
        isManual: true,
      );
      final yesterdayExam = ExamScheduleModel(
        id: 'manual_yesterday',
        title: '昨天考试',
        time: DateTime(now.year, now.month, now.day).subtract(const Duration(hours: 5)),
        isManual: true,
      );
      final automaticYesterdayExam = ExamScheduleModel(
        id: 'auto_yesterday',
        title: '超星昨天考试',
        time: DateTime(now.year, now.month, now.day).subtract(const Duration(hours: 5)),
        isManual: false,
      );
      final tomorrowExam = ExamScheduleModel(
        id: 'auto_tomorrow',
        title: '超星明天考试',
        time: DateTime(now.year, now.month, now.day).add(const Duration(days: 1, hours: 9)),
        isManual: false,
      );

      // 验证日期判定方法：只保留今天及今天之后的考试
      expect(ExamStorage.isUpcomingOrToday(todayExam, now), isTrue);
      expect(ExamStorage.isExamExpired(todayExam, now), isFalse);

      expect(ExamStorage.isUpcomingOrToday(tomorrowExam, now), isTrue);
      expect(ExamStorage.isExamExpired(tomorrowExam, now), isFalse);

      expect(ExamStorage.isUpcomingOrToday(yesterdayExam, now), isFalse);
      expect(ExamStorage.isExamExpired(yesterdayExam, now), isTrue);

      expect(ExamStorage.isUpcomingOrToday(automaticYesterdayExam, now), isFalse);
      expect(ExamStorage.isExamExpired(automaticYesterdayExam, now), isTrue);

      // 始终只储存开始时间是今天以及今天之后日期的考试，历史考试落盘前被过滤，读取时亦自动清理
      await storage.saveExamList([todayExam, yesterdayExam, automaticYesterdayExam, tomorrowExam]);
      final loaded = await storage.readExamList();
      expect(loaded.any((e) => e.id == 'manual_yesterday'), isFalse);
      expect(loaded.any((e) => e.id == 'auto_yesterday'), isFalse);
      expect(loaded.any((e) => e.id == 'manual_today'), isTrue);
      expect(loaded.any((e) => e.id == 'auto_tomorrow'), isTrue);
      expect(loaded.length, 2);
    });
  });
}

class _MockExamNotifier extends ExamNotifier {
  _MockExamNotifier(super.ref, List<ExamScheduleModel> initial, {String? errorMessage}) {
    if (errorMessage != null) {
      state = AsyncValue<List<ExamScheduleModel>>.error(
        errorMessage,
        StackTrace.empty,
      ).copyWithPrevious(AsyncValue.data(initial));
    } else {
      state = AsyncValue.data(initial);
    }
  }
}
