import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/features/profile/services/backup_export_service.dart';

void main() {
  group('BackupExportService.parseBackupJson', () {
    test('accepts a valid backup payload', () {
      final raw = jsonEncode({
        'format': 'chilleast-backup',
        'version': 1,
        'settings': {},
        'localData': {},
      });
      final parsed = BackupExportService.parseBackupJson(raw);
      expect(parsed['format'], 'chilleast-backup');
      expect(parsed['version'], 1);
    });

    test('rejects non-JSON text', () {
      expect(
        () => BackupExportService.parseBackupJson('not json{{{'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects foreign format', () {
      final raw = jsonEncode({'format': 'other-app', 'version': 1});
      expect(
        () => BackupExportService.parseBackupJson(raw),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects newer version', () {
      final raw = jsonEncode({
        'format': 'chilleast-backup',
        'version': BackupExportService.backupVersion + 1,
      });
      expect(
        () => BackupExportService.parseBackupJson(raw),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('rejects missing version', () {
      final raw = jsonEncode({'format': 'chilleast-backup'});
      expect(
        () => BackupExportService.parseBackupJson(raw),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('BackupExportService.applyBackupData widgetItems', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('restores widget_function_items and syncs widget_quick_ids', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final backup = {
        'format': 'chilleast-backup',
        'version': 1,
        'settings': {
          'appearance': {
            'widgetItems': [
              {'id': 'bus', 'isVisible': true},
              {'id': 'score', 'isVisible': true},
              {'id': 'library', 'isVisible': false},
            ],
          },
        },
        'localData': {},
      };

      await BackupExportService.applyBackupData(backup);

      final widgetJson = prefs.getString('widget_function_items');
      expect(widgetJson, isNotNull);
      final widgetList = jsonDecode(widgetJson!) as List;
      expect(widgetList.length, 3);
      expect(widgetList[0]['id'], 'bus');

      final quickIdsJson = prefs.getString('widget_quick_ids');
      expect(quickIdsJson, isNotNull);
      final quickIds = jsonDecode(quickIdsJson!) as List;
      expect(quickIds, ['bus', 'score']);
    });

    test('buildBackupData includes widgetItems when set in prefs', () async {
      SharedPreferences.setMockInitialValues({
        'widget_function_items': jsonEncode([
          {'id': 'bus', 'isVisible': true},
        ]),
      });

      final backup = await BackupExportService.buildBackupData();
      final appearance = backup['settings']['appearance'] as Map<String, dynamic>;
      expect(appearance['widgetItems'], isNotNull);
      expect((appearance['widgetItems'] as List).first['id'], 'bus');
    });

    test('reconciles function items: drops unknown cloud items, keeps local-only items, overwrites matching items', () async {
      SharedPreferences.setMockInitialValues({
        'app_language_code': 'zh',
        'course_reminder_minutes': 15,
        'widget_function_items': jsonEncode([
          {'id': 'bus', 'isVisible': true},
          {'id': 'library', 'isVisible': true},
        ]),
      });
      final prefs = await SharedPreferences.getInstance();

      final cloudBackup = {
        'format': 'chilleast-backup',
        'version': 1,
        'settings': {
          'courseReminderMinutes': 30, // 覆盖本地为 30
          // 未提供 languageCode：应继续保留本地的 'zh'
          'appearance': {
            'widgetItems': [
              {'id': 'bus', 'isVisible': false}, // 覆盖本地 bus 为 false
              {'id': 'score', 'isVisible': true}, // 云端新增的合法功能项
              {'id': 'unknown_alien_feature', 'isVisible': true}, // 本地没有的未知项目：当它不存在
            ],
          },
        },
        'localData': {},
      };

      await BackupExportService.applyBackupData(cloudBackup);

      // 1. 验证常规配置：云端有的覆盖，云端没有的保留本地
      expect(prefs.getInt('course_reminder_minutes'), 30);
      expect(prefs.getString('app_language_code'), 'zh');

      // 2. 验证外观项目合并：
      final widgetJson = prefs.getString('widget_function_items');
      expect(widgetJson, isNotNull);
      final widgetList = jsonDecode(widgetJson!) as List;

      // unknown_alien_feature 应该被丢弃
      expect(widgetList.any((e) => e['id'] == 'unknown_alien_feature'), isFalse);

      // bus 应当被云端覆盖为 isVisible: false
      final bus = widgetList.firstWhere((e) => e['id'] == 'bus');
      expect(bus['isVisible'], isFalse);

      // score 应当由云端添加为 isVisible: true
      final score = widgetList.firstWhere((e) => e['id'] == 'score');
      expect(score['isVisible'], isTrue);

      // library 在云端没有，但本地有：继续使用本地项并保留其 isVisible: true
      final library = widgetList.firstWhere((e) => e['id'] == 'library');
      expect(library['isVisible'], isTrue);
    });
  });
}
