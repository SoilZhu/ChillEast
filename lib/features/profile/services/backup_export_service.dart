import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/ai/ai_service.dart';
import '../../../core/services/home_widget_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/atomic_storage_helper.dart';
import '../../../core/utils/secure_storage_helper.dart';
import '../models/appearance_state.dart';
import '../providers/appearance_provider.dart';

/// 设置与本地资料导出（备份为单个 JSON 文件）。
///
/// 包含：
/// - SharedPreferences 中的用户设置（语言、通知、外观、课表开关、电费房间等）
/// - App 文档目录下的本地资料（课表 ICS/元数据/课程/规则、作业列表）
/// - SharedPreferences 中的本地缓存（图书馆预约、请假、问卷、报修）
///
/// 出于安全考虑，**不包含** SecureStorage 中的登录敏感数据：
/// 学号/密码、Token 等均不会写入备份。
/// AI Key 例外：仅当用户填写了自定义 Key、且与 App 内置默认 Key
///（打包时 --dart-define=DEFAULT_AI_API_KEY 注入）不同时，才会一并导出，
/// 方便换机恢复；默认 Key 本身不会写入备份。
class BackupExportService {
  static const String legacyBackupFormat = 'chilleast-backup';
  static const String modernBackupFormat = 'chilleast-modern';
  static const String backupFormat = modernBackupFormat;
  static const int backupVersion = 1;
  static const String unknownPassthroughFile = 'unknown_backup_passthrough.json';

  /// 顶级已知字段
  static const Set<String> _knownTopLevelKeys = {
    'format',
    'version',
    'exportedAt',
    'appVersion',
    'settings',
    'localData',
  };

  /// settings 下的已知一级字段
  static const Set<String> _knownSettingsKeys = {
    'languageCode',
    'courseReminderMinutes',
    'homeworkReminderHours',
    'libraryReminderMinutes',
    'courseLiveEnabled',
    'flymeLiveEnabled',
    'timetableAutoSyncEnabled',
    'timetableShowEndTime',
    'timetableSubscription',
    'manualFirstWeekMonday',
    'customCourseColors',
    'appearance',
    'electricityRoom',
    'electricityRoom2',
    'ai',
  };

  /// settings.appearance 下的已知二级字段
  static const Set<String> _knownAppearanceKeys = {
    'homeItems',
    'functionItems',
    'feedItems',
    'widgetItems',
    'functionGroupOrder',
    'hiddenFunctionGroups',
    'feedAutoSort',
  };

  /// settings.ai 下的已知二级字段
  static const Set<String> _knownAiKeys = {
    'apiUrl',
    'model',
    'apiKey',
    'hasCustomApiKey',
  };

  /// settings.timetableSubscription 下的已知二级字段
  static const Set<String> _knownSubscriptionKeys = {
    'enabled',
    'uuid',
  };

  /// localData 下的已知一级字段
  static const Set<String> _knownLocalDataKeys = {
    'timetableIcs',
    'timetableMeta',
    'courses',
    'rawCourses',
    'timetableRules',
    'homeworkList',
    'examList',
    'manualExamList',
    'aiMemories',
  };

  static bool isSupportedFormat(String? format) =>
      format == modernBackupFormat || format == legacyBackupFormat;

