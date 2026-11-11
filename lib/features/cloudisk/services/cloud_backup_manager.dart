import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/cookie_manager.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/secure_storage_helper.dart';
import '../../auth/services/http_login_service.dart';
import '../../profile/services/backup_export_service.dart';
import 'cloudisk_service.dart';

/// 开启时的首次同步结果：下拉覆盖 / 本地推上 / 失败。
enum InitialSyncOutcome { pulled, pushed, failed }

class InitialSyncResult {
  final InitialSyncOutcome outcome;
  final Map<String, dynamic>? backup;

  const InitialSyncResult(this.outcome, [this.backup]);
}

/// 本地备份 → 学习通云盘自动同步。
///
/// 文件名：`chilleast-backup-b-{stamp}.json`（读取兼容历史 a/b 槽位），
/// stamp 为 `yyyyMMdd-HHmmss`（字典序即时间序，删除失败也能肉眼定位最新）。
/// 写入时固定为槽位 b（兼容老版本/MCP识别正则，且 'b' > 'a' 消除轮换字典序错位），
/// 校验成功后删除**所有**其它同前缀旧文件（即使某次删除失败，下次同步也会收敛清理）。
class CloudBackupManager {
  static final CloudBackupManager instance = CloudBackupManager._internal();
  CloudBackupManager._internal();

  static const String filePrefix = 'chilleast-backup-';
  static const String modernFilePrefix = 'chilleast-modern-';
  static const String fixedSlot = 'b';
  static const int defaultKeepCount = 3;
  static const String toggleKey = 'cloud_backup_auto_sync';
  static const String promptDecidedKey = 'cloud_backup_prompt_decided';
  static const String _activeSlotKey = 'cloud_backup_active_slot';
  static const String _activeResidKey = 'cloud_backup_active_resid';
  static const String _activeEncryptedIdKey =
      'cloud_backup_active_encrypted_id';
  static const Duration _debounce = Duration(seconds: 10);

  final _logger = AppLogger.instance;
  final CloudiskService _cloudisk = CloudiskService();
  Timer? _debounceTimer;
  bool _running = false;
  bool _requeued = false;
  bool _refreshingAuth = false;

  /// 现代轨文件名（严格去除无意义槽位字母 b，直接携带时间戳）。
  static String buildModernFileName([DateTime? time]) {
    final t = time ?? DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp = '${t.year}${two(t.month)}${two(t.day)}-'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
    return '$modernFilePrefix$stamp.json';
  }

  /// 解析现代轨备份文件名 → (stamp)，不匹配返回 null。
  static ({String stamp})? parseModernFileName(String name) {
    final m = RegExp(
      '^${RegExp.escape(modernFilePrefix)}(\\d{8}-\\d{6})\\.json\$',
    ).firstMatch(name);
    if (m == null) return null;
    return (stamp: m.group(1)!);
  }

  /// 兼容轨文件名：维持老版 main 规范（slot 为 a/b，新备份固定使用 'b'）。
  static String buildFileName([String slot = fixedSlot, DateTime? time]) {
    final t = time ?? DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp = '${t.year}${two(t.month)}${two(t.day)}-'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
    return '$filePrefix$slot-$stamp.json';
  }

  /// 解析兼容轨备份文件名 → (slot, stamp)，不匹配返回 null。
  static ({String slot, String stamp})? parseFileName(String name) {
    final m = RegExp(
      '^${RegExp.escape(filePrefix)}([ab])-(\\d{8}-\\d{6})\\.json\$',
    ).firstMatch(name);
    if (m == null) return null;
    return (slot: m.group(1)!, stamp: m.group(2)!);
  }

  /// 目标槽位：固定为 b，兼容历史调用。
  static String pickTargetSlot([String? activeSlot]) => fixedSlot;

  /// 从目录条目中挑出最新的现代备份文件（按 stamp 字典序即时间序）。
  static Map<String, String>? pickLatestModernBackupEntry(
    List<Map<String, dynamic>> entries,
  ) {
    Map<String, String>? best;
    for (final e in entries) {
      final name = e['name']?.toString() ?? '';
      final parsed = parseModernFileName(name);
      if (parsed == null) continue;
      final resid = e['id']?.toString() ?? '';
      final encryptedId = e['encryptedId']?.toString() ?? '';
      if (resid.isEmpty || encryptedId.isEmpty) continue;
      if (best == null || parsed.stamp.compareTo(best['stamp']!) > 0) {
        best = {
          'resid': resid,
          'encryptedId': encryptedId,
          'puid': e['puid']?.toString() ?? '',
          'name': name,
          'stamp': parsed.stamp,
        };
      }
    }
    return best;
  }

