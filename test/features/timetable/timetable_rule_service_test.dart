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

    test('Reschedule rule moves Friday courses of week 5 to Sunday of week 6 (move / shift)', () {
      // 节假日调休：第 6 周周日 补 第 5 周周五 的课
      final rule = TimetableRule.createReschedule(
        sourceWeek: 5,
        sourceDayOfWeek: 5,
        targetWeek: 6,
        targetDayOfWeek: 7,
        action: 'move',
      );
      expect(rule.description, contains('（平移）'));

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

    test('Reschedule rule with action copy copies courses while preserving source courses', () {
      final rule = TimetableRule.createReschedule(
        sourceWeek: 5,
        sourceDayOfWeek: 5,
        targetWeek: 6,
        targetDayOfWeek: 7,
        action: 'copy',
      );
      expect(rule.description, contains('（复制）'));

      final result = service.applyRules(testCourses, [rule]);

      // 验证第 5 周周五原课程依然保留！
      final fridayEnglish = result.where((c) => c.name == '大学英语' && c.dayOfWeek == 5).first;
      expect(WeekParser.parseWeeks(fridayEnglish.weeks).contains(5), isTrue);

      final fridayPhysics = result.where((c) => c.name == '大学物理' && c.dayOfWeek == 5).first;
      expect(WeekParser.parseWeeks(fridayPhysics.weeks).contains(5), isTrue);

      // 验证在周日同样生成了对应的副本
      final sundayEnglish = result.where((c) => c.name == '大学英语' && c.dayOfWeek == 7).toList();
      expect(sundayEnglish.isNotEmpty, isTrue);
      expect(WeekParser.parseWeeks(sundayEnglish.first.weeks), contains(6));

      final sundayPhysics = result.where((c) => c.name == '大学物理' && c.dayOfWeek == 7).toList();
      expect(sundayPhysics.isNotEmpty, isTrue);
      expect(WeekParser.parseWeeks(sundayPhysics.first.weeks), contains(6));
    });

    test('Reschedule rule with action swap swaps courses between source and target days', () {
      final rule = TimetableRule.createReschedule(
        sourceWeek: 5,
        sourceDayOfWeek: 1, // 周一高等数学
        targetWeek: 5,
        targetDayOfWeek: 5, // 周五大学英语+大学物理
        action: 'swap',
      );
      expect(rule.description, contains('（对调）'));

      final result = service.applyRules(testCourses, [rule]);

      // 验证周一有了周五的课，且不再有高数
      final mondayMath = result.where((c) => c.name == '高等数学' && c.dayOfWeek == 1).first;
      expect(WeekParser.parseWeeks(mondayMath.weeks).contains(5), isFalse);

      final mondayEnglish = result.where((c) => c.name == '大学英语' && c.dayOfWeek == 1).toList();
      expect(mondayEnglish.isNotEmpty, isTrue);
      expect(WeekParser.parseWeeks(mondayEnglish.first.weeks), contains(5));

      // 验证周五有了周一的高数，且不再有原本的英语和物理
      final fridayMath = result.where((c) => c.name == '高等数学' && c.dayOfWeek == 5).toList();
      expect(fridayMath.isNotEmpty, isTrue);
      expect(WeekParser.parseWeeks(fridayMath.first.weeks), contains(5));

      final fridayEnglish = result.where((c) => c.name == '大学英语' && c.dayOfWeek == 5).first;
      expect(WeekParser.parseWeeks(fridayEnglish.weeks).contains(5), isFalse);
    });

    test('In copy and move modes, target day original courses are overwritten', () {
      // 1. 复制模式：把周一高数复制到周五（第 5 周）
      final copyRule = TimetableRule.createReschedule(
        sourceWeek: 5,
        sourceDayOfWeek: 1, // 周一高等数学
        targetWeek: 5,
        targetDayOfWeek: 5, // 周五大学英语+大学物理
        action: 'copy',
      );
      final copyResult = service.applyRules(testCourses, [copyRule]);

      // 源日期周一高数依然保留（复制特性）
      final mondayMathCopy = copyResult.where((c) => c.name == '高等数学' && c.dayOfWeek == 1).first;
      expect(WeekParser.parseWeeks(mondayMathCopy.weeks).contains(5), isTrue);

      // 目标日周五原本的英语和物理被覆盖（不包含第 5 周）
      final fridayEnglishCopy = copyResult.where((c) => c.name == '大学英语' && c.dayOfWeek == 5).first;
      expect(WeekParser.parseWeeks(fridayEnglishCopy.weeks).contains(5), isFalse);
      final fridayPhysicsCopy = copyResult.where((c) => c.name == '大学物理' && c.dayOfWeek == 5).first;
      expect(WeekParser.parseWeeks(fridayPhysicsCopy.weeks).contains(5), isFalse);

      // 目标日周五排上了高数
      final fridayMathCopy = copyResult.where((c) => c.name == '高等数学' && c.dayOfWeek == 5).toList();
      expect(fridayMathCopy.isNotEmpty, isTrue);
      expect(WeekParser.parseWeeks(fridayMathCopy.first.weeks), contains(5));

      // 2. 平移模式：把周一高数平移到周五（第 5 周）
      final moveRule = TimetableRule.createReschedule(
        sourceWeek: 5,
        sourceDayOfWeek: 1,
        targetWeek: 5,
        targetDayOfWeek: 5,
        action: 'move',
      );
      final moveResult = service.applyRules(testCourses, [moveRule]);

      // 源日期周一高数被移走（平移特性）
      final mondayMathMove = moveResult.where((c) => c.name == '高等数学' && c.dayOfWeek == 1).first;
      expect(WeekParser.parseWeeks(mondayMathMove.weeks).contains(5), isFalse);

      // 目标日周五原本的英语和物理被覆盖（不包含第 5 周）
      final fridayEnglishMove = moveResult.where((c) => c.name == '大学英语' && c.dayOfWeek == 5).first;
      expect(WeekParser.parseWeeks(fridayEnglishMove.weeks).contains(5), isFalse);
      final fridayPhysicsMove = moveResult.where((c) => c.name == '大学物理' && c.dayOfWeek == 5).first;
      expect(WeekParser.parseWeeks(fridayPhysicsMove.weeks).contains(5), isFalse);

      // 目标日周五排上了高数
      final fridayMathMove = moveResult.where((c) => c.name == '高等数学' && c.dayOfWeek == 5).toList();
      expect(fridayMathMove.isNotEmpty, isTrue);
      expect(WeekParser.parseWeeks(fridayMathMove.first.weeks), contains(5));
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
