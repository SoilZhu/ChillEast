import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/cookie_manager.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/secure_storage_helper.dart';
import '../../auth/services/http_login_service.dart';
import '../../profile/services/backup_export_service.dart';
import 'cloudisk_service.dart';

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
