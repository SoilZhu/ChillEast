import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/features/timetable/models/course_model.dart';
import 'package:ChillEast/features/timetable/models/timetable_rule_model.dart';
import 'package:ChillEast/features/timetable/services/timetable_rule_service.dart';
import 'package:ChillEast/features/timetable/utils/ics_generator.dart';
import 'package:ChillEast/features/timetable/utils/ics_parser.dart';
import 'package:ChillEast/features/timetable/utils/week_parser.dart';

void main() {
  group('TimetableRuleService Rules Logic Tests', () {
    final service = TimetableRuleService();

    final testCourses = [
      const CourseModel(
        id: 'c1',
        name: '高等数学',
        teacher: '张老师',
        classroom: '十教南101',
        weeks: '1-16(周)',
        periods: '01-02',
        dayOfWeek: 1, // 周一
        startPeriod: 1,
        endPeriod: 2,
      ),
      const CourseModel(
        id: 'c2',
        name: '大学英语',
        teacher: '王老师',
        classroom: '十教北201',
        weeks: '1-16(周)',
        periods: '03-04',
        dayOfWeek: 5, // 周五
        startPeriod: 3,
        endPeriod: 4,
      ),
      const CourseModel(
        id: 'c3',
        name: '大学物理',
        teacher: '李老师',
        classroom: '十教南202',
        weeks: '1-8(周)',
        periods: '01-02',
        dayOfWeek: 5, // 周五
        startPeriod: 1,
        endPeriod: 2,
      ),
    ];

    test('Suspension rule removes specified course from specified weeks', () {
      final rule = TimetableRule.createSuspension(
        startWeek: 5,
        endWeek: 6,
        courseName: '高等数学',
      );

      final result = service.applyRules(testCourses, [rule]);

      final math = result.firstWhere((c) => c.name == '高等数学');
      final activeWeeks = WeekParser.parseWeeks(math.weeks);

      expect(activeWeeks.contains(4), isTrue);
      expect(activeWeeks.contains(5), isFalse);
      expect(activeWeeks.contains(6), isFalse);
      expect(activeWeeks.contains(7), isTrue);

      // 其他课程不受影响
      final english = result.firstWhere((c) => c.name == '大学英语');
      expect(WeekParser.parseWeeks(english.weeks).length, equals(16));
    });

    test('Suspension rule removes all courses on a given day and week range', () {
      // 周五第 5 周全部停课（放假）
      final rule = TimetableRule.createSuspension(
        startWeek: 5,
        endWeek: 5,
        dayOfWeek: 5,
      );

      final result = service.applyRules(testCourses, [rule]);

      final english = result.firstWhere((c) => c.name == '大学英语');
      final physics = result.firstWhere((c) => c.name == '大学物理');

      expect(WeekParser.parseWeeks(english.weeks).contains(5), isFalse);
      expect(WeekParser.parseWeeks(physics.weeks).contains(5), isFalse);

      // 周一高数不受影响
      final math = result.firstWhere((c) => c.name == '高等数学');
      expect(WeekParser.parseWeeks(math.weeks).contains(5), isTrue);
    });

    test('Reschedule rule moves Friday courses of week 5 to Sunday of week 6', () {
      // 节假日调休：第 6 周周日 补 第 5 周周五 的课
      final rule = TimetableRule.createReschedule(
        sourceWeek: 5,
        sourceDayOfWeek: 5,
        targetWeek: 6,
        targetDayOfWeek: 7,
        isSwap: false,
      );

      final result = service.applyRules(testCourses, [rule]);

      // 验证第 5 周周五原课程已移走
      final fridayEnglish = result.where((c) => c.name == '大学英语' && c.dayOfWeek == 5).first;
      expect(WeekParser.parseWeeks(fridayEnglish.weeks).contains(5), isFalse);
      expect(WeekParser.parseWeeks(fridayEnglish.weeks).contains(6), isTrue);

      // 验证在周日生成了对应的补课
      final sundayEnglish = result.where((c) => c.name == '大学英语' && c.dayOfWeek == 7).toList();
      expect(sundayEnglish.isNotEmpty, isTrue);
      expect(WeekParser.parseWeeks(sundayEnglish.first.weeks), contains(6));
      expect(sundayEnglish.first.startPeriod, equals(3));
      expect(sundayEnglish.first.endPeriod, equals(4));

      final sundayPhysics = result.where((c) => c.name == '大学物理' && c.dayOfWeek == 7).toList();
      expect(sundayPhysics.isNotEmpty, isTrue);
      expect(WeekParser.parseWeeks(sundayPhysics.first.weeks), contains(6));
    });

    test('Custom course rule adds new course successfully', () {
      const customCourse = CourseModel(
        id: 'custom_1',
        name: '机器学习选修',
        teacher: '赵老师',
        classroom: '信息楼301',
        weeks: '2-10(周)',
        periods: '07-08',
        dayOfWeek: 3,
        startPeriod: 7,
        endPeriod: 8,
      );

      final rule = TimetableRule.createCustomCourse(course: customCourse);
      final result = service.applyRules(testCourses, [rule]);

      expect(result.any((c) => c.name == '机器学习选修'), isTrue);
      final found = result.firstWhere((c) => c.name == '机器学习选修');
      expect(found.dayOfWeek, equals(3));
      expect(found.startPeriod, equals(7));
      expect(found.endPeriod, equals(8));
    });

    test('Rules output can be directly serialized to ICS and parsed back without data loss', () {
      final customCourse = const CourseModel(
        id: 'custom_2',
        name: '物理实验',
        teacher: '钱老师',
        classroom: '实验楼102',
        weeks: '3-5(周)',
        periods: '05-06',
        dayOfWeek: 4,
        startPeriod: 5,
        endPeriod: 6,
      );

      final rules = [
        TimetableRule.createSuspension(startWeek: 2, endWeek: 2, courseName: '大学物理'),
        TimetableRule.createReschedule(
          sourceWeek: 3,
          sourceDayOfWeek: 5,
          targetWeek: 3,
          targetDayOfWeek: 6,
        ),
        TimetableRule.createCustomCourse(course: customCourse),
      ];

      final modifiedCourses = service.applyRules(testCourses, rules);
      final firstWeekMonday = DateTime(2026, 9, 1);

      // 生成 ICS
      final icsContent = IcsGenerator.generate(modifiedCourses, firstWeekMonday);
      expect(icsContent, contains('BEGIN:VCALENDAR'));
      expect(icsContent, contains('物理实验'));
      expect(icsContent, contains('高等数学'));

      // 解析 ICS
      final parsedCourses = IcsParser.parse(icsContent);
      expect(parsedCourses.isNotEmpty, isTrue);
      expect(parsedCourses.any((c) => c.name == '物理实验'), isTrue);
      expect(parsedCourses.any((c) => c.name == '高等数学'), isTrue);
    });
  });
}
