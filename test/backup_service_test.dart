import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
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
}
