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
/// 文件名：`chilleast-backup-{slot}-{stamp}.json`，
/// stamp 为 `yyyyMMdd-HHmmss`（字典序即时间序，删除失败也能肉眼定位最新）。
/// A/B 轮换：每轮上传到对侧槽位，校验成功后删除**所有**其它同前缀旧文件
///（即使某次删除失败，下次同步也会收敛清理）。
class CloudBackupManager {
  static final CloudBackupManager instance = CloudBackupManager._internal();
  CloudBackupManager._internal();

  static const String filePrefix = 'chilleast-backup-';
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

  /// 文件名：slot 为 a/b。
  static String buildFileName(String slot, DateTime time) {
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp = '${time.year}${two(time.month)}${two(time.day)}-'
        '${two(time.hour)}${two(time.minute)}${two(time.second)}';
    return '$filePrefix$slot-$stamp.json';
  }

  /// 解析备份文件名 → (slot, stamp)，不匹配返回 null。
  static ({String slot, String stamp})? parseFileName(String name) {
    final m = RegExp(
      '^${RegExp.escape(filePrefix)}([ab])-(\\d{8}-\\d{6})\\.json\$',
    ).firstMatch(name);
    if (m == null) return null;
    return (slot: m.group(1)!, stamp: m.group(2)!);
  }

  /// 轮换目标槽位（无记录时首轮用 a）。
  static String pickTargetSlot(String? activeSlot) =>
      activeSlot == 'a' ? 'b' : 'a';

