import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/features/score/models/score_model.dart';

void main() {
  group('Score & Semester Parsing Tests', () {
    test('Parse semesterList json data', () {
      final semesterJson = {
        "code": "1",
        "Msg": "success",
        "data": [
          {
            "isdqxq": "1",
            "semesterId": "2026-2027-1",
            "semesterName": "2026-2027-1"
          },
          {
            "isdqxq": "0",
            "semesterId": "2025-2026-2",
            "semesterName": "2025-2026-2"
          },
          {
            "isdqxq": "0",
            "semesterId": "2025-2026-1",
            "semesterName": "2025-2026-1"
          }
        ]
      };

      final list = (semesterJson['data'] as List).map((item) {
        final map = item as Map<String, dynamic>;
        final id = map['semesterId']?.toString() ?? '';
        final name = map['semesterName']?.toString() ?? id;
        final isdqxq = map['isdqxq']?.toString() == '1';
        return SemesterModel(
          id: id,
          name: name,
          isActive: isdqxq,
        );
      }).toList();

      expect(list.length, 3);
      expect(list[0].id, '2026-2027-1');
      expect(list[0].name, '2026-2027-1');
      expect(list[0].isActive, true);
      expect(list[0].value, '2026-2027-1');
      expect(list[0].xq, '1');

      expect(list[1].id, '2025-2026-2');
      expect(list[1].isActive, false);
      expect(list[1].xq, '2');
    });

    test('Parse termGPA scores json data', () {
      final scoresJson = {
        "Msg": "success",
        "code": "1",
        "data": [
          {
            "studentID": "202440800233",
            "xqgpa": [],
            "pjcj": "",
            "achievement": [
              {
                "curriculumAttributes": "必修",
                "courseName": "材料力学",
                "curSemesterName": "2025-2026-2",
                "courseNature": "专业必修课",
                "examinationNature": "正常考试",
                "kcbh": "B332L18300",
                "credit": 3,
                "cj0708id": "54CEE87A2C941392E0632A06080A95C9",
                "fraction": "65"
              },
              {
                "curriculumAttributes": "必修",
                "courseName": "机械设计基础课程设计",
                "curSemesterName": "2025-2026-2",
                "courseNature": "专业必修课",
                "examinationNature": "正常考试",
                "kcbh": "B692J10011",
                "credit": 2,
                "cj0708id": "569F31CBEEDF762DE0632A06080A18AF",
                "fraction": "及格"
              },
              {
                "curriculumAttributes": "必修",
                "courseName": "液压与气压传动课程设计",
                "curSemesterName": "2025-2026-2",
                "courseNature": "专业必修课",
                "examinationNature": "正常考试",
                "kcbh": "B692J10022",
                "credit": 1,
                "cj0708id": "56E2B7D0F9DF73ACE0632A06080AD0C1",
                "fraction": "良好"
              },
              {
                "curriculumAttributes": "必修",
                "courseName": "毛泽东思想和中国特色社会主义理论体系概论",
                "curSemesterName": "2025-2026-2",
                "courseNature": "公共必修课",
                "examinationNature": "正常考试",
                "kcbh": "B621L10002",
                "credit": 3,
                "cj0708id": "56B08368636B51B5E0632A06080AEB0E",
                "fraction": "93"
              }
            ],
            "name": "朱天兆",
            "yxzxf": "101",
            "zxfjd": "268.65",
            "pjxfjd": "2.66"
          }
        ]
      };

      final rawList = scoresJson['data'] as List;
      final firstStudent = rawList.first as Map<String, dynamic>;
      final achievements = firstStudent['achievement'] as List;

      final scores = achievements.map((item) {
        final map = item as Map<String, dynamic>;
        return ScoreModel(
          courseName: map['courseName']?.toString() ?? '未知课程',
          score: map['fraction']?.toString() ?? 'N/A',
          credit: map['credit']?.toString(),
          examType: map['examinationNature']?.toString() ?? '正常考试',
          curriculumAttributes: map['curriculumAttributes']?.toString(),
          courseNature: map['courseNature']?.toString(),
          courseCode: map['kcbh']?.toString(),
          id: map['cj0708id']?.toString(),
        );
      }).toList();

      expect(scores.length, 4);

      expect(scores[0].courseName, '材料力学');
      expect(scores[0].score, '65');
      expect(scores[0].credit, '3');
      expect(scores[0].examType, '正常考试');
      expect(scores[0].courseNature, '专业必修课');
      expect(scores[0].curriculumAttributes, '必修');

      expect(scores[1].courseName, '机械设计基础课程设计');
      expect(scores[1].score, '及格');

      expect(scores[2].courseName, '液压与气压传动课程设计');
      expect(scores[2].score, '良好');

      expect(scores[3].courseName, '毛泽东思想和中国特色社会主义理论体系概论');
      expect(scores[3].score, '93');
    });
  });
}
