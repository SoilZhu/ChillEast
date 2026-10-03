import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ai/ai_provider.dart';
import '../../../core/services/home_widget_service.dart';
import '../../../core/state/locale_provider.dart';
import '../../homework/providers/homework_provider.dart';
import '../providers/appearance_provider.dart';
import '../providers/settings_provider.dart';

/// 备份写回后的 Provider 刷新（导入 / 云端下拉共用），界面立即生效。
class BackupProviderRefresh {
  static Future<void> refreshAfterRestore(
    dynamic ref,
    Map<String, dynamic> backup,
  ) async {
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
    try {
      await HomeWidgetService().syncWidgets();
    } catch (_) {}
  }
}
