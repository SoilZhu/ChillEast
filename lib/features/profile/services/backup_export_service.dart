import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/ai/ai_service.dart';
import '../../../core/services/home_widget_service.dart';
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
  static const String backupFormat = 'chilleast-backup';
  static const int backupVersion = 1;

  /// 组装备份 JSON（纯 Map，可直接 jsonEncode）。
  static Future<Map<String, dynamic>> buildBackupData() async {
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

    return {
      'format': backupFormat,
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
        'manualFirstWeekMonday':
            prefs.getString('timetable_first_week_monday_manual'),
        'appearance': {
          'homeItems': _decodeJson(prefs.getString('home_function_items')),
          'functionItems': _decodeJson(prefs.getString('function_page_items')),
          'feedItems': _decodeJson(prefs.getString('home_feed_items')),
          'widgetItems': _decodeJson(prefs.getString('widget_function_items')),
          'functionGroupOrder':
              _decodeJson(prefs.getString('function_group_order')),
          'hiddenFunctionGroups':
              _decodeJson(prefs.getString('hidden_function_groups')),
        },
        'electricityRoom':
            _decodeJson(prefs.getString('saved_electricity_room')),
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
      },
    };
  }

  /// 组装备份 JSON 并写入临时文件，返回文件路径。
  static Future<String> writeBackupFile() async {
    final data = await buildBackupData();
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
    if (decoded['format'] != backupFormat) {
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
  /// - 云端有本地没有的项：当它不存在（直接过滤丢弃）。
  static Future<void> applyBackupData(Map<String, dynamic> backup) async {
    // 先校验，避免写一半才发现版本不对
    if (backup['format'] != backupFormat) {
      throw const FormatException('不是自在东湖备份文件');
    }
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

    // —— 文档目录文件（课表/手动作业）——
    await _writeDocFile(
        'current_timetable.ics', localData, 'timetableIcs');
    await _writeDocFile(
        'timetable_meta.json', localData, 'timetableMeta');
    await _writeDocFile('courses.json', localData, 'courses');
    await _writeDocFile('raw_courses.json', localData, 'rawCourses');
    await _writeDocFile(
        'timetable_rules.json', localData, 'timetableRules');
    await _applyManualHomeworkList(localData['homeworkList']);

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

  static Future<void> _setOrRemoveString(
      SharedPreferences prefs, String key, dynamic value) async {
    final v = _asStringOrNull(value);
    if (v == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, v);
    }
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

  static Future<void> _writePrefsJson(SharedPreferences prefs, String key,
      Map<String, dynamic> parent, String field) async {
    if (!parent.containsKey(field)) return;
    final v = parent[field];
    if (v == null) return;
    await prefs.setString(key, jsonEncode(v));
  }

  static Future<void> _writeDocFile(
      String fileName, Map<String, dynamic> parent, String field) async {
    if (!parent.containsKey(field)) return;
    final v = parent[field];
    if (v == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    if (v is String) {
      await file.writeAsString(v);
    } else {
      await file.writeAsString(jsonEncode(v));
    }
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
    final text = await _readDocFileText(fileName);
    if (text == null || text.isEmpty) return null;
    try {
      return jsonDecode(text);
    } catch (_) {
      // 非 JSON 文件原样返回文本，避免备份失败
      return text;
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
    await file.writeAsString(jsonEncode(finalHomework));
  }
}
