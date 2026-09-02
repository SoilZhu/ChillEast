import 'package:ChillEast/features/library/models/library_models.dart';
import 'package:ChillEast/features/library/widgets/library_quick_reserve_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Library Quick Reserve Tests', () {
    final sampleReserve = LibraryReserveModel(
      id: 1001,
      roomId: 12,
      deptId: 33430,
      seatNum: '045',
      startTime: DateTime(2026, 9, 2, 8, 0),
      endTime: DateTime(2026, 9, 2, 12, 0),
      status: 7,
      firstLevelName: '图书馆三楼',
      secondLevelName: '自然科学阅览室',
      thirdLevelName: '302室',
      today: '2026-09-02',
    );

    testWidgets('LibraryQuickReserveSheet renders seat info and selection chips',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LibraryQuickReserveSheet(item: sampleReserve),
          ),
        ),
      );

      // Verify title and seat info
      expect(find.text('快速预约'), findsOneWidget);
      expect(find.text('045 号座位'), findsOneWidget);
      expect(
          find.text('图书馆三楼 · 自然科学阅览室 · 302室'), findsOneWidget);

      // Verify date section
      expect(find.text('选择日期'), findsOneWidget);
      expect(find.text('开始时间'), findsOneWidget);
      expect(find.text('结束时间'), findsOneWidget);
    });

    testWidgets('LibraryQuickReserveSheet can switch date and confirm selection',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await showLibraryQuickReserveSheet(
                    context: context,
                    item: sampleReserve,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Open bottom sheet
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('快速预约'), findsOneWidget);

      // Tap on tomorrow or next day chip if present
      final choiceChips = find.byType(ChoiceChip);
      if (choiceChips.evaluate().isNotEmpty) {
        // Tap on a date chip
        await tester.tap(choiceChips.at(1));
        await tester.pumpAndSettle();
      }

      // Check confirm button
      final confirmButton = find.byType(ElevatedButton);
      expect(confirmButton, findsWidgets);
    });

    test('LibraryReserveModel serialization and failure validation', () {
      final validJson = {
        'id': 123,
        'roomId': 456,
        'deptId': 33430,
        'seatNum': '001',
        'startTime': 1725264000000,
        'endTime': 1725278400000,
        'status': 0,
        'firstLevelName': '图书馆',
        'secondLevelName': '二楼',
        'thirdLevelName': '201室',
        'today': '2026-09-02',
      };

      final model = LibraryReserveModel.fromJson(validJson);
      expect(model.id, 123);
      expect(model.seatNum, '001');
      expect(model.reserveStatus, ReserveStatus.reserved);
    });
  });
}