  /// 从给定的备份数据中提取本版本不认识的未知字段与配置项（暗盒）。
  static Map<String, dynamic> extractUnknownFields(Map<String, dynamic> backup) {
    final unknown = <String, dynamic>{};

    // 1. 顶级未知键
    for (final entry in backup.entries) {
      if (!_knownTopLevelKeys.contains(entry.key)) {
        unknown[entry.key] = entry.value;
      }
    }

    // 2. settings 下的未知键与子结构
    final rawSettings = backup['settings'];
    if (rawSettings is Map) {
      final unknownSettings = <String, dynamic>{};
      for (final entry in rawSettings.entries) {
        final key = entry.key.toString();
        if (!_knownSettingsKeys.contains(key)) {
          unknownSettings[key] = entry.value;
        }
      }

      // 2a. appearance 内部未知键与未知项
      final rawApp = rawSettings['appearance'];
      if (rawApp is Map) {
        final unknownApp = <String, dynamic>{};
        for (final entry in rawApp.entries) {
          final key = entry.key.toString();
          if (!_knownAppearanceKeys.contains(key)) {
            unknownApp[key] = entry.value;
          }
        }

        final masterIds = AppearanceNotifier.masterPool.map((e) => e.id).toSet();
        final feedIds = AppearanceNotifier.feedPool.map((e) => e.id).toSet();
        final validGroupKeys = functionGroups.map((g) => g.titleKey).toSet();

        final unknownListItems = <String, dynamic>{};

        for (final listKey in ['homeItems', 'functionItems', 'widgetItems']) {
          final list = rawApp[listKey];
          if (list is List) {
            final items = list.whereType<Map>().where((item) {
              final id = item['id']?.toString();
              return id != null && !masterIds.contains(id);
            }).map((item) => Map<String, dynamic>.from(item)).toList();
            if (items.isNotEmpty) {
              unknownListItems[listKey] = items;
            }
          }
        }

        final feedList = rawApp['feedItems'];
        if (feedList is List) {
          final items = feedList.whereType<Map>().where((item) {
            final id = item['id']?.toString();
            return id != null && !feedIds.contains(id);
          }).map((item) => Map<String, dynamic>.from(item)).toList();
          if (items.isNotEmpty) {
            unknownListItems['feedItems'] = items;
          }
        }

        final groupOrder = rawApp['functionGroupOrder'];
        if (groupOrder is List) {
          final unknownGroups = groupOrder
              .map((e) => e?.toString())
              .where((k) => k != null && !validGroupKeys.contains(k))
              .cast<String>()
              .toList();
          if (unknownGroups.isNotEmpty) {
            unknownListItems['functionGroupOrder'] = unknownGroups;
          }
        }

        final hiddenGroups = rawApp['hiddenFunctionGroups'];
        if (hiddenGroups is List) {
          final unknownHidden = hiddenGroups
              .map((e) => e?.toString())
              .where((k) => k != null && !validGroupKeys.contains(k))
              .cast<String>()
              .toList();
          if (unknownHidden.isNotEmpty) {
            unknownListItems['hiddenFunctionGroups'] = unknownHidden;
          }
        }

        if (unknownListItems.isNotEmpty) {
          unknownApp['_unknownListItems'] = unknownListItems;
        }

        if (unknownApp.isNotEmpty) {
          unknownSettings['appearance'] = unknownApp;
        }
      }

      // 2b. AI 内部未知键
      final rawAi = rawSettings['ai'];
      if (rawAi is Map) {
        final unknownAi = <String, dynamic>{};
        for (final entry in rawAi.entries) {
          final key = entry.key.toString();
          if (!_knownAiKeys.contains(key)) {
            unknownAi[key] = entry.value;
          }
        }
        if (unknownAi.isNotEmpty) {
          unknownSettings['ai'] = unknownAi;
        }
      }

      // 2c. Subscription 内部未知键
      final rawSub = rawSettings['timetableSubscription'];
      if (rawSub is Map) {
        final unknownSub = <String, dynamic>{};
        for (final entry in rawSub.entries) {
          final key = entry.key.toString();
          if (!_knownSubscriptionKeys.contains(key)) {
            unknownSub[key] = entry.value;
          }
        }
        if (unknownSub.isNotEmpty) {
          unknownSettings['timetableSubscription'] = unknownSub;
        }
      }

      if (unknownSettings.isNotEmpty) {
        unknown['settings'] = unknownSettings;
      }
    }

    // 3. localData 下的未知键
    final rawLocal = backup['localData'];
    if (rawLocal is Map) {
      final unknownLocal = <String, dynamic>{};
      for (final entry in rawLocal.entries) {
        final key = entry.key.toString();
        if (!_knownLocalDataKeys.contains(key)) {
          unknownLocal[key] = entry.value;
        }
      }
      if (unknownLocal.isNotEmpty) {
        unknown['localData'] = unknownLocal;
      }
    }

    return unknown;
  }