  /// 从目录条目中挑出最新的兼容备份文件（按 stamp 字典序即时间序）。
  /// 忽略非备份文件；无备份返回 null。
  static Map<String, String>? pickLatestBackupEntry(
    List<Map<String, dynamic>> entries,
  ) {
    Map<String, String>? best;
    for (final e in entries) {
      final name = e['name']?.toString() ?? '';
      final parsed = parseFileName(name);
      if (parsed == null) continue;
      final resid = e['id']?.toString() ?? '';
      final encryptedId = e['encryptedId']?.toString() ?? '';
      if (resid.isEmpty || encryptedId.isEmpty) continue;
      if (best == null || parsed.stamp.compareTo(best['stamp']!) > 0) {
        best = {
          'resid': resid,
          'encryptedId': encryptedId,
          'puid': e['puid']?.toString() ?? '',
          'name': name,
          'slot': parsed.slot,
          'stamp': parsed.stamp,
        };
      }
    }
    return best;
  }

  /// 从目录条目中挑出需删除的现代备份 resid（严格保留包含本次 [keepResid] 在内的最新 [keepCount] 份）。
  static List<Map<String, String>> pickStaleModernEntries(
    List<Map<String, dynamic>> entries,
    String keepResid, {
    int keepCount = defaultKeepCount,
  }) {
    final valid = <({String resid, String encryptedId, String puid, String stamp})>[];
    for (final e in entries) {
      final name = e['name']?.toString() ?? '';
      final parsed = parseModernFileName(name);
      if (parsed == null) continue;
      final resid = e['id']?.toString() ?? '';
      final encryptedId = e['encryptedId']?.toString() ?? '';
      if (resid.isEmpty || encryptedId.isEmpty) continue;
      valid.add((
        resid: resid,
        encryptedId: encryptedId,
        puid: e['puid']?.toString() ?? '',
        stamp: parsed.stamp,
      ));
    }

    valid.sort((a, b) => b.stamp.compareTo(a.stamp));

    final keptResids = <String>{};
    if (keepResid.isNotEmpty && valid.any((v) => v.resid == keepResid)) {
      keptResids.add(keepResid);
    }

    for (final item in valid) {
      if (keptResids.length >= keepCount) break;
      keptResids.add(item.resid);
    }

    final stale = <Map<String, String>>[];
    for (final item in valid) {
      if (!keptResids.contains(item.resid) && item.resid != keepResid) {
        stale.add({
          'resid': item.resid,
          'encryptedId': item.encryptedId,
          'puid': item.puid,
        });
      }
    }
    return stale;
  }

  /// 从目录条目中挑出需删除的兼容备份 resid（严格保留包含本次 [keepResid] 在内的最新 [keepCount] 份）。
  static List<Map<String, String>> pickStaleEntries(
    List<Map<String, dynamic>> entries,
    String keepResid, {
    int keepCount = defaultKeepCount,
  }) {
    final valid = <({String resid, String encryptedId, String puid, String stamp})>[];
    for (final e in entries) {
      final name = e['name']?.toString() ?? '';
      final parsed = parseFileName(name);
      if (parsed == null) continue;
      final resid = e['id']?.toString() ?? '';
      final encryptedId = e['encryptedId']?.toString() ?? '';
      if (resid.isEmpty || encryptedId.isEmpty) continue;
      valid.add((
        resid: resid,
        encryptedId: encryptedId,
        puid: e['puid']?.toString() ?? '',
        stamp: parsed.stamp,
      ));
    }

    valid.sort((a, b) => b.stamp.compareTo(a.stamp));

    final keptResids = <String>{};
    if (keepResid.isNotEmpty && valid.any((v) => v.resid == keepResid)) {
      keptResids.add(keepResid);
    }

    for (final item in valid) {
      if (keptResids.length >= keepCount) break;
      keptResids.add(item.resid);
    }

    final stale = <Map<String, String>>[];
    for (final item in valid) {
      if (!keptResids.contains(item.resid) && item.resid != keepResid) {
        stale.add({
          'resid': item.resid,
          'encryptedId': item.encryptedId,
          'puid': item.puid,
        });
      }
    }
    return stale;
  }

