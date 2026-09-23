import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/state/auth_state.dart';
import '../../../core/state/locale_provider.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/route_utils.dart';
import '../../../core/widgets/brand_switch.dart';
import '../../timetable/services/timetable_service.dart';
import '../providers/settings_provider.dart';
import 'notification_settings_screen.dart';
import 'appearance_settings_screen.dart';
import 'ai_settings_screen.dart';
import 'language_settings_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final currentLocale = ref.watch(localeProvider);

    final currentCode = LocaleNotifier.localeToCode(currentLocale);
    final currentOption = LocaleNotifier.supportedLanguages.firstWhere(
      (opt) => opt.code == currentCode,
      orElse: () => LocaleNotifier.supportedLanguages.first,
    );
    final currentLanguageLabel = currentOption.getLocalizedName(context);
    final autoSyncEnabled =
        ref.watch(settingsProvider).timetableAutoSyncEnabled;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.settings),
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
          _buildSettingItem(
            context,
            icon: Icons.language_rounded,
            title: l10n.language,
            trailing: Text(
              currentLanguageLabel,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : const Color(0xFF5F6368),
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                createSlideUpRoute(const LanguageSettingsScreen()),
              );
            },
          ),
          _buildSettingItem(
            context,
            icon: Icons.code_rounded,
            title: l10n.agentSettings,
            onTap: () {
              Navigator.push(
                context,
                createSlideUpRoute(const AiSettingsScreen()),
              );
            },
          ),
          _buildSettingItem(
            context,
            icon: Icons.palette_outlined,
            title: l10n.appearanceSettings,
            onTap: () {
              Navigator.push(
                context,
                createSlideUpRoute(const AppearanceSettingsScreen()),
              );
            },
          ),
          _buildSettingItem(
            context,
            icon: Icons.notifications_none_rounded,
            title: l10n.notificationSettings,
            onTap: () {
              Navigator.push(
                context,
                createSlideUpRoute(const NotificationSettingsScreen()),
              );
            },
          ),
          _buildSwitchItem(
            context,
            icon: Icons.calendar_month_outlined,
            title: l10n.timetableAutoSync,
            value: autoSyncEnabled,
            onChanged: (v) => _onAutoSyncToggle(context, ref, v),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 24, color: const Color(0xFF5F6368)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: isDark ? Colors.white : const Color(0xFF202124),
                ),
              ),
            ),
            if (trailing != null) ...[
              trailing,
              const SizedBox(width: 4),
            ],
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Color(0xFF9E9E9E),
            ),
          ],
        ),
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

  /// 自动同步开关切换。关闭时二次确认（会删本地课表、保留规则）；
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
}
