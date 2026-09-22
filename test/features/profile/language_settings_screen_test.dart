import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/core/state/locale_provider.dart';
import 'package:ChillEast/core/utils/fallback_localizations_delegate.dart';
import 'package:ChillEast/features/profile/screens/language_settings_screen.dart';
import 'package:ChillEast/features/profile/screens/settings_screen.dart';
import 'package:ChillEast/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestWidget({
    required Widget child,
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: overrides,
      child: Consumer(
        builder: (context, ref, _) {
          final locale = ref.watch(localeProvider);
          return MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              AppMaterialLocalizationsDelegate(),
              AppCupertinoLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            locale: locale ?? const Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            home: child,
          );
        },
      ),
    );
  }

  group('LanguageSettingsScreen Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('renders AppBar with language title and all language options',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(child: const LanguageSettingsScreen()),
      );
      await tester.pumpAndSettle();

      // Verify AppBar title exists
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('语言设置'), findsOneWidget);

      // Verify first and last options are present by scrolling
      expect(find.text('跟随系统'), findsOneWidget);
      expect(find.text('简体中文'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('赣语（南昌话）'),
        200,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('赣语（南昌话）'), findsOneWidget);
    });

    testWidgets('shows checkmark on currently active language and switches when tapped',
        (WidgetTester tester) async {
      // Start with simplified Chinese
      SharedPreferences.setMockInitialValues({
        LocaleNotifier.localeKey: 'zh',
      });

      await tester.pumpWidget(
        buildTestWidget(child: const LanguageSettingsScreen()),
      );
      await tester.pumpAndSettle();

      // Checkmark exists on current locale
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // Verify that simplified Chinese is at the first position
      final initialTiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
      final initialFirstTitle = initialTiles.first.title as Text;
      expect(initialFirstTitle.data, equals('简体中文'));

      // Tap on English option
      final englishFinder = find.text('English');
      expect(englishFinder, findsOneWidget);
      await tester.tap(englishFinder);
      await tester.pumpAndSettle();

      // In English locale, AppBar title should update to 'Language'
      expect(find.text('Language'), findsOneWidget);

      // Checkmark should still exist (now on English)
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // Verify English is now at the first position
      final updatedTiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
      final updatedFirstTitle = updatedTiles.first.title as Text;
      expect(updatedFirstTitle.data, equals('English'));

      // Verify SharedPreferences persisted 'en'
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(LocaleNotifier.localeKey), equals('en'));
    });

    testWidgets('SettingsScreen navigates to LanguageSettingsScreen on tap',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(child: const SettingsScreen()),
      );
      await tester.pumpAndSettle();

      // Find language row
      final languageRowFinder = find.widgetWithText(InkWell, '语言设置');
      expect(languageRowFinder, findsOneWidget);

      // Tap to navigate
      await tester.tap(languageRowFinder);
      await tester.pumpAndSettle();

      // Verify LanguageSettingsScreen is pushed
      expect(find.byType(LanguageSettingsScreen), findsOneWidget);
      expect(find.text('跟随系统'), findsOneWidget);
    });
  });
}
