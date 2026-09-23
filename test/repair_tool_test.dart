import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/core/mcp/tools/repair_tool.dart';
import 'package:ChillEast/core/state/auth_state.dart';
import 'package:ChillEast/features/repairs/models/repair_models.dart';
import 'package:ChillEast/features/repairs/services/repair_service.dart';

class FakeRepairService extends RepairService {
  final List<RepairOrder> ongoingOrders;
  final List<RepairOrder> finishedOrders;
  final List<RepairOrder> draftOrders;
  final RepairOrder? detailOrder;
  final RepairFormSession? customSession;

  bool submitCalled = false;
  Map<String, dynamic>? lastSubmittedValues;
  List<File> uploadedFiles = [];

  FakeRepairService({
    this.ongoingOrders = const [],
    this.finishedOrders = const [],
    this.draftOrders = const [],
    this.detailOrder,
    this.customSession,
    AuthState auth = const AuthState.authenticated(
      uid: '123',
      username: '202440800233',
      realName: '朱天兆',
    ),
  }) : super(auth);

  @override
  Future<List<RepairOrder>> fetchOrders({
    required bool ongoing,
    bool isDraft = false,
    int pageIndex = 1,
    int pageSize = 10,
  }) async {
    if (isDraft) return draftOrders;
    if (ongoing) return ongoingOrders;
    return finishedOrders;
  }

  @override
  Future<RepairOrder> fetchOrderDetailById(String orderId) async {
    return detailOrder ??
        RepairOrder(
          id: orderId,
          code: 'WX$orderId',
          title: '宿舍水管漏水',
          description: '卫生间水龙头坏了',
          catalog: '后勤报修',
          status: '处理中',
          statusId: '1',
          createdAt: DateTime(2026, 9, 23),
          closedAt: null,
          department: '后勤保障中心',
          applicant: '朱天兆',
          phone: '13800138000',
        );
  }

  @override
  Future<RepairFormSession> loadForm(RepairCatalog catalog) async {
    return customSession ??
        RepairFormSession(
          catalog: catalog,
          instanceId: 'inst-123',
          ciType: 'ci-123',
          nodeId: 'node-start',
          submitActionId: 'act-submit',
          formRuleId: null,
          fields: const [
            RepairField(
              name: 'scwttp',
              label: '上传问题图片',
              editor: 'upload',
              required: false,
              hidden: false,
              readonly: false,
            ),
            RepairField(
              name: 'wtmsh',
              label: '问题描述',
              editor: 'textarea',
              required: false,
              hidden: false,
              readonly: false,
            ),
            RepairField(
              name: 'xxwzhfjy',
              label: '详细位置',
              editor: 'input',
              required: false,
              hidden: false,
              readonly: false,
            ),
            RepairField(
              name: 'yyrq',
              label: '预约日期',
              editor: 'datepicker',
              required: false,
              hidden: false,
              readonly: false,
            ),
            RepairField(
              name: 'sjhm',
              label: '手机号码',
              editor: 'input',
              required: false,
              hidden: false,
              readonly: false,
            ),
            RepairField(
              name: 'xm',
              label: '姓名',
              editor: 'input',
              required: false,
              hidden: false,
              readonly: false,
            ),
          ],
          initialValues: const {
            'id': 'inst-123',
            'xm': '朱天兆',
            'sjhm': '13800138000',
          },
        );
  }

  @override
  Future<RepairAttachment> uploadAttachment(
    RepairFormSession session,
    RepairField field,
    File file,
  ) async {
    uploadedFiles.add(file);
    return RepairAttachment(
      id: 'att-${uploadedFiles.length}',
      fileName: file.path.split(Platform.pathSeparator).last,
      downloadUrl: 'https://bxpt.hunau.edu.cn/relax/file/att-${uploadedFiles.length}',
      createTime: DateTime.now(),
    );
  }

