import 'package:ChillEast/core/services/home_widget_service.dart';
import 'package:ChillEast/features/homework/models/homework_model.dart';
import 'package:ChillEast/features/timetable/models/course_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CourseModel course({
  required String name,
  required int dayOfWeek,
  required String weeks,
  required int start,
  required int end,
  String classroom = '教室101',
}) {
  return CourseModel(
    id: '$name-$dayOfWeek-$start',
    name: name,
    teacher: '老师',
    classroom: classroom,
    weeks: weeks,
    periods: '0$start-0$end',
    dayOfWeek: dayOfWeek,
    startPeriod: start,
    endPeriod: end,
  );
}

HomeworkModel homework({
  required String title,
  DateTime? endTime,
  HomeworkStatus status = HomeworkStatus.pending,
}) {
  return HomeworkModel(
    id: title,
    courseName: '课程A',
    title: title,
    endTime: endTime,
    status: status,
    studentId: 'test',
  );
}

void main() {
  group('previewDateFor', () {
    test('22 点前预览今天', () {
      final now = DateTime(2026, 9, 28, 21, 59);
      expect(HomeWidgetService.previewDateFor(now), DateTime(2026, 9, 28));
      expect(HomeWidgetService.isTomorrowPreview(now), isFalse);
    });

    test('22 点整切换到明天', () {
      final now = DateTime(2026, 9, 28, 22, 0);
      expect(HomeWidgetService.previewDateFor(now), DateTime(2026, 9, 29));
      expect(HomeWidgetService.isTomorrowPreview(now), isTrue);
    });

    test('跨月切换正确', () {
      final now = DateTime(2026, 9, 30, 23, 30);
      expect(HomeWidgetService.previewDateFor(now), DateTime(2026, 10, 1));
    });
  });

  group('filterDayCourses', () {
    final all = [
      course(name: '数学', dayOfWeek: 1, weeks: '1-16(周)', start: 1, end: 2),
      course(name: '英语', dayOfWeek: 1, weeks: '1-8(周)', start: 3, end: 4),
      course(name: '物理', dayOfWeek: 2, weeks: '1-16(周)', start: 1, end: 2),
    ];

    test('按星期与周次过滤并按节次排序', () {
      final result = HomeWidgetService.filterDayCourses(all, 1, 10);
      expect(result.map((e) => e.name), ['数学']);
    });

    test('week <= 0 时不过滤周次', () {
      final result = HomeWidgetService.filterDayCourses(all, 1, 0);
      expect(result.map((e) => e.name), ['数学', '英语']);
    });
  });

  group('filterFinishedCourses', () {
    test('过滤已结束课程', () {
      final courses = [
        course(name: '早课', dayOfWeek: 1, weeks: '1-16(周)', start: 1, end: 2),
        course(name: '午课', dayOfWeek: 1, weeks: '1-16(周)', start: 5, end: 6),
      ];
      // 1-2 节 08:00-09:40，10:00 时早课已结束
      final result = HomeWidgetService.filterFinishedCourses(
        courses,
        const TimeOfDay(hour: 10, minute: 0),
      );
      expect(result.map((e) => e.name), ['午课']);
    });
  });

  group('filterDayHomework', () {
    test('只保留当天截止的待办', () {
      final date = DateTime(2026, 9, 28);
      final all = [
        homework(title: '今天到期', endTime: DateTime(2026, 9, 28, 23, 59)),
        homework(title: '明天到期', endTime: DateTime(2026, 9, 29, 8, 0)),
        homework(
          title: '今天但已完成',
          endTime: DateTime(2026, 9, 28, 12, 0),
          status: HomeworkStatus.completed,
        ),
        homework(title: '无截止时间'),
      ];
      final result = HomeWidgetService.filterDayHomework(all, date);
      expect(result.map((e) => e.title), ['今天到期']);
    });
  });

  group('buildAgendaMap', () {
    test('作业排在课程前面且不超过上限', () {
      final map = HomeWidgetService.buildAgendaMap(
        title: '今日日程',
        dateLine: '9月28日 周日',
        isTomorrow: false,
        emptyText: '无课',
        dayHomework: [
          homework(title: '作业1', endTime: DateTime(2026, 9, 28, 20, 0)),
          homework(title: '作业2', endTime: DateTime(2026, 9, 28, 21, 0)),
        ],
        dayCourses: [
          course(name: '数学', dayOfWeek: 1, weeks: '1-16(周)', start: 1, end: 2),
          course(name: '英语', dayOfWeek: 1, weeks: '1-16(周)', start: 3, end: 4),
          course(name: '物理', dayOfWeek: 1, weeks: '1-16(周)', start: 5, end: 6),
        ],
        deadlinePrefix: '截止',
        noDeadline: '无截止',
        maxItems: 4,
      );
      final items = map['items'] as List;
      expect(items.length, 4);
      expect(items[0]['kind'], 'homework');
      expect(items[1]['kind'], 'homework');
      expect(items[2]['kind'], 'course');
      expect((items[2]['sub'] as String).contains('08:00-09:40'), isTrue);
    });
  });

  group('courseColorFor', () {
    test('同一课程名颜色稳定且为有效 ARGB', () {
      final a = HomeWidgetService.courseColorFor('高等数学');
      final b = HomeWidgetService.courseColorFor('高等数学');
      expect(a, b);
      expect(a & 0xFF000000, 0xFF000000);
      expect(HomeWidgetService.coursePalette.contains(a), isTrue);
    });
  });

  group('buildQuickMap', () {
    test('非法 id 被过滤并补齐到 4 个', () {
      final map = HomeWidgetService.buildQuickMap(
        ids: const ['vpn', 'not_exist'],
        labelOf: (id) => id,
      );
      final items = map['items'] as List;
      expect(items.length, 4);
      expect(items[0]['id'], 'vpn');
    });

    test('超过 4 个时截断', () {
      final map = HomeWidgetService.buildQuickMap(
        ids: const [
          'payment_code',
          'library',
          'empty_classroom',
          'bus',
          'score',
          'vpn',
        ],
        labelOf: (id) => id,
      );
      expect((map['items'] as List).length, 4);
    });
  });
}