  /// 将未知字段暗盒合并回基础备份数据中（回填拼接）。
  static Map<String, dynamic> mergeUnknownFields(
    Map<String, dynamic> base,
    Map<String, dynamic> unknown,
  ) {
    if (unknown.isEmpty) return base;

    final result = Map<String, dynamic>.from(base);

    // 1. 顶级未知键
    for (final entry in unknown.entries) {
      if (entry.key != 'settings' && entry.key != 'localData') {
        result[entry.key] = entry.value;
      }
    }

    // 2. settings 下的未知键
    final unknownSettings = unknown['settings'];
    if (unknownSettings is Map) {
      final baseSettings = result['settings'] is Map
          ? Map<String, dynamic>.from(result['settings'] as Map)
          : <String, dynamic>{};

      for (final entry in unknownSettings.entries) {
        final key = entry.key.toString();
        if (key != 'appearance' && key != 'ai' && key != 'timetableSubscription') {
          baseSettings[key] = entry.value;
        }
      }

      // 2a. appearance
      final unknownApp = unknownSettings['appearance'];
      if (unknownApp is Map) {
        final baseApp = baseSettings['appearance'] is Map
            ? Map<String, dynamic>.from(baseSettings['appearance'] as Map)
            : <String, dynamic>{};

        for (final entry in unknownApp.entries) {
          final key = entry.key.toString();
          if (key != '_unknownListItems') {
            baseApp[key] = entry.value;
          }
        }

        final unknownListItems = unknownApp['_unknownListItems'];
        if (unknownListItems is Map) {
          for (final listKey in ['homeItems', 'functionItems', 'widgetItems', 'feedItems']) {
            final unknownItems = unknownListItems[listKey];
            if (unknownItems is List && unknownItems.isNotEmpty) {
              final baseList = baseApp[listKey] is List
                  ? List<Map<String, dynamic>>.from(
                      (baseApp[listKey] as List)
                          .whereType<Map>()
                          .map((e) => Map<String, dynamic>.from(e)))
                  : <Map<String, dynamic>>[];
              final existingIds = baseList.map((e) => e['id']?.toString()).toSet();
              for (final item in unknownItems) {
                if (item is Map) {
                  final id = item['id']?.toString();
                  if (id != null && !existingIds.contains(id)) {
                    baseList.add(Map<String, dynamic>.from(item));
                    existingIds.add(id);
                  }
                }
              }
              baseApp[listKey] = baseList;
            }
          }

          for (final groupKey in ['functionGroupOrder', 'hiddenFunctionGroups']) {
            final unknownGroups = unknownListItems[groupKey];
            if (unknownGroups is List && unknownGroups.isNotEmpty) {
              final baseList = baseApp[groupKey] is List
                  ? List<String>.from((baseApp[groupKey] as List).map((e) => e.toString()))
                  : <String>[];
              final existingSet = baseList.toSet();
              for (final g in unknownGroups) {
                final str = g.toString();
                if (!existingSet.contains(str)) {
                  baseList.add(str);
                  existingSet.add(str);
                }
              }
              baseApp[groupKey] = baseList;
            }
          }
        }

        baseSettings['appearance'] = baseApp;
      }

      // 2b. AI
      final unknownAi = unknownSettings['ai'];
      if (unknownAi is Map) {
        final baseAi = baseSettings['ai'] is Map
            ? Map<String, dynamic>.from(baseSettings['ai'] as Map)
            : <String, dynamic>{};
        for (final entry in unknownAi.entries) {
          baseAi[entry.key.toString()] = entry.value;
        }
        baseSettings['ai'] = baseAi;
      }

      // 2c. Subscription
      final unknownSub = unknownSettings['timetableSubscription'];
      if (unknownSub is Map) {
        final baseSub = baseSettings['timetableSubscription'] is Map
            ? Map<String, dynamic>.from(baseSettings['timetableSubscription'] as Map)
            : <String, dynamic>{};
        for (final entry in unknownSub.entries) {
          baseSub[entry.key.toString()] = entry.value;
        }
        baseSettings['timetableSubscription'] = baseSub;
      }

      result['settings'] = baseSettings;
    }

    // 3. localData 下的未知键
    final unknownLocal = unknown['localData'];
    if (unknownLocal is Map) {
      final baseLocal = result['localData'] is Map
          ? Map<String, dynamic>.from(result['localData'] as Map)
          : <String, dynamic>{};
      for (final entry in unknownLocal.entries) {
        baseLocal[entry.key.toString()] = entry.value;
      }
      result['localData'] = baseLocal;
    }

    return result;
  }

