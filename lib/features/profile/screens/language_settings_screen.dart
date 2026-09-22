import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state/locale_provider.dart';
import '../../../core/utils/l10n_extension.dart';

class LanguageSettingsScreen extends ConsumerWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final currentLocale = ref.watch(localeProvider);
    final currentCode = LocaleNotifier.localeToCode(currentLocale);
    final primaryColor = Theme.of(context).primaryColor;

    final currentOption = LocaleNotifier.supportedLanguages.firstWhere(
      (opt) => opt.code == currentCode,
      orElse: () => LocaleNotifier.supportedLanguages.first,
    );
    final otherOptions = LocaleNotifier.supportedLanguages
        .where((opt) => opt.code != currentOption.code)
        .toList();
    final languages = [currentOption, ...otherOptions];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.language),
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
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: languages.length,
        itemBuilder: (context, index) {
          final option = languages[index];
          final isSelected = currentCode == option.code;
          final title = LocaleNotifier.getDisplayTitle(option, context);

          return ListTile(
            title: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? primaryColor
                    : (isDark ? Colors.white : const Color(0xFF202124)),
              ),
            ),
            trailing: isSelected
                ? Icon(Icons.check_rounded, color: primaryColor)
                : null,
            onTap: () {
              ref.read(localeProvider.notifier).setLocale(option.locale);
            },
          );
        },
      ),
    );
  }
}
