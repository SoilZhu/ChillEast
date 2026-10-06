import 'dart:convert';
import 'dart:io';
import 'package:ChillEast/features/dormitory/models/dormitory_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DormitoryInfo Parser Tests', () {
    test('Correctly parses HAR response HTML with assigned bed', () {
      final harFile = File('/home/soilzhu/下载/查询床位.har');
      expect(harFile.existsSync(), isTrue);

      final harJson = json.decode(harFile.readAsStringSync()) as Map<String, dynamic>;
      final entries = harJson['log']['entries'] as List<dynamic>;
      final entry5 = entries[5] as Map<String, dynamic>;
      final html = entry5['response']['content']['text'] as String;

      final info = DormitoryInfo.fromHtml(html);

      expect(info.isAssigned, isTrue);
      expect(info.building, equals('金岸1栋'));
      expect(info.unit, isNull);
      expect(info.floor, equals('第6层'));
      expect(info.room, equals('629'));
      expect(info.bed, equals('4'));
      expect(info.academicYear, equals('2026'));
      expect(info.termCode, equals('1'));
      expect(info.termName, equals('秋季学期'));
      expect(info.formattedRoom, equals('金岸1栋 629室'));
      expect(info.formattedBed, equals('4号床'));
      expect(info.fullAddress, equals('金岸1栋 629室 4号床'));
      expect(info.fields.length, equals(5));
      expect(info.fields.any((f) => f.code == 'ssl' && f.value == '金岸1栋'), isTrue);
      expect(info.fields.any((f) => f.code == 'fj' && f.value == '629'), isTrue);
    });

    test('Correctly handles unit when present', () {
      const htmlWithUnit = '''
        <script>
          SFSchCalendar.curXn = "2026";
          SFSchCalendar.curXq = "1";
          SFSchCalendar.curXqMc = "秋季学期";
          var ch = "2";
          function loadData() {
            view.createRow("ssl", "宿舍楼", "丰泽3栋");
            view.createRow("dy", "单元", "2单元");
            view.createRow("lc", "楼层", "第3层");
            view.createRow("fj", "宿舍", "305");
            view.createRow("ch", "床号", "2");
          }
        </script>
      ''';

      final info = DormitoryInfo.fromHtml(htmlWithUnit);

      expect(info.isAssigned, isTrue);
      expect(info.building, equals('丰泽3栋'));
      expect(info.unit, equals('2单元'));
      expect(info.floor, equals('第3层'));
      expect(info.room, equals('305'));
      expect(info.bed, equals('2'));
      expect(info.formattedRoom, equals('丰泽3栋 2单元 305室'));
      expect(info.fullAddress, equals('丰泽3栋 2单元 305室 2号床'));
    });

    test('Correctly identifies unassigned bed', () {
      const unassignedHtml = '''
        <script>
          SFSchCalendar.curXn = "2026";
          SFSchCalendar.curXq = "1";
          SFSchCalendar.curXqMc = "秋季学期";
          var ch = "";
          function loadData() {
            view.createRow("ssl", "宿舍楼", "未安排床位");
          }
        </script>
      ''';

      final info = DormitoryInfo.fromHtml(unassignedHtml);

      expect(info.isAssigned, isFalse);
      expect(info.formattedRoom, equals('未安排床位'));
      expect(info.fullAddress, equals('未安排床位'));
    });

    test('Ignores commented code containing 未安排床位', () {
      const commentedHtml = '''
        <script>
          var ch = "1";
          function loadData() {
            // view.createRow("ssl", "宿舍楼", "未安排床位");
            /* view.createRow("ssl", "宿舍楼", "未安排床位"); */
            view.createRow("ssl", "宿舍楼", "芷兰4栋");
            view.createRow("fj", "宿舍", "101");
            view.createRow("ch", "床号", "1");
          }
        </script>
      ''';

      final info = DormitoryInfo.fromHtml(commentedHtml);

      expect(info.isAssigned, isTrue);
      expect(info.building, equals('芷兰4栋'));
      expect(info.room, equals('101'));
      expect(info.bed, equals('1'));
    });

    test('JSON serialization and deserialization roundtrip works', () {
      const original = DormitoryInfo(
        isAssigned: true,
        building: '金岸1栋',
        unit: '1单元',
        floor: '第6层',
        room: '629',
        bed: '4',
        academicYear: '2026',
        termCode: '1',
        termName: '秋季学期',
        fields: [
          DormitoryField(code: 'ssl', label: '宿舍楼', value: '金岸1栋'),
          DormitoryField(code: 'fj', label: '宿舍', value: '629'),
        ],
      );

      final jsonMap = original.toJson();
      final restored = DormitoryInfo.fromJson(jsonMap);

      expect(restored.isAssigned, equals(original.isAssigned));
      expect(restored.building, equals(original.building));
      expect(restored.unit, equals(original.unit));
      expect(restored.floor, equals(original.floor));
      expect(restored.room, equals(original.room));
      expect(restored.bed, equals(original.bed));
      expect(restored.academicYear, equals(original.academicYear));
      expect(restored.termCode, equals(original.termCode));
      expect(restored.termName, equals(original.termName));
      expect(restored.fields.length, equals(2));
      expect(restored.fields.first.label, equals('宿舍楼'));
    });
  });
}
