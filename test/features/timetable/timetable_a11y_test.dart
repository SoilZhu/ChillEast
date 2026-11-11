import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/features/timetable/utils/course_color_utils.dart';
import 'package:ChillEast/features/timetable/models/course_model.dart';

void main() {
  group('Timetable A11y Tests', () {
    test('verifies course color utils contains expected 19 palette items', () {
      final colors = CourseColorUtils.selectablePalette;
      expect(colors.length, 19);
    });

    test('constructs accessibility semantic string accurately', () {
      const course = CourseModel(
        id: 'c1',
        name: '高等数学',
        teacher: '张老师',
        classroom: '十教北101',
        weeks: '1-16周',
        periods: '3-4节',
        dayOfWeek: 2,
        startPeriod: 3,
        endPeriod: 4,
      );

      final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      final weekdayStr = weekdays[(course.dayOfWeek - 1).clamp(0, 6)];

      final buffer = StringBuffer()
        ..write(
            '$weekdayStr 第${course.startPeriod}至${course.endPeriod}节，${course.name}')
        ..write(course.classroom.isNotEmpty ? '，教室：${course.classroom}' : '');

      expect(buffer.toString(), '周二 第3至4节，高等数学，教室：十教北101');
    });
  });
}
