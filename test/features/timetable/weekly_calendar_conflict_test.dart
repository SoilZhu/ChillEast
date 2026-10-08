import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/features/timetable/models/course_model.dart';
import 'package:ChillEast/features/timetable/widgets/weekly_calendar_view.dart';

void main() {
  group('WeeklyCalendarView Course Conflict Layering Tests', () {
    const courseWithRoomLong = CourseModel(
      id: 'c1',
      name: '线下实验课',
      teacher: '李老师',
      classroom: '实验楼302',
      weeks: '1-16(周)',
      periods: '01-04',
      dayOfWeek: 1,
      startPeriod: 1,
      endPeriod: 4, // 时长 4 节
    );

    const courseWithRoomShort = CourseModel(
      id: 'c2',
      name: '高等数学',
      teacher: '张老师',
      classroom: '十教南101',
      weeks: '1-16(周)',
      periods: '01-02',
      dayOfWeek: 1,
      startPeriod: 1,
      endPeriod: 2, // 时长 2 节
    );

    const courseWithoutRoomLong = CourseModel(
      id: 'c3',
      name: '网络通识课',
      teacher: '王老师',
      classroom: '', // 无教室
      weeks: '1-16(周)',
      periods: '01-04',
      dayOfWeek: 1,
      startPeriod: 1,
      endPeriod: 4, // 时长 4 节
    );

    const courseWithoutRoomShort = CourseModel(
      id: 'c4',
      name: '在线选修讲座',
      teacher: '赵老师',
      classroom: '   ', // 空白无教室
      weeks: '1-16(周)',
      periods: '01-02',
      dayOfWeek: 1,
      startPeriod: 1,
      endPeriod: 2, // 时长 2 节
    );

    test('1. 有教室的比没教室的层级更高', () {
      // 相同或不同时长下，有教室的课程应排在后面（层级更高）
      final list = [courseWithRoomLong, courseWithoutRoomLong];
      list.sort(WeeklyCalendarViewState.compareCourseLayers);

      expect(list.first, equals(courseWithoutRoomLong)); // 底层
      expect(list.last, equals(courseWithRoomLong)); // 顶层
    });

    test('2. 都有教室时，时长更短的比时长更长的层级更高', () {
      final list = [courseWithRoomShort, courseWithRoomLong];
      list.sort(WeeklyCalendarViewState.compareCourseLayers);

      expect(list.first, equals(courseWithRoomLong)); // 时长长在底层
      expect(list.last, equals(courseWithRoomShort)); // 时长短在顶层
    });

    test('3. 都没教室时，时长更短的比时长更长的层级更高', () {
      final list = [courseWithoutRoomShort, courseWithoutRoomLong];
      list.sort(WeeklyCalendarViewState.compareCourseLayers);

      expect(list.first, equals(courseWithoutRoomLong)); // 时长长在底层
      expect(list.last, equals(courseWithoutRoomShort)); // 时长短在顶层
    });

    test('4. 综合排序：无教室长 < 无教室短 < 有教室长 < 有教室短', () {
      final list = [
        courseWithRoomShort,
        courseWithoutRoomLong,
        courseWithRoomLong,
        courseWithoutRoomShort,
      ];

      list.sort(WeeklyCalendarViewState.compareCourseLayers);

      expect(list, equals([
        courseWithoutRoomLong,
        courseWithoutRoomShort,
        courseWithRoomLong,
        courseWithRoomShort,
      ]));
    });

    test('5. 冲突判定 areCoursesOverlapping 正确识别时间重叠', () {
      // 同一天节次重叠
      expect(
        WeeklyCalendarViewState.areCoursesOverlapping(courseWithRoomLong, courseWithRoomShort),
        isTrue,
      );

      // 同一天节次不重叠
      const courseAfternoon = CourseModel(
        id: 'c5',
        name: '下午课程',
        teacher: '老师',
        classroom: '教室',
        weeks: '1-16',
        periods: '05-06',
        dayOfWeek: 1,
        startPeriod: 5,
        endPeriod: 6,
      );
      expect(
        WeeklyCalendarViewState.areCoursesOverlapping(courseWithRoomShort, courseAfternoon),
        isFalse,
      );

      // 不同天节次相同
      const courseTuesday = CourseModel(
        id: 'c6',
        name: '周二课程',
        teacher: '老师',
        classroom: '教室',
        weeks: '1-16',
        periods: '01-02',
        dayOfWeek: 2,
        startPeriod: 1,
        endPeriod: 2,
      );
      expect(
        WeeklyCalendarViewState.areCoursesOverlapping(courseWithRoomShort, courseTuesday),
        isFalse,
      );
    });
  });
}
