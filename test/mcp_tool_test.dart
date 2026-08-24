import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/core/mcp/mcp.dart';
import 'package:ChillEast/features/homework/models/homework_model.dart';
import 'package:ChillEast/features/homework/services/homework_storage.dart';
import 'package:ChillEast/features/timetable/models/course_model.dart';
import 'package:ChillEast/features/timetable/services/timetable_storage.dart';
import 'package:ChillEast/features/workspace/models/classroom_model.dart';
import 'package:ChillEast/features/workspace/models/electricity_model.dart';
import 'package:ChillEast/features/workspace/services/classroom_service.dart';
import 'package:ChillEast/features/workspace/services/campus_card_service.dart';
import 'package:ChillEast/features/workspace/services/electricity_service.dart';
import 'package:ChillEast/features/score/models/score_model.dart';
import 'package:ChillEast/features/score/services/score_service.dart';
import 'package:ChillEast/features/notice/models/message_model.dart';
import 'package:ChillEast/features/notice/services/notice_service.dart';

// --- Mocks ---

class FakeTimetableStorage extends TimetableStorage {
  List<CourseModel> courses = [
    const CourseModel(
      id: '1',
      name: '高等数学',
      teacher: '张老师',
      classroom: '十教南101',
      weeks: '1-16(周)',
      periods: '01-02',
      dayOfWeek: 1,
      startPeriod: 1,
      endPeriod: 2,
    ),
    const CourseModel(
      id: '2',
      name: '大学物理',
      teacher: '李老师',
      classroom: '十教北202',
      weeks: '1-8(周)',
      periods: '03-04',
      dayOfWeek: 2,
      startPeriod: 3,
      endPeriod: 4,
    ),
  ];

  @override
  Future<List<CourseModel>> readCourseList() async => courses;

  @override
  Future<Map<String, dynamic>?> readMetadata() async => {
        'semester': '2025-2026-1',
        'firstWeekMonday': '2025-09-01T00:00:00.000',
      };
}

class FakeHomeworkStorage extends HomeworkStorage {
  List<HomeworkModel> homeworks = [
    HomeworkModel(
      id: 'hw1',
      courseName: '高等数学',
      title: '第一章课后习题',
      status: HomeworkStatus.pending,
      studentId: '20240001',
      endTime: DateTime.parse('2026-09-10 23:59:00'),
    ),
    HomeworkModel(
      id: 'hw2',
      courseName: '大学物理',
      title: '力学实验报告',
      status: HomeworkStatus.completed,
      studentId: '20240001',
      endTime: DateTime.parse('2026-09-05 23:59:00'),
    ),
    HomeworkModel(
      id: 'manual_1',
      courseName: '英语四级',
      title: '背诵Unit 1单词',
      status: HomeworkStatus.pending,
      studentId: 'manual',
      isManual: true,
      endTime: DateTime.parse('2026-09-15 23:59:00'),
    ),
  ];

  @override
  Future<List<HomeworkModel>> readHomeworkList() async => homeworks;

  @override
  Future<void> saveHomeworkList(List<HomeworkModel> list) async {
    homeworks = list;
  }
}

class FakeClassroomService extends ClassroomService {
  @override
  Future<ClassroomInquiryOptions> fetchOptions() async {
    return ClassroomInquiryOptions(
      buildings: ['第十教学楼', '第九教学楼'],
      sections: ['0102', '0304'],
      weeks: ['1', '2'],
      days: [
        {'label': '星期一', 'value': '1'},
        {'label': '星期二', 'value': '2'},
      ],
    );
  }

  @override
  Future<List<ClassroomModel>> queryClassrooms({
    required String building,
    required String week,
    required String jc,
    required String day,
  }) async {
    return [
      ClassroomModel(jsmc: '$building 南101', zws: '120'),
      ClassroomModel(jsmc: '$building 北202', zws: '80'),
    ];
  }
}

class FakeScoreService extends ScoreService {
  @override
  Future<List<SemesterModel>> fetchSemesterList({bool isRetry = false}) async => [
        SemesterModel(id: '2024-2025-2', name: '2024-2025第2学期', isActive: true),
        SemesterModel(id: '2024-2025-1', name: '2024-2025第1学期', isActive: false),
      ];

