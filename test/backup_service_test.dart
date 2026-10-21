import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/features/profile/services/backup_export_service.dart';

void main() {
  group('BackupExportService.parseBackupJson', () {
    test('accepts valid legacy and modern backup payloads', () {
      final legacyRaw = jsonEncode({
        'format': 'chilleast-backup',
        'version': 1,
        'settings': {},
        'localData': {},
      });
      final parsedLegacy = BackupExportService.parseBackupJson(legacyRaw);
      expect(parsedLegacy['format'], 'chilleast-backup');
      expect(parsedLegacy['version'], 1);

      final modernRaw = jsonEncode({
        'format': 'chilleast-modern',
        'version': 1,
        'settings': {},
        'localData': {},
      });
      final parsedModern = BackupExportService.parseBackupJson(modernRaw);
      expect(parsedModern['format'], 'chilleast-modern');
      expect(parsedModern['version'], 1);
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
    late io.Directory tempDir;

    setUpAll(() async {
      tempDir = await io.Directory.systemTemp.createTemp('backup-test-');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              (call) async => tempDir.path);
    });

    tearDownAll(() async {
      await tempDir.delete(recursive: true);
    });

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

    test('buildBackupData excludes school caches and only includes manual homework', () async {
      SharedPreferences.setMockInitialValues({
        'cached_library_reserves': jsonEncode([{'title': 'seat 1'}]),
        'cached_leave_items': jsonEncode([{'id': 'leave1'}]),
        'cached_questionnaire_items': jsonEncode([{'id': 'q1'}]),
        'cached_ongoing_repair_items': jsonEncode([{'id': 'r1'}]),
      });

      final backup = await BackupExportService.buildBackupData();
      final localData = backup['localData'] as Map<String, dynamic>;

      // 学工与日常功能缓存不再包含在 localData 中
      expect(localData.containsKey('libraryReserves'), isFalse);
      expect(localData.containsKey('leaveItems'), isFalse);
      expect(localData.containsKey('questionnaireItems'), isFalse);
      expect(localData.containsKey('repairItems'), isFalse);
    });

    test('applyBackupData merges manual homework and ignores cloud school caches', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final cloudBackup = {
        'format': 'chilleast-backup',
        'version': 1,
        'settings': {},
        'localData': {
          'homeworkList': [
            {'id': 'manual_1', 'title': '手动作业1', 'isManual': true},
            {'id': 'scraped_1', 'title': '超星作业1', 'isManual': false}, // 爬取作业不应被当作手动作业写入
          ],
          // 旧备份中可能残留的缓存字段
          'libraryReserves': [{'title': 'seat 1'}],
          'leaveItems': [{'id': 'leave1'}],
          'questionnaireItems': [{'id': 'q1'}],
          'repairItems': [{'id': 'r1'}],
        },
      };

      await BackupExportService.applyBackupData(cloudBackup);

      // 验证学工缓存不会被写回 SharedPreferences
      expect(prefs.containsKey('cached_library_reserves'), isFalse);
      expect(prefs.containsKey('cached_leave_items'), isFalse);
      expect(prefs.containsKey('cached_questionnaire_items'), isFalse);
      expect(prefs.containsKey('cached_ongoing_repair_items'), isFalse);
    });

    test('buildBackupData includes customCourseColors and manual exams only', () async {
      SharedPreferences.setMockInitialValues({
        'custom_course_colors': jsonEncode({'Math': 0xFFD32F2F}),
      });

      final examFile = io.File('${tempDir.path}/exam_schedule_list.json');
      final futureDate =
          DateTime.now().add(const Duration(days: 3)).toIso8601String();
      final pastDate =
          DateTime.now().subtract(const Duration(days: 3)).toIso8601String();

      await examFile.writeAsString(jsonEncode([
        {'id': 'exam_manual_1', 'title': '英语期末考', 'time': futureDate, 'isManual': true},
        {'id': 'exam_scraped_1', 'title': '高数网课考', 'time': futureDate, 'isManual': false},
        {'id': 'exam_expired_1', 'title': '历史过期考', 'time': pastDate, 'isManual': true},
      ]));

      final backup = await BackupExportService.buildBackupData();
      final settings = backup['settings'] as Map<String, dynamic>;
      final localData = backup['localData'] as Map<String, dynamic>;

      expect(settings['customCourseColors'], {'Math': 0xFFD32F2F});

      final examList = localData['examList'] as List<dynamic>;
      expect(examList.length, 1);
      expect(examList[0]['id'], 'exam_manual_1');
      expect(examList[0]['isManual'], isTrue);
    });

    test('applyBackupData merges customCourseColors properly', () async {
      SharedPreferences.setMockInitialValues({
        'custom_course_colors': jsonEncode({
          'English': 0xFFC2185B,
          'Math': 0xFF388E3C,
        }),
      });
      final prefs = await SharedPreferences.getInstance();

      final cloudBackup = {
        'format': 'chilleast-backup',
        'version': 1,
        'settings': {
          'customCourseColors': {
            'Math': 0xFFD32F2F, // 覆盖 Math
            'Physics': 0xFF1976D2, // 新增 Physics
          },
        },
        'localData': {},
      };

      await BackupExportService.applyBackupData(cloudBackup);

      final resultRaw = prefs.getString('custom_course_colors');
      expect(resultRaw, isNotNull);
      final resultMap = jsonDecode(resultRaw!) as Map<String, dynamic>;

      expect(resultMap['Math'], 0xFFD32F2F);
      expect(resultMap['English'], 0xFFC2185B);
      expect(resultMap['Physics'], 0xFF1976D2);
    });

    test('applyBackupData merges manual exams and preserves scraped exams', () async {
      SharedPreferences.setMockInitialValues({});
      final examFile = io.File('${tempDir.path}/exam_schedule_list.json');

      final futureDate =
          DateTime.now().add(const Duration(days: 5)).toIso8601String();
      final pastDate =
          DateTime.now().subtract(const Duration(days: 5)).toIso8601String();

      // 本地初始状态：包含一个本地手动作业和一个爬取作业
      await examFile.writeAsString(jsonEncode([
        {'id': 'local_manual_1', 'title': '本地手动原考', 'time': futureDate, 'isManual': true},
        {'id': 'local_scraped_1', 'title': '本地超星原考', 'time': futureDate, 'isManual': false},
      ]));

      final cloudBackup = {
        'format': 'chilleast-backup',
        'version': 1,
        'settings': {},
        'localData': {
          'examList': [
            {'id': 'local_manual_1', 'title': '云端覆盖手动考', 'time': futureDate, 'isManual': true},
            {'id': 'cloud_manual_2', 'title': '云端新增手动考', 'time': futureDate, 'isManual': true},
            {'id': 'cloud_scraped_2', 'title': '云端爬取考', 'time': futureDate, 'isManual': false}, // 爬取考不应合入
            {'id': 'cloud_expired_3', 'title': '云端过期手动考', 'time': pastDate, 'isManual': true}, // 过期考应被过滤
          ],
        },
      };

      await BackupExportService.applyBackupData(cloudBackup);

      final content = await examFile.readAsString();
      final list = jsonDecode(content) as List<dynamic>;

      // 应该保留：覆盖后的 local_manual_1, 新增的 cloud_manual_2, 原有的 local_scraped_1
      expect(list.length, 3);
      final ids = list.map((e) => e['id']).toSet();
      expect(ids.contains('local_manual_1'), isTrue);
      expect(ids.contains('cloud_manual_2'), isTrue);
      expect(ids.contains('local_scraped_1'), isTrue);
      expect(ids.contains('cloud_scraped_2'), isFalse);
      expect(ids.contains('cloud_expired_3'), isFalse);

      final updatedManual = list.firstWhere((e) => e['id'] == 'local_manual_1');
      expect(updatedManual['title'], '云端覆盖手动考');
    });
  });

  group('BackupExportService unknown fields preservation (Round-tripping)', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    late io.Directory tempDir;

    setUpAll(() async {
      tempDir = await io.Directory.systemTemp.createTemp('backup-unknown-test-');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              (call) async => tempDir.path);
    });

    tearDownAll(() async {
      await tempDir.delete(recursive: true);
    });

    test('extractUnknownFields extracts unknown keys at all levels and ignores known keys', () {
      final payload = {
        'format': 'chilleast-modern',
        'version': 1,
        'exportedAt': '2026-10-21T00:00:00Z',
        'appVersion': '1.0.0+1',
        'futureTopKey': 'extra_top_level_value',
        'settings': {
          'languageCode': 'zh',
          'courseReminderMinutes': 15,
          'futureSettingA': 999,
          'appearance': {
            'homeItems': [
              {'id': 'bus', 'isVisible': true},
              {'id': 'future_tool_x', 'isVisible': true},
            ],
            'futureAppearanceColor': '#FFAABB',
            'functionGroupOrder': ['groupStudy', 'future_group_z'],
          },
          'ai': {
            'model': 'gpt-4o',
            'futureAiParam': true,
          },
          'timetableSubscription': {
            'enabled': true,
            'futureSubField': 'custom_url',
          },
        },
        'localData': {
          'courses': [{'name': 'Math'}],
          'futureModuleData': {'test': 123},
        },
      };

      final unknown = BackupExportService.extractUnknownFields(payload);

      expect(unknown['futureTopKey'], 'extra_top_level_value');
      expect(unknown.containsKey('format'), isFalse);
      expect(unknown.containsKey('version'), isFalse);

      final settings = unknown['settings'] as Map<String, dynamic>;
      expect(settings['futureSettingA'], 999);
      expect(settings.containsKey('languageCode'), isFalse);
      expect(settings.containsKey('courseReminderMinutes'), isFalse);

      final app = settings['appearance'] as Map<String, dynamic>;
      expect(app['futureAppearanceColor'], '#FFAABB');
      final listItems = app['_unknownListItems'] as Map<String, dynamic>;
      final homeItems = listItems['homeItems'] as List;
      expect(homeItems.length, 1);
      expect(homeItems.first['id'], 'future_tool_x');
      final groupOrder = listItems['functionGroupOrder'] as List;
      expect(groupOrder, ['future_group_z']);

      final ai = settings['ai'] as Map<String, dynamic>;
      expect(ai['futureAiParam'], true);
      expect(ai.containsKey('model'), isFalse);

      final sub = settings['timetableSubscription'] as Map<String, dynamic>;
      expect(sub['futureSubField'], 'custom_url');
      expect(sub.containsKey('enabled'), isFalse);

      final localData = unknown['localData'] as Map<String, dynamic>;
      expect(localData['futureModuleData'], {'test': 123});
      expect(localData.containsKey('courses'), isFalse);
    });

    test('mergeUnknownFields merges unknown fields back into base backup', () {
      final base = {
        'format': 'chilleast-modern',
        'version': 1,
        'settings': {
          'languageCode': 'en',
          'appearance': {
            'homeItems': [
              {'id': 'courses', 'isVisible': false},
            ],
            'functionGroupOrder': ['daily'],
          },
          'ai': {'model': 'base_model'},
          'timetableSubscription': {'enabled': false},
        },
        'localData': {
          'courses': [],
        },
      };

      final unknown = {
        'futureTopKey': 'extra_val',
        'settings': {
          'futureSettingA': 123,
          'appearance': {
            'futureAppearanceColor': '#FFF',
            '_unknownListItems': {
              'homeItems': [
                {'id': 'future_tool_x', 'isVisible': true},
              ],
              'functionGroupOrder': ['future_group_z'],
            },
          },
          'ai': {'futureAiParam': 'param1'},
          'timetableSubscription': {'futureSubField': 'sub1'},
        },
        'localData': {
          'futureModuleData': {'saved': true},
        },
      };

      final merged = BackupExportService.mergeUnknownFields(base, unknown);

      expect(merged['futureTopKey'], 'extra_val');
      final settings = merged['settings'] as Map<String, dynamic>;
      expect(settings['languageCode'], 'en');
      expect(settings['futureSettingA'], 123);

      final app = settings['appearance'] as Map<String, dynamic>;
      expect(app['futureAppearanceColor'], '#FFF');
      final homeItems = app['homeItems'] as List;
      expect(homeItems.length, 2);
      expect(homeItems[0]['id'], 'courses');
      expect(homeItems[1]['id'], 'future_tool_x');
      final groupOrder = app['functionGroupOrder'] as List;
      expect(groupOrder, ['daily', 'future_group_z']);

      final ai = settings['ai'] as Map<String, dynamic>;
      expect(ai['model'], 'base_model');
      expect(ai['futureAiParam'], 'param1');

      final sub = settings['timetableSubscription'] as Map<String, dynamic>;
      expect(sub['enabled'], false);
      expect(sub['futureSubField'], 'sub1');

      final localData = merged['localData'] as Map<String, dynamic>;
      expect(localData['futureModuleData'], {'saved': true});
    });

    test('round-trip: applyBackupData saves unknown fields, buildBackupData stitches them back', () async {
      SharedPreferences.setMockInitialValues({});
      await BackupExportService.clearUnknownFields();

      final futureCloudBackup = {
        'format': 'chilleast-modern',
        'version': 1,
        'futureGlobalConfig': {'featureFlag': true},
        'settings': {
          'languageCode': 'zh',
          'futureCustomSetting': 'awesome_value',
          'appearance': {
            'homeItems': [
              {'id': 'bus', 'isVisible': true},
              {'id': 'future_tool_abc', 'isVisible': true},
            ],
            'futureThemeName': 'cyberpunk',
          },
        },
        'localData': {
          'futureFeatureCollection': [{'id': 1, 'text': 'hello'}],
        },
      };

      // 1. 低版本拉取/导入该高版本备份
      await BackupExportService.applyBackupData(futureCloudBackup);

      // 2. 验证暗盒已经落盘保存
      final loadedUnknown = await BackupExportService.loadUnknownFields();
      expect(loadedUnknown, isNotNull);
      expect(loadedUnknown!['futureGlobalConfig'], {'featureFlag': true});

      // 3. 低版本修改了本地数据并触发 buildBackupData 组装
      final built = await BackupExportService.buildBackupData();

      // 4. 验证生成的备份不仅包含本地数据，还完美拼回了高版本的未知数据
      expect(built['futureGlobalConfig'], {'featureFlag': true});
      final builtSettings = built['settings'] as Map<String, dynamic>;
      expect(builtSettings['futureCustomSetting'], 'awesome_value');
      final builtApp = builtSettings['appearance'] as Map<String, dynamic>;
      expect(builtApp['futureThemeName'], 'cyberpunk');
      final homeItems = builtApp['homeItems'] as List;
      expect(homeItems.any((e) => e['id'] == 'future_tool_abc'), isTrue);

      final builtLocal = built['localData'] as Map<String, dynamic>;
      expect(builtLocal['futureFeatureCollection'], [{'id': 1, 'text': 'hello'}]);

      // 5. 验证防幽灵数据（Zombie Data Prevention）：
      // 当随后的云端快照已经不再包含该功能数据（用户在新设备删除了），再次 apply 后暗盒被清空
      final cleanBackup = {
        'format': 'chilleast-modern',
        'version': 1,
        'settings': {'languageCode': 'zh'},
        'localData': {},
      };
      await BackupExportService.applyBackupData(cleanBackup);

      final clearedUnknown = await BackupExportService.loadUnknownFields();
      expect(clearedUnknown, isNull);

      final builtAgain = await BackupExportService.buildBackupData();
      expect(builtAgain.containsKey('futureGlobalConfig'), isFalse);
      expect((builtAgain['settings'] as Map).containsKey('futureCustomSetting'), isFalse);
    });

    test('clearUnknownFields removes passthrough file and prevents leakage across accounts', () async {
      await BackupExportService.saveUnknownFields({'secretKey': 'secret_val'});
      expect(await BackupExportService.loadUnknownFields(), isNotNull);

      await BackupExportService.clearUnknownFields();
      expect(await BackupExportService.loadUnknownFields(), isNull);
    });
  });
}
