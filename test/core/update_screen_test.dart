import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/core/widgets/update_screen.dart';
import 'package:ChillEast/l10n/app_localizations.dart';

Widget createTestWidget(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('zh'),
    home: child,
  );
}

void main() {
  testWidgets('UpdateScreen renders optional update correctly with close button', (tester) async {
    await tester.pumpWidget(
      createTestWidget(
        const UpdateScreen(
          version: '1.2.0',
          releaseNotes: '- 优化体验',
          downloadUrl: 'https://example.com/app.apk',
          isForceUpdate: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('发现新版本 v1.2.0'), findsOneWidget);
    expect(find.textContaining('优化体验'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    final popScopeFinder = find.byType(PopScope);
    expect(popScopeFinder, findsOneWidget);
    final popScope = tester.widget<PopScope>(popScopeFinder);
    expect(popScope.canPop, isTrue);
  });

  testWidgets('UpdateScreen renders force update correctly without close button and cannot pop', (tester) async {
    await tester.pumpWidget(
      createTestWidget(
        const UpdateScreen(
          version: '2.0.0',
          releaseNotes: '- 必须更新以修复关键故障',
          downloadUrl: 'https://example.com/app.apk',
          isForceUpdate: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('发现新版本 v2.0.0'), findsOneWidget);
    expect(find.textContaining('必须更新以修复关键故障'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);

    final popScopeFinder = find.byType(PopScope);
    expect(popScopeFinder, findsOneWidget);
    final popScope = tester.widget<PopScope>(popScopeFinder);
    expect(popScope.canPop, isFalse);
  });
}