  /// 保存未知字段暗盒到本地存储（全量替换；为空时自动删除文件以防幽灵数据）。
  static Future<void> saveUnknownFields(Map<String, dynamic> unknownFields) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$unknownPassthroughFile');
      if (unknownFields.isEmpty) {
        if (await file.exists()) {
          await file.delete();
        }
        final bakFile = File('${file.path}.bak');
        if (await bakFile.exists()) {
          await bakFile.delete();
        }
        return;
      }
      final content = jsonEncode(unknownFields);
      await AtomicStorageHelper.atomicWriteString(file, content);
    } catch (e) {
      AppLogger.instance.w('Failed to save unknown backup passthrough fields: $e');
    }
  }

  /// 从本地存储加载未知字段暗盒。
  static Future<Map<String, dynamic>?> loadUnknownFields() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$unknownPassthroughFile');
      final decoded = await AtomicStorageHelper.readJsonWithRecovery(file,
          logTag: 'BackupExportService');
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return null;
    } catch (e) {
      AppLogger.instance.w('Failed to load unknown backup passthrough fields: $e');
      return null;
    }
  }

  /// 清除未知字段暗盒（退出登录时隔离调用）。
  static Future<void> clearUnknownFields() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$unknownPassthroughFile');
      if (await file.exists()) {
        await file.delete();
      }
      final bakFile = File('${file.path}.bak');
      if (await bakFile.exists()) {
        await bakFile.delete();
      }
    } catch (e) {
      AppLogger.instance.w('Failed to clear unknown backup passthrough fields: $e');
    }
  }

  /// 组装备份 JSON（纯 Map，可直接 jsonEncode）。
  /// [format] 默认走现代轨 'chilleast-modern'，导出文件走 'chilleast-backup'。
  static Future<Map<String, dynamic>> buildBackupData({
    String format = modernBackupFormat,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final secure = SecureStorageHelper();

    String? aiApiUrl;
    String? aiModel;
    String? aiApiKey;
    bool aiHasCustomKey = false;
    try {
      aiApiUrl = await secure.getAiApiUrl();
      aiModel = await secure.getAiModel();
      final key = await secure.getAiApiKey();
      aiHasCustomKey = key != null && key.isNotEmpty;
      // 只导出用户自定义、且与 App 内置默认 Key 不同的 Key。
      // SecureStorage 里存的本就是用户填写值；若用户把默认 Key 原样
      // 填进去，则视为默认，不写入备份。
      if (aiHasCustomKey && key != AiAssistantService.defaultApiKey) {
        aiApiKey = key;
      }
    } catch (_) {}

    String? appVersion;
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {}

    final baseData = {
      'format': format,
      'version': backupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'appVersion': appVersion,
      'settings': {
        'languageCode': prefs.getString('app_language_code'),
        'courseReminderMinutes': prefs.getInt('course_reminder_minutes') ?? 0,
        'homeworkReminderHours':
            prefs.getDouble('homework_reminder_hours') ?? 0,
        'libraryReminderMinutes':
            prefs.getInt('library_reminder_minutes') ?? 0,
        'courseLiveEnabled': prefs.getBool('course_live_enabled') ?? false,
        'flymeLiveEnabled': prefs.getBool('flyme_live_enabled') ?? false,
        'timetableAutoSyncEnabled':
            prefs.getBool('timetable_auto_sync_enabled') ?? true,
        'timetableShowEndTime':
            prefs.getBool('timetable_show_end_time') ?? false,
        'timetableSubscription': {
          'enabled': prefs.getBool('timetable_subscription_enabled') ?? false,
          'uuid': prefs.getString('timetable_subscription_uuid'),
        },
        'manualFirstWeekMonday':
            prefs.getString('timetable_first_week_monday_manual'),
        'customCourseColors':
            _decodeJson(prefs.getString('custom_course_colors')),
        'appearance': {
          'homeItems': _decodeJson(prefs.getString('home_function_items')),
          'functionItems': _decodeJson(prefs.getString('function_page_items')),
          'feedItems': _decodeJson(prefs.getString('home_feed_items')),
          'widgetItems': _decodeJson(prefs.getString('widget_function_items')),
          'functionGroupOrder':
              _decodeJson(prefs.getString('function_group_order')),
          'hiddenFunctionGroups':
              _decodeJson(prefs.getString('hidden_function_groups')),
          'feedAutoSort': prefs.getBool('feed_auto_sort') ?? false,
        },
        'electricityRoom':
            _decodeJson(prefs.getString('saved_electricity_room')),
        'electricityRoom2':
            _decodeJson(prefs.getString('saved_electricity_room_2')),
        'ai': {
          'apiUrl': aiApiUrl,
          'model': aiModel,
          // 自定义 Key（与默认 Key 相同时为 null，不导出默认 Key）
          'apiKey': aiApiKey,
          'hasCustomApiKey': aiHasCustomKey,
        },
      },
      'localData': {
        'timetableIcs': await _readDocFileText('current_timetable.ics'),
        'timetableMeta': await _readDocFileJson('timetable_meta.json'),
        'courses': await _readDocFileJson('courses.json'),
        'rawCourses': await _readDocFileJson('raw_courses.json'),
        'timetableRules': await _readDocFileJson('timetable_rules.json'),
        'homeworkList': await _readManualHomeworkJson(),
        'examList': await _readManualExamJson(),
        'aiMemories': await _readDocFileJson('ai_memories.json'),
      },
    };

    final unknown = await loadUnknownFields();
    if (unknown != null && unknown.isNotEmpty) {
      return mergeUnknownFields(baseData, unknown);
    }
    return baseData;
  }

  /// 组装备份 JSON 并写入临时文件，返回文件路径。
  /// 手动导出统一写入 legacyBackupFormat ('chilleast-backup')，确保老版本 main 亦可顺利手动导入。
  static Future<String> writeBackupFile() async {
    final data = await buildBackupData(format: legacyBackupFormat);
    final tempDir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${tempDir.path}/chilleast-backup-$stamp.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
    );
    return file.path;
  }

  /// 导出并调起系统分享。返回分享的文件路径。
  static Future<String> exportAndShare({String? shareText}) async {
    final path = await writeBackupFile();
    await Share.shareXFiles([XFile(path)], text: shareText);
    return path;
  }

  /// 解析并校验备份 JSON 文本，返回备份 Map。
  /// 格式不对抛 [FormatException]，版本过新抛 [UnsupportedError]。
  static Map<String, dynamic> parseBackupJson(String raw) {
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw const FormatException('不是有效的 JSON 备份文件');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('不是有效的备份文件');
    }
    if (!isSupportedFormat(decoded['format']?.toString())) {
      throw const FormatException('不是自在东湖备份文件');
    }
    final version = decoded['version'];
    final v = version is int ? version : int.tryParse('$version') ?? -1;
    if (v < 1) throw const FormatException('无法识别的备份版本');
    if (v > backupVersion) {
      throw UnsupportedError('备份版本过新（v$v），请先升级 App 后再导入');
    }
    return decoded;
  }

  /// 读取备份文件并解析校验。
  static Future<Map<String, dynamic>> readBackupFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const FormatException('备份文件不存在');
    }
    return parseBackupJson(await file.readAsString());
  }

  /// 将备份数据写回 SharedPreferences / 文档目录文件 / SecureStorage。
  /// 语义为：
  /// - 云端有且本地有的项：使用云端数据覆盖本地并应用。
  /// - 云端没有本地有的项：继续使用本地的项目，不删除、不清空。
  /// - 云端有本地没有的项：进入未知字段暗盒暂存，待后续上传/导出时保真回填，避免高版本功能数据被抹杀。
  static Future<void> applyBackupData(Map<String, dynamic> backup) async {
    // 先校验，避免写一半才发现版本不对
    if (!isSupportedFormat(backup['format']?.toString())) {
      throw const FormatException('不是自在东湖备份文件');
    }

    // 提取并保存未知字段暗盒（全量替换，确保跨版本保真与防死灰复活）
    final unknownFields = extractUnknownFields(backup);
    await saveUnknownFields(unknownFields);

    final settings = backup['settings'] is Map
        ? Map<String, dynamic>.from(backup['settings'] as Map)
        : <String, dynamic>{};
    final localData = backup['localData'] is Map
        ? Map<String, dynamic>.from(backup['localData'] as Map)
        : <String, dynamic>{};

    final prefs = await SharedPreferences.getInstance();

    // —— 语言 ——
    if (settings.containsKey('languageCode')) {
      final lang = _asStringOrNull(settings['languageCode']);
      if (lang != null && lang.isNotEmpty) {
        await prefs.setString('app_language_code', lang);
      }
    }
    // —— 通知/实时/课表开关 ——
    await _writeInt(prefs, 'course_reminder_minutes',
        settings, 'courseReminderMinutes');
    await _writeDouble(prefs, 'homework_reminder_hours',
        settings, 'homeworkReminderHours');
    await _writeInt(prefs, 'library_reminder_minutes',
        settings, 'libraryReminderMinutes');
    await _writeBool(
        prefs, 'course_live_enabled', settings, 'courseLiveEnabled');
    await _writeBool(
        prefs, 'flyme_live_enabled', settings, 'flymeLiveEnabled');
    await _writeBool(prefs, 'timetable_auto_sync_enabled', settings,
        'timetableAutoSyncEnabled');
    await _writeBool(prefs, 'timetable_show_end_time', settings,
        'timetableShowEndTime');
    if (settings.containsKey('manualFirstWeekMonday')) {
      final v = _asStringOrNull(settings['manualFirstWeekMonday']);
      if (v != null && v.isNotEmpty) {
        await prefs.setString('timetable_first_week_monday_manual', v);
      }
    }

    // —— 外观 ——
    final appearance = settings['appearance'] is Map
        ? Map<String, dynamic>.from(settings['appearance'] as Map)
        : <String, dynamic>{};
    if (settings.containsKey('appearance')) {
      final masterIds =
          AppearanceNotifier.masterPool.map((e) => e.id).toList();
      final defaultHomeVis = {
        for (final id in masterIds)
          id: AppearanceNotifier.defaultVisibleHomeIds.contains(id)
      };
      final defaultFuncVis = {for (final id in masterIds) id: true};
      final defaultWidgetVis = {
        for (final id in masterIds)
          id: HomeWidgetService.defaultQuickIds.contains(id)
      };

      if (appearance.containsKey('homeItems')) {
        final localList = _decodeJson(prefs.getString('home_function_items'));
        final merged = _reconcileFunctionItems(
          cloudList: appearance['homeItems'],
          localList: localList,
          masterIds: masterIds,
          defaultVisibility: defaultHomeVis,
        );
        await prefs.setString('home_function_items', jsonEncode(merged));
      }

      if (appearance.containsKey('functionItems')) {
        final localList = _decodeJson(prefs.getString('function_page_items'));
        final merged = _reconcileFunctionItems(
          cloudList: appearance['functionItems'],
          localList: localList,
          masterIds: masterIds,
          defaultVisibility: defaultFuncVis,
        );
        await prefs.setString('function_page_items', jsonEncode(merged));
      }

      if (appearance.containsKey('feedItems')) {
        final feedIds = AppearanceNotifier.feedPool.map((e) => e.id).toList();
        final defaultFeedVis = {for (final id in feedIds) id: true};
        final localList = _decodeJson(prefs.getString('home_feed_items'));
        final merged = _reconcileFunctionItems(
          cloudList: appearance['feedItems'],
          localList: localList,
          masterIds: feedIds,
          defaultVisibility: defaultFeedVis,
        );
        await prefs.setString('home_feed_items', jsonEncode(merged));
      }

      if (appearance.containsKey('feedAutoSort')) {
        await prefs.setBool(
            'feed_auto_sort', appearance['feedAutoSort'] == true);
      }

      if (appearance.containsKey('widgetItems')) {
        final localList = _decodeJson(prefs.getString('widget_function_items'));
        final merged = _reconcileFunctionItems(
          cloudList: appearance['widgetItems'],
          localList: localList,
          masterIds: masterIds,
          defaultVisibility: defaultWidgetVis,
        );
        await prefs.setString('widget_function_items', jsonEncode(merged));

        final quickIds = merged
            .where((item) => item['isVisible'] == true)
            .map((item) => item['id']?.toString())
            .where((id) =>
                id != null && HomeWidgetService.allFunctionIds.contains(id))
            .take(4)
            .cast<String>()
            .toList();
        await prefs.setString(
            HomeWidgetService.quickIdsKey, jsonEncode(quickIds));
      }

      if (appearance.containsKey('functionGroupOrder')) {
        final validKeys = functionGroups.map((g) => g.titleKey).toList();
        final localOrder = _decodeJson(prefs.getString('function_group_order'));
        final mergedOrder = _reconcileKeys(
          cloudList: appearance['functionGroupOrder'],
          localList: localOrder,
          validMasterKeys: validKeys,
        );
        await prefs.setString('function_group_order', jsonEncode(mergedOrder));
      }

      if (appearance.containsKey('hiddenFunctionGroups')) {
        final validKeys = functionGroups.map((g) => g.titleKey).toSet();
        final raw = appearance['hiddenFunctionGroups'];
        if (raw is List) {
          final filtered = raw
              .map((e) => e.toString())
              .where(validKeys.contains)
              .toSet()
              .toList();
          await prefs.setString(
              'hidden_function_groups', jsonEncode(filtered));
        }
      }
    }

    // —— 电费房间 ——
    if (settings.containsKey('electricityRoom')) {
      final v = settings['electricityRoom'];
      if (v != null) {
        await prefs.setString('saved_electricity_room', jsonEncode(v));
      }
    }
    if (settings.containsKey('electricityRoom2')) {
      final v = settings['electricityRoom2'];
      if (v != null) {
        await prefs.setString('saved_electricity_room_2', jsonEncode(v));
      }
    }

    // —— 课程自定义颜色 ——
    if (settings.containsKey('customCourseColors')) {
      final cloudColors = settings['customCourseColors'];
      if (cloudColors is Map) {
        final localRaw = prefs.getString('custom_course_colors');
        final localMap = <String, dynamic>{};
        if (localRaw != null && localRaw.isNotEmpty) {
          try {
            final decoded = jsonDecode(localRaw);
            if (decoded is Map) {
              localMap.addAll(Map<String, dynamic>.from(decoded));
            }
          } catch (_) {}
        }
        for (final entry in cloudColors.entries) {
          localMap[entry.key.toString()] = entry.value;
        }
        await prefs.setString('custom_course_colors', jsonEncode(localMap));
      }
    }

    // —— 课表云端订阅 ——
    if (settings.containsKey('timetableSubscription')) {
      final sub = settings['timetableSubscription'];
      if (sub is Map) {
        if (sub.containsKey('enabled') && sub['enabled'] is bool) {
          await prefs.setBool(
              'timetable_subscription_enabled', sub['enabled'] as bool);
        }
        if (sub.containsKey('uuid') && sub['uuid'] != null) {
          await prefs.setString(
              'timetable_subscription_uuid', sub['uuid'].toString());
        }
      }
    }

    // —— 文档目录文件（课表/手动作业/手动考试）——
    await _writeDocFile(
        'current_timetable.ics', localData, 'timetableIcs');
    await _writeDocFile(
        'timetable_meta.json', localData, 'timetableMeta');
    await _writeDocFile('courses.json', localData, 'courses');
    await _writeDocFile('raw_courses.json', localData, 'rawCourses');
    await _writeDocFile(
        'timetable_rules.json', localData, 'timetableRules');
    await _applyManualHomeworkList(localData['homeworkList']);
    await _applyManualExamList(
        localData['examList'] ?? localData['manualExamList']);
    await _writeDocFile('ai_memories.json', localData, 'aiMemories');

    // —— AI 设置（SecureStorage）——
    final ai = settings['ai'] is Map
        ? Map<String, dynamic>.from(settings['ai'] as Map)
        : null;
    if (ai != null) {
      final secure = SecureStorageHelper();
      if (ai.containsKey('apiUrl')) {
        final v = _asStringOrNull(ai['apiUrl']);
        if (v != null && v.isNotEmpty) {
          await secure.saveAiApiUrl(v);
        }
      }
      if (ai.containsKey('model')) {
        final v = _asStringOrNull(ai['model']);
        if (v != null && v.isNotEmpty) {
          await secure.saveAiModel(v);
        }
      }
      if (ai.containsKey('apiKey')) {
        final v = _asStringOrNull(ai['apiKey']);
        if (v != null &&
            v.isNotEmpty &&
            v != AiAssistantService.defaultApiKey) {
          await secure.saveAiApiKey(v);
        }
      }
    }
  }

  /// 合并功能项目列表：
  /// - 云端有且本地有的项：按云端顺序和可见性覆盖本地（覆盖本地且应用）。
  /// - 云端有但本地没有的项目（不在 masterIds 中）：直接丢弃（当它不存在）。
  /// - 本地有但云端没有的项目：继续使用本地的项目配置（保持原有顺序与可见性）。
  static List<Map<String, dynamic>> _reconcileFunctionItems({
    required dynamic cloudList,
    required dynamic localList,
    required List<String> masterIds,
    required Map<String, bool> defaultVisibility,
  }) {
    final masterSet = masterIds.toSet();
    final localMap = <String, Map<String, dynamic>>{};
    final localOrder = <String>[];

    if (localList is List) {
      for (final item in localList) {
        if (item is Map) {
          final id = item['id']?.toString();
          if (id != null && masterSet.contains(id)) {
            localMap[id] = Map<String, dynamic>.from(item);
            localOrder.add(id);
          }
        }
      }
    }

    final result = <Map<String, dynamic>>[];
    final addedIds = <String>{};

    // 1. 先消费云端列表（覆盖本地顺序与可见性；本地没有的项目当它不存在）
    if (cloudList is List) {
      for (final item in cloudList) {
        if (item is Map) {
          final id = item['id']?.toString();
          // 若云端有但本地没有的项目（不在当前 masterPool 中），直接丢弃（当它不存在）
          if (id != null && masterSet.contains(id) && !addedIds.contains(id)) {
            final isVisible = item['isVisible'];
            result.add({
              'id': id,
              'isVisible': isVisible is bool
                  ? isVisible
                  : (localMap[id]?['isVisible'] ?? defaultVisibility[id] ?? false),
            });
            addedIds.add(id);
          }
        }
      }
    }

    // 2. 本地有但云端没有的项目：继续使用本地的项目配置
    for (final id in localOrder) {
      if (!addedIds.contains(id)) {
        result.add(localMap[id]!);
        addedIds.add(id);
      }
    }

    return result;
  }

  /// 合并分组顺序列表：
  /// - 云端有且合法的 key：按云端顺序排列。
  /// - 云端有但本地没有的 key（非 validMasterKeys）：直接丢弃（当它不存在）。
  /// - 本地有但云端没有的 key：按本地顺序保留追加。
  static List<String> _reconcileKeys({
    required dynamic cloudList,
    required dynamic localList,
    required List<String> validMasterKeys,
  }) {
    final validSet = validMasterKeys.toSet();
    final result = <String>[];
    final added = <String>{};

    if (cloudList is List) {
      for (final item in cloudList) {
        final k = item.toString();
        if (validSet.contains(k) && !added.contains(k)) {
          result.add(k);
          added.add(k);
        }
      }
    }

    if (localList is List) {
      for (final item in localList) {
        final k = item.toString();
        if (validSet.contains(k) && !added.contains(k)) {
          result.add(k);
          added.add(k);
        }
      }
    }

    for (final k in validMasterKeys) {
      if (!added.contains(k)) {
        result.add(k);
        added.add(k);
      }
    }

    return result;
  }

  static String? _asStringOrNull(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static Future<void> _writeInt(SharedPreferences prefs, String key,
      Map<String, dynamic> parent, String field) async {
    if (!parent.containsKey(field)) return;
    final v = parent[field];
    if (v == null) return;
    if (v is int) {
      await prefs.setInt(key, v);
    } else if (v is num) {
      await prefs.setInt(key, v.toInt());
    } else if (v is String) {
      final parsed = int.tryParse(v);
      if (parsed != null) {
        await prefs.setInt(key, parsed);
      }
    }
  }

  static Future<void> _writeDouble(SharedPreferences prefs, String key,
      Map<String, dynamic> parent, String field) async {
    if (!parent.containsKey(field)) return;
    final v = parent[field];
    if (v == null) return;
    if (v is num) {
      await prefs.setDouble(key, v.toDouble());
    } else if (v is String) {
      final parsed = double.tryParse(v);
      if (parsed != null) {
        await prefs.setDouble(key, parsed);
      }
    }
  }

  static Future<void> _writeBool(SharedPreferences prefs, String key,
      Map<String, dynamic> parent, String field) async {
    if (!parent.containsKey(field)) return;
    final v = parent[field];
    if (v is bool) {
      await prefs.setBool(key, v);
    }
  }

  static Future<void> _writeDocFile(
      String fileName, Map<String, dynamic> parent, String field) async {
    if (!parent.containsKey(field)) return;
    final v = parent[field];
    if (v == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    final content = v is String ? v : jsonEncode(v);
    await AtomicStorageHelper.atomicWriteString(file, content);
  }

  static dynamic _decodeJson(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _readDocFileText(String fileName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      if (await file.exists()) return file.readAsString();
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<dynamic> _readDocFileJson(String fileName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      final decoded = await AtomicStorageHelper.readJsonWithRecovery(file,
          logTag: 'BackupExportService');
      if (decoded != null) return decoded;
      // 容错：若非 JSON 格式文本文件则回退原样返回文本
      return await _readDocFileText(fileName);
    } catch (_) {
      return null;
    }
  }

  /// 仅读取本地手动作业（isManual == true），排除在线爬取的作业
  static Future<List<Map<String, dynamic>>?> _readManualHomeworkJson() async {
    final raw = await _readDocFileJson('homework_list.json');
    if (raw is! List) return null;
    final manualOnly = raw
        .whereType<Map>()
        .where((item) => item['isManual'] == true)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    return manualOnly;
  }

  /// 合并备份中的手动作业到本地：
  /// - 云端手动作业覆盖/合并到本地手动作业列表（以 id 为准）
  /// - 本地原有的爬取作业（isManual != true）不受影响继续保留
  /// - 本地已有但云端没有的手动作业继续保留
  static Future<void> _applyManualHomeworkList(dynamic cloudHomework) async {
    if (cloudHomework == null || cloudHomework is! List) return;

    final cloudManual = cloudHomework
        .whereType<Map>()
        .where((item) => item['isManual'] == true)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/homework_list.json');

    List<Map<String, dynamic>> localList = [];
    if (await file.exists()) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is List) {
          localList = decoded
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      } catch (_) {}
    }

    // 分离本地爬取作业和手动作业
    final localScraped =
        localList.where((item) => item['isManual'] != true).toList();
    final localManual =
        localList.where((item) => item['isManual'] == true).toList();

    final mergedManual = <Map<String, dynamic>>[];
    final addedIds = <String>{};

    // 1. 云端手动作业覆盖本地
    for (final item in cloudManual) {
      final id = item['id']?.toString();
      if (id != null && !addedIds.contains(id)) {
        mergedManual.add(item);
        addedIds.add(id);
      }
    }

    // 2. 本地有但云端没有的手动作业：继续保留本地手动作业
    for (final item in localManual) {
      final id = item['id']?.toString();
      if (id != null && !addedIds.contains(id)) {
        mergedManual.add(item);
        addedIds.add(id);
      }
    }

    // 3. 保留本地爬取作业 + 合并后的手动作业
    final finalHomework = [...mergedManual, ...localScraped];
    await AtomicStorageHelper.atomicWriteString(
        file, jsonEncode(finalHomework));
  }

  /// 仅读取本地手动考试（isManual == true 且未过期），排除在线爬取的考试
  static Future<List<Map<String, dynamic>>?> _readManualExamJson() async {
    final raw = await _readDocFileJson('exam_schedule_list.json');
    if (raw is! List) return null;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final manualOnly = raw
        .whereType<Map>()
        .where((item) {
          if (item['isManual'] != true) return false;
          try {
            final timeStr = (item['time'] ?? item['startTime']) as String?;
            if (timeStr == null) return true;
            final t = DateTime.parse(timeStr);
            return !t.isBefore(todayStart);
          } catch (_) {
            return true;
          }
        })
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    return manualOnly;
  }

  /// 合并备份中的手动考试到本地：
  /// - 云端手动考试覆盖/合并到本地手动考试列表（以 id 为准）
  /// - 本地原有的爬取考试（isManual != true）不受影响继续保留
  /// - 本地已有但云端没有的手动考试继续保留
  /// - 始终只保留开始时间是今天及未来未过期的考试
  static Future<void> _applyManualExamList(dynamic cloudExams) async {
    if (cloudExams == null || cloudExams is! List) return;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final cloudManual = cloudExams
        .whereType<Map>()
        .where((item) {
          if (item['isManual'] != true) return false;
          try {
            final timeStr = (item['time'] ?? item['startTime']) as String?;
            if (timeStr == null) return true;
            final t = DateTime.parse(timeStr);
            return !t.isBefore(todayStart);
          } catch (_) {
            return true;
          }
        })
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/exam_schedule_list.json');

    List<Map<String, dynamic>> localList = [];
    if (await file.exists()) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is List) {
          localList = decoded
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      } catch (_) {}
    }

    // 分离本地爬取考试和手动考试
    final localScraped =
        localList.where((item) => item['isManual'] != true).toList();
    final localManual =
        localList.where((item) => item['isManual'] == true).toList();

    final mergedManual = <Map<String, dynamic>>[];
    final addedIds = <String>{};

    // 1. 云端手动考试覆盖本地
    for (final item in cloudManual) {
      final id = item['id']?.toString();
      if (id != null && !addedIds.contains(id)) {
        mergedManual.add(item);
        addedIds.add(id);
      }
    }

    // 2. 本地有但云端没有的手动考试：继续保留本地手动考试
    for (final item in localManual) {
      final id = item['id']?.toString();
      if (id != null && !addedIds.contains(id)) {
        mergedManual.add(item);
        addedIds.add(id);
      }
    }

    // 3. 保留本地爬取考试 + 合并后的手动考试（过滤今天及未来）
    final finalExams = [...mergedManual, ...localScraped].where((item) {
      try {
        final timeStr = (item['time'] ?? item['startTime']) as String?;
        if (timeStr == null) return true;
        final t = DateTime.parse(timeStr);
        return !t.isBefore(todayStart);
      } catch (_) {
        return true;
      }
    }).toList();

    await AtomicStorageHelper.atomicWriteString(file, jsonEncode(finalExams));
  }
}
