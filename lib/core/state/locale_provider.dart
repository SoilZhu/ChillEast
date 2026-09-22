import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/l10n_extension.dart';

/// 语言项配置模型
class AppLanguageOption {
  final String code;
  final Locale? locale;
  final String nativeName;
  final String Function(BuildContext context) getLocalizedName;

  const AppLanguageOption({
    required this.code,
    required this.locale,
    required this.nativeName,
    required this.getLocalizedName,
  });
}

/// 全局语言状态 Provider
/// state 为 null 表示跟随系统，否则为指定的 Locale（如 Locale('zh')、Locale('en')、Locale('zh', 'HK')）
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale?> {
  static const String localeKey = 'app_language_code';

  /// 所有受支持的语言与方言选项列表
  static final List<AppLanguageOption> supportedLanguages = [
    AppLanguageOption(
      code: 'system',
      locale: null,
      nativeName: 'Follow System',
      getLocalizedName: (context) => context.l10n.followSystem,
    ),
    AppLanguageOption(
      code: 'zh',
      locale: const Locale('zh'),
      nativeName: '简体中文',
      getLocalizedName: (context) => context.l10n.simplifiedChinese,
    ),
    AppLanguageOption(
      code: 'en',
      locale: const Locale('en'),
      nativeName: 'English',
      getLocalizedName: (context) => context.l10n.english,
    ),
    AppLanguageOption(
      code: 'zh_HK',
      locale: const Locale('zh', 'HK'),
      nativeName: '繁體中文（中國香港）',
      getLocalizedName: (context) => context.l10n.traditionalChineseHK,
    ),
    AppLanguageOption(
      code: 'zh_TW',
      locale: const Locale('zh', 'TW'),
      nativeName: '繁體中文',
      getLocalizedName: (context) => context.l10n.traditionalChineseTW,
    ),
    AppLanguageOption(
      code: 'ja',
      locale: const Locale('ja'),
      nativeName: '日本語',
      getLocalizedName: (context) => context.l10n.japanese,
    ),
    AppLanguageOption(
      code: 'es',
      locale: const Locale('es'),
      nativeName: 'Español',
      getLocalizedName: (context) => context.l10n.spanish,
    ),
    AppLanguageOption(
      code: 'fr',
      locale: const Locale('fr'),
      nativeName: 'Français',
      getLocalizedName: (context) => context.l10n.french,
    ),
    AppLanguageOption(
      code: 'pt',
      locale: const Locale('pt'),
      nativeName: 'Português',
      getLocalizedName: (context) => context.l10n.portuguese,
    ),
    AppLanguageOption(
      code: 'ru',
      locale: const Locale('ru'),
      nativeName: 'Русский',
      getLocalizedName: (context) => context.l10n.russian,
    ),
    AppLanguageOption(
      code: 'yue',
      locale: const Locale('yue'),
      nativeName: '粵語（廣州話）',
      getLocalizedName: (context) => context.l10n.cantonese,
    ),
    AppLanguageOption(
      code: 'wuu',
      locale: const Locale('wuu'),
      nativeName: '吴语（苏州话）',
      getLocalizedName: (context) => context.l10n.wuSuzhou,
    ),
    AppLanguageOption(
      code: 'hsn',
      locale: const Locale('hsn'),
      nativeName: '湘语（长沙话）',
      getLocalizedName: (context) => context.l10n.xiangChangsha,
    ),
    AppLanguageOption(
      code: 'zh_hefei',
      locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'hefei'),
      nativeName: '江淮官话（合肥话）',
      getLocalizedName: (context) => context.l10n.jianghuaiHefei,
    ),
    AppLanguageOption(
      code: 'gan',
      locale: const Locale('gan'),
      nativeName: '赣语（南昌话）',
      getLocalizedName: (context) => context.l10n.ganNanchang,
    ),
  ];

  LocaleNotifier() : super(null) {
    _loadLocale();
  }

  /// 将 Locale 转换为存储/传递的代码字符串
  static String localeToCode(Locale? locale) {
    if (locale == null) return 'system';
    if (locale.languageCode == 'zh') {
      if (locale.scriptCode == 'hefei') return 'zh_hefei';
      if (locale.countryCode == 'HK') return 'zh_HK';
      if (locale.countryCode == 'TW') return 'zh_TW';
      return 'zh';
    }
    return locale.languageCode;
  }

  /// 中文及汉语族方言语言代码集合
  static const Set<String> chineseLanguageCodes = {
    'zh',
    'zh_HK',
    'zh_TW',
    'zh_hefei',
    'yue',
    'wuu',
    'hsn',
    'gan',
  };

  /// 判断指定代码是否为中文或其方言
  static bool isChineseCode(String? code) {
    if (code == null) return false;
    return chineseLanguageCodes.contains(code);
  }

  /// 判断指定 Locale 是否为中文或其方言
  static bool isChineseLocale(Locale? locale) {
    if (locale == null) return false;
    if (chineseLanguageCodes.contains(localeToCode(locale))) return true;
    const prefixes = {'zh', 'yue', 'wuu', 'hsn', 'gan'};
    return prefixes.contains(locale.languageCode);
  }

  /// 获取适合在界面列表中展示的语言项名称
  /// - 当为跟随系统时：展示本地化名称（如“跟随系统”或“Follow System”）
  /// - 当当前环境为中文或汉语族方言时：所有中文及方言选项直接展示本地化名称（如“吴语（苏州话）”），不重复附加“ (吴语（苏州话）)”等括号后缀
  /// - 其余非中文语言或在非中文环境下：若本地化名称与原生名称不同，展示“本地化名称 (原生名称)”（如“俄文 (Русский)”、“Wu (Suzhou) (吴语（苏州话）)”）
  static String getDisplayTitle(AppLanguageOption option, BuildContext context) {
    final localizedName = option.getLocalizedName(context);
    if (option.code == 'system' || localizedName == option.nativeName) {
      return localizedName;
    }

    final activeLocale = Localizations.localeOf(context);
    final isCurrentChinese = isChineseLocale(activeLocale);
    final isOptionChinese = isChineseCode(option.code);

    if (isCurrentChinese && isOptionChinese) {
      return localizedName;
    }

    return '$localizedName (${option.nativeName})';
  }

  /// 将代码字符串转换为 Locale（'system' 或 null 返回 null）
  static Locale? codeToLocale(String? code) {
    if (code == null || code.isEmpty || code == 'system') return null;
    switch (code) {
      case 'zh':
        return const Locale('zh');
      case 'zh_HK':
        return const Locale('zh', 'HK');
      case 'zh_TW':
        return const Locale('zh', 'TW');
      case 'zh_hefei':
        return const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'hefei');
      default:
        return Locale(code);
    }
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(localeKey);
    state = codeToLocale(code);
  }

  /// 设置语言（null 表示跟随系统）
  Future<void> setLocale(Locale? locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(localeKey, localeToCode(locale));
  }

  /// 通过标识码切换（'system' / 'zh' / 'en' / 'zh_HK' ...）
  Future<void> setLocaleByCode(String code) async {
    await setLocale(codeToLocale(code));
  }
}
