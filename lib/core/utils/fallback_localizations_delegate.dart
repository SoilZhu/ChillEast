import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../../l10n/app_localizations.dart';

/// 适用于方言或 Flutter 未内置 MaterialLocalizations 语言的降级委托。
/// 当语言为粤语 (yue)、吴语 (wuu)、湘语 (hsn)、赣语 (gan)、江淮官话 (zh_hefei) 等时，
/// 底层 Material/Cupertino/Widgets 组件回退使用标准中文（zh 或 zh_HK）资源，
/// 避免出现 "No MaterialLocalizations found" 红屏错误。
class AppMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const AppMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    if (GlobalMaterialLocalizations.delegate.isSupported(locale)) {
      return GlobalMaterialLocalizations.delegate.load(locale);
    }
    if (locale.languageCode == 'yue') {
      return GlobalMaterialLocalizations.delegate.load(const Locale('zh', 'HK'));
    }
    return GlobalMaterialLocalizations.delegate.load(const Locale('zh'));
  }

  @override
  bool shouldReload(AppMaterialLocalizationsDelegate old) => false;
}

class AppCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const AppCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    if (GlobalCupertinoLocalizations.delegate.isSupported(locale)) {
      return GlobalCupertinoLocalizations.delegate.load(locale);
    }
    if (locale.languageCode == 'yue') {
      return GlobalCupertinoLocalizations.delegate.load(const Locale('zh', 'HK'));
    }
    return GlobalCupertinoLocalizations.delegate.load(const Locale('zh'));
  }

  @override
  bool shouldReload(AppCupertinoLocalizationsDelegate old) => false;
}

class AppWidgetsLocalizationsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const AppWidgetsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<WidgetsLocalizations> load(Locale locale) {
    if (GlobalWidgetsLocalizations.delegate.isSupported(locale)) {
      return GlobalWidgetsLocalizations.delegate.load(locale);
    }
    if (locale.languageCode == 'yue') {
      return GlobalWidgetsLocalizations.delegate.load(const Locale('zh', 'HK'));
    }
    return GlobalWidgetsLocalizations.delegate.load(const Locale('zh'));
  }

  @override
  bool shouldReload(AppWidgetsLocalizationsDelegate old) => false;
}

/// 全局本地化委托列表，完全替代默认的 AppLocalizations.localizationsDelegates
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = [
  AppLocalizations.delegate,
  AppMaterialLocalizationsDelegate(),
  AppCupertinoLocalizationsDelegate(),
  AppWidgetsLocalizationsDelegate(),
];
