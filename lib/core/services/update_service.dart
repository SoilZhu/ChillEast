import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:android_package_installer/android_package_installer.dart';
import 'package:logger/logger.dart';
import '../../../core/utils/route_utils.dart';
import '../utils/l10n_extension.dart';
import '../widgets/update_screen.dart';

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  final Dio _dio = Dio();
  final Logger _logger = Logger();
  
  static const String _apiUrl = 'https://eastchill-apk.soilzhu.su/latest/version.json';
  static const String _downloadUrl = 'https://eastchill-apk.soilzhu.su/latest/app-release.apk';

  /// 自动扫描并清理历史下载的 APK 安装包以释放手机存储空间
  static Future<void> cleanHistoricalApks({String? excludePath}) async {
    try {
      final dirs = <Directory>[];

      // 1. 外部存储私有文件目录（旧版本 APK 累积的主目录）
      final extDir = await getExternalStorageDirectory();
      if (extDir != null && extDir.existsSync()) {
        dirs.add(extDir);
      }

      // 2. 临时缓存目录
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        dirs.add(tempDir);
      }

      for (final dir in dirs) {
        try {
          final entities = dir.listSync();
          for (final entity in entities) {
            if (entity is File && entity.path.toLowerCase().endsWith('.apk')) {
              if (excludePath != null && entity.path == excludePath) {
                continue;
              }
              try {
                entity.deleteSync();
              } catch (_) {}
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// 检查更新
  Future<void> checkUpdate(BuildContext context, {bool showNoUpdate = false}) async {
    try {
      // 1. 获取当前版本
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      // 2. 获取最新版本信息 (从 CDN version.json 获取版本号和更新日志)
      final response = await _dio.get(_apiUrl);
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch version information');
      }
      
      dynamic data = response.data;
      if (data is String) {
        data = jsonDecode(data);
      }
      
      final String rawTag = ((data['version'] ?? data['tag_name'] ?? '') as Object).toString();
      final latestVersion = rawTag.replaceAll('v', '').trim();
      final releaseNotes = ((data['release_notes'] ?? data['body'] ?? '') as Object).toString();
      final bool forceUpdate = data['force_update'] == true || data['force'] == true;
      final downloadUrl = (data['download_url'] as String?)?.isNotEmpty == true
          ? (data['download_url'] as String)
          : _downloadUrl;
      
      // 3. 比较版本
      if (isNewerVersion(latestVersion, currentVersion)) {
        if (context.mounted) {
          if (forceUpdate) {
            // 强制更新：不可关闭直接打开更新界面
            Navigator.push(
              context,
              createSlideUpRoute(UpdateScreen(
                version: latestVersion,
                releaseNotes: releaseNotes,
                downloadUrl: downloadUrl,
                isForceUpdate: true,
              )),
            );
          } else {
            // 在底部显示提醒 (类似正在登录的 SnackBar)
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.newVersionFoundSnackBar(latestVersion)),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 10),
                action: SnackBarAction(
                  label: context.l10n.viewAction,
                  onPressed: () => Navigator.push(context, createSlideUpRoute(UpdateScreen(
                    version: latestVersion,
                    releaseNotes: releaseNotes,
                    downloadUrl: downloadUrl,
                    isForceUpdate: false,
                  ))),
                ),
              ),
            );
            
            // 如果是手动检查，或者用户没有关闭过，直接跳转到更新页面
            if (showNoUpdate) {
              Navigator.push(context, createSlideUpRoute(UpdateScreen(
                version: latestVersion,
                releaseNotes: releaseNotes,
                downloadUrl: downloadUrl,
                isForceUpdate: false,
              )));
            }
          }
        }
      } else {
        if (showNoUpdate && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.alreadyLatestVersion)),
          );
        }
      }
    } catch (e) {
      _logger.e('Check update failed: $e');
      if (showNoUpdate && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.checkUpdateFailed(e.toString()))),
        );
      }
    }
  }

  /// 比较两个版本号，判断 latest 是否高于 current
  static bool isNewerVersion(String latest, String current) {
    String cleanVersion(String v) => v.replaceAll('v', '').split('+')[0].split('-')[0].trim();
    List<int> latestParts = cleanVersion(latest)
        .split('.')
        .map((e) => int.tryParse(e) ?? 0)
        .toList();
    List<int> currentParts = cleanVersion(current)
        .split('.')
        .map((e) => int.tryParse(e) ?? 0)
        .toList();
    
    for (int i = 0; i < latestParts.length && i < currentParts.length; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return latestParts.length > currentParts.length;
  }

  Future<void> startDownload(
    BuildContext context,
    String url,
    String version, {
    bool isForceUpdate = false,
  }) async {
    // 下载前先清理历史旧安装包
    await cleanHistoricalApks();

    if (!context.mounted) return;

    // 非强制更新时在底部显示“正在下载”提醒
    ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? snackBar;
    if (!isForceUpdate) {
      snackBar = ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
              ),
              const SizedBox(width: 12),
              Text(context.l10n.downloadingUpdate(version)),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(days: 1), // 持久显示直到手动关闭或完成
        ),
      );
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;

    // 显示下载进度对话框 (保持原有的进度对话框)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _DownloadProgressDialog(
        url: url,
        fileName: 'chilleast_v$version.apk',
        isForceUpdate: isForceUpdate,
        onCompleted: (path) {
          snackBar?.close();
          if (dialogContext.mounted) {
            Navigator.pop(dialogContext);
          }
          _installApk(path);
        },
        onError: (err) {
          snackBar?.close();
          if (dialogContext.mounted) {
            Navigator.pop(dialogContext);
          }
          messenger?.showSnackBar(
            SnackBar(content: Text(l10n.downloadFailedWithReason(err)), behavior: SnackBarBehavior.floating),
          );
        },
        onCancel: () {
          snackBar?.close();
        },
      ),
    );
  }

  Future<void> _installApk(String path) async {
    try {
      final statusCode = await AndroidPackageInstaller.installApk(apkFilePath: path);
      if (statusCode != null) {
        PackageInstallerStatus installationStatus = PackageInstallerStatus.byCode(statusCode);
        _logger.i('Install APK status: ${installationStatus.name}');
      }
    } catch (e) {
      _logger.e('Install APK error: $e');
    }
  }
}