  /// 当老版设备产生较新的兼容快照时，将现代全量数据与老版的较新通用修改进行智能合并
  static Map<String, dynamic> mergeModernWithLegacy(
    Map<String, dynamic> modern,
    Map<String, dynamic> legacy,
  ) {
    final merged = Map<String, dynamic>.from(modern);
    merged['format'] = BackupExportService.modernBackupFormat;

    final modernSettings = merged['settings'] is Map
        ? Map<String, dynamic>.from(merged['settings'] as Map)
        : <String, dynamic>{};
    final legacySettings = legacy['settings'] is Map
        ? Map<String, dynamic>.from(legacy['settings'] as Map)
        : <String, dynamic>{};

    final modernLocalData = merged['localData'] is Map
        ? Map<String, dynamic>.from(merged['localData'] as Map)
        : <String, dynamic>{};
    final legacyLocalData = legacy['localData'] is Map
        ? Map<String, dynamic>.from(legacy['localData'] as Map)
        : <String, dynamic>{};

    // 1. 基础设置项以老版较新的设置覆盖
    const baseSettingsKeys = [
      'languageCode',
      'courseReminderMinutes',
      'homeworkReminderHours',
      'libraryReminderMinutes',
      'courseLiveEnabled',
      'flymeLiveEnabled',
      'timetableAutoSyncEnabled',
      'timetableShowEndTime',
      'manualFirstWeekMonday',
      'electricityRoom',
    ];
    for (final k in baseSettingsKeys) {
      if (legacySettings.containsKey(k)) {
        modernSettings[k] = legacySettings[k];
      }
    }

    // 2. 外观设置
    if (legacySettings.containsKey('appearance')) {
      final legacyApp = legacySettings['appearance'] is Map
          ? Map<String, dynamic>.from(legacySettings['appearance'] as Map)
          : <String, dynamic>{};
      final modernApp = modernSettings['appearance'] is Map
          ? Map<String, dynamic>.from(modernSettings['appearance'] as Map)
          : <String, dynamic>{};

      for (final k in [
        'homeItems',
        'functionItems',
        'feedItems',
        'widgetItems',
        'functionGroupOrder',
        'hiddenFunctionGroups',
      ]) {
        if (legacyApp.containsKey(k)) {
          modernApp[k] = legacyApp[k];
        }
      }
      modernSettings['appearance'] = modernApp;
    }

    // 3. 课表、作业与考试数据：若老版有更新则覆盖
    for (final k in [
      'timetableIcs',
      'timetableMeta',
      'courses',
      'rawCourses',
      'timetableRules',
      'homeworkList',
      'examList',
    ]) {
      if (legacyLocalData.containsKey(k) && legacyLocalData[k] != null) {
        modernLocalData[k] = legacyLocalData[k];
      }
    }
    if (!legacyLocalData.containsKey('examList') &&
        legacyLocalData.containsKey('manualExamList') &&
        legacyLocalData['manualExamList'] != null) {
      modernLocalData['examList'] = legacyLocalData['manualExamList'];
    }

    merged['settings'] = modernSettings;
    merged['localData'] = modernLocalData;
    return merged;
  }

  static const String _dirtyStorageKey = 'cloud_backup_is_dirty';
  int _sessionGeneration = 0;

  /// 本地数据有更改时调用（各存储落盘点）。去抖 10s 后同步一次。
  void markDirty() {
    _debounceTimer?.cancel();
    SharedPreferences.getInstance().then((p) {
      p.setBool(_dirtyStorageKey, true);
    }).catchError((_) {});
    _debounceTimer = Timer(_debounce, () => syncNow());
  }

  /// 立即同步一次（开关关闭时直接返回，除非 force）。
  Future<bool> syncNow({bool force = false}) async {
    if (_running) {
      _requeued = true;
      return false;
    }
    _running = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!force && (prefs.getBool(toggleKey) ?? false) == false) return false;
      // 未登录（无保存凭证）则不同步，静默跳过
      if (!await SecureStorageHelper().hasCredentials()) return false;

