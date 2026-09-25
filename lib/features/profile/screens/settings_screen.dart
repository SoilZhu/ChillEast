import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ai/ai_provider.dart';
import '../../../core/state/locale_provider.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/route_utils.dart';
import '../../homework/providers/homework_provider.dart';
import '../providers/appearance_provider.dart';
import '../providers/settings_provider.dart';
import '../services/backup_export_service.dart';
import 'notification_settings_screen.dart';
import 'appearance_settings_screen.dart';
import 'button_reorder_screen.dart';
import 'ai_settings_screen.dart';
import 'language_settings_screen.dart';
import 'timetable_settings_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _exporting = false;
  bool _importing = false;

  Future<void> _handleExportBackup() async {
    if (_exporting || _importing) return;
    setState(() => _exporting = true);
    try {
      await BackupExportService.exportAndShare(
        shareText: context.l10n.backupShareText,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.backupExportSuccess),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.backupExportFailed(e.toString())),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _handleImportBackup() async {
    if (_exporting || _importing) return;
    final l10n = context.l10n;

    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.dataImportFailed(e.toString())),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    if (picked == null || picked.files.isEmpty) return; // 用户取消
    final path = picked.files.single.path;
    if (path == null || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.dataImportInvalidFile),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    late final Map<String, dynamic> backup;
    try {
      backup = await BackupExportService.readBackupFile(path);
    } on FormatException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.dataImportInvalidFile),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    } on UnsupportedError {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.dataImportVersionTooNew),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.dataImportFailed(e.toString())),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.dataImportConfirmTitle),
        content: Text(l10n.dataImportConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _importing = true);
    try {
      await BackupExportService.applyBackupData(backup);
      // 写回后刷新各 Provider，界面立即生效
      final settings = backup['settings'] is Map
          ? backup['settings'] as Map
          : const {};
      final langCode = settings['languageCode'];
      if (langCode is String) {
        try {
          await ref.read(localeProvider.notifier).setLocaleByCode(langCode);
        } catch (_) {}
      }
      try {
        await ref.read(settingsProvider.notifier).reload();
      } catch (_) {}
      try {
        await ref.read(appearanceProvider.notifier).reload();
      } catch (_) {}
      try {
        await ref.read(aiAssistantProvider.notifier).loadSettings();
      } catch (_) {}
      try {
        await ref.read(homeworkProvider.notifier).reloadFromStorage();
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.dataImportSuccess),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on FormatException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.dataImportInvalidFile),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on UnsupportedError {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.dataImportVersionTooNew),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.dataImportFailed(e.toString())),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final currentLocale = ref.watch(localeProvider);

    final currentCode = LocaleNotifier.localeToCode(currentLocale);
    final currentOption = LocaleNotifier.supportedLanguages.firstWhere(
      (opt) => opt.code == currentCode,
      orElse: () => LocaleNotifier.supportedLanguages.first,
    );
    final currentLanguageLabel = currentOption.getLocalizedName(context);

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
            icon: Icons.widgets_outlined,
            title: l10n.widgetSettings,
            onTap: () {
              Navigator.push(
                context,
                createSlideUpRoute(ButtonReorderScreen(
                  title: l10n.widgetSettings,
                  listType: 'widget',
                )),
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
          _buildSettingItem(
            context,
            icon: Icons.calendar_month_outlined,
            title: l10n.timetableSettings,
            onTap: () {
              Navigator.push(
                context,
                createSlideUpRoute(const TimetableSettingsScreen()),
              );
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _buildSettingItem(
            context,
            icon: Icons.backup_outlined,
            title: l10n.dataBackup,
            subtitle: l10n.backupSecurityTip,
            trailing: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            showChevron: !_exporting,
            onTap: _handleExportBackup,
          ),
          _buildSettingItem(
            context,
            icon: Icons.restore_outlined,
            title: l10n.dataImport,
            trailing: _importing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            showChevron: !_importing,
            onTap: _handleImportBackup,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    bool showChevron = true,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: isDark ? Colors.white : const Color(0xFF202124),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : const Color(0xFF9E9E9E),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              trailing,
              const SizedBox(width: 4),
            ],
            if (showChevron)
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
}
