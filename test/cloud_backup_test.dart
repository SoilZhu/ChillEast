import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/features/cloudisk/services/cloud_backup_manager.dart';
import 'package:ChillEast/features/cloudisk/services/cloudisk_service.dart';

void main() {
  group('CloudBackupManager.buildFileName', () {
    test('formats slot + timestamp', () {
      expect(
        CloudBackupManager.buildFileName('a', DateTime(2026, 9, 26, 9, 30, 15)),
        'chilleast-backup-a-20260926-093015.json',
      );
    });

    test('lexicographic order matches chronological order', () {
      final earlier = CloudBackupManager.buildFileName(
          'a', DateTime(2026, 9, 26, 9, 30, 15));
      final later = CloudBackupManager.buildFileName(
          'a', DateTime(2026, 9, 26, 9, 31, 2));
      expect(earlier.compareTo(later) < 0, isTrue);
    });
  });

  group('CloudBackupManager.parseFileName', () {
    test('round-trips buildFileName', () {
      const name = 'chilleast-backup-b-20260926-093015.json';
      final parsed = CloudBackupManager.parseFileName(name);
      expect(parsed, isNotNull);
      expect(parsed!.slot, 'b');
      expect(parsed.stamp, '20260926-093015');
    });

    test('rejects foreign names', () {
      expect(CloudBackupManager.parseFileName('pubspec.yaml'), isNull);
      expect(
          CloudBackupManager.parseFileName('chilleast-backup-c-20260926.json'),
          isNull);
      expect(
          CloudBackupManager.parseFileName('chilleast-backup-a-latest.json'),
          isNull);
    });
  });

  group('CloudBackupManager.pickTargetSlot', () {
    test('first round uses a, then alternates', () {
      expect(CloudBackupManager.pickTargetSlot(null), 'a');
      expect(CloudBackupManager.pickTargetSlot('a'), 'b');
      expect(CloudBackupManager.pickTargetSlot('b'), 'a');
    });
  });

  group('CloudBackupManager.pickStaleEntries', () {
    List<Map<String, dynamic>> entries() => [
          {
            'id': 'new-resid',
            'name': 'chilleast-backup-b-20260926-093015.json',
            'encryptedId': 'enc-new',
            'puid': '1',
          },
          {
            'id': 'old-resid',
            'name': 'chilleast-backup-a-20260925-220000.json',
            'encryptedId': 'enc-old',
            'puid': '1',
          },
          {
            'id': 'other',
            'name': 'pubspec.yaml',
            'encryptedId': 'enc-x',
            'puid': '1',
          },
        ];

    test('keeps the fresh upload, flags other backup files', () {
      final stale =
          CloudBackupManager.pickStaleEntries(entries(), 'new-resid');
      expect(stale.map((e) => e['resid']), ['old-resid']);
    });

    test('ignores non-backup files', () {
      final stale =
          CloudBackupManager.pickStaleEntries(entries(), 'missing-resid');
      // 新文件 resid 对不上时，旧备份照样被标记（收敛清理）
      expect(stale.map((e) => e['resid']),
          containsAll(['new-resid', 'old-resid']));
      expect(stale.map((e) => e['resid']), isNot(contains('other')));
    });
  });

  group('CloudBackupManager.pickLatestBackupEntry', () {
    List<Map<String, dynamic>> entries() => [
          {
            'id': 'old-resid',
            'name': 'chilleast-backup-a-20260925-220000.json',
            'encryptedId': 'enc-old',
            'puid': '1',
          },
          {
            'id': 'new-resid',
            'name': 'chilleast-backup-b-20260926-093015.json',
            'encryptedId': 'enc-new',
            'puid': '1',
          },
          {
            'id': 'other',
            'name': 'pubspec.yaml',
            'encryptedId': 'enc-x',
            'puid': '1',
          },
          {
            'id': 'broken',
            'name': 'chilleast-backup-a-20260927-000000.json',
            'encryptedId': '',
            'puid': '1',
          },
        ];

    test('picks newest by stamp, ignores foreign and broken entries', () {
      final latest = CloudBackupManager.pickLatestBackupEntry(entries());
      expect(latest, isNotNull);
      expect(latest!['resid'], 'new-resid');
      expect(latest['slot'], 'b');
    });

    test('returns null when no backup exists', () {
      expect(
        CloudBackupManager.pickLatestBackupEntry([
          {'id': 'x', 'name': 'pubspec.yaml', 'encryptedId': 'e', 'puid': '1'},
        ]),
        isNull,
      );
    });
  });

  group('CloudiskService.parseSession', () {
    const html = '''
      <script>
      rootdir = "1040921812082581504";
      const _token = "930e5385a80fe00fcedd018b0502c004";
      const encstr = "d34171a3f77471befaf2ef6f66cfcb34"
      const currentPuid = "342380530";
      </script>
    ''';

    test('extracts session constants', () {
      final s = CloudiskService.parseSession(html);
      expect(s.puid, '342380530');
      expect(s.rootDirId, '1040921812082581504');
      expect(s.enc, 'd34171a3f77471befaf2ef6f66cfcb34');
      expect(s.token, '930e5385a80fe00fcedd018b0502c004');
    });

    test('throws auth error on login page', () {
      expect(
        () => CloudiskService.parseSession('<html>passport login</html>'),
        throwsA(isA<CloudiskAuthException>()),
      );
    });

    test('ignores p_auth_token and cx_p_token traps', () {
      // 真实首页文末 script 之前散落着 var p_auth_token = ""、
      // cx_p_token = "…"、href="?p_auth_token=" 等干扰串（见 HAR）。
      const trapped = '''
        <script>var p_auth_token = ""; cx_p_token = "11b6581db641bc297b2936a1802063c2";</script>
        <a href="/pcuserpan/squareIndex?customRootId=&p_auth_token=">x</a>
        <script>
        const rootdir = "1040921812082581504";
        const _token = "930e5385a80fe00fcedd018b0502c004";
        const encstr = "d34171a3f77471befaf2ef6f66cfcb34"
        const currentPuid = "342380530";
        </script>
      ''';
      final s = CloudiskService.parseSession(trapped);
      expect(s.token, '930e5385a80fe00fcedd018b0502c004');
      expect(s.puid, '342380530');
    });
  });

  group('CloudBackupManager.pullLatestOnStartup', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('returns null when cloud backup toggle is disabled', () async {
      SharedPreferences.setMockInitialValues({
        CloudBackupManager.toggleKey: false,
      });
      final result =
          await CloudBackupManager.instance.pullLatestOnStartup();
      expect(result, isNull);
    });

    test('returns null when toggle is not set', () async {
      SharedPreferences.setMockInitialValues({});
      final result =
          await CloudBackupManager.instance.pullLatestOnStartup();
      expect(result, isNull);
    });
  });
}
