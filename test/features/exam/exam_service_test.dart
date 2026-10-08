import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/features/exam/models/exam_schedule_model.dart';
import 'package:ChillEast/features/exam/services/exam_service.dart';

void main() {
  group('ExamService HAR & HTML parsing tests', () {
    late Map<String, dynamic> harData;
    late String entry0Html;
    late String entry2Html;
    late String entry4Html;
    late ExamService examService;

    setUpAll(() async {
      final harFile = File('/home/soilzhu/code/debug/mooc1-api.chaoxing.com.har');
      expect(await harFile.exists(), isTrue, reason: 'HAR file must exist');
      final content = await harFile.readAsString();
      harData = jsonDecode(content) as Map<String, dynamic>;

      final entries = harData['log']['entries'] as List<dynamic>;
      entry0Html = entries[0]['response']['content']['text'] as String;
      entry2Html = entries[2]['response']['content']['text'] as String;
      entry4Html = entries[4]['response']['content']['text'] as String;

      examService = ExamService();
    });

    test('parseExamListHtml should extract 46 exam items with correct ids and titles', () {
      final list = examService.parseExamListHtml(entry0Html);
      expect(list.length, equals(46));

      // 验证第 1 项
      final first = list[0];
      expect(first['title'], equals('2026年9月10日补考试题'));
      expect(first['status'], equals('已完成'));
      expect(first['id'], equals('10762596'));
      expect(first['dataUrl'], contains('taskrefId=10762596'));

      // 验证未交项 (第 5 项)
      final fifth = list[4];
      expect(fifth['title'], equals('26年春形策期末考试'));
      expect(fifth['status'], equals('未交'));
      expect(fifth['id'], equals('9473825'));
    });

    test('parseExamDetailHtml on entry 2 (watermark-wrapper with 领取/提交时间)', () {
      // 提取到的时间应为 2026-09-10 19:00 和 2026-09-10 19:30
      final result = examService.parseExamDetailHtml(entry2Html);

      expect(result, isNotNull);
      // 时间显示为第一个出现的时间
      expect(result!.displayTime, equals(DateTime(2026, 9, 10, 19, 0)));
      expect(result.allTimes.length, equals(2));
      expect(result.allTimes[0], equals(DateTime(2026, 9, 10, 19, 0)));
      expect(result.allTimes[1], equals(DateTime(2026, 9, 10, 19, 30)));
      expect(result.studentName, equals('朱天兆'));
      expect(result.studentId, equals('202440800233'));
    });

    test('parseExamDetailHtml on entry 4 (watermark-wrapper with 开始/截止时间)', () {
      // 提取到的时间应为 2026-05-10 17:00 和 2026-05-10 23:59
      final result = examService.parseExamDetailHtml(entry4Html);

      expect(result, isNotNull);
      // 时间显示为第一个出现的时间 (17:00 而非 23:59)
      expect(result!.displayTime, equals(DateTime(2026, 5, 10, 17, 0)));
      expect(result.allTimes.length, equals(2));
      expect(result.allTimes[0], equals(DateTime(2026, 5, 10, 17, 0)));
      expect(result.allTimes[1], equals(DateTime(2026, 5, 10, 23, 59)));
      expect(result.studentName, equals('朱天兆'));
      expect(result.studentId, equals('202440800233'));
    });

    test('ExamScheduleModel toJson and fromJson roundtrip', () {
      final model = ExamScheduleModel(
        id: '9473825',
        title: '26年春形策期末考试',
        courseName: '形势与政策',
        time: DateTime(2026, 5, 10, 17, 0),
        allTimes: [
          DateTime(2026, 5, 10, 17, 0),
          DateTime(2026, 5, 10, 23, 59),
        ],
        rawTimeStrs: ['2026-05-10 17:00', '2026-05-10 23:59'],
        detailUrl: 'https://mooc1-api.chaoxing.com/...',
        status: '未交',
        studentName: '朱天兆',
        studentId: '202440800233',
        createdAt: DateTime(2026, 10, 7),
      );

      final json = model.toJson();
      final restored = ExamScheduleModel.fromJson(json);

      expect(restored.id, equals(model.id));
      expect(restored.title, equals(model.title));
      expect(restored.time, equals(model.time));
      expect(restored.allTimes.length, equals(2));
      expect(restored.rawTimeStrs, equals(model.rawTimeStrs));
      expect(restored.status, equals(model.status));
      expect(restored.studentName, equals(model.studentName));
      expect(restored.studentId, equals(model.studentId));
    });

    test('isCurrentSemester accurately filters exams to current semester only', () {
      final nowAutumn = DateTime(2026, 10, 7); // 2026 年秋季学期
      final examAutumn = ExamScheduleModel(
        id: '10762596',
        title: '2026年9月10日补考试题',
        time: DateTime(2026, 9, 10, 19, 0),
      );
      final examSpring = ExamScheduleModel(
        id: '9473825',
        title: '26年春形策期末考试',
        time: DateTime(2026, 5, 10, 17, 0),
      );
      final examLastYear = ExamScheduleModel(
        id: '9002736',
        title: '2025年秋季学期《马克思主义基本原理》课程考试',
        time: DateTime(2025, 12, 20, 9, 0),
      );

      // 当前是 2026 秋季学期：只应显示 2026 年 9 月秋季考试，不显示春季和往年考试
      expect(examAutumn.isCurrentSemester(referenceTime: nowAutumn), isTrue);
      expect(examSpring.isCurrentSemester(referenceTime: nowAutumn), isFalse);
      expect(examLastYear.isCurrentSemester(referenceTime: nowAutumn), isFalse);

      // 结合课表开学周一 (2026-09-07)
      final monday = DateTime(2026, 9, 7);
      expect(
        examAutumn.isCurrentSemester(firstWeekMonday: monday, referenceTime: nowAutumn),
        isTrue,
      );
      expect(
        examSpring.isCurrentSemester(firstWeekMonday: monday, referenceTime: nowAutumn),
        isFalse,
      );

      // 若参考时间为 2026 年 5 月（春季学期）：则只显示春季学期考试
      final nowSpring = DateTime(2026, 5, 1);
      expect(examSpring.isCurrentSemester(referenceTime: nowSpring), isTrue);
      expect(examAutumn.isCurrentSemester(referenceTime: nowSpring), isFalse);
    });
  });
}
