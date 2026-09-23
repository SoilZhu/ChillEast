import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/state/auth_state.dart';
import '../../../core/utils/date_format_utils.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/brand_switch.dart';
import '../../timetable/services/timetable_service.dart';
import '../../timetable/services/timetable_storage.dart';
import '../providers/settings_provider.dart';

/// 课表设置页：自动同步开关 + 手动指定本学期第一周周一。
class TimetableSettingsScreen extends ConsumerWidget {
  const TimetableSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final autoSyncEnabled =
        ref.watch(settingsProvider).timetableAutoSyncEnabled;
    final manualIso =
        ref.watch(settingsProvider.select((s) => s.manualFirstWeekMondayIso));
    final manualMonday =
        manualIso != null ? DateTime.tryParse(manualIso) : null;

    // 第二行仅在自动同步关闭时可设置
    final mondayEnabled = !autoSyncEnabled;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.timetableSettings),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF202124),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      body: ListView(
        children: [
          _buildSwitchItem(
            context,
            icon: Icons.sync_rounded,
            title: l10n.timetableAutoSync,
            value: autoSyncEnabled,
            onChanged: (v) => _onAutoSyncToggle(context, ref, v),
          ),
          Opacity(
            opacity: mondayEnabled ? 1.0 : 0.5,
            child: InkWell(
              onTap: mondayEnabled
                  ? () => _pickFirstWeekMonday(context, ref)
                  : null,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    const Icon(Icons.date_range_outlined,
                        size: 24, color: Color(0xFF5F6368)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        l10n.firstWeekMonday,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF202124),
                        ),
                      ),
                    ),
                    FutureBuilder<DateTime>(
                      // 未手动设置时显示当前生效值（元数据 > 按月份猜）
                      future: TimetableStorage().resolveFirstWeekMonday(),
                      builder: (context, snapshot) {
                        final monday = snapshot.data ?? manualMonday;
                        return Text(
                          monday != null
                              ? formatYMMMd(
                                  monday,
                                  Localizations.localeOf(context).toString(),
                                )
                              : l10n.notSet,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF5F6368),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: Color(0xFF9E9E9E),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 24, color: const Color(0xFF5F6368)),
          const SizedBox(width: 16),
          Expanded(
            child: subtitle == null
                ? Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: isDark ? Colors.white : const Color(0xFF202124),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF202124),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
          ),
          BrandSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  /// 自动同步开关切换。关闭时二次确认（会删本地课表、保留规则与元数据）；
  /// 开启且已登录时立即同步一次，免得等到下次登录。
  Future<void> _onAutoSyncToggle(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    final l10n = context.l10n;

    if (!value) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(l10n.disableAutoSyncTitle),
          content: Text(l10n.disableAutoSyncMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(c, true),
              child: Text(l10n.confirm),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;

      await ref
          .read(settingsProvider.notifier)
          .setTimetableAutoSyncEnabled(false);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.localTimetableDeleted),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await ref.read(settingsProvider.notifier).setTimetableAutoSyncEnabled(true);
    if (!context.mounted) return;

    final authed =
        ref.read(authStateProvider).status == AuthStatus.authenticated;
    if (!authed) return;

    try {
      await TimetableService().downloadAndSaveTimetable(
        semester: AppConstants.defaultSemester,
      );
      await ref.read(settingsProvider.notifier).rescheduleNotifications();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.timetableRefreshed),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.timetableRefreshFailed(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 选择本学期第一周周一（自动归一到所选周的周一）。
  /// 保存后课表页通过 settings 监听自动重载。
  Future<void> _pickFirstWeekMonday(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final now = DateTime.now();
    final currentIso =
        ref.read(settingsProvider).manualFirstWeekMondayIso;
    final initial =
        currentIso != null ? DateTime.tryParse(currentIso) ?? now : now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      helpText: context.l10n.selectFirstWeekMondayHelp,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).brightness == Brightness.dark
                ? const ColorScheme.dark(
                    primary: Colors.orange,
                    onPrimary: Colors.black,
                    surface: Color(0xFF1E1E1E),
                  )
                : ColorScheme.light(
                    primary: Theme.of(context).primaryColor,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: const Color(0xFF202124),
                  ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !context.mounted) return;
    await ref
        .read(settingsProvider.notifier)
        .setManualFirstWeekMonday(picked);
  }
}
