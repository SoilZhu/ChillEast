import 'package:flutter/widgets.dart';
import '../../l10n/app_localizations.dart';

extension LocalizationExtension on BuildContext {
  /// 便捷获取当前上下文的本地化文案，例如 context.l10n.settings
  AppLocalizations get l10n => AppLocalizations.of(this);
}
