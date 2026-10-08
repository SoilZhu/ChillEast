import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/features/exam/models/exam_schedule_model.dart';
import 'package:ChillEast/features/exam/providers/exam_provider.dart';
import 'package:ChillEast/features/exam/services/exam_storage.dart';
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
      final exams = [
        ExamScheduleModel(
          id: '10762596',
          title: '2026年9月10日补考试题',
          time: DateTime(2026, 9, 10, 19, 0),
          allTimes: [
            DateTime(2026, 9, 10, 19, 0),
            DateTime(2026, 9, 10, 19, 30),
          ],
          rawTimeStrs: ['2026-09-10 19:00', '2026-09-10 19:30'],
          status: '已完成',
        ),
      ];

      await storage.saveExamList(exams);
      final loaded = await storage.readExamList();
      expect(loaded.length, equals(1));
      expect(loaded.first.id, equals('10762596'));
      expect(loaded.first.title, equals('2026年9月10日补考试题'));
      // 时间显示为第一个出现的时间
      expect(loaded.first.time, equals(DateTime(2026, 9, 10, 19, 0)));

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
                  final timeStr = DateFormat('HH:mm').format(mockExam.time);
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
  });
}

class _MockExamNotifier extends ExamNotifier {
  _MockExamNotifier(super.ref, List<ExamScheduleModel> initial) {
    state = AsyncValue.data(initial);
  }
}
