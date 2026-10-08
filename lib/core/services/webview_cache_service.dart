import 'dart:io';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/app_logger.dart';

/// WebView 缓存管理服务
/// 负责控制、清理与限制 InAppWebView 产生的磁盘缓存与离线存储 (LocalStorage/IndexedDB)
class WebViewCacheService {
  static final WebViewCacheService _instance = WebViewCacheService._internal();
  factory WebViewCacheService() => _instance;
  WebViewCacheService._internal();

  static final _logger = AppLogger.instance;

  /// 清理 WebView 缓存
  /// - [includeDiskFiles]: 是否清理磁盘缓存文件（默认 true）
  /// - [clearStorage]: 是否同时清理 WebStorage / IndexedDB / ServiceWorker 离线存储（默认 false，登出时建议传 true）
  static Future<void> clearCache({
    bool includeDiskFiles = true,
    bool clearStorage = false,
  }) async {
    try {
      // 1. 清理 WebView 内存与磁盘网络缓存
      await InAppWebViewController.clearAllCache(
        includeDiskFiles: includeDiskFiles,
      );
      _logger.i('🧹 WebView cache cleared (includeDiskFiles: $includeDiskFiles)');

      // 2. 若指定，清理 WebStorage (IndexedDB, LocalStorage, WebSQL 等)
      if (clearStorage) {
        try {
          await WebStorageManager.instance().deleteAllData();
          _logger.i('🧹 WebView WebStorage & IndexedDB deleted');
        } catch (e) {
          _logger.w('⚠️ WebStorageManager deleteAllData failed: $e');
        }
      }

      // 3. 扫描并清理应用缓存目录中的 webview 临时文件
      if (includeDiskFiles) {
        await _cleanWebViewCacheDirectories();
      }
    } catch (e) {
      _logger.w('⚠️ Clear WebView cache encountered error: $e');
    }
  }

  /// 扫描并清理 Android/iOS 系统缓存目录中由 WebView 生成的临时缓存目录
  static Future<void> _cleanWebViewCacheDirectories() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        await for (final entity in tempDir.list()) {
          final name = entity.path.split(Platform.pathSeparator).last.toLowerCase();
          if (name.contains('webview') ||
              name.contains('org.chromium') ||
              name.contains('gpu') ||
              name.contains('cache')) {
            try {
              if (entity is Directory) {
                await entity.delete(recursive: true);
              } else if (entity is File) {
                await entity.delete();
              }
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }

  /// 计算临时缓存目录的大致字节数（供 UI 展示）
  static Future<int> getEstimatedCacheSize() async {
    int totalBytes = 0;
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        await for (final entity in tempDir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            try {
              totalBytes += await entity.length();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
    return totalBytes;
  }

  /// 冷启动自动维护：清理磁盘无用 WebView 缓存
  static Future<void> autoPruneCacheOnStartup() async {
    try {
      // 仅清理磁盘文件缓存，保留用户会话 LocalStorage
      await clearCache(includeDiskFiles: true, clearStorage: false);
    } catch (_) {}
  }
}