      try {
        return await _doSync(prefs);
      } on CloudiskAuthException {
        // 超星会话过期：portal/index 的 Chaoxing Cookie 已失效。
        // HttpLoginService.login 本就是 portal/login→login6→index 全链路，
        // 重登一次即可重新签发 .chaoxing.com 10 件套，无需额外“绑定”请求。
        _cloudisk.invalidateSession();
        if (await _refreshChaoxingSession()) {
          _cloudisk.invalidateSession();
          try {
            return await _doSync(prefs);
          } on CloudiskAuthException {
            _cloudisk.invalidateSession();
            return false;
          }
        }
        return false;
      }
    } catch (e) {
      _logger.w('☁️ Cloud backup sync failed: $e');
      return false;
    } finally {
      _running = false;
      if (_requeued) {
        _requeued = false;
        markDirty();
      }
    }
  }

  /// 退出登录时重置：取消待同步任务并清除云端备份定位
  ///（槽位/resid/开关），避免下个账号复用上个账号的云盘位置。
  /// 下次登录后开关保持默认关闭，由用户手动开启。
  Future<void> resetOnLogout() async {
    _sessionGeneration++;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _running = false;
    _requeued = false;
    _cloudisk.invalidateSession();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(toggleKey);
      await prefs.remove(promptDecidedKey);
      await prefs.remove(_activeSlotKey);
      await prefs.remove(_activeResidKey);
      await prefs.remove(_activeEncryptedIdKey);
      await prefs.remove(_dirtyStorageKey);
      await BackupExportService.clearUnknownFields();
    } catch (e) {
      _logger.w('☁️ Cloud backup logout reset failed: $e');
    }
  }

  /// 超星会话过期时用保存的凭证静默重登，把新 Cookie 发布到共享 Jar。
  /// 同一时间只跑一份，避免和前台登录打架。
  Future<bool> _refreshChaoxingSession() async {
    if (_refreshingAuth) return false;
    _refreshingAuth = true;
    final currentGen = _sessionGeneration;
    try {
      final snapshot = await SecureStorageHelper().readAuthSnapshot();
      final u = snapshot.username;
      final p = snapshot.password;
      if (u == null || u.isEmpty || p == null || p.isEmpty) return false;
      _logger.i('☁️ Chaoxing session expired, silent re-login…');
      final result = await HttpLoginService().login(u, p);

      // 校验世代与用户，若登出或换号则丢弃旧 Cookie，避免覆盖新会话
      final latestSnapshot = await SecureStorageHelper().readAuthSnapshot();
      if (_sessionGeneration != currentGen || latestSnapshot.username != u) {
        _logger.w('☁️ Silent re-login aborted: session generation mismatch or logged out');
        return false;
      }

      await AppCookieManager().saveHttpLoginCookies(result.cookies);
      _logger.i('☁️ Silent re-login ok, cookies refreshed');
      return true;
    } catch (e) {
      _logger.w('☁️ Silent re-login failed: $e');
      return false;
    } finally {
      _refreshingAuth = false;
    }
  }

  /// 应用启动并在静默登录后拉取云端最新备份。
  /// 若本地有未同步的离线修改（dirty），进行合并并把最新数据推上云端；
  /// 若本地无离线修改，则拉取云端最新备份写回本地。
  Future<Map<String, dynamic>?> pullLatestOnStartup() async {
    if (_running) {
      return null;
    }
    _running = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if ((prefs.getBool(toggleKey) ?? false) == false) return null;
      if (!await SecureStorageHelper().hasCredentials()) return null;

      final isDirty = prefs.getBool(_dirtyStorageKey) ?? false;

      try {
        final pulled = await _pullAndApply(prefs);
        if (isDirty) {
          // 本地存在离线修改：合并后将最新数据推至云端并清除 dirty 标记
          _logger.i('☁️ Local offline edits detected, merging and syncing to cloud...');
          await _doSync(prefs);
        }
        return pulled;
      } on CloudiskAuthException {
        _cloudisk.invalidateSession();
        if (await _refreshChaoxingSession()) {
          _cloudisk.invalidateSession();
          try {
            final pulled = await _pullAndApply(prefs);
            if (isDirty) {
              await _doSync(prefs);
            }
            return pulled;
          } on CloudiskAuthException {
            _cloudisk.invalidateSession();
            return null;
          }
        }
        return null;
      }
    } catch (e) {
      _logger.w('☁️ Cloud backup startup pull failed: $e');
      return null;
    } finally {
      _running = false;
      if (_requeued) {
        _requeued = false;
        markDirty();
      }
    }
  }

  /// 开启开关时的首次同步：云上有备份就拉最新覆盖本地，
  /// 云上没有才把本地推上去。调用方在 pulled 时需刷新各 Provider。
  Future<InitialSyncResult> initialSync() async {
    if (_running) {
      _requeued = true;
      return const InitialSyncResult(InitialSyncOutcome.failed);
    }
    _running = true;
    try {
      if (!await SecureStorageHelper().hasCredentials()) {
        return const InitialSyncResult(InitialSyncOutcome.failed);
      }
      final prefs = await SharedPreferences.getInstance();
      try {
        return await _pullOrPush(prefs);
      } on CloudiskAuthException {
        _cloudisk.invalidateSession();
        if (await _refreshChaoxingSession()) {
          _cloudisk.invalidateSession();
          try {
            return await _pullOrPush(prefs);
          } on CloudiskAuthException {
            _cloudisk.invalidateSession();
            return const InitialSyncResult(InitialSyncOutcome.failed);
          }
        }
        return const InitialSyncResult(InitialSyncOutcome.failed);
      }
    } catch (e) {
      _logger.w('☁️ Cloud backup initial sync failed: $e');
      return const InitialSyncResult(InitialSyncOutcome.failed);
    } finally {
      _running = false;
      if (_requeued) {
        _requeued = false;
        markDirty();
      }
    }
  }

  /// 先找云端最新备份：有则下载覆盖本地，无则本地推上。
  Future<InitialSyncResult> _pullOrPush(SharedPreferences prefs) async {
    final pulled = await _pullAndApply(prefs);
    if (pulled != null) {
      return InitialSyncResult(InitialSyncOutcome.pulled, pulled);
    }
    final ok = await _doSync(prefs);
    return InitialSyncResult(
        ok ? InitialSyncOutcome.pushed : InitialSyncOutcome.failed);
  }

  /// 下载云端最新备份并写回本地。若云端无备份返回 null。
  /// 优先拉取现代全量轨（chilleast-modern-*）；若老版本兼容快照更新，执行智能对齐合并。
  Future<Map<String, dynamic>?> _pullAndApply(SharedPreferences prefs) async {
    final currentGen = _sessionGeneration;
    final session = await _cloudisk.ensureSession();
    final scan = await _findLatestBackups(session);
    final modernEntry = scan.modern;
    final legacyEntry = scan.legacy;

    if (modernEntry == null && legacyEntry == null) return null;

    Map<String, dynamic> backup;
    String activeSlot = fixedSlot;
    String activeResid = '';
    String activeEncryptedId = '';

    // 决策仲裁：
    // 1. 若现代轨存在，且 (没有老版快照 或 现代轨时间戳 >= 老版快照时间戳) -> 直接全量拉取现代轨
    // 2. 若仅存在老版快照 -> 老用户升级，拉取老版快照
    // 3. 若两者均存在，但老版快照更新 -> 老设备修改过基础设置，拉取两者进行合并
    if (modernEntry != null &&
        (legacyEntry == null ||
            modernEntry['stamp']!.compareTo(legacyEntry['stamp']!) >= 0)) {
      final bytes = await _cloudisk.downloadBytes(
        resid: modernEntry['resid']!,
        encryptedId: modernEntry['encryptedId']!,
        puid: modernEntry['puid']!.isNotEmpty
            ? modernEntry['puid']!
            : session.puid,
        folderId: session.rootDirId,
      );
      backup = BackupExportService.parseBackupJson(utf8.decode(bytes));
      activeResid = modernEntry['resid']!;
      activeEncryptedId = modernEntry['encryptedId']!;
      _logger.i('☁️ Modern cloud backup pulled: ${modernEntry['name']}');
    } else if (legacyEntry != null && modernEntry == null) {
      final bytes = await _cloudisk.downloadBytes(
        resid: legacyEntry['resid']!,
        encryptedId: legacyEntry['encryptedId']!,
        puid: legacyEntry['puid']!.isNotEmpty
            ? legacyEntry['puid']!
            : session.puid,
        folderId: session.rootDirId,
      );
      backup = BackupExportService.parseBackupJson(utf8.decode(bytes));
      activeSlot = legacyEntry['slot']!;
      activeResid = legacyEntry['resid']!;
      activeEncryptedId = legacyEntry['encryptedId']!;
      _logger.i(
          '☁️ Legacy backup pulled (upgrading to modern): ${legacyEntry['name']}');
    } else {
      // 场景 3：老设备修改过基础设置，拉取两者进行合并
      final modernBytes = await _cloudisk.downloadBytes(
        resid: modernEntry!['resid']!,
        encryptedId: modernEntry['encryptedId']!,
        puid: modernEntry['puid']!.isNotEmpty
            ? modernEntry['puid']!
            : session.puid,
        folderId: session.rootDirId,
      );
      final legacyBytes = await _cloudisk.downloadBytes(
        resid: legacyEntry!['resid']!,
        encryptedId: legacyEntry['encryptedId']!,
        puid: legacyEntry['puid']!.isNotEmpty
            ? legacyEntry['puid']!
            : session.puid,
        folderId: session.rootDirId,
      );
      final modernJson =
          BackupExportService.parseBackupJson(utf8.decode(modernBytes));
      final legacyJson =
          BackupExportService.parseBackupJson(utf8.decode(legacyBytes));
      backup = mergeModernWithLegacy(modernJson, legacyJson);
      activeResid = modernEntry['resid']!;
      activeEncryptedId = modernEntry['encryptedId']!;
      _logger.i('☁️ Merged modern backup with newer legacy backup');
    }

    if (_sessionGeneration != currentGen) {
      _logger.w('☁️ Pull backup aborted: session generation changed');
      return null;
    }

    await BackupExportService.applyBackupData(backup);
    if (_sessionGeneration != currentGen) {
      return null;
    }

    await prefs.setString(_activeSlotKey, activeSlot);
    await prefs.setString(_activeResidKey, activeResid);
    await prefs.setString(_activeEncryptedIdKey, activeEncryptedId);
    return backup;
  }

  /// 翻页检索云端最新的现代备份与兼容备份（最多 5 页）。
  Future<({Map<String, String>? modern, Map<String, String>? legacy})>
      _findLatestBackups(
    CloudiskSession session,
  ) async {
    Map<String, String>? bestModern;
    Map<String, String>? bestLegacy;
    var page = 1;
    const size = 60;
    for (var i = 0; i < 5; i++) {
      final result =
          await _cloudisk.listRes(parentId: session.rootDirId, page: page);
      final modernCandidate = pickLatestModernBackupEntry(result.entries);
      if (modernCandidate != null &&
          (bestModern == null ||
              modernCandidate['stamp']!.compareTo(bestModern['stamp']!) > 0)) {
        bestModern = modernCandidate;
      }
      final legacyCandidate = pickLatestBackupEntry(result.entries);
      if (legacyCandidate != null &&
          (bestLegacy == null ||
              legacyCandidate['stamp']!.compareTo(bestLegacy['stamp']!) > 0)) {
        bestLegacy = legacyCandidate;
      }
      if (result.entries.length >= result.totalCount ||
          result.entries.length < size) {
        break;
      }
      page++;
    }
    return (modern: bestModern, legacy: bestLegacy);
  }

  Future<bool> _doSync(SharedPreferences prefs) async {
    final currentGen = _sessionGeneration;
    final now = DateTime.now();

    // 1. 现代轨（全量数据，format: 'chilleast-modern'）
    final modernData = await BackupExportService.buildBackupData(
      format: BackupExportService.modernBackupFormat,
    );
    final modernBytes = utf8.encode(const JsonEncoder().convert(modernData));

    // 上传前完整性回环反序列化预检
    try {
      final decoded = jsonDecode(utf8.decode(modernBytes));
      if (decoded is! Map<String, dynamic> ||
          decoded['format'] != BackupExportService.modernBackupFormat) {
        throw const FormatException('备份完整性校验失败：缺少合法 modern format 标识');
      }
    } catch (e) {
      _logger.e('☁️ Cloud modern backup pre-upload integrity check failed: $e');
      return false;
    }

    final session = await _cloudisk.ensureSession();
    final modernFilename = buildModernFileName(now);

    final modernUploaded = await _cloudisk.uploadJson(
      folderId: session.rootDirId,
      filename: modernFilename,
      bytes: modernBytes,
    );
    final modernResid = modernUploaded['resid'].toString();

    if (_sessionGeneration != currentGen) {
      _logger.w('☁️ Sync backup aborted: session generation changed');
      return false;
    }

    // 2. 兼容轨（format: 'chilleast-backup'，供 main 1.0.12 消费）
    String? legacyResid;
    try {
      final legacyData = await BackupExportService.buildBackupData(
        format: BackupExportService.legacyBackupFormat,
      );
      final legacyBytes = utf8.encode(const JsonEncoder().convert(legacyData));
      final legacyFilename = buildFileName(fixedSlot, now);
      final legacyUploaded = await _cloudisk.uploadJson(
        folderId: session.rootDirId,
        filename: legacyFilename,
        bytes: legacyBytes,
      );
      legacyResid = legacyUploaded['resid']?.toString();
    } catch (e) {
      _logger.w('☁️ Legacy mirror sync failed: $e');
    }

    if (_sessionGeneration != currentGen) {
      return false;
    }

    // 3. 独立收敛清理两轨，各自严格滚动保留最新 3 份
    await _pruneDualTracks(
      session,
      keepModernResid: modernResid,
      keepLegacyResid: legacyResid,
      keepCount: defaultKeepCount,
    );

    if (_sessionGeneration != currentGen) {
      return false;
    }

    await prefs.setString(_activeSlotKey, fixedSlot);
    await prefs.setString(_activeResidKey, modernResid);
    await prefs.setString(_activeEncryptedIdKey,
        modernUploaded['encryptedId']?.toString() ?? '');
    await prefs.remove(_dirtyStorageKey);
    _logger.i('☁️ Dual cloud backup synced: $modernFilename');
    return true;
  }

  Future<void> _pruneDualTracks(
    CloudiskSession session, {
    required String keepModernResid,
    String? keepLegacyResid,
    int keepCount = defaultKeepCount,
  }) async {
    final allEntries = <Map<String, dynamic>>[];
    var page = 1;
    const size = 60;
    for (var i = 0; i < 5; i++) {
      final result =
          await _cloudisk.listRes(parentId: session.rootDirId, page: page);
      allEntries.addAll(result.entries);
      if (result.entries.length >= result.totalCount ||
          result.entries.length < size) {
        break;
      }
      page++;
    }

    // 1. 清理现代轨（超过 3 份的旧文件）
    final staleModern = pickStaleModernEntries(allEntries, keepModernResid,
        keepCount: keepCount);
    for (final s in staleModern) {
      if (s['encryptedId']!.isEmpty) continue;
      try {
        await _cloudisk.deleteRes(
          resid: s['resid']!,
          encryptedId: s['encryptedId']!,
          puid: s['puid']!.isNotEmpty ? s['puid']! : session.puid,
        );
      } catch (e) {
        _logger.w('☁️ Prune modern backup ${s['resid']} failed: $e');
      }
    }

    // 2. 清理兼容轨（超过 3 份的旧文件）
    if (keepLegacyResid != null) {
      final staleLegacy = pickStaleEntries(allEntries, keepLegacyResid,
          keepCount: keepCount);
      for (final s in staleLegacy) {
        if (s['encryptedId']!.isEmpty) continue;
        try {
          await _cloudisk.deleteRes(
            resid: s['resid']!,
            encryptedId: s['encryptedId']!,
            puid: s['puid']!.isNotEmpty ? s['puid']! : session.puid,
          );
        } catch (e) {
          _logger.w('☁️ Prune legacy backup ${s['resid']} failed: $e');
        }
      }
    }

    // 3. 清理已废弃的旧 sidecar 孤儿文件（如果存在）
    for (final e in allEntries) {
      final name = e['name']?.toString() ?? '';
      if (name == 'chilleast-sidecar-v2.json') {
        final resid = e['id']?.toString() ?? '';
        final encryptedId = e['encryptedId']?.toString() ?? '';
        if (resid.isNotEmpty && encryptedId.isNotEmpty) {
          try {
            await _cloudisk.deleteRes(
              resid: resid,
              encryptedId: encryptedId,
              puid: e['puid']?.toString() ?? session.puid,
            );
          } catch (_) {}
        }
      }
    }
  }
}
