import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state/locale_provider.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/route_utils.dart';
import 'notification_settings_screen.dart';
import 'appearance_settings_screen.dart';
import 'ai_settings_screen.dart';

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
            onTap: () => _showLanguageDialog(context, ref),
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
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.read(localeProvider);
    final currentCode = LocaleNotifier.localeToCode(currentLocale);

    showDialog(
      context: context,
      builder: (ctx) {
        final l10n = ctx.l10n;
        return AlertDialog(
          title: Text(l10n.language),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          content: SizedBox(
            width: double.maxFinite,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.6,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: LocaleNotifier.supportedLanguages.map((option) {
                    final isSelected = currentCode == option.code;
                    final displayTitle = LocaleNotifier.getDisplayTitle(option, ctx);

                    return _buildLanguageOption(
                      context: ctx,
                      title: displayTitle,
                      isSelected: isSelected,
                      onTap: () {
                        ref.read(localeProvider.notifier).setLocale(option.locale);
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLanguageOption({
    required BuildContext context,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected
              ? primaryColor
              : (isDark ? Colors.white : const Color(0xFF202124)),
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_rounded, color: primaryColor)
          : null,
      onTap: onTap,
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
}
