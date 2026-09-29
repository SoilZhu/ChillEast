import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/core/mcp/tools/library_tool.dart';
import 'package:ChillEast/core/mcp/tools/sunshine_tool.dart';
import 'package:ChillEast/features/library/models/library_models.dart';
import 'package:ChillEast/features/library/models/library_book_models.dart';
import 'package:ChillEast/features/library/services/library_service.dart';
import 'package:ChillEast/features/library/services/library_book_service.dart';
import 'package:ChillEast/features/library/utils/library_time_utils.dart';
import 'package:ChillEast/features/sunshine/models/sunshine_models.dart';
import 'package:ChillEast/features/sunshine/services/sunshine_service.dart';

class FakeLibraryBookService extends LibraryBookService {
  @override
  Future<LibraryBookSearchResult> searchBooks({
    required String keyword,
    String searchType = 'title',
    dynamic cancelToken,
    void Function(int current, int total)? onProgress,
  }) async {
    return const LibraryBookSearchResult(
      books: [
        LibraryBook(
          detailParam: '{"marc_no":"zyk0161024"}',
          title: '美语阅读一日一篇',
          author: '何庆权编著',
          callNumber: 'H319.4/839',
          publisher: '北京 中国国际广播音像出版社',
          isbn: '7-88004-367-5',
        ),
      ],
      totalCount: 1,
      totalPages: 1,
    );
  }

  @override
  Future<LibraryBookDetail> fetchBookDetail(LibraryBook book) async {
    return const LibraryBookDetail(
      title: '美语阅读一日一篇',
      author: '何庆权编著',
      callNumber: 'H319.4/839',
      subject: '英语阅读-教材',
      isbn: '7-88004-367-5',
      price: '18.00元',
      publishInfo: '北京 中国国际广播音像出版社 [不详]',
      holdings: [
        LibraryBookHolding(
          barcode: '00173443',
          copyType: '文科图书',
          status: '在库',
          holdingUnit: '湖南农业大学文渊馆',
          location: '文科图书二阅览室',
        ),
      ],
    );
  }
}

class FakeLibraryService extends LibraryService {
  final LibraryIndexData indexData;
  bool submitCalled = false;

  FakeLibraryService({required this.indexData});

  @override
  Future<LibraryIndexData> fetchIndexData() async => indexData;

  @override
  Future<LibraryReserveModel> submitReservation({
    required int roomId,
    required String seatNum,
    required String day,
    required String startTime,
    required String endTime,
  }) async {
    submitCalled = true;
    return LibraryReserveModel(
      id: 8888,
      roomId: roomId,
      deptId: 33430,
      seatNum: seatNum,
      startTime: DateTime.now(),
      endTime: DateTime.now().add(const Duration(hours: 2)),
      status: 0,
      firstLevelName: '图书馆',
      secondLevelName: '二楼',
      thirdLevelName: '社科阅览室',
      today: day,
    );
  }
}

class FakeSunshineService extends SunshineService {
  final SunshineFormData formData;
  bool submitCalled = false;

  FakeSunshineService({required this.formData});

  @override
  Future<SunshineFormData> fetchForm() async => formData;

