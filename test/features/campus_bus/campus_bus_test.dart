import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/features/campus_bus/models/campus_bus_data.dart';
import 'package:ChillEast/features/campus_bus/screens/campus_bus_map_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ChillEast/l10n/app_localizations.dart';

void main() {
  group('CampusBusRepository Tests', () {
    test('Lines definitions are complete and valid', () {
      expect(CampusBusRepository.lines.length, greaterThanOrEqualTo(5));
      final lineIds = CampusBusRepository.lines.map((l) => l.id).toSet();
      expect(lineIds.contains('red_loop'), isTrue);
      expect(lineIds.contains('green_line'), isTrue);
      expect(lineIds.contains('purple_line'), isTrue);
      expect(lineIds.contains('metro_feeder'), isTrue);
      expect(lineIds.contains('metro_line6'), isTrue);
    });

    test('Stations definitions are complete with valid coordinates', () {
      expect(CampusBusRepository.stations.length, equals(17));
      for (final stn in CampusBusRepository.stations) {
        expect(stn.id.isNotEmpty, isTrue);
        expect(stn.name.isNotEmpty, isTrue);
        expect(stn.englishName.isNotEmpty, isTrue);
        expect(stn.normX, inInclusiveRange(0.0, 1.0));
        expect(stn.normY, inInclusiveRange(0.0, 1.0));
      }
    });
  });

  group('CampusBusMapScreen Tests', () {
    Widget buildTestScreen() {
      return const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        locale: Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        home: CampusBusMapScreen(),
      );
    }

    testWidgets('Renders CampusBusMapScreen with AppBar and InteractiveViewer',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      // Verify AppBar exists with title
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('校内公交线路'), findsOneWidget);

      // Verify InteractiveViewer exists for pinch-to-zoom
      expect(find.byType(InteractiveViewer), findsOneWidget);

      // Verify SvgPicture exists
      expect(find.byType(SvgPicture), findsOneWidget);
    });
  });
}