  @override
  Future<List<ScoreModel>> fetchScores({required String semester, bool isRetry = false}) async => [
        ScoreModel(courseName: '数据结构与算法', score: '95', credit: '3.5', dailyScore: '98', examType: '正常考试'),
        ScoreModel(courseName: '操作系统原理', score: '88', credit: '4.0', dailyScore: '85', examType: '正常考试'),
      ];
}

class FakeCampusCardService extends CampusCardService {
  @override
  CampusCardInfo? get cachedInfo => CampusCardInfo(
        name: '张三',
        idserial: '202440800001',
        balance: '66.50',
      );

  @override
  Future<CampusCardInfo> fetchRechargeInfo({bool isRetry = false}) async {
    return CampusCardInfo(
      name: '张三',
      idserial: '202440800001',
      balance: '66.50',
    );
  }
}

class FakeElectricityService implements ElectricityService {
  SavedElectricityRoom? _savedRoom;

  @override
  Future<SavedElectricityRoom?> getSavedRoom() async => _savedRoom;

  @override
  Future<void> saveSavedRoom(SavedElectricityRoom room) async {
    _savedRoom = room;
  }

  @override
  Future<void> clearSavedRoom() async {
    _savedRoom = null;
  }

  @override
  Future<List<ElectricityArea>> getAreas() async => [
        ElectricityArea(id: '东湖校区', name: '东湖校区'),
      ];

  @override
  Future<List<ElectricityBuilding>> getBuildings(String areaName) async => [
        ElectricityBuilding(id: '东湖公寓1栋', name: '东湖公寓1栋'),
      ];

  @override
  Future<List<ElectricityRoom>> getRooms(String areaName, String buildingName) async => [
        ElectricityRoom(id: '101', name: '101', mertype: 'yk'),
      ];

  @override
  Future<ElectricityBalanceInfo> getBalance({
    required String areaName,
    required String buildingName,
    required String roomId,
    required String mertype,
  }) async =>
      ElectricityBalanceInfo(balance: '35.80', detail: '可用电量 62.8 度');

  @override
  Future<bool> recharge({
    required String areaName,
    required String buildingName,
    required String roomId,
    required String mertype,
    required double amount,
  }) async {
    _savedRoom = SavedElectricityRoom(
      areaName: areaName,
      buildingName: buildingName,
      roomId: roomId,
      roomName: roomId,
      mertype: mertype,
    );
    return true;
  }
}

class FakeNoticeService extends NoticeService {
  @override
  Future<NoticeResult> fetchMessageList({String? lastValue}) async {
    return NoticeResult(
      messages: [
        const MessageModel(
          idCode: '1001',
          title: '关于2026年秋季学期开学的通知',
          content: '请各位同学按时返校报到...',
          createrName: '教务处',
          sendTime: '2026-08-20 09:00',
          isRead: false,
          hasRedDot: true,
          countAll: 100,
          countRead: 50,
          uuid: 'notice_uuid_1001',
        ),
        const MessageModel(
          idCode: '1002',
          title: '奖学金评定结果公示',
          content: '现将本年度奖学金评定结果公示如下...',
          createrName: '学生工作部',
          sendTime: '2026-08-19 15:30',
          isRead: true,
          hasRedDot: false,
          countAll: 200,
          countRead: 180,
          uuid: 'notice_uuid_1002',
        ),
      ],
      hasMore: false,
    );
  }

  @override
  Future<Map<String, dynamic>> fetchNoticeDetail(String uuid) async {
    return {
      'uuid': uuid,
      'title': '关于2026年秋季学期开学的通知',
      'content': '请各位同学于9月1日之前到校报到注册...',
      'createrName': '教务处',
      'sendTime': '2026-08-20 09:00',
    };
  }
}

