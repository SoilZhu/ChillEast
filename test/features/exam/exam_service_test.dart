import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:ChillEast/features/exam/models/exam_schedule_model.dart';
import 'package:ChillEast/features/exam/services/exam_service.dart';

void main() {
  group('ExamService HAR & HTML parsing tests', () {
    late ExamService examService;

    setUpAll(() async {
      examService = ExamService();
    });

    test('buildTaskExamUrl should append ut=s and preserve fragment', () {
      const raw =
          '/exam-ans/exam/phone/task-exam?taskrefId=10783790&courseId=266204575&classId=152272723&from=examlist#INNER';
      final built = ExamService.buildTaskExamUrl(raw);
      expect(
        built,
        equals(
          'https://mooc1-api.chaoxing.com/exam-ans/exam/phone/task-exam?taskrefId=10783790&courseId=266204575&classId=152272723&from=examlist&ut=s#INNER',
        ),
      );
    });

    test('parseExamListHtml on user snippet from prompt', () {
      const snippet = '''
<li onclick="goTask(this);" data="/exam-ans/exam/phone/task-exam?taskrefId=10783790&courseId=266204575&classId=152272723&from=examlist"
				data-stopexam="0" title="2误差">
            		<div class="ks_pic"><img tabindex="-1" aria-hidden="true" src="//mooc1-api.chaoxing.com/exam-ans/views/identifycode/images/ks_02.png"/></div>
            		<dl class="ks_text" tabindex="0" role="text" aria-label='考试名称：2误差; 考试状态：已完成;
						 '
					>
            			<dt>2误差</dt>
            			            		</dl>
            		<span tabindex="-1" aria-hidden="true" class="ks_state">已完成</span>
            	</li>
''';
      final items = examService.parseExamListHtml(snippet);
      expect(items.length, equals(1));
      expect(items[0]['id'], equals('10783790'));
      expect(items[0]['title'], equals('2误差'));
      expect(items[0]['status'], equals('已完成'));
      expect(
        items[0]['dataUrl'],
        equals(
          'https://mooc1-api.chaoxing.com/exam-ans/exam/phone/task-exam?taskrefId=10783790&courseId=266204575&classId=152272723&from=examlist&ut=s',
        ),
      );
    });

    test('parseExamDetailHtml on user prompt snippet: first is startTime, second is endTime', () {
      const snippet = '''
<div id="watermark-wrapper" class="watermark-wrapper"></div>
<div style="position:relative;z-index:100">
    <p>姓名：张三</p>
    <p>学号：202440800000</p>
    <p>领取时间：
        <span class="din font16">2026-09-10 19:00</span></p>
    <p>提交时间：
        <span class="din font16">2026-09-10 19:30</span></p>
    <p>考试用时：<span class="din font16">30</span>分钟</p>
    <p>提交方式：学生交卷</p>
</div>
''';
      final result = examService.parseExamDetailHtml(snippet);
      expect(result, isNotNull);
      // 第一个时间一律视为开始时间
      expect(result!.startTime, equals(DateTime(2026, 9, 10, 19, 0)));
      expect(result.displayTime, equals(DateTime(2026, 9, 10, 19, 0)));
      // 第二个时间一律视为结束时间
      expect(result.endTime, equals(DateTime(2026, 9, 10, 19, 30)));
      expect(result.studentName, equals('张三'));
      expect(result.studentId, equals('202440800000'));
      expect(result.allTimes.length, equals(2));
    });

    test('parseExamDetailHtml strictly extracts from z-index:100 and ignores dynamicNowTime', () {
      const htmlWithCurrentTime = '''
<p class="paper_time">当前时间<span class="din_bold font4" id="dynamicNowTime">2026-10-17 03:44:00</span></p>
<div class="result_gray_div pad80" style="position:relative;overflow:hidden;">
  <div id="watermark-wrapper" class="watermark-wrapper"></div>
  <div style="position:relative;z-index:100">
    <p>姓名：张三</p> <p>学号：202440800000</p>
    <p>领取时间：
        <span class="din font16">2024-12-26 11:10</span></p>
    <p>提交时间：
        <span class="din font16">2024-12-26 11:37</span></p>
  </div>
</div>
''';
      final result = examService.parseExamDetailHtml(htmlWithCurrentTime);
      expect(result, isNotNull);
      // 必须严格提取 领取时间 (2024-12-26 11:10)，绝不能误提取当前时间 (2026-10-17 03:44:00)
      expect(result!.startTime, equals(DateTime(2024, 12, 26, 11, 10)));
      expect(result.endTime, equals(DateTime(2024, 12, 26, 11, 37)));
      expect(result.studentName, equals('张三'));
      expect(result.studentId, equals('202440800000'));
    });

    test('parseExamDetailHtml on mock HAR entries', () {
      const entry2 = '''
<div id="watermark-wrapper" class="watermark-wrapper"></div>
<div style="position:relative;z-index:100">
    <p>姓名：张三</p>
    <p>学号：202440800000</p>
    <p>领取时间：
        <span class="din font16">2026-09-10 19:00</span></p>
    <p>提交时间：
        <span class="din font16">2026-09-10 19:30</span></p>
</div>
''';
      final result2 = examService.parseExamDetailHtml(entry2);
      expect(result2, isNotNull);
      expect(result2!.startTime, equals(DateTime(2026, 9, 10, 19, 0)));
      expect(result2.endTime, equals(DateTime(2026, 9, 10, 19, 30)));
      expect(result2.studentName, equals('张三'));
      expect(result2.studentId, equals('202440800000'));

      const entry4 = '''
<div id="watermark-wrapper" class="watermark-wrapper"></div>
<div style="position:relative;z-index:100">
    <p>姓名：张三</p>
    <p>学号：202440800000</p>
    <p>开始时间：
        <span class="din font16">2026-09-15 11:00</span></p>
    <p>截止时间：
        <span class="din font16">2026-09-15 11:03</span></p>
</div>
''';
      final result4 = examService.parseExamDetailHtml(entry4);
      expect(result4, isNotNull);
      expect(result4!.startTime, equals(DateTime(2026, 9, 15, 11, 0)));
      expect(result4.endTime, equals(DateTime(2026, 9, 15, 11, 3)));
      expect(result4.studentName, equals('张三'));
      expect(result4.studentId, equals('202440800000'));
    });

    test('fetchExamDetailContent handles 302 redirect from task-exam to look page', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.contains('task-exam')) {
              // 模拟返回 302 Found
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 302,
                  headers: Headers.fromMap({
                    'location': [
                      'https://mooc1-api.chaoxing.com/exam-ans/exam/phone/look?courseId=260840114&classId=152563140&examId=10762596&cpi=100000000&examAnswerId=200000000&code=&protocol_v=1#INNER',
                    ],
                  }),
                ),
              );
            } else if (options.path.contains('look?')) {
              // 模拟返回 200 OK 页面
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: '''
<div id="watermark-wrapper" class="watermark-wrapper"></div>
<div style="position:relative;z-index:100">
    <p>姓名：张三</p>
    <p>学号：202440800000</p>
    <p>领取时间：<span class="din font16">2026-09-10 19:00</span></p>
    <p>提交时间：<span class="din font16">2026-09-10 19:30</span></p>
</div>
''',
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final result = await examService.fetchExamDetailContent(
        'https://mooc1-api.chaoxing.com/exam-ans/exam/phone/task-exam?taskrefId=10762596&courseId=260840114&classId=152563140&from=examlist&ut=s',
        dioClient: dio,
      );

      expect(result, isNotNull);
      // 验证保留 fragment #INNER
      expect(result!.finalUrl, contains('#INNER'));
      expect(result.finalUrl, contains('look?courseId=260840114'));
      expect(result.html, contains('张三'));

      final detail = examService.parseExamDetailHtml(result.html);
      expect(detail, isNotNull);
      expect(detail!.startTime, equals(DateTime(2026, 9, 10, 19, 0)));
      expect(detail.endTime, equals(DateTime(2026, 9, 10, 19, 30)));
    });

    test('ExamScheduleModel toJson and fromJson roundtrip with startTime and endTime', () {
      final model = ExamScheduleModel(
        id: '10762596',
        title: '2026年9月10日补考试题',
        courseName: '形势与政策',
        time: DateTime(2026, 9, 10, 19, 0),
        endTime: DateTime(2026, 9, 10, 19, 30),
        allTimes: [
          DateTime(2026, 9, 10, 19, 0),
          DateTime(2026, 9, 10, 19, 30),
        ],
        rawTimeStrs: ['2026-09-10 19:00', '2026-09-10 19:30'],
        detailUrl: 'https://mooc1-api.chaoxing.com/exam-ans/exam/phone/look?...',
        status: '已完成',
        studentName: '张三',
        studentId: '202440800000',
        createdAt: DateTime(2026, 10, 7),
      );

      final json = model.toJson();
      final restored = ExamScheduleModel.fromJson(json);

      expect(restored.id, equals(model.id));
      expect(restored.title, equals(model.title));
      expect(restored.time, equals(model.time));
      expect(restored.startTime, equals(model.startTime));
      expect(restored.endTime, equals(model.endTime));
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
        endTime: DateTime(2026, 9, 10, 19, 30),
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

    test('isNotStartedOrInProgress correctly identifies active and upcoming statuses', () {
      expect(ExamService.isNotStartedOrInProgress('未开始'), isTrue);
      expect(ExamService.isNotStartedOrInProgress('进行中'), isTrue);
      expect(ExamService.isNotStartedOrInProgress('未交'), isTrue);
      expect(ExamService.isNotStartedOrInProgress('待考'), isTrue);
      expect(ExamService.isNotStartedOrInProgress('待考试'), isTrue);
      expect(ExamService.isNotStartedOrInProgress('考试中'), isTrue);

      expect(ExamService.isNotStartedOrInProgress('已完成'), isFalse);
      expect(ExamService.isNotStartedOrInProgress('已结束'), isFalse);
      expect(ExamService.isNotStartedOrInProgress(''), isFalse);
    });

    test('fetchExams ONLY fetches and stores pending/unfinished exams, excluding 已完成', () async {
      final requestedUrls = <String>[];
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final uri = options.uri.toString();
            requestedUrls.add(uri);
            if (uri.contains('examcode')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: '''
<ul class="ks_list">
  <li data="/exam-ans/exam/phone/task-exam?taskrefId=111&courseId=1&classId=1&from=examlist" data-stopexam="0" title="已完成考试1">
    <span class="ks_state">已完成</span>
  </li>
  <li data="/exam-ans/exam/phone/task-exam?taskrefId=222&courseId=1&classId=1&from=examlist" data-stopexam="0" title="未交考试2">
    <span class="ks_state">未交</span>
  </li>
  <li data="/exam-ans/exam/phone/task-exam?taskrefId=333&courseId=1&classId=1&from=examlist" data-stopexam="0" title="进行中考试3">
    <span class="ks_state">进行中</span>
  </li>
  <li data="/exam-ans/exam/phone/task-exam?taskrefId=444&courseId=1&classId=1&from=examlist" data-stopexam="1" title="未开放未开始4">
    <span class="ks_state">未开始</span>
  </li>
  <li data="/exam-ans/exam/phone/task-exam?taskrefId=555&courseId=1&classId=1&from=examlist" data-stopexam="0" title="开放未开始5">
    <span class="ks_state">未开始</span>
  </li>
</ul>
''',
                ),
              );
            } else if (uri.contains('task-exam')) {
              // 302 重定向到 look
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 302,
                  headers: Headers.fromMap({
                    'location': [
                      'https://mooc1-api.chaoxing.com/exam-ans/exam/phone/look?courseId=1&classId=1&examId=333&protocol_v=1#INNER',
                    ],
                  }),
                ),
              );
            } else if (uri.contains('look?')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: '''
<div id="watermark-wrapper" class="watermark-wrapper"></div>
<div style="position:relative;z-index:100">
  <p>领取时间：<span class="din font16">2099-10-18 09:00</span></p>
  <p>提交时间：<span class="din font16">2099-10-18 11:00</span></p>
</div>
''',
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final results = await examService.fetchExams(dioClient: dio);

      // 仅纳入 4 门未完成/待开始的考试（222 未交, 333 进行中, 444 未开始, 555 未开始），已完成(111)被完全排除
      expect(results.length, equals(4));
      expect(results.any((r) => r.id == '111'), isFalse);

      // 验证网络请求：
      // 1. 必须有 examcode 列表请求
      expect(requestedUrls.any((u) => u.contains('examcode')), isTrue);

      // 2. 绝不能向“已完成”(111)发送 task-exam 请求
      expect(requestedUrls.any((u) => u.contains('taskrefId=111')), isFalse);

      // 3. 所有未完成与待开始考试（包括 222, 333, 444, 555）都会发起详情请求
      expect(requestedUrls.any((u) => u.contains('taskrefId=222')), isTrue);
      expect(requestedUrls.any((u) => u.contains('taskrefId=333')), isTrue);
      expect(requestedUrls.any((u) => u.contains('taskrefId=444')), isTrue);
      expect(requestedUrls.any((u) => u.contains('taskrefId=555')), isTrue);
    });

    test('excludeDynamicNowTime removes dynamicNowTime element from DOM', () {
      const html1 = '''
<p class="paper_time">当前时间<span class="din_bold font4" id="dynamicNowTime">2026-10-17 03:44:12</span></p>
<div class="content">内容</div>
''';
      final doc = html_parser.parse(html1);
      ExamService.excludeDynamicNowTime(doc);
      expect(doc.querySelector('#dynamicNowTime'), isNull);
      expect(doc.querySelector('.paper_time'), isNull);
      expect(doc.body?.text.contains('2026-10-17'), isFalse);
    });

    test('parseExamDetailHtml with sequential times strictly excludes dynamicNowTime', () {
      // 模拟页面没有“领取时间”关键词，包含动态时间和容器内真实考试时间
      const html = '''
<span id="dynamicNowTime">2026-10-17 03:44:00</span>
<div id="watermark-wrapper" class="watermark-wrapper"></div>
<div style="position:relative;z-index:100">
    <p>真实考试时间段：2026-11-20 09:00 至 2026-11-20 11:00</p>
</div>
''';
      final result = examService.parseExamDetailHtml(html);
      expect(result, isNotNull);
      expect(result!.startTime, equals(DateTime(2026, 11, 20, 9, 0)));
      expect(result.endTime, equals(DateTime(2026, 11, 20, 11, 0)));
      expect(result.allTimes.contains(DateTime(2026, 10, 17, 3, 44, 0)), isFalse);
    });

    test('fetchExams includes exams without detail time directly in results with time == null', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final uri = options.uri.toString();
            if (uri.contains('examcode')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: '''
<ul class="ks_list">
  <li data="/exam-ans/exam/phone/task-exam?taskrefId=valid1&courseId=1&classId=1&from=examlist" data-stopexam="0" title="正常考试">
    <span class="ks_state">进行中</span>
  </li>
  <li data="/exam-ans/exam/phone/task-exam?taskrefId=invalid2&courseId=1&classId=1&from=examlist" data-stopexam="0" title="暂无时间考试">
    <span class="ks_state">待考</span>
  </li>
</ul>
''',
                ),
              );
            } else if (uri.contains('taskrefId=valid1')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: '''
<div id="watermark-wrapper" class="watermark-wrapper"></div>
<div style="position:relative;z-index:100">
  <p>领取时间：<span class="din font16">2099-10-18 09:00</span></p>
</div>
''',
                ),
              );
            } else if (uri.contains('taskrefId=invalid2')) {
              // 模拟详情页无法解析出时间（例如错误页或空内容）
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: '<div>系统维护中，暂无详情</div>',
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final results = await examService.fetchExams(dioClient: dio);

      // 两门考试均应出现在列表中，valid1 包含具体时间，invalid2 的 time 为 null（直接显示在安排里，不需要有时间）
      expect(results.length, equals(2));
      final valid = results.firstWhere((r) => r.id == 'valid1');
      final withoutTime = results.firstWhere((r) => r.id == 'invalid2');

      expect(valid.time, equals(DateTime(2099, 10, 18, 9, 0)));
      expect(withoutTime.time, isNull);
      // 有时间的排在前面，无时间的排在最后
      expect(results.first.id, equals('valid1'));
      expect(results.last.id, equals('invalid2'));
    });
  });
}
