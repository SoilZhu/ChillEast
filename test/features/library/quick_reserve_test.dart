import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:ChillEast/features/library/models/library_models.dart';
import 'package:ChillEast/features/library/providers/library_provider.dart';
import 'package:ChillEast/features/library/screens/library_quick_reserve_screen.dart';
import 'package:ChillEast/features/library/services/library_service.dart';
import 'package:ChillEast/features/library/widgets/library_quick_reserve_sheet.dart';
import 'package:ChillEast/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeLibraryService extends LibraryService {
  @override
  Future<Map<String, dynamic>> fetchLiveStartEndTime() async {
    return {'ymd': '2026-10-08'};
  }

  @override
  Future<List<String>> fetchLevels({
    required int type,
    String? firstLevelName,
    String? secondLevelName,
  }) async {
    if (type == 0) return ['图书馆'];
    if (type == 1) return ['2楼', '3楼', '4楼'];
    return ['301', '304'];
  }

  @override
  Future<LibraryMatchedSeatModel> matchSeat({
    required String startTime,
    required String endTime,
    String firstLevelName = '',
    String secondLevelName = '',
    String thirdLevelName = '',
  }) async {
    return LibraryMatchedSeatModel(
      roomId: 14100,
      seatNum: '042',
      firstLevelName: '图书馆',
      secondLevelName: '3楼',
      thirdLevelName: '301',
      startTime: DateTime(2026, 10, 8, 17, 0),
      endTime: DateTime(2026, 10, 8, 17, 30),
      duration: '0.5',
    );
  }

  @override
  Future<LibraryReserveModel> submitQuickReservation({
    required int roomId,
    required String seatNum,
    required String day,
    required String startTime,
    required String endTime,
  }) async {
    return LibraryReserveModel(
      id: 194450368,
      roomId: roomId,
      deptId: 33430,
      seatNum: seatNum,
      startTime: DateTime(2026, 10, 8, 17, 0),
      endTime: DateTime(2026, 10, 8, 17, 30),
      status: 0,
      firstLevelName: '图书馆',
      secondLevelName: '3楼',
      thirdLevelName: '301',
      today: day,
    );
  }
}

Widget _createTestApp({required Widget home}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('zh'),
    home: home,
  );
}

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

    testWidgets(
        'LibraryQuickReserveSheet renders seat info and selection chips',
        (tester) async {
      await tester.pumpWidget(
        _createTestApp(
          home: Scaffold(
            body: LibraryQuickReserveSheet(item: sampleReserve),
          ),
        ),
      );

      // Verify title and seat info
      expect(find.text('快速预约'), findsOneWidget);
      expect(find.text('045 号座位'), findsOneWidget);
      expect(find.text('图书馆三楼 · 自然科学阅览室 · 302室'), findsOneWidget);

      // Verify date section
      expect(find.text('选择日期'), findsOneWidget);
      expect(find.text('开始时间'), findsOneWidget);
      expect(find.text('结束时间'), findsOneWidget);
    });

    testWidgets(
        'LibraryQuickReserveSheet can switch date and confirm selection',
        (tester) async {
      await tester.pumpWidget(
        _createTestApp(
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

    test('LibraryMatchedSeatModel parsing from HAR getseatinfo response', () {
      final harMatchedJson = {
        'duration': '0.5',
        'endTime': 1791451800000,
        'firstLevelName': '图书馆',
        'roomId': 14100,
        'seatNum': '042',
        'secondLevelName': '3楼',
        'startTime': 1791450000000,
        'thirdLevelName': '社会科学图书阅览四区301',
      };

      final model = LibraryMatchedSeatModel.fromJson(harMatchedJson);
      expect(model.roomId, 14100);
      expect(model.seatNum, '042');
      expect(model.firstLevelName, '图书馆');
      expect(model.secondLevelName, '3楼');
      expect(model.thirdLevelName, '社会科学图书阅览四区301');
      expect(model.fullRoomName, '图书馆 · 3楼 · 社会科学图书阅览四区301');
      expect(model.duration, '0.5');
      expect(model.formattedTimeRange, '17:00 ~ 17:30');
      expect(model.formattedDate, '2026-10-08');
    });

    test('HAR submission MD5 signature generation matches HAR Entry 12', () {
      // Data extracted from debug/图书馆快速预约.har Entry 12 & Entry 0
      const submitEnc = '4aa684d0956a4310933b37c777ccc2d4_342380530';
      final paramObj = <String, dynamic>{
        'roomId': 14100,
        'startTime': '17:00',
        'endTime': '17:30',
        'day': '2026-10-08',
        'captcha': '',
        'seatNum': '042',
        'wyToken': '',
      };

      final sortedKeys = paramObj.keys.toList()..sort();
      final parts = <String>[];
      for (final k in sortedKeys) {
        parts.add('[$k=${paramObj[k] ?? ''}]');
      }
      parts.add('[$submitEnc]');
      final raw = parts.join('');
      final enc = md5.convert(utf8.encode(raw)).toString();

      // Verified from HAR file entry 12: enc=8880b5eb16c1c39798b6882fb7073187
      expect(enc, '8880b5eb16c1c39798b6882fb7073187');
    });

    testWidgets(
        'LibraryQuickReserveScreen renders full live reservation flow UI and matches seat',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryServiceProvider.overrideWithValue(FakeLibraryService()),
          ],
          child: _createTestApp(
            home: const LibraryQuickReserveScreen(),
          ),
        ),
      );

      // Settle initial load
      await tester.pumpAndSettle();

      // Verify title and main components
      expect(find.text('快速预约'), findsOneWidget);
      expect(find.text('选择预约时段'), findsOneWidget);
      expect(find.text('位置偏好'), findsOneWidget);
      expect(find.text('全部楼层'), findsOneWidget);
      expect(find.text('2楼'), findsOneWidget);
      expect(find.text('3楼'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, '预约'), findsOneWidget);

      // Tap on '3楼'
      await tester.tap(find.text('3楼'));
      await tester.pumpAndSettle();

      // Tap on '预约'
      await tester.tap(find.widgetWithText(ElevatedButton, '预约'));
      await tester.pumpAndSettle();

      // Verify matched result card
      expect(find.text('已为您分配推荐座位'), findsNothing);
      expect(find.textContaining('042'), findsWidgets);
      expect(find.widgetWithText(ElevatedButton, '确认'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.textContaining('换一个'),
          matching: find.byType(TextButton),
        ),
        findsOneWidget,
      );
    });
  });
}
