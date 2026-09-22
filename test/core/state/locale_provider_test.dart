import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/core/state/locale_provider.dart';
import 'package:ChillEast/core/utils/fallback_localizations_delegate.dart';
import 'package:ChillEast/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocaleNotifier Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initial state is null (Follow System) when no preference stored', () async {
      final notifier = LocaleNotifier();
      // 等待异步加载完成
      await Future.delayed(const Duration(milliseconds: 50));
      expect(notifier.state, isNull);
    });

    test('Loads existing zh locale from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        LocaleNotifier.localeKey: 'zh',
      });
      final notifier = LocaleNotifier();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(notifier.state, equals(const Locale('zh')));
    });

    test('Loads existing en locale from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        LocaleNotifier.localeKey: 'en',
      });
      final notifier = LocaleNotifier();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(notifier.state, equals(const Locale('en')));
    });

    test('Loads compound locales (zh_HK, zh_TW, zh_hefei) from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        LocaleNotifier.localeKey: 'zh_HK',
      });
      var notifier = LocaleNotifier();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(notifier.state, equals(const Locale('zh', 'HK')));

      SharedPreferences.setMockInitialValues({
        LocaleNotifier.localeKey: 'zh_TW',
      });
      notifier = LocaleNotifier();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(notifier.state, equals(const Locale('zh', 'TW')));

      SharedPreferences.setMockInitialValues({
        LocaleNotifier.localeKey: 'zh_hefei',
      });
      notifier = LocaleNotifier();
      await Future.delayed(const Duration(milliseconds: 50));
      expect(
        notifier.state,
        equals(const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'hefei')),
      );
    });

    test('Switches between locales and persists correctly', () async {
      final notifier = LocaleNotifier();
      await Future.delayed(const Duration(milliseconds: 50));

      // 切换为繁体中文（香港）
      await notifier.setLocale(const Locale('zh', 'HK'));
      expect(notifier.state, equals(const Locale('zh', 'HK')));
      var prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LocaleNotifier.localeKey), equals('zh_HK'));

      // 切换为江淮官话（合肥话）
      const hefeiLocale = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'hefei');
      await notifier.setLocale(hefeiLocale);
      expect(notifier.state, equals(hefeiLocale));
      prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LocaleNotifier.localeKey), equals('zh_hefei'));

      // 切换为英文
      await notifier.setLocale(const Locale('en'));
      expect(notifier.state, equals(const Locale('en')));
      prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LocaleNotifier.localeKey), equals('en'));

      // 切换为跟随系统 (null)
      await notifier.setLocale(null);
      expect(notifier.state, isNull);
      prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LocaleNotifier.localeKey), equals('system'));
    });

    test('setLocaleByCode works for all supported language codes', () async {
      final notifier = LocaleNotifier();
      await Future.delayed(const Duration(milliseconds: 50));

      for (final option in LocaleNotifier.supportedLanguages) {
        await notifier.setLocaleByCode(option.code);
        expect(notifier.state, equals(option.locale));
        expect(LocaleNotifier.localeToCode(notifier.state), equals(option.code));
      }
    });

    test('supportedLanguages contains all 15 options including follow system', () {
      expect(LocaleNotifier.supportedLanguages.length, equals(15));
      final codes = LocaleNotifier.supportedLanguages.map((o) => o.code).toList();
      expect(codes, containsAll([
        'system',
        'zh',
        'en',
        'zh_HK',
        'zh_TW',
        'ja',
        'es',
        'fr',
        'pt',
        'ru',
        'yue',
        'wuu',
        'hsn',
        'zh_hefei',
        'gan',
      ]));

      final zhHK = LocaleNotifier.supportedLanguages.firstWhere((o) => o.code == 'zh_HK');
      final zhTW = LocaleNotifier.supportedLanguages.firstWhere((o) => o.code == 'zh_TW');
      expect(zhHK.nativeName, equals('繁體中文（中國香港）'));
      expect(zhTW.nativeName, equals('繁體中文'));
    });

    test('isChineseCode and isChineseLocale correctly identify Chinese variants and dialects', () {
      final chineseCodes = ['zh', 'zh_HK', 'zh_TW', 'zh_hefei', 'yue', 'wuu', 'hsn', 'gan'];
      final nonChineseCodes = ['en', 'ja', 'es', 'fr', 'pt', 'ru', 'system', 'de', null];

      for (final code in chineseCodes) {
        expect(LocaleNotifier.isChineseCode(code), isTrue, reason: '$code should be Chinese');
        final locale = LocaleNotifier.codeToLocale(code);
        expect(LocaleNotifier.isChineseLocale(locale), isTrue, reason: '$locale should be Chinese');
      }

      for (final code in nonChineseCodes) {
        expect(LocaleNotifier.isChineseCode(code), isFalse, reason: '$code should NOT be Chinese');
        final locale = LocaleNotifier.codeToLocale(code);
        expect(LocaleNotifier.isChineseLocale(locale), isFalse, reason: '$locale should NOT be Chinese');
      }
    });
  });

  group('AppLocalizations Resource Tests', () {
    test('AppLocalizations returns correct zh texts', () {
      final l10n = lookupAppLocalizations(const Locale('zh'));
      expect(l10n.appTitle, equals('自在东湖'));
      expect(l10n.settings, equals('设置'));
      expect(l10n.language, equals('语言设置'));
      expect(l10n.followSystem, equals('跟随系统'));
      expect(l10n.simplifiedChinese, equals('简体中文'));
      expect(l10n.traditionalChineseHK, equals('繁体中文（中国香港）'));
      expect(l10n.traditionalChineseTW, equals('繁体中文'));
      expect(l10n.english, equals('English'));
      expect(l10n.tabHome, equals('首页'));
      expect(l10n.tabTimetable, equals('课表'));
      expect(l10n.funcBus, equals('实时校车'));
      expect(l10n.funcCsBus, equals('长沙实时公交'));
    });

    test('AppLocalizations returns correct en texts', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(l10n.appTitle, equals('ChillEast'));
      expect(l10n.settings, equals('Settings'));
      expect(l10n.language, equals('Language'));
      expect(l10n.followSystem, equals('System Default'));
      expect(l10n.simplifiedChinese, equals('Simplified Chinese'));
      expect(l10n.traditionalChineseHK, equals('Traditional Chinese (Hong Kong, China)'));
      expect(l10n.traditionalChineseTW, equals('Traditional Chinese'));
      expect(l10n.english, equals('English'));
      expect(l10n.tabHome, equals('Home'));
      expect(l10n.tabTimetable, equals('Schedule'));
      expect(l10n.funcBus, equals('Campus Bus'));
      expect(l10n.funcCsBus, equals('Changsha Bus'));
    });

    test('AppLocalizations returns correct zh_HK texts', () {
      final l10n = lookupAppLocalizations(const Locale('zh', 'HK'));
      expect(l10n.appTitle, equals('自在東湖'));
      expect(l10n.settings, equals('設定'));
      expect(l10n.traditionalChineseHK, equals('繁體中文（中國香港）'));
      expect(l10n.traditionalChineseTW, equals('繁體中文'));
      expect(l10n.tabHome, equals('首頁'));
      expect(l10n.tabTimetable, equals('課表'));
    });

    test('AppLocalizations returns correct zh_TW texts', () {
      final l10n = lookupAppLocalizations(const Locale('zh', 'TW'));
      expect(l10n.appTitle, equals('自在東湖'));
      expect(l10n.settings, equals('設定'));
      expect(l10n.traditionalChineseHK, equals('繁體中文（中國香港）'));
      expect(l10n.traditionalChineseTW, equals('繁體中文'));
      expect(l10n.tabHome, equals('首頁'));
      expect(l10n.tabTimetable, equals('課表'));
    });

    test('AppLocalizations returns correct ja texts', () {
      final l10n = lookupAppLocalizations(const Locale('ja'));
      expect(l10n.appTitle, equals('ChillEast'));
      expect(l10n.settings, equals('設定'));
      expect(l10n.tabHome, equals('ホーム'));
    });

    test('AppLocalizations returns correct es texts', () {
      final l10n = lookupAppLocalizations(const Locale('es'));
      expect(l10n.appTitle, equals('ChillEast'));
      expect(l10n.settings, equals('Ajustes'));
      expect(l10n.tabHome, equals('Inicio'));
    });

    test('AppLocalizations returns correct fr texts', () {
      final l10n = lookupAppLocalizations(const Locale('fr'));
      expect(l10n.appTitle, equals('ChillEast'));
      expect(l10n.settings, equals('Paramètres'));
      expect(l10n.tabHome, equals('Accueil'));
    });

    test('AppLocalizations returns correct pt texts', () {
      final l10n = lookupAppLocalizations(const Locale('pt'));
      expect(l10n.appTitle, equals('ChillEast'));
      expect(l10n.settings, equals('Configurações'));
      expect(l10n.tabHome, equals('Início'));
    });

    test('AppLocalizations returns correct ru texts', () {
      final l10n = lookupAppLocalizations(const Locale('ru'));
      expect(l10n.appTitle, equals('ChillEast'));
      expect(l10n.settings, equals('Настройки'));
      expect(l10n.tabHome, equals('Главная'));
    });

    test('AppLocalizations returns correct yue texts', () {
      final l10n = lookupAppLocalizations(const Locale('yue'));
      expect(l10n.appTitle, equals('自在东湖'));
      expect(l10n.settings, equals('设定'));
      expect(l10n.traditionalChineseHK, equals('繁体中文（中国香港）'));
      expect(l10n.traditionalChineseTW, equals('繁体中文'));
      expect(l10n.tabHome, equals('主页'));
    });

    test('AppLocalizations returns correct wuu texts', () {
      final l10n = lookupAppLocalizations(const Locale('wuu'));
      expect(l10n.appTitle, equals('自在东湖'));
      expect(l10n.settings, equals('设定'));
      expect(l10n.tabHome, equals('头一页'));
    });

    test('AppLocalizations returns correct hsn texts', () {
      final l10n = lookupAppLocalizations(const Locale('hsn'));
      expect(l10n.appTitle, equals('自在东湖'));
      expect(l10n.settings, equals('设置'));
      expect(l10n.tabHome, equals('首页'));
    });

    test('AppLocalizations returns correct zh_hefei texts', () {
      final l10n = lookupAppLocalizations(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'hefei'),
      );
      expect(l10n.appTitle, equals('自在东湖'));
      expect(l10n.settings, equals('设定'));
      expect(l10n.tabHome, equals('头页'));
      expect(l10n.cancel, equals('算了'));
      expect(l10n.confirm, equals('定下'));
      expect(l10n.noData, equals('没得数据'));
    });

    test('AppLocalizations returns correct gan texts', () {
      final l10n = lookupAppLocalizations(const Locale('gan'));
      expect(l10n.appTitle, equals('自在东湖'));
      expect(l10n.settings, equals('设置'));
      expect(l10n.tabHome, equals('首页'));
      expect(l10n.ganNanchang, equals('赣语（南昌话）'));
    });
  });

  group('MaterialLocalizations & CupertinoLocalizations Fallback Tests', () {
    testWidgets(
      'Scaffold and Drawer render with MaterialLocalizations across all 15 options without error',
      (tester) async {
        for (final option in LocaleNotifier.supportedLanguages) {
          await tester.pumpWidget(
            MaterialApp(
              locale: option.locale,
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                drawer: const Drawer(),
                body: Builder(
                  builder: (context) {
                    final l10n = AppLocalizations.of(context);
                    final mat = MaterialLocalizations.of(context);
                    return Text('${l10n.tabHome} - ${mat.openAppDrawerTooltip}');
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(Scaffold), findsOneWidget);
        }
      },
    );
  });

  group('LocaleNotifier.getDisplayTitle Tests', () {
    testWidgets('Displays clean titles for Chinese dialects in zh locale', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final wuu = LocaleNotifier.supportedLanguages.firstWhere((o) => o.code == 'wuu');
              final yue = LocaleNotifier.supportedLanguages.firstWhere((o) => o.code == 'yue');
              final hsn = LocaleNotifier.supportedLanguages.firstWhere((o) => o.code == 'hsn');
              final hefei = LocaleNotifier.supportedLanguages.firstWhere((o) => o.code == 'zh_hefei');
              final gan = LocaleNotifier.supportedLanguages.firstWhere((o) => o.code == 'gan');
              final zh = LocaleNotifier.supportedLanguages.firstWhere((o) => o.code == 'zh');
              final zhHK = LocaleNotifier.supportedLanguages.firstWhere((o) => o.code == 'zh_HK');
              final zhTW = LocaleNotifier.supportedLanguages.firstWhere((o) => o.code == 'zh_TW');
              final ru = LocaleNotifier.supportedLanguages.firstWhere((o) => o.code == 'ru');

              expect(LocaleNotifier.getDisplayTitle(wuu, context), equals('吴语（苏州话）'));
              expect(LocaleNotifier.getDisplayTitle(yue, context), equals('粤语（广州话）'));
              expect(LocaleNotifier.getDisplayTitle(hsn, context), equals('湘语（长沙话）'));
              expect(LocaleNotifier.getDisplayTitle(hefei, context), equals('江淮官话（合肥话）'));
              expect(LocaleNotifier.getDisplayTitle(gan, context), equals('赣语（南昌话）'));
              expect(LocaleNotifier.getDisplayTitle(zh, context), equals('简体中文'));
              expect(LocaleNotifier.getDisplayTitle(zhHK, context), equals('繁体中文（中国香港）'));
              expect(LocaleNotifier.getDisplayTitle(zhTW, context), equals('繁体中文'));
              expect(LocaleNotifier.getDisplayTitle(ru, context), equals('俄语 (Русский)'));

              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('Displays clean titles for Chinese dialects in yue locale without duplicate suffixes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('yue'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final wuu = LocaleNotifier.supportedLanguages.firstWhere((o) => o.code == 'wuu');
              final yue = LocaleNotifier.supportedLanguages.firstWhere((o) => o.code == 'yue');
              final hsn = LocaleNotifier.supportedLanguages.firstWhere((o) => o.code == 'hsn');
              final hefei = LocaleNotifier.supportedLanguages.firstWhere((o) => o.code == 'zh_hefei');
              final gan = LocaleNotifier.supportedLanguages.firstWhere((o) => o.code == 'gan');
              final zh = LocaleNotifier.supportedLanguages.firstWhere((o) => o.code == 'zh');
              final zhHK = LocaleNotifier.supportedLanguages.firstWhere((o) => o.code == 'zh_HK');
              final zhTW = LocaleNotifier.supportedLanguages.firstWhere((o) => o.code == 'zh_TW');
              final ru = LocaleNotifier.supportedLanguages.firstWhere((o) => o.code == 'ru');

              expect(LocaleNotifier.getDisplayTitle(wuu, context), equals('吴语（苏州话）'));
              expect(LocaleNotifier.getDisplayTitle(yue, context), equals('粤语（广州话）'));
              expect(LocaleNotifier.getDisplayTitle(hsn, context), equals('湘语（长沙话）'));
              expect(LocaleNotifier.getDisplayTitle(hefei, context), equals('江淮官话（合肥话）'));
              expect(LocaleNotifier.getDisplayTitle(gan, context), equals('赣语（南昌话）'));
              expect(LocaleNotifier.getDisplayTitle(zh, context), equals('简体中文'));
              expect(LocaleNotifier.getDisplayTitle(zhHK, context), equals('繁体中文（中国香港）'));
              expect(LocaleNotifier.getDisplayTitle(zhTW, context), equals('繁体中文'));
              expect(LocaleNotifier.getDisplayTitle(ru, context), equals('俄语 (Русский)'));

              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('Displays localized and native name in English locale', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final wuu = LocaleNotifier.supportedLanguages.firstWhere((o) => o.code == 'wuu');
              final zhHK = LocaleNotifier.supportedLanguages.firstWhere((o) => o.code == 'zh_HK');
              final zhTW = LocaleNotifier.supportedLanguages.firstWhere((o) => o.code == 'zh_TW');
              final en = LocaleNotifier.supportedLanguages.firstWhere((o) => o.code == 'en');

              expect(LocaleNotifier.getDisplayTitle(wuu, context), equals('Wu (吴语（苏州话）)'));
              expect(LocaleNotifier.getDisplayTitle(zhHK, context), equals('Traditional Chinese (Hong Kong, China) (繁體中文（中國香港）)'));
              expect(LocaleNotifier.getDisplayTitle(zhTW, context), equals('Traditional Chinese (繁體中文)'));
              expect(LocaleNotifier.getDisplayTitle(en, context), equals('English'));

              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    });
  });
}

