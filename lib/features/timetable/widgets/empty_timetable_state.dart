import 'package:flutter/material.dart';
import '../../../core/utils/l10n_extension.dart';

/// 课表空状态组件
class EmptyTimetableState extends StatelessWidget {
  /// 自动同步是否开启。
  /// 开启时显示“正在同步”转圈；关闭时提示点右上角刷新按钮手动同步。
  final bool autoSyncEnabled;

  const EmptyTimetableState({super.key, this.autoSyncEnabled = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                autoSyncEnabled
                    ? Icons.calendar_today_outlined
                    : Icons.cloud_off_outlined,
                size: 64,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              autoSyncEnabled
                  ? context.l10n.timetableSyncing
                  : context.l10n.noLocalTimetable,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF202124),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              autoSyncEnabled
                  ? context.l10n.timetableSyncingDesc
                  : context.l10n.tapRefreshButtonToSync,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF5F6368),
                height: 1.5,
              ),
            ),
            if (autoSyncEnabled) ...[
              const SizedBox(height: 32),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
