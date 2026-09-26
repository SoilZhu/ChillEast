import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../profile/providers/settings_provider.dart';
import '../../profile/services/backup_provider_refresh.dart';
import '../services/cloud_backup_manager.dart';

/// 登录后是否展示同步推荐页（仅手动登录成功时置 true，内存态）。
final cloudSyncPromptPendingProvider = StateProvider<bool>((ref) => false);

/// 登录后推荐开启自动同步的一屏：以顶层弹窗盖在主页之上，开启后立即同步。
class CloudSyncPromptScreen extends ConsumerStatefulWidget {
  const CloudSyncPromptScreen({super.key});

  /// 带有下往上淡入动画的全屏弹窗路由
  static Route route() {
    return PageRouteBuilder(
      fullscreenDialog: true,
      pageBuilder: (context, animation, secondaryAnimation) =>
          const CloudSyncPromptScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 0.1);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);

        var fadeTween = Tween<double>(begin: 0.0, end: 1.0);
        var fadeAnimation = animation.drive(fadeTween);

        return FadeTransition(
          opacity: fadeAnimation,
          child: SlideTransition(
            position: offsetAnimation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  @override
  ConsumerState<CloudSyncPromptScreen> createState() =>
      _CloudSyncPromptScreenState();
}

class _CloudSyncPromptScreenState
    extends ConsumerState<CloudSyncPromptScreen> {
  bool _busy = false;
  bool _allowPop = false;

  Future<void> _dismiss() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(CloudBackupManager.promptDecidedKey, true);
    } catch (_) {}
    ref.read(cloudSyncPromptPendingProvider.notifier).state = false;
    if (!mounted) return;
    // PopScope 平时禁掉系统返回，仅此处程序化放行退出
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _handleEnable() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // 先拉云端最新覆盖本地，云上没有才推本地上去
      final result = await ref
          .read(settingsProvider.notifier)
          .setCloudBackupAutoSyncEnabled(true);
      if (result?.outcome == InitialSyncOutcome.pulled &&
          result?.backup != null) {
        await BackupProviderRefresh.refreshAfterRestore(ref, result!.backup!);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _dismiss();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: _allowPop,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          surfaceTintColor: theme.scaffoldBackgroundColor,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: Icon(
              Icons.close,
              color: isDark ? Colors.white70 : const Color(0xFF5F6368),
            ),
            onPressed: _busy ? null : () => _dismiss(),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Icon(
                Icons.cloud_sync_outlined,
                size: 56,
                color: theme.primaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                context.l10n.cloudSyncPromptTitle,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF202124),
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.left,
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.cloudSyncPromptMessage,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : const Color(0xFF5F6368),
                  height: 1.5,
                ),
                textAlign: TextAlign.left,
              ),
              const Spacer(),
              // 底部操作按钮 (右对齐)
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _handleEnable,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    minimumSize: const Size(88, 36),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                    elevation: 0,
                  ),
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.cloud_sync_outlined, size: 18),
                  label: Text(
                    context.l10n.cloudSyncPromptEnable,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
