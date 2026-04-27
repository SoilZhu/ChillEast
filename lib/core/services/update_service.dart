import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:install_plugin_v2/install_plugin_v2.dart';
import 'package:logger/logger.dart';
import '../../../core/utils/route_utils.dart';
import '../widgets/update_screen.dart';

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  final Dio _dio = Dio();
  final Logger _logger = Logger();
  
  static const String _githubRepo = 'soilzhu/chilleast';
  static const String _apiUrl = 'https://api.github.com/repos/$_githubRepo/releases/latest';
  static const String _downloadUrl = 'https://eastchill-apk.soilzhu.su/latest/app-release.apk';

  /// 检查更新
  Future<void> checkUpdate(BuildContext context, {bool showNoUpdate = false}) async {
    try {
      // 1. 获取当前版本
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      // 2. 获取最新版本信息 (从 GitHub 获取版本号和更新日志)
      final response = await _dio.get(_apiUrl);
      if (response.statusCode != 200) {
        throw Exception('无法获取版本信息');
      }
      
      final data = response.data;
      final latestVersion = (data['tag_name'] as String).replaceAll('v', '');
      final releaseNotes = data['body'] as String;
      
      // 3. 比较版本
      if (_isNewerVersion(latestVersion, currentVersion)) {
        if (context.mounted) {
          // 在底部显示提醒 (类似正在登录的 SnackBar)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🚀 发现新版本 v$latestVersion，点击查看详情'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 10),
              action: SnackBarAction(
                label: '查看',
                onPressed: () => Navigator.push(context, createSlideUpRoute(UpdateScreen(
                  version: latestVersion,
                  releaseNotes: releaseNotes,
                  downloadUrl: _downloadUrl,
                ))),
              ),
            ),
          );
          
          // 如果是手动检查，或者用户没有关闭过，直接跳转到更新页面
          if (showNoUpdate) {
            Navigator.push(context, createSlideUpRoute(UpdateScreen(
              version: latestVersion,
              releaseNotes: releaseNotes,
              downloadUrl: _downloadUrl,
            )));
          }
        }
      } else {
        if (showNoUpdate && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已是最新版本')),
          );
        }
      }
    } catch (e) {
      _logger.e('Check update failed: $e');
      if (showNoUpdate && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('检查更新失败: $e')),
        );
      }
    }
  }

  bool _isNewerVersion(String latest, String current) {
    List<int> latestParts = latest.split('.').map(int.parse).toList();
    List<int> currentParts = current.split('.').map(int.parse).toList();
    
    for (int i = 0; i < latestParts.length && i < currentParts.length; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return latestParts.length > currentParts.length;
  }

  Future<void> startDownload(BuildContext context, String url, String version) async {
    // 在底部显示“正在下载”提醒
    final snackBar = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
            ),
            const SizedBox(width: 12),
            Text('正在下载更新 v$version...'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(days: 1), // 持久显示直到手动关闭或完成
      ),
    );

    // 显示下载进度对话框 (保持原有的进度对话框)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DownloadProgressDialog(
        url: url,
        fileName: 'chilleast_v$version.apk',
        onCompleted: (path) {
          snackBar.close();
          Navigator.pop(context);
          _installApk(path);
        },
        onError: (err) {
          snackBar.close();
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('下载失败: $err'), behavior: SnackBarBehavior.floating),
          );
        },
      ),
    );
  }

  Future<void> _installApk(String path) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final appId = packageInfo.packageName;
      
      final result = await InstallPluginV2.installApk(path, appId);
      _logger.i('Install APK result: $result');
    } catch (e) {
      _logger.e('Install APK error: $e');
    }
  }
}

class _DownloadProgressDialog extends StatefulWidget {
  final String url;
  final String fileName;
  final Function(String) onCompleted;
  final Function(String) onError;

  const _DownloadProgressDialog({
    required this.url,
    required this.fileName,
    required this.onCompleted,
    required this.onError,
  });

  @override
  State<_DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  double _progress = 0;
  final Dio _dio = Dio();
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) throw Exception('无法访问外部存储');
      
      final savePath = '${dir.path}/${widget.fileName}';
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
      if (!CancelToken.isCancel(e as DioException)) {
        widget.onError(e.toString());
      }
    }
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: const Text('正在下载更新'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: _progress),
          const SizedBox(height: 16),
          Text('${(_progress * 100).toStringAsFixed(1)}%'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _cancelToken?.cancel();
            Navigator.pop(context);
          },
          child: const Text('取消'),
        ),
      ],
    );
  }
}