  /// 从目录条目中挑出最新的备份文件（文件名 stamp 字典序即时间序）。
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
      if (best == null || name.compareTo(best['name']!) > 0) {
        best = {
          'resid': resid,
          'encryptedId': encryptedId,
          'puid': e['puid']?.toString() ?? '',
          'name': name,
          'slot': parsed.slot,
        };
      }
    }
    return best;
  }

  /// 从目录条目中挑出需删除的 resid（同前缀且非本次上传）。
  static List<Map<String, String>> pickStaleEntries(
    List<Map<String, dynamic>> entries,
    String keepResid,
  ) {
    final stale = <Map<String, String>>[];
    for (final e in entries) {
      final name = e['name']?.toString() ?? '';
      if (parseFileName(name) == null) continue;
      final resid = e['id']?.toString() ?? '';
      if (resid.isEmpty || resid == keepResid) continue;
      stale.add({
        'resid': resid,
        'encryptedId': e['encryptedId']?.toString() ?? '',
        'puid': e['puid']?.toString() ?? '',
      });
    }
    return stale;
  }

  /// 本地数据有更改时调用（各存储落盘点）。去抖 10s 后同步一次。
  void markDirty() {
    _debounceTimer?.cancel();
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
        // （之前临时 Jar 剥 campus_user 走 /login 的方案是错的：
        // 无 CAS ticket 时 /login 只回登录页，根本不会跳 login6。）
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
    } catch (e) {
      _logger.w('☁️ Cloud backup logout reset failed: $e');
    }
  }

  /// 超星会话过期时用保存的凭证静默重登，把新 Cookie 发布到共享 Jar。
  /// 同一时间只跑一份，避免和前台登录打架。
  Future<bool> _refreshChaoxingSession() async {
    if (_refreshingAuth) return false;
    _refreshingAuth = true;
    try {
      final snapshot = await SecureStorageHelper().readAuthSnapshot();
      final u = snapshot.username;
      final p = snapshot.password;
      if (u == null || u.isEmpty || p == null || p.isEmpty) return false;
      _logger.i('☁️ Chaoxing session expired, silent re-login…');
      final result = await HttpLoginService().login(u, p);
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

  /// 应用启动并在静默登录后拉取云端最新备份并覆盖应用到本地。
  /// 若未开启自动同步或无凭据或云端无备份，则静默返回 null。
  Future<Map<String, dynamic>?> pullLatestOnStartup() async {
    if (_running) {
      return null;
    }
    _running = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if ((prefs.getBool(toggleKey) ?? false) == false) return null;
      if (!await SecureStorageHelper().hasCredentials()) return null;

      try {
        return await _pullAndApply(prefs);
      } on CloudiskAuthException {
        _cloudisk.invalidateSession();
        if (await _refreshChaoxingSession()) {
          _cloudisk.invalidateSession();
          try {
            return await _pullAndApply(prefs);
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
  Future<Map<String, dynamic>?> _pullAndApply(SharedPreferences prefs) async {
    final session = await _cloudisk.ensureSession();
    final latest = await _findLatestBackup(session);
    if (latest == null) return null;

    final bytes = await _cloudisk.downloadBytes(
      resid: latest['resid']!,
      encryptedId: latest['encryptedId']!,
      puid: latest['puid']!.isNotEmpty ? latest['puid']! : session.puid,
      folderId: session.rootDirId,
    );
    // 先校验再写回：坏文件不碰本地
    final backup =
        BackupExportService.parseBackupJson(utf8.decode(bytes));
    await BackupExportService.applyBackupData(backup);
    await prefs.setString(_activeSlotKey, latest['slot']!);
    await prefs.setString(_activeResidKey, latest['resid']!);
    await prefs.setString(_activeEncryptedIdKey, latest['encryptedId']!);
    _logger.i('☁️ Cloud backup pulled: ${latest['name']}');
    return backup;
  }

  /// 翻页找云端最新的备份文件（最多 5 页）。
  Future<Map<String, String>?> _findLatestBackup(
    CloudiskSession session,
  ) async {
    Map<String, String>? best;
    var page = 1;
    const size = 60;
    for (var i = 0; i < 5; i++) {
      final result =
          await _cloudisk.listRes(parentId: session.rootDirId, page: page);
      final candidate = pickLatestBackupEntry(result.entries);
      if (candidate != null &&
          (best == null ||
              candidate['name']!.compareTo(best['name']!) > 0)) {
        best = candidate;
      }
      if (result.entries.length >= result.totalCount ||
          result.entries.length < size) {
        break;
      }
      page++;
    }
    return best;
  }

  Future<bool> _doSync(SharedPreferences prefs) async {
      final data = await BackupExportService.buildBackupData();
      final bytes = utf8.encode(const JsonEncoder().convert(data));

      final session = await _cloudisk.ensureSession();
      final targetSlot =
          pickTargetSlot(prefs.getString(_activeSlotKey));
      final filename = buildFileName(targetSlot, DateTime.now());

      final uploaded = await _cloudisk.uploadJson(
        folderId: session.rootDirId,
        filename: filename,
        bytes: bytes,
      );
      final resid = uploaded['resid'].toString();

      // 收敛清理：删掉所有其它同前缀旧文件
      await _pruneOthers(session, keepResid: resid);

      await prefs.setString(_activeSlotKey, targetSlot);
      await prefs.setString(_activeResidKey, resid);
      await prefs.setString(_activeEncryptedIdKey,
          uploaded['encryptedId']?.toString() ?? '');
      _logger.i('☁️ Cloud backup synced: $filename');
      return true;
  }

  Future<void> _pruneOthers(
    CloudiskSession session, {
    required String keepResid,
  }) async {
    var page = 1;
    const size = 60;
    // 最多翻 5 页，防异常大目录
    for (var i = 0; i < 5; i++) {
      final result =
          await _cloudisk.listRes(parentId: session.rootDirId, page: page);
      final stale = pickStaleEntries(result.entries, keepResid);
      for (final s in stale) {
        if (s['encryptedId']!.isEmpty) continue;
        try {
          await _cloudisk.deleteRes(
            resid: s['resid']!,
            encryptedId: s['encryptedId']!,
            puid: s['puid']!.isNotEmpty ? s['puid']! : session.puid,
          );
        } catch (e) {
          // 单个删除失败不影响整体，下次同步继续收敛
          _logger.w('☁️ Prune ${s['resid']} failed: $e');
        }
      }
      if (result.entries.length >= result.totalCount ||
          result.entries.length < size) {
        break;
      }
      page++;
    }
  }
}