void main() {
  group('Standard MCP Tools Tests', () {
    late McpToolRegistry registry;
    late FakeHomeworkStorage fakeHomeworkStorage;

    setUp(() {
      fakeHomeworkStorage = FakeHomeworkStorage();
      registry = McpToolRegistry([
        TimetableTool.create(storage: FakeTimetableStorage()),
        HomeworkQueryTool.create(storage: fakeHomeworkStorage),
        HomeworkAddTool.create(storage: fakeHomeworkStorage),
        HomeworkCompleteTool.create(storage: fakeHomeworkStorage),
        ClassroomTool.create(service: FakeClassroomService()),
        ScoreTool.create(service: FakeScoreService()),
        CampusCardTool.create(service: FakeCampusCardService()),
        ElectricityTool.create(service: FakeElectricityService()),
        NoticeTool.create(service: FakeNoticeService()),
      ]);
    });

    test('All 9 tools are registered and conform to MCP tool schema', () {
      final tools = registry.listTools();
      expect(tools.length, 9);

      final toolNames = tools.map((t) => t['name']).toSet();
      expect(toolNames, containsAll([
        'query_timetable',
        'query_homework',
        'add_homework',
        'complete_homework',
        'query_empty_classrooms',
        'query_scores',
        'query_campus_card_balance',
        'recharge_electricity',
        'query_notices',
      ]));

      for (final tool in tools) {
        expect(tool['name'], isNotEmpty);
        expect(tool['description'], isNotEmpty);
        expect(tool['inputSchema'], isA<Map<String, dynamic>>());
        final schema = tool['inputSchema'] as Map<String, dynamic>;
        expect(schema['type'], 'object');
        expect(schema['properties'], isA<Map<String, dynamic>>());
      }
    });

    test('1. Timetable Tool (query_timetable) execution', () async {
      final res = await registry.callTool('query_timetable', {'week': 1, 'dayOfWeek': 1});
      expect(res.isError, isFalse);
      expect(res.content.first.text, contains('高等数学'));
      expect(res.content.first.text, contains('十教南101'));
    });

    test('2. Homework Query Tool (query_homework) execution', () async {
      final res = await registry.callTool('query_homework', {'status': 'pending'});
      expect(res.isError, isFalse);
      expect(res.content.first.text, contains('第一章课后习题'));
    });

    test('3. Homework Add Tool (add_homework) execution', () async {
      final res = await registry.callTool('add_homework', {
        'title': '编译原理大作业',
        'courseName': '编译原理',
        'endTime': '2026-09-30 23:59:00',
        'remarks': '完成词法与语法分析器',
      });
      expect(res.isError, isFalse);
      expect(res.content.first.text, contains('编译原理大作业'));
      expect(res.content.first.text, contains('作业添加成功'));
    });

    test('4. Homework Complete Tool (complete_homework) execution', () async {
      // 1) 成功标记手动添加的作业为完成（通过 ID）
      final resById = await registry.callTool('complete_homework', {'id': 'manual_1'});
      expect(resById.isError, isFalse);
      expect(resById.content.first.text, contains('背诵Unit 1单词'));
      expect(resById.content.first.text, contains('作业已成功标记为完成'));

      // 2) 成功标记手动添加的作业为完成（通过 title）
      await registry.callTool('add_homework', {
        'title': '操作系统实验',
        'courseName': '操作系统',
      });
      final resByTitle = await registry.callTool('complete_homework', {'title': '操作系统实验'});
      expect(resByTitle.isError, isFalse);
      expect(resByTitle.content.first.text, contains('操作系统实验'));
      expect(resByTitle.content.first.text, contains('已完成'));

      // 3) 尝试标记超星同步的非手动作业 -> 失败并提示仅限手动添加的作业
      final resNonManual = await registry.callTool('complete_homework', {'id': 'hw1'});
      expect(resNonManual.isError, isTrue);
      expect(resNonManual.content.first.text, contains('超星/学习通同步作业'));
      expect(resNonManual.content.first.text, contains('仅支持完成自己手动添加的作业'));

      // 4) 参数为空 -> 报错
      final resEmpty = await registry.callTool('complete_homework', {});
      expect(resEmpty.isError, isTrue);
      expect(resEmpty.content.first.text, contains('请提供需要标记完成的作业 id 或 title'));
    });

    test('5. Empty Classroom Tool (query_empty_classrooms) execution', () async {
      // Query options
      final optionsRes = await registry.callTool('query_empty_classrooms', {'action': 'get_options'});
      expect(optionsRes.isError, isFalse);
      expect(optionsRes.content.first.text, contains('第十教学楼'));

      // Query classrooms
      final queryRes = await registry.callTool('query_empty_classrooms', {
        'building': '第十教学楼',
        'week': '1',
        'section': '0102',
        'dayOfWeek': '1',
      });
      expect(queryRes.isError, isFalse);
      expect(queryRes.content.first.text, contains('第十教学楼 南101'));
    });

    test('5. Score Tool (query_scores) execution', () async {
      final res = await registry.callTool('query_scores', {'academicYear': '2024-2025', 'semester': '2'});
      expect(res.isError, isFalse);
      expect(res.content.first.text, contains('数据结构与算法'));
      expect(res.content.first.text, contains('95'));
    });

    test('6. Campus Card Balance Tool (query_campus_card_balance) execution', () async {
      final res = await registry.callTool('query_campus_card_balance', {});
      expect(res.isError, isFalse);
      expect(res.content.first.text, contains('张三'));
      expect(res.content.first.text, contains('66.50'));
    });

    test('7. Electricity Tool (recharge_electricity) query & recharge execution', () async {
      // Query balance
      final balanceRes = await registry.callTool('recharge_electricity', {
        'action': 'query_balance',
        'areaName': '东湖校区',
        'buildingName': '东湖公寓1栋',
        'roomId': '101',
      });
      expect(balanceRes.isError, isFalse);
      expect(balanceRes.content.first.text, contains('35.80'));

      // Recharge
      final rechargeRes = await registry.callTool('recharge_electricity', {
        'action': 'recharge',
        'areaName': '东湖校区',
        'buildingName': '东湖公寓1栋',
        'roomId': '101',
        'amount': 50,
      });
      expect(rechargeRes.isError, isFalse);
      expect(rechargeRes.content.first.text, contains('电费充值成功'));

      // Query balance without specifying dorm (should use remembered dorm)
      final defaultQueryRes = await registry.callTool('recharge_electricity', {
        'action': 'query_balance',
      });
      expect(defaultQueryRes.isError, isFalse);
      expect(defaultQueryRes.content.first.text, contains('35.80'));
      expect(defaultQueryRes.content.first.text, contains('东湖公寓1栋'));
    });

    test('8. Notice Tool (query_notices) query & detail execution', () async {
      // List
      final listRes = await registry.callTool('query_notices', {'unreadOnly': true});
      expect(listRes.isError, isFalse);
      expect(listRes.content.first.text, contains('关于2026年秋季学期开学的通知'));

      // Detail
      final detailRes = await registry.callTool('query_notices', {
        'action': 'get_detail',
        'noticeUuid': 'notice_uuid_1001',
      });
      expect(detailRes.isError, isFalse);
      expect(detailRes.content.first.text, contains('请各位同学于9月1日之前到校报到注册'));
    });

    test('JSON-RPC 2.0 protocol dispatching', () async {
      // initialize
      final initResp = await registry.handleRequest(
        const McpRequest(id: 1, method: 'initialize'),
      );
      expect(initResp.error, isNull);
      expect(initResp.result['protocolVersion'], '2024-11-05');

      // tools/list
      final listResp = await registry.handleRequest(
        const McpRequest(id: 2, method: 'tools/list'),
      );
      expect(listResp.error, isNull);
      expect((listResp.result['tools'] as List).length, 9);

      // tools/call
      final callResp = await registry.handleRequest(
        const McpRequest(
          id: 3,
          method: 'tools/call',
          params: {
            'name': 'query_campus_card_balance',
            'arguments': {},
          },
        ),
      );
      expect(callResp.error, isNull);
      expect(callResp.result['isError'], isFalse);

      // methodNotFound
      final errResp = await registry.handleRequest(
        const McpRequest(id: 4, method: 'unknown/method'),
      );
      expect(errResp.error, isNotNull);
      expect(errResp.error!.code, McpError.methodNotFound);
    });
  });
}