class _DownloadProgressDialog extends StatefulWidget {
  final String url;
  final String fileName;
  final bool isForceUpdate;
  final Function(String) onCompleted;
  final Function(String) onError;
  final VoidCallback? onCancel;

  const _DownloadProgressDialog({
    required this.url,
    required this.fileName,
    this.isForceUpdate = false,
    required this.onCompleted,
    required this.onError,
    this.onCancel,
  });

  @override
  State<_DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  double _progress = 0;
  final Dio _dio = Dio();
  CancelToken? _cancelToken;
  String? _savePath;

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) throw Exception('External storage unavailable');
      
      final savePath = '${dir.path}/${widget.fileName}';
      _savePath = savePath;
      _cancelToken = CancelToken();

      await _dio.download(
        widget.url,
        savePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (count, total) {
          if (total != -1) {
            if (mounted) {
              setState(() {
                _progress = count / total;
              });
            }
          }
        },
      );
      
      widget.onCompleted(savePath);
    } catch (e) {
      if (_savePath != null) {
        try {
          final file = File(_savePath!);
          if (file.existsSync()) {
            file.deleteSync();
          }
        } catch (_) {}
      }
      if (e is! DioException || !CancelToken.isCancel(e)) {
        widget.onError(e.toString());
      }
    }
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    widget.onCancel?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isForceUpdate,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        title: Text(context.l10n.downloadingUpdateTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 16),
            Text('${(_progress * 100).toStringAsFixed(1)}%'),
          ],
        ),
        actions: [
          if (!widget.isForceUpdate)
            TextButton(
              onPressed: () {
                _cancelToken?.cancel();
                widget.onCancel?.call();
                Navigator.pop(context);
              },
              child: Text(context.l10n.cancel),
            ),
        ],
      ),
    );
  }
}