  @override
  Future<String> submit(
    RepairFormSession session,
    Map<String, dynamic> values, {
    bool isDraft = false,
  }) async {
    submitCalled = true;
    lastSubmittedValues = values;
    return 'ok';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Repair MCP Tools Tests', () {
    late Directory tempDir;
    late File testImgFile;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('repair_test_');
      testImgFile = File('${tempDir.path}/test_leak.jpg');
      testImgFile.writeAsStringSync('fake-image-bytes');
      RepairSubmitTool.lastChatImagePath = null;
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
      RepairSubmitTool.lastChatImagePath = null;
    });

    test('query_repairs queries ongoing, completed, and draft orders', () async {
      final ongoing = [
        RepairOrder(
          id: '1',
          code: 'WX001',
          title: '水龙头漏水',
          description: '洗手台',
          catalog: '后勤报修',
          status: '处理中',
          statusId: '1',
          createdAt: DateTime(2026, 9, 23),
          closedAt: null,
          department: '后勤保障中心',
        ),
      ];
      final finished = [
        RepairOrder(
          id: '2',
          code: 'WX002',
          title: '网络故障已修好',
          description: 'WiFi',
          catalog: '校园网络报修',
          status: '已完成',
          statusId: '2',
          createdAt: DateTime(2026, 9, 20),
          closedAt: DateTime(2026, 9, 21),
          department: '信息与网络中心',
        ),
      ];
      final drafts = [
        RepairOrder(
          id: '3',
          code: 'WX003',
          title: '门锁损坏草稿',
          description: '门锁',
          catalog: '后勤报修',
          status: '草稿',
          statusId: '0',
          createdAt: DateTime(2026, 9, 23),
          closedAt: null,
          department: '后勤保障中心',
        ),
      ];

      final service = FakeRepairService(
        ongoingOrders: ongoing,
        finishedOrders: finished,
        draftOrders: drafts,
      );

      final tool = RepairOrdersQueryTool.create(service: service);

      // 默认查询处理中
      final ongoingRes = await tool.execute({'status': '处理中'});
      final ongoingJson = jsonDecode(ongoingRes.content.first.text!);
      expect(ongoingJson['success'], isTrue);
      expect(ongoingJson['count'], 1);
      expect(ongoingJson['orders'][0]['code'], 'WX001');

      // 查询已完成
      final finishedRes = await tool.execute({'status': '已完成'});
      final finishedJson = jsonDecode(finishedRes.content.first.text!);
      expect(finishedJson['count'], 1);
      expect(finishedJson['orders'][0]['code'], 'WX002');

      // 查询草稿箱
      final draftRes = await tool.execute({'status': '草稿箱'});
      final draftJson = jsonDecode(draftRes.content.first.text!);
      expect(draftJson['count'], 1);
      expect(draftJson['orders'][0]['code'], 'WX003');

      // 查询全部
      final allRes = await tool.execute({'status': '全部'});
      final allJson = jsonDecode(allRes.content.first.text!);
      expect(allJson['count'], 3);
    });

    test('query_repair_detail returns detailed order info and logs', () async {
      final service = FakeRepairService();
      final tool = RepairDetailTool.create(service: service);

      final res = await tool.execute({'id': '123'});
      final json = jsonDecode(res.content.first.text!);
      expect(json['success'], isTrue);
      expect(json['order']['id'], '123');
      expect(json['order']['title'], '宿舍水管漏水');
      expect(json['applicant'], '朱天兆');
    });

    test('submit_repair_order for logistics WITHOUT image is rejected with strict message', () async {
      final service = FakeRepairService();
      final tool = RepairSubmitTool.create(service: service);

      // 未提供图片，且没有 lastChatImagePath
      final res = await tool.execute({
        'catalog': '后勤报修',
        'location': '12栋502',
        'description': '水龙头坏了不停流水',
        'confirmed': false,
      });

      expect(res.isError, isTrue);
      expect(res.content.first.text, contains('后勤报修严格要求提供现场图片'));
      expect(service.submitCalled, isFalse);
    });

    test('submit_repair_order for logistics with non-existent file path is rejected', () async {
      final service = FakeRepairService();
      final tool = RepairSubmitTool.create(service: service);

      final res = await tool.execute({
        'catalog': '后勤报修',
        'location': '12栋502',
        'description': '水龙头坏了',
        'image_path': '/path/to/non_existent_img.jpg',
        'confirmed': false,
      });

      expect(res.isError, isTrue);
      expect(res.content.first.text, contains('后勤报修严格要求提供现场图片'));
    });

    test('submit_repair_order for logistics with image returns preview when confirmed=false', () async {
      final service = FakeRepairService();
      final tool = RepairSubmitTool.create(service: service);

      final res = await tool.execute({
        'catalog': '后勤报修',
        'location': '12栋502',
        'description': '水龙头漏水严重',
        'image_path': testImgFile.path,
        'confirmed': false,
      });

      expect(res.isError, isFalse);
      final json = jsonDecode(res.content.first.text!);
      expect(json['success'], isTrue);
      expect(json['needConfirmation'], isTrue);
      expect(json['preview']['catalog'], '后勤报修');
      expect(json['preview']['hasImage'], isTrue);
      expect(json['preview']['imageCount'], 1);
      expect(json['preview']['imageFiles'], contains(testImgFile.path));
      expect(service.submitCalled, isFalse);
      expect(service.uploadedFiles, isEmpty);
    });

    test('submit_repair_order for logistics with image uploads image and submits when confirmed=true', () async {
      final service = FakeRepairService();
      final tool = RepairSubmitTool.create(service: service);

      final res = await tool.execute({
        'catalog': '后勤报修',
        'location': '12栋502',
        'description': '水龙头漏水严重',
        'image_path': testImgFile.path,
        'confirmed': true,
      });

      expect(res.isError, isFalse);
      final json = jsonDecode(res.content.first.text!);
      expect(json['success'], isTrue);
      expect(json['uploadedImages'], 1);
      expect(service.uploadedFiles.length, 1);
      expect(service.uploadedFiles.first.path, testImgFile.path);
      expect(service.submitCalled, isTrue);
      expect(service.lastSubmittedValues?['scwttp'], 1);
      expect(service.lastSubmittedValues?['wtmsh'], '水龙头漏水严重');
    });

    test('submit_repair_order automatically picks up lastChatImagePath if image_path omitted', () async {
      RepairSubmitTool.lastChatImagePath = testImgFile.path;

      final service = FakeRepairService();
      final tool = RepairSubmitTool.create(service: service);

      final res = await tool.execute({
        'catalog': '后勤报修',
        'location': '12栋502',
        'description': '水龙头漏水',
        'confirmed': true,
      });

      expect(res.isError, isFalse);
      final json = jsonDecode(res.content.first.text!);
      expect(json['success'], isTrue);
      expect(service.uploadedFiles.length, 1);
      expect(service.uploadedFiles.first.path, testImgFile.path);
      // 成功提交后自动清空 lastChatImagePath
      expect(RepairSubmitTool.lastChatImagePath, isNull);
    });

    test('submit_repair_order for non-logistics (e.g. 校园网络报修) does not mandate image', () async {
      final service = FakeRepairService();
      final tool = RepairSubmitTool.create(service: service);

      final res = await tool.execute({
        'catalog': '校园网络报修',
        'location': '第十教学楼102',
        'description': '教室内无线网无法连接',
        'confirmed': true,
      });

      expect(res.isError, isFalse);
      final json = jsonDecode(res.content.first.text!);
      expect(json['success'], isTrue);
      expect(json['catalog'], '校园网络报修');
      expect(service.submitCalled, isTrue);
    });
  });
}
