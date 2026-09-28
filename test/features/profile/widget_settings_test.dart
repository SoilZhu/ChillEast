import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/core/state/locale_provider.dart';
import 'package:ChillEast/core/utils/fallback_localizations_delegate.dart';
import 'package:ChillEast/features/profile/providers/appearance_provider.dart';
import 'package:ChillEast/features/profile/screens/button_reorder_screen.dart';
import 'package:ChillEast/features/profile/screens/settings_screen.dart';
import 'package:ChillEast/features/profile/screens/widget_settings_screen.dart';
import 'package:ChillEast/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestWidget({
    required Widget child,
  }) {
    return ProviderScope(
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

  group('Widget Settings in SettingsScreen & ButtonReorderScreen', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('SettingsScreen has Widget Settings entry and navigates to reorder screen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(child: const SettingsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('小组件设置'), findsOneWidget);
      expect(find.byIcon(Icons.widgets_outlined), findsOneWidget);

      await tester.tap(find.text('小组件设置'));
      await tester.pumpAndSettle();

      expect(find.byType(ButtonReorderScreen), findsOneWidget);
      expect(find.text('显示中的功能'), findsOneWidget);
      expect(find.textContaining('4/4'), findsNothing);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      expect(find.textContaining('已隐藏的功能'), findsOneWidget);
      expect(find.textContaining('小组件的快捷入口独立于首页'), findsNothing);
    });

    testWidgets('WidgetSettingsScreen wraps ButtonReorderScreen directly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(child: const WidgetSettingsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ButtonReorderScreen), findsOneWidget);
      expect(find.text('显示中的功能'), findsOneWidget);
      expect(find.textContaining('已隐藏的功能'), findsOneWidget);
    });

    test('AppearanceNotifier initializes and updates widget items correctly', () async {
      final container = ProviderContainer();

      final state = container.read(appearanceProvider);
      final visibleItems = state.widgetItems.where((e) => e.isVisible).toList();

      // Default 4 visible items
      expect(visibleItems.length, 4);
      expect(visibleItems.map((e) => e.id).toList(), [
        'payment_code',
        'library',
        'repairs',
        'empty_classroom',
      ]);

      // Toggle visibility of one item
      container.read(appearanceProvider.notifier).toggleItemVisibility('widget', 'payment_code');
      final updatedState = container.read(appearanceProvider);
      final newVisible = updatedState.widgetItems.where((e) => e.isVisible).toList();
      expect(newVisible.any((e) => e.id == 'payment_code'), isFalse);
      expect(newVisible.length, 3);

      // Allow pending async saves to complete before disposing
      await Future<void>.delayed(const Duration(milliseconds: 50));
      container.dispose();
    });

    test('reorderItems restricts visible widget items to 4 and squeezes the last item to the top of hidden', () async {
      final container = ProviderContainer();

      final state = container.read(appearanceProvider);
      final initialVisible = state.widgetItems.where((e) => e.isVisible).toList();
      final initialHidden = state.widgetItems.where((e) => !e.isVisible).toList();
      expect(initialVisible.length, 4);
      expect(initialVisible.map((e) => e.id).toList(), ['payment_code', 'library', 'repairs', 'empty_classroom']);
      final firstHiddenId = initialHidden.first.id;

      // Drag the first hidden item (UI index 5, since header_hidden is index 4) to index 0 (top of visible)
      container.read(appearanceProvider.notifier).reorderItems('widget', 5, 0);

      final updatedState = container.read(appearanceProvider);
      final updatedVisible = updatedState.widgetItems.where((e) => e.isVisible).toList();
      final updatedHidden = updatedState.widgetItems.where((e) => !e.isVisible).toList();

      // Visible must remain 4 items
      expect(updatedVisible.length, 4);
      // The dragged item is now at index 0
      expect(updatedVisible.first.id, firstHiddenId);
      // The original 4th item 'empty_classroom' was squeezed out to become the first item in hidden
      expect(updatedHidden.first.id, 'empty_classroom');

      await Future<void>.delayed(const Duration(milliseconds: 50));
      container.dispose();
    });

    test('reorderItems when dragging hidden item to the bottom of visible squeezes previous last item', () async {
      final container = ProviderContainer();

      final state = container.read(appearanceProvider);
      final initialHidden = state.widgetItems.where((e) => !e.isVisible).toList();
      final firstHiddenId = initialHidden.first.id;

      // Drag the first hidden item (UI index 5) to index 4 (bottom of visible, right above header_hidden)
      container.read(appearanceProvider.notifier).reorderItems('widget', 5, 4);

      final updatedState = container.read(appearanceProvider);
      final updatedVisible = updatedState.widgetItems.where((e) => e.isVisible).toList();
      final updatedHidden = updatedState.widgetItems.where((e) => !e.isVisible).toList();

      expect(updatedVisible.length, 4);
      // The dragged item successfully becomes the 4th visible item
      expect(updatedVisible[3].id, firstHiddenId);
      // The original 4th item 'empty_classroom' was squeezed out to become the first item in hidden
      expect(updatedHidden.first.id, 'empty_classroom');

      await Future<void>.delayed(const Duration(milliseconds: 50));
      container.dispose();
    });
  });
}
