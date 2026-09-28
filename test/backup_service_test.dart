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
  });
}