  @override
  Future<String> submit({
    required SunshineIdentity identity,
    required SunshineDepartment department,
    required String type,
    required String title,
    required String content,
    required String phone,
    required String email,
    required String finishTime,
  }) async {
    submitCalled = true;
    return '1';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Library MCP Tools Tests', () {
    final mockLastReserve = LibraryReserveModel(
      id: 101,
      roomId: 301,
      deptId: 33430,
      seatNum: '042',
      startTime: DateTime.now().subtract(const Duration(days: 1)),
      endTime: DateTime.now().subtract(const Duration(days: 1, hours: -2)),
      status: 7,
      firstLevelName: '图书馆',
      secondLevelName: '二楼',
      thirdLevelName: '社科阅览室',
      today: '2026-09-16',
    );

    final mockIndexData = LibraryIndexData(
      curReserves: [],
      nearReserves: [mockLastReserve],
    );

    test('query_library_last_seat finds the last reserved seat', () async {
      final fakeService = FakeLibraryService(indexData: mockIndexData);
      final tool = LibraryLastSeatQueryTool.create(service: fakeService);

      final result = await tool.execute({});
      expect(result.isError, isFalse);

      final json = jsonDecode(result.content.first.text!);
      expect(json['found'], isTrue);
      expect(json['seatNum'], equals('042'));
      expect(json['roomId'], equals(301));
      expect(json['roomName'], contains('社科阅览室'));
    });

    test('reserve_library_seat defaults to last seat and requires confirmation when confirmed=false', () async {
      final fakeService = FakeLibraryService(indexData: mockIndexData);
      final tool = LibraryReserveTool.create(service: fakeService);

      // 首次未指定座位且未明确确认
      final result = await tool.execute({
        'confirmed': false,
      });

      expect(result.isError, isFalse);
      final json = jsonDecode(result.content.first.text!);
      expect(json['status'], equals('requires_confirmation'));
      expect(json['needsUserConsent'], isTrue);
      expect(json['pendingReservation']['seatNum'], equals('042'));
      expect(json['pendingReservation']['roomId'], equals(301));
      expect(json['pendingReservation']['isDefaultedFromLastSeat'], isTrue);
      expect(fakeService.submitCalled, isFalse); // 不得真正调用提交
    });

    test('reserve_library_seat successfully submits when confirmed=true', () async {
      final fakeService = FakeLibraryService(indexData: mockIndexData);
      final tool = LibraryReserveTool.create(service: fakeService);

      final reserveDay = LibraryTimeUtils.availableReserveDays().last;
      final result = await tool.execute({
        'roomId': 301,
        'seatNum': '042',
        'day': reserveDay,
        'startTime': '08:00',
        'endTime': '10:00',
        'confirmed': true,
      });

      expect(result.isError, isFalse);
      final json = jsonDecode(result.content.first.text!);
      expect(json['status'], equals('success'));
      expect(json['reservation']['seatNum'], equals('042'));
      expect(fakeService.submitCalled, isTrue); // 真正调用了提交
    });

    test('search_library_books searches catalog and returns books', () async {
      final fakeBookService = FakeLibraryBookService();
      final tool = LibraryBookSearchTool.create(service: fakeBookService);

      final result = await tool.execute({
        'keyword': '美语阅读',
        'searchType': 'title',
      });

      expect(result.isError, isFalse);
      final json = jsonDecode(result.content.first.text!);
      expect(json['totalCount'], equals(1));
      expect(json['books'].length, equals(1));
      expect(json['books'][0]['title'], equals('美语阅读一日一篇'));
      expect(json['books'][0]['detailParam'], contains('zyk0161024'));
    });

    test('query_library_book_detail fetches book detail with holdings', () async {
      final fakeBookService = FakeLibraryBookService();
      final tool = LibraryBookDetailTool.create(service: fakeBookService);

      final result = await tool.execute({
        'detailParam': '{"marc_no":"zyk0161024"}',
        'title': '美语阅读一日一篇',
      });

      expect(result.isError, isFalse);
      final json = jsonDecode(result.content.first.text!);
      expect(json['title'], equals('美语阅读一日一篇'));
      expect(json['callNumber'], equals('H319.4/839'));
      expect(json['holdings'].length, equals(1));
      expect(json['holdings'][0]['status'], equals('在库'));
      expect(json['availableHoldings'], equals(1));
    });

    test('query_library_book_detail auto-searches by title when detailParam is omitted', () async {
      final fakeBookService = FakeLibraryBookService();
      final tool = LibraryBookDetailTool.create(service: fakeBookService);

      final result = await tool.execute({
        'title': '美语阅读一日一篇',
      });

      expect(result.isError, isFalse);
      final json = jsonDecode(result.content.first.text!);
      expect(json['title'], equals('美语阅读一日一篇'));
      expect(json['holdings'].length, equals(1));
    });
  });

  group('Sunshine MCP Tools Tests', () {
    const mockFormData = SunshineFormData(
      SunshineIdentity('20240001', '张三', '13800138000', 'zhangsan@hunau.edu.cn'),
      [
        SunshineDepartment('1001', '后勤保卫部'),
        SunshineDepartment('1002', '教务处'),
        SunshineDepartment('1003', '学生工作部'),
      ],
    );

    test('query_sunshine_departments lists available departments', () async {
      final fakeService = FakeSunshineService(formData: mockFormData);
      final tool = SunshineDepartmentsQueryTool.create(service: fakeService);

      final result = await tool.execute({});
      expect(result.isError, isFalse);

      final json = jsonDecode(result.content.first.text!);
      expect(json['success'], isTrue);
      expect(json['departmentCount'], equals(3));
      expect(json['departments'][0]['name'], equals('后勤保卫部'));
    });

    test('submit_sunshine_letter matches dept and requires confirmation before submission', () async {
      final fakeService = FakeSunshineService(formData: mockFormData);
      final tool = SunshineSubmitTool.create(service: fakeService);

      // 模糊匹配“后勤”，首次未确认
      final result = await tool.execute({
        'department': '后勤',
        'title': '宿舍热水水温较低',
        'content': '最近几天晚上洗澡水温偏低，希望能排查一下热水供应。',
        'type': '建议',
        'confirmed': false,
      });

      expect(result.isError, isFalse);
      final json = jsonDecode(result.content.first.text!);
      expect(json['status'], equals('requires_confirmation'));
      expect(json['needsUserConsent'], isTrue);
      expect(json['formPreview']['departmentName'], equals('后勤保卫部'));
      expect(json['formPreview']['typeName'], equals('建议'));
      expect(json['formPreview']['submitterName'], equals('张三'));
      expect(fakeService.submitCalled, isFalse);
    });

    test('submit_sunshine_letter submits successfully when confirmed=true', () async {
      final fakeService = FakeSunshineService(formData: mockFormData);
      final tool = SunshineSubmitTool.create(service: fakeService);

      final result = await tool.execute({
        'department': '后勤保卫部',
        'title': '宿舍热水水温较低',
        'content': '最近几天晚上洗澡水温偏低，希望能排查一下热水供应。',
        'type': '建议',
        'confirmed': true,
      });

      expect(result.isError, isFalse);
      final json = jsonDecode(result.content.first.text!);
      expect(json['status'], equals('success'));
      expect(fakeService.submitCalled, isTrue);
    });
  });
}
