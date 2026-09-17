import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/features/timetable/parsers/ydjwxt_json_parser.dart';
import 'package:ChillEast/features/timetable/utils/ics_generator.dart';

void main() {
  group('YdjwxtJsonParser - Period parsing tests', () {
    test('Should parse 2-period course correctly (e.g. 10102 -> 1-2)', () {
      final json = {
        "code": "1",
        "data": [
          {
            "date": [],
            "courses": [
              {
                "courseName": "习近平新时代中国特色社会主义思想概论",
                "teacherName": "柳博",
                "classroomName": "",
                "classWeek": "2-7",
                "classTime": "10102",
                "weekDay": "1",
                "weekNoteDetail": "101,102",
                "coursesNote": 2,
              }
            ]
          }
        ]
      };

      final courses = YdjwxtJsonParser.parseWeekJson(json);
      expect(courses.length, 1);
      expect(courses[0].startPeriod, 1);
      expect(courses[0].endPeriod, 2);
      expect(courses[0].periods, '01-02');
      expect(courses[0].dayOfWeek, 1);
    });

    test('Should parse 4-period course correctly (e.g. 609101112 -> 9-12)', () {
      final json = {
        "code": "1",
        "data": [
          {
            "date": [],
            "courses": [
              {
                "courseName": "机器人学",
                "teacherName": "刘天宇",
                "classroomName": "八教南617(微机)",
                "classWeek": "4-6",
                "classTime": "609101112",
                "weekDay": "6",
                "weekNoteDetail": "609,610,611,612",
                "coursesNote": 4,
                "startTime": "19:30",
                "endTIme": "23:00",
              }
            ]
          }
        ]
      };

      final courses = YdjwxtJsonParser.parseWeekJson(json);
      expect(courses.length, 1);
      expect(courses[0].name, '机器人学');
      expect(courses[0].startPeriod, 9);
      expect(courses[0].endPeriod, 12);
      expect(courses[0].periods, '09-12');
      expect(courses[0].dayOfWeek, 6);
    });

    test('Should parse 4-period course with weekNoteDetail fallback when classTime is empty', () {
      final json = {
        "code": "1",
        "data": [
          {
            "date": [],
            "courses": [
              {
                "courseName": "机器人学",
                "teacherName": "刘天宇",
                "classroomName": "八教南617(微机)",
                "classWeek": "4-6",
                "classTime": "",
                "weekDay": "6",
                "weekNoteDetail": "609,610,611,612",
                "coursesNote": 4,
              }
            ]
          }
        ]
      };

      final courses = YdjwxtJsonParser.parseWeekJson(json);
      expect(courses.length, 1);
      expect(courses[0].startPeriod, 9);
      expect(courses[0].endPeriod, 12);
      expect(courses[0].periods, '09-12');
    });

    test('Should generate ICS with full duration 19:30 - 23:00 for 4-period course', () {
      final json = {
        "code": "1",
        "data": [
          {
            "date": [],
            "courses": [
              {
                "courseName": "机器人学",
                "teacherName": "刘天宇",
                "classroomName": "八教南617(微机)",
                "classWeek": "4-6",
                "classTime": "609101112",
                "weekDay": "6",
                "weekNoteDetail": "609,610,611,612",
                "coursesNote": 4,
              }
            ]
          }
        ]
      };

      final courses = YdjwxtJsonParser.parseWeekJson(json);
      final firstWeekMonday = DateTime(2026, 8, 31);
      final ics = IcsGenerator.generate(courses, firstWeekMonday);

      // Week 4 Saturday should be 2026-09-26
      expect(ics.contains('DTSTART:20260926T193000'), isTrue);
      expect(ics.contains('DTEND:20260926T230000'), isTrue);
    });
  });
}
