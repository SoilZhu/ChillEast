import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/ai/ai_service.dart';
import '../../../core/services/home_widget_service.dart';
import '../../../core/utils/secure_storage_helper.dart';

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
        'homeworkList': await _readDocFileJson('homework_list.json'),
        'libraryReserves':
            _decodeJson(prefs.getString('cached_library_reserves')) ??
                _decodeJson(prefs.getString('cached_library_reserve')),
        'leaveItems': _decodeJson(prefs.getString('cached_leave_items')),
        'questionnaireItems':
            _decodeJson(prefs.getString('cached_questionnaire_items')),
        'repairItems':
            _decodeJson(prefs.getString('cached_ongoing_repair_items')),
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
  /// 语义为“恢复到备份时的状态”：备份中包含的字段若为 null，
  /// 则清除本地对应项；备份中缺失的字段（旧版本备份）则保持现状。
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
      await _setOrRemoveString(
          prefs, 'app_language_code', settings['languageCode']);
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
      await _setOrRemoveString(prefs, 'timetable_first_week_monday_manual',
          settings['manualFirstWeekMonday']);
    }

    // —— 外观 ——
    final appearance = settings['appearance'] is Map
        ? Map<String, dynamic>.from(settings['appearance'] as Map)
        : <String, dynamic>{};
    if (settings.containsKey('appearance')) {
      await _writePrefsJson(prefs, 'home_function_items', appearance,
          'homeItems');
      await _writePrefsJson(
          prefs, 'function_page_items', appearance, 'functionItems');
      await _writePrefsJson(
          prefs, 'home_feed_items', appearance, 'feedItems');
      await _writePrefsJson(
          prefs, 'widget_function_items', appearance, 'widgetItems');
      await _writePrefsJson(
          prefs, 'function_group_order', appearance, 'functionGroupOrder');
      await _writePrefsJson(prefs, 'hidden_function_groups', appearance,
          'hiddenFunctionGroups');

      if (appearance.containsKey('widgetItems')) {
        final widgetItems = appearance['widgetItems'];
        if (widgetItems is List) {
          final quickIds = widgetItems
              .whereType<Map>()
              .where((item) => item['isVisible'] == true)
              .map((item) => item['id']?.toString())
              .where((id) =>
                  id != null && HomeWidgetService.allFunctionIds.contains(id))
              .take(4)
              .cast<String>()
              .toList();
          await prefs.setString(
              HomeWidgetService.quickIdsKey, jsonEncode(quickIds));
        } else if (widgetItems == null) {
          await prefs.remove(HomeWidgetService.quickIdsKey);
        }
      }
    }
    // —— 电费房间 ——
    if (settings.containsKey('electricityRoom')) {
      final v = settings['electricityRoom'];
      if (v == null) {
        await prefs.remove('saved_electricity_room');
      } else {
        await prefs.setString(
            'saved_electricity_room', jsonEncode(v));
      }
    }

    // —— 本地缓存（图书馆/请假/问卷/报修）——
    await _writePrefsJson(
        prefs, 'cached_library_reserves', localData, 'libraryReserves');
    if (localData.containsKey('libraryReserves')) {
      // 写回后旧单条缓存即失效，避免降级回退读到脏数据
      await prefs.remove('cached_library_reserve');
    }
    await _writePrefsJson(
        prefs, 'cached_leave_items', localData, 'leaveItems');
    await _writePrefsJson(prefs, 'cached_questionnaire_items', localData,
        'questionnaireItems');
    await _writePrefsJson(prefs, 'cached_ongoing_repair_items', localData,
        'repairItems');

    // —— 文档目录文件（课表/作业）——
    await _writeDocFile(
        'current_timetable.ics', localData, 'timetableIcs');
    await _writeDocFile(
        'timetable_meta.json', localData, 'timetableMeta');
    await _writeDocFile('courses.json', localData, 'courses');
    await _writeDocFile('raw_courses.json', localData, 'rawCourses');
    await _writeDocFile(
        'timetable_rules.json', localData, 'timetableRules');
    await _writeDocFile(
        'homework_list.json', localData, 'homeworkList');

    // —— AI 设置（SecureStorage）——
    final ai = settings['ai'] is Map
        ? Map<String, dynamic>.from(settings['ai'] as Map)
        : null;
    if (ai != null) {
      final secure = SecureStorageHelper();
      if (ai.containsKey('apiUrl')) {
        final v = _asStringOrNull(ai['apiUrl']);
        if (v == null || v.isEmpty) {
          await secure.clearAiApiUrl();
        } else {
          await secure.saveAiApiUrl(v);
        }
      }
      if (ai.containsKey('model')) {
        final v = _asStringOrNull(ai['model']);
        if (v == null || v.isEmpty) {
          await secure.clearAiModel();
        } else {
          await secure.saveAiModel(v);
        }
      }
      if (ai.containsKey('apiKey')) {
        final v = _asStringOrNull(ai['apiKey']);
        // 默认 Key 永不落盘：备份里本就不应含默认 Key，
        // 此处再挡一次，避免脏备份把默认 Key 写成自定义配置
        if (v == null ||
            v.isEmpty ||
            v == AiAssistantService.defaultApiKey) {
          await secure.clearAiApiKey();
        } else {
          await secure.saveAiApiKey(v);
        }
      }
    }
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
    if (v == null) {
      await prefs.remove(key);
    } else if (v is int) {
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
    if (v == null) {
      await prefs.remove(key);
    } else if (v is num) {
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
    if (v == null) {
      await prefs.remove(key);
    } else if (v is bool) {
      await prefs.setBool(key, v);
    }
  }

  static Future<void> _writePrefsJson(SharedPreferences prefs, String key,
      Map<String, dynamic> parent, String field) async {
    if (!parent.containsKey(field)) return;
    final v = parent[field];
    if (v == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, jsonEncode(v));
    }
  }

  static Future<void> _writeDocFile(
      String fileName, Map<String, dynamic> parent, String field) async {
    if (!parent.containsKey(field)) return;
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    final v = parent[field];
    if (v == null) {
      if (await file.exists()) await file.delete();
      return;
    }
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
}
