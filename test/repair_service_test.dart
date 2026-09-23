import 'dart:io';
import 'package:ChillEast/core/constants/app_constants.dart';
import 'package:ChillEast/core/state/auth_state.dart';
import 'package:ChillEast/features/repairs/models/repair_models.dart';
import 'package:ChillEast/features/repairs/services/repair_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Dio dio;
  late List<RequestOptions> requests;
  late dynamic Function(RequestOptions) respond;
  const testBxptUuid = '076fa927-5cf8-445b-b14f-1eef6c56429d';
  const testStudentId = '202440800233';

  setUp(() {
    requests = [];
    dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(options);
      final result = respond(options);
      if (result is DioException) {
        handler.reject(result);
      } else if (result is Response) {
        handler.resolve(result);
      } else {
        handler.resolve(
          Response(requestOptions: options, statusCode: 200, data: result),
        );
      }
    }));
  });

  const auth = AuthState.authenticated(
    uid: testStudentId,
    username: testStudentId,
    realName: '朱天兆',
  );

  test('CAS redirect chain follows SSO ticket to completion and upgrades HTTP to HTTPS', () async {
    final service = RepairService(auth, dio: dio);

    respond = (options) {
      final url = options.uri.toString();
      if (url == AppConstants.repairsSsoUrl) {
        return Response(
          requestOptions: options,
          statusCode: 302,
          headers: Headers.fromMap({
            HttpHeaders.locationHeader: [
              'http://bxpt.hunau.edu.cn/relax/sso/cas/login?ticket=ST-test-ticket'
            ],
          }),
        );
      }
      if (url == 'https://bxpt.hunau.edu.cn/relax/sso/cas/login?ticket=ST-test-ticket') {
        return Response(
          requestOptions: options,
          statusCode: 302,
          headers: Headers.fromMap({
            HttpHeaders.locationHeader: ['http://bxpt.hunau.edu.cn/relax/index.html'],
          }),
        );
      }
      if (url == 'https://bxpt.hunau.edu.cn/relax/index.html') {
        return Response(
          requestOptions: options,
          statusCode: 200,
          data: '<!DOCTYPE html><html><body>Relax</body></html>',
        );
      }
      if (options.uri.path == '/relax/mobile/rpc') {
        final method = options.data is Map ? options.data['method'] : '';
        if (method == '/v2/login/isAuthenticated') {
          final ticketExchanged = requests.any((r) => r.uri.toString().contains('ticket=ST-test-ticket'));
          if (!ticketExchanged) {
            return {'id': 1, 'jsonrpc': '2.0'};
          }
          return {
            'id': 1,
            'jsonrpc': '2.0',
            'result': {
              'id': testBxptUuid,
              'account': testStudentId,
              'display_name': '朱天兆',
            },
          };
        }
        if (method == '/v2/service/portal/workorderData/ongoingPage') {
          return {
            'id': 1,
            'jsonrpc': '2.0',
            'result': {'data': []},
          };
        }
      }
      return Response(requestOptions: options, statusCode: 404);
    };

    final orders = await service.fetchOrders(ongoing: true);
    expect(orders, isEmpty);
    expect(service.bxptUserId, testBxptUuid);

    // Verify redirect chain URLs and HSTS upgrades
    final urls = requests.map((r) => r.uri.toString()).toList();
    expect(urls, contains(AppConstants.repairsSsoUrl));
    expect(urls, contains('https://bxpt.hunau.edu.cn/relax/sso/cas/login?ticket=ST-test-ticket'));
    expect(urls, contains('https://bxpt.hunau.edu.cn/relax/index.html'));

    // Verify ongoingPage RPC params format matches HAR
    final rpcReq = requests.firstWhere((r) =>
        r.uri.path == '/relax/mobile/rpc' &&
        r.data is Map &&
        r.data['method'] == '/v2/service/portal/workorderData/ongoingPage');
    final params = rpcReq.data['params'] as List;
    expect(params.length, 2);
    expect(params[0], '37ea4a70-af77-4c1a-9422-7582afc0de41');

    final payloadMap = params[1] as Map<String, dynamic>;
    expect(payloadMap['pageSize'], '10');
    expect(payloadMap['pageIndex'], '1');
    expect(payloadMap['orders'], [{'name': 'start_time', 'type': 'desc'}]);

    // Verify filter uses extracted internal bxpt UUID
    final filter = payloadMap['filter'] as Map<String, dynamic>;
    final filterStr = filter.toString();
    expect(filterStr, contains(testBxptUuid));

    // Verify request headers
    expect(rpcReq.headers['Origin'], 'https://bxpt.hunau.edu.cn');
    expect(rpcReq.headers['Referer'], 'https://bxpt.hunau.edu.cn/relax/mobile/index.html');
    expect(rpcReq.headers['X-Requested-With'], 'XMLHttpRequest');
  });

  test('expired TGC invokes reauthenticate and recovers repair session', () async {
    var reauthenticated = false;
    final service = RepairService(
      auth,
      dio: dio,
      reauthenticate: () async {
        reauthenticated = true;
      },
    );

    respond = (options) {
      final url = options.uri.toString();
      if (url == AppConstants.repairsSsoUrl) {
        if (!reauthenticated) {
          // SSO session expired, returns 200 login page without redirect
          return Response(
            requestOptions: options,
            statusCode: 200,
            data: '<html>Login</html>',
          );
        }
        return Response(
          requestOptions: options,
          statusCode: 302,
          headers: Headers.fromMap({
            HttpHeaders.locationHeader: [
              'http://bxpt.hunau.edu.cn/relax/sso/cas/login?ticket=ST-fresh-ticket'
            ],
          }),
        );
      }
      if (url == 'https://bxpt.hunau.edu.cn/relax/sso/cas/login?ticket=ST-fresh-ticket') {
        return Response(
          requestOptions: options,
          statusCode: 302,
          headers: Headers.fromMap({
            HttpHeaders.locationHeader: ['http://bxpt.hunau.edu.cn/relax/index.html'],
          }),
        );
      }
      if (url == 'https://bxpt.hunau.edu.cn/relax/index.html') {
        return Response(requestOptions: options, statusCode: 200, data: 'OK');
      }
      if (options.uri.path == '/relax/mobile/rpc') {
        final method = options.data is Map ? options.data['method'] : '';
        if (method == '/v2/login/isAuthenticated') {
          if (!reauthenticated) {
            return {'id': 1, 'jsonrpc': '2.0'};
          }
          return {
            'id': 1,
            'jsonrpc': '2.0',
            'result': {
              'id': testBxptUuid,
              'account': testStudentId,
              'display_name': '朱天兆',
            },
          };
        }
        if (method == '/v2/service/portal/workorderData/ongoingPage') {
          return {
            'id': 1,
            'jsonrpc': '2.0',
            'result': {'data': []},
          };
        }
      }
      return Response(requestOptions: options, statusCode: 404);
    };

    final orders = await service.fetchOrders(ongoing: true);
    expect(reauthenticated, isTrue);
    expect(orders, isEmpty);
    expect(service.bxptUserId, testBxptUuid);
  });

  test('RPC server error throws RepairException with message', () async {
    final service = RepairService(auth, dio: dio);

    respond = (options) {
      if (options.uri.path == '/relax/mobile/rpc') {
        final method = options.data is Map ? options.data['method'] : '';
        if (method == '/v2/login/isAuthenticated') {
          return {
            'id': 1,
            'jsonrpc': '2.0',
            'result': {
              'id': testBxptUuid,
              'account': testStudentId,
            },
          };
        }
        return {
          'id': 1,
          'jsonrpc': '2.0',
          'error': {'code': -32601, 'message': 'params error!'},
        };
      }
      return Response(requestOptions: options, statusCode: 200);
    };

    await expectLater(
      service.fetchOrders(ongoing: true),
      throwsA(isA<RepairException>().having(
        (e) => e.message,
        'message',
        contains('params error!'),
      )),
    );
  });

  test('fetchOrders with isDraft calls officePage and returns draft orders', () async {
    final service = RepairService(auth, dio: dio);

    respond = (options) {
      if (options.uri.path == '/relax/mobile/rpc') {
        final method = options.data is Map ? options.data['method'] : '';
        if (method == '/v2/login/isAuthenticated') {
          return {
            'id': 1,
            'jsonrpc': '2.0',
            'result': {
              'id': testBxptUuid,
              'account': testStudentId,
            },
          };
        }
        if (method == '/v2/workorder/data/officePage') {
          return {
            'id': 1,
            'jsonrpc': '2.0',
            'result': {
              'data': [
                {
                  'id': 'draft-order-1',
                  'code': 'IN26090001',
                  'dynamic_title': '测试草稿工单',
                  'service_catalog': {'display_name': '后勤报修'},
                  'flow_status': {'name': 'NEW', 'display_name': '草稿'},
                  'create_time': 1788839297264,
                }
              ]
            },
          };
        }
      }
      return Response(requestOptions: options, statusCode: 200);
    };

    final drafts = await service.fetchOrders(ongoing: false, isDraft: true);
    expect(drafts.length, 1);
    expect(drafts.first.id, 'draft-order-1');
    expect(drafts.first.isDraft, isTrue);
  });

  test('fetchOrderDetail fetches details, activity logs, attachments and actions', () async {
    final service = RepairService(auth, dio: dio);

    respond = (options) {
      if (options.uri.path == '/relax/mobile/rpc') {
        final method = options.data is Map ? options.data['method'] : '';
        if (method == '/v2/login/isAuthenticated') {
          return {
            'id': 1,
            'jsonrpc': '2.0',
            'result': {'id': testBxptUuid},
          };
        }
        if (method == '/v2/workorder/data/getById') {
          return {
            'id': 1,
            'jsonrpc': '2.0',
            'result': {
              'wtmsh': '网络无法连接',
              'bchshm': '第十教学楼',
              'actual_handler': {'display_name': '付阿妮'},
              'actual_handler_department': {'display_name': '信息与网络中心'},
              'lxfs': '13965043045',
              'chljg': '已处理',
              'user_response': '速度很快',
              'score': 5.0,
            }
          };
        }
        if (method == '/v2/workorder/orderConfig/getNodeByOrder') {
          return {'id': 1, 'jsonrpc': '2.0', 'result': 'node-accept-123'};
        }
        if (method == '/v2/workorder/action/list') {
          return {
            'id': 1,
            'jsonrpc': '2.0',
            'result': [
              {
                'id': 'action-cancel-1',
                'name': '取消报修',
                'display_name': '取消报修',
                'possessor': 'node-accept-123',
              }
            ]
          };
        }
        if (method == '/v2/cmdb/ci/list') {
          return {
            'id': 1,
            'jsonrpc': '2.0',
            'result': [
              {
                'id': 'log-1',
                'description': '朱天兆在“开始”节点，提交了该工单!',
                'create_user': {'display_name': '朱天兆'},
                'create_time': 1788839297294,
              }
            ]
          };
        }
        if (method == '/v2/file/list') {
          return {
            'id': 1,
            'jsonrpc': '2.0',
            'result': [
              {
                'id': 'file-1',
                'upload_file_name': 'test.png',
                'thumbnail': 'rpc?method=/v2/file/thumbnail&id=file-1',
                'create_time': 1788839282725,
              }
            ]
          };
        }
      }
      return Response(requestOptions: options, statusCode: 200);
    };

    final order = RepairOrder(
      id: 'order-123',
      code: 'IN260908000041',
      title: '网络报修',
      description: '',
      catalog: '校园网络故障报修',
      status: '处理中',
      statusId: 'PROCESSING',
      createdAt: DateTime.now(),
      closedAt: null,
      department: '信息与网络中心',
      raw: {
        'type': {'id': 'type-ci-1'},
        'service_catalog': {'id': 'catalog-ci-1'},
      },
    );

    final detail = await service.fetchOrderDetail(order);
    expect(detail.description, '网络无法连接');
    expect(detail.supplement, '第十教学楼');
    expect(detail.handler, '付阿妮');
    expect(detail.handleResult, '已处理');
    expect(detail.userResponse, '速度很快');
    expect(detail.score, 5.0);
    expect(detail.phone, '13965043045');
    expect(detail.logs.length, 1);
    expect(detail.logs.first.description, contains('提交了该工单'));
    expect(detail.attachments.length, 1);
    expect(detail.attachments.first.fileName, 'test.png');
    expect(detail.canCancel, isTrue);

    // Now test cancelOrder
    respond = (options) {
      if (options.uri.path == '/relax/mobile/rpc') {
        final method = options.data is Map ? options.data['method'] : '';
        if (method == '/v2/login/isAuthenticated') {
          return {'id': 1, 'jsonrpc': '2.0', 'result': {'id': testBxptUuid}};
        }
        if (method == '/v2/workorder/action/executeWithValidate') {
          return {'id': 1, 'jsonrpc': '2.0', 'result': {'state': true}};
        }
      }
      return Response(requestOptions: options, statusCode: 200);
    };

    final cancelSuccess = await service.cancelOrder(detail);
    expect(cancelSuccess, isTrue);
  });

  test('references calls /v2/cmdb/ci/page and falls back to /v2/cmdb/ci/list', () async {
    final service = RepairService(auth, dio: dio);

    respond = (options) {
      if (options.uri.path == '/relax/mobile/rpc') {
        final method = options.data is Map ? options.data['method'] : '';
        if (method == '/v2/login/isAuthenticated') {
          return {'id': 1, 'jsonrpc': '2.0', 'result': {'id': testBxptUuid}};
        }
        if (method == '/v2/cmdb/ci/page') {
          final params = options.data['params'];
          expect(params[0], 'ref-type-1');
          expect(params[1]['filter']['query'], '');
          return {
            'id': 1,
            'jsonrpc': '2.0',
            'result': {
              'data': [
                {'id': 'choice-1', 'display_name': '东区'},
                {'id': 'choice-2', 'display_name': '西区'},
              ]
            }
          };
        }
      }
      return Response(requestOptions: options, statusCode: 200);
    };

    final choices = await service.references('ref-type-1');
    expect(choices.length, 2);
    expect(choices[0].id, 'choice-1');
    expect(choices[0].label, '东区');

    // Test fallback when /v2/cmdb/ci/page fails
    respond = (options) {
      if (options.uri.path == '/relax/mobile/rpc') {
        final method = options.data is Map ? options.data['method'] : '';
        if (method == '/v2/login/isAuthenticated') {
          return {'id': 1, 'jsonrpc': '2.0', 'result': {'id': testBxptUuid}};
        }
        if (method == '/v2/cmdb/ci/page') {
          return {
            'id': 1,
            'jsonrpc': '2.0',
            'error': {'code': -32601, 'message': 'Method not found'}
          };
        }
        if (method == '/v2/cmdb/ci/list') {
          final params = options.data['params'];
          expect(params[0], 'ref-type-2');
          expect(params[1]['filter'], {});
          return {
            'id': 1,
            'jsonrpc': '2.0',
            'result': [
              {'id': 'choice-fallback', 'display_name': '北校区'}
            ]
          };
        }
      }
      return Response(requestOptions: options, statusCode: 200);
    };

    final fallbackChoices = await service.references('ref-type-2');
    expect(fallbackChoices.length, 1);
    expect(fallbackChoices[0].id, 'choice-fallback');
    expect(fallbackChoices[0].label, '北校区');
  });

  test('lookup calls /v2/cmdb/meta/lookup/page successfully', () async {
    final service = RepairService(auth, dio: dio);

    respond = (options) {
      if (options.uri.path == '/relax/mobile/rpc') {
        final method = options.data is Map ? options.data['method'] : '';
        if (method == '/v2/login/isAuthenticated') {
          return {'id': 1, 'jsonrpc': '2.0', 'result': {'id': testBxptUuid}};
        }
        if (method == '/v2/cmdb/meta/lookup/page') {
          return {
            'id': 1,
            'jsonrpc': '2.0',
            'result': {
              'data': [
                {'name': '1', 'display_name': '高'},
                {'name': '2', 'display_name': '中'},
              ]
            }
          };
        }
      }
      return Response(requestOptions: options, statusCode: 200);
    };

    final choices = await service.lookup('priority-lookup');
    expect(choices.length, 2);
    expect(choices[0].id, '1');
    expect(choices[0].label, '高');
  });

  test('RepairField correctly identifies date fields', () {
    const f1 = RepairField(
      name: 'yyrq',
      label: '预约日期',
      editor: 'datepicker',
      required: true,
      hidden: false,
      readonly: false,
    );
    expect(f1.isDate, isTrue);

    const f2 = RepairField(
      name: 'custom_date',
      label: '检查日期',
      editor: 'text',
      required: false,
      hidden: false,
      readonly: false,
    );
    expect(f2.isDate, isTrue);

    const f3 = RepairField(
      name: 'sftywrrq',
      label: '是否同意无人入寝维修',
      editor: 'radiogroup',
      required: true,
      hidden: false,
      readonly: false,
    );
    expect(f3.isDate, isFalse);
    expect(f3.isChoice, isTrue);
  });

  test('lookup with notInNames constructs exact filter matching HAR', () async {
    final service = RepairService(auth, dio: dio);

    respond = (options) {
      if (options.uri.path == '/relax/mobile/rpc') {
        final method = options.data is Map ? options.data['method'] : '';
        if (method == '/v2/login/isAuthenticated') {
          return {'id': 1, 'jsonrpc': '2.0', 'result': {'id': testBxptUuid}};
        }
        if (method == '/v2/cmdb/meta/lookup/page') {
          final params = options.data['params'] as List;
          final criteria = params[0] as Map;
          final andList = criteria['filter']['attribute']['and'] as List;
          expect(andList.length, 2);
          expect(andList[0]['simple']['name'], 'lookup_type');
          expect(andList[0]['simple']['value'], '3965f192-b6ed-11eb-8b80-af0eafc5dd38');
          expect(andList[1]['simple']['name'], 'name');
          expect(andList[1]['simple']['operator'], 'notin');
          expect(andList[1]['simple']['value'], ['8_9', '9_10', '10_11', '11_12']);
          return {
            'id': 1,
            'jsonrpc': '2.0',
            'result': {
              'data': [
                {
                  'name': '14_15',
                  'display_name': '16:20-18:00（第四大节）',
                }
              ]
            }
          };
        }
      }
      return Response(requestOptions: options, statusCode: 200);
    };

    final choices = await service.lookup(
      '3965f192-b6ed-11eb-8b80-af0eafc5dd38',
      notInNames: ['8_9', '9_10', '10_11', '11_12'],
    );
    expect(choices.length, 1);
    expect(choices[0].id, '14_15');
    expect(choices[0].label, '16:20-18:00（第四大节）');
  });

  test('resolveCatalog accurately identifies all four repair categories', () {
    // 1. By catalogId
    final o1 = RepairOrder.fromJson({
      'id': '1',
      'service_catalog': {'id': '5bbbaf0a-b7b7-11eb-b305-4bcc6b2984af'},
    });
    expect(RepairService.resolveCatalog(o1).title, '后勤报修');

    final o2 = RepairOrder.fromJson({
      'id': '2',
      'service_catalog': {'id': 'b4435ca0-99f6-11ec-bf7a-177427586306'},
    });
    expect(RepairService.resolveCatalog(o2).title, '校园网络报修');

    final o3 = RepairOrder.fromJson({
      'id': '3',
      'service_catalog': {'id': 'f11e3e78-9ace-11ec-9f07-f7b2f4ca88d7'},
    });
    expect(RepairService.resolveCatalog(o3).title, '一校通报修');

    final o4 = RepairOrder.fromJson({
      'id': '4',
      'service_catalog': {'id': 'ffa62964-9539-11ec-a409-0f7763ad71f7'},
    });
    expect(RepairService.resolveCatalog(o4).title, '业务系统报修');

    // 2. By processId
    final o5 = RepairOrder.fromJson({
      'id': '5',
      'process': {'id': 'f83a50f6-95f9-41d9-bf27-851f340035a4', 'display_name': '信息系统报修'},
    });
    expect(RepairService.resolveCatalog(o5).title, '业务系统报修');

    // 3. By title keywords
    final o6 = RepairOrder.fromJson({
      'id': '6',
      'dynamic_title': '朱天兆的身份认证的业务系统故障-时间:2026-09-23 01:37',
    });
    expect(RepairService.resolveCatalog(o6).title, '业务系统报修');
  });

  test('loadDraftForm queries /v2/workorder/data/getById and populates draft values', () async {
    final service = RepairService(auth, dio: dio);

    final draftOrder = RepairOrder.fromJson({
      'id': 'draft-ci-123',
      'service_catalog': {
        'id': 'ffa62964-9539-11ec-a409-0f7763ad71f7',
        'display_name': '业务系统故障',
      },
      'type': {
        'id': 'ce75fee6-952f-11ec-a62b-c71d06e6a54f',
        'display_name': '信息系统报修',
      },
      'code': 'IN260923000003',
      'dynamic_title': '测试业务系统报修草稿',
      'flow_status': {'id': 'NEW', 'display_name': '草稿'},
    });

    bool getByIdCalled = false;
    respond = (options) {
      if (options.uri.path == '/relax/mobile/rpc') {
        final method = options.data is Map ? options.data['method'] : '';
        if (method == '/v2/login/isAuthenticated') {
          return {'id': 1, 'jsonrpc': '2.0', 'result': {'id': testBxptUuid}};
        }
        if (method == '/v2/cmdb/ci/id') {
          return {'id': 1, 'jsonrpc': '2.0', 'result': 'new-temp-id'};
        }
        if (method == '/v2/workorder/serviceitem/card/getMobileCatalogById') {
          return {
            'id': 1,
            'jsonrpc': '2.0',
            'result': {
              'type': {'id': 'ce75fee6-952f-11ec-a62b-c71d06e6a54f'}
            }
          };
        }
        if (method == '/v2/workorder/orderConfig/getNodeByServiceCatalog') {
          return {'id': 1, 'jsonrpc': '2.0', 'result': 'node-1'};
        }
        if (method == '/v2/workorder/action/list') {
          return {
            'id': 1,
            'jsonrpc': '2.0',
            'result': [
              {'id': 'submit-action-id', 'name': '提交', 'display_name': '提交'},
              {'id': 'draft-action-id', 'name': '保存草稿', 'display_name': '保存草稿'},
            ]
          };
        }
        if (method == '/v2/workorder/view/form/getNotRelationOrderForm') {
          return {
            'id': 1,
            'jsonrpc': '2.0',
            'result': [
              {
                'constructData': '{"ciType":"ce75fee6-952f-11ec-a62b-c71d06e6a54f","components":[{"name":"wtmsh","label":"问题描述","editor":"textarea"},{"name":"ywxtmc","label":"业务系统名称","editor":"lookup"}]}'
              }
            ]
          };
        }
        if (method == '/v2/workorder/data/getById') {
          getByIdCalled = true;
          final params = options.data['params'] as List;
          expect(params[0], 'ce75fee6-952f-11ec-a62b-c71d06e6a54f');
          expect(params[1], 'draft-ci-123');
          return {
            'id': 1,
            'jsonrpc': '2.0',
            'result': {
              'wtmsh': '阳光平台无法提交咨询建议',
              'bchshm': '阳光平台',
              'ywxtmc': {
                'id': 'others',
                'name': 'others',
                'display_name': '其它',
              },
            }
          };
        }
      }
      return Response(requestOptions: options, statusCode: 200);
    };

    final session = await service.loadDraftForm(draftOrder);
    expect(getByIdCalled, isTrue);
    expect(session.instanceId, 'draft-ci-123');
    expect(session.catalog.title, '业务系统报修');
    expect(session.initialValues['wtmsh'], '阳光平台无法提交咨询建议');
    expect(session.initialValues['bchshm'], '阳光平台');
    expect(session.initialValues['ywxtmc'], isA<Map>());
    expect((session.initialValues['ywxtmc'] as Map)['display_name'], '其它');
  });

  test('submit sanitizes Map values to primitive ids before RPC', () async {
    final service = RepairService(auth, dio: dio);

    final catalog = RepairService.catalogs.firstWhere((c) => c.title == '业务系统报修');
    final session = RepairFormSession(
      catalog: catalog,
      instanceId: 'test-instance-id',
      ciType: 'ce75fee6-952f-11ec-a62b-c71d06e6a54f',
      nodeId: 'test-node',
      submitActionId: 'submit-action-id',
      saveDraftActionId: 'draft-action-id',
      formRuleId: null,
      fields: const [
        RepairField(name: 'wtmsh', label: '问题描述', editor: 'textarea', required: true, hidden: false, readonly: false),
        RepairField(name: 'ywxtmc', label: '业务系统名称', editor: 'lookup', required: true, hidden: false, readonly: false),
      ],
      initialValues: {
        'id': 'test-instance-id',
        'type': 'ce75fee6-952f-11ec-a62b-c71d06e6a54f',
        // Nested Map from draftData
        'apply_department': {
          'id': 'dept-uuid-456',
          'display_name': '机电工程学院',
        },
      },
    );

    bool executeCalled = false;
    respond = (options) {
      if (options.uri.path == '/relax/mobile/rpc') {
        final method = options.data is Map ? options.data['method'] : '';
        if (method == '/v2/login/isAuthenticated') {
          return {'id': 1, 'jsonrpc': '2.0', 'result': {'id': testBxptUuid}};
        }
        if (method == '/v2/workorder/action/executeWithValidate') {
          executeCalled = true;
          final params = options.data['params'] as List;
          expect(params[0], 'draft-action-id');
          final data = params[1][1] as Map;
          expect(data['apply_department'], 'dept-uuid-456');
          expect(data['wtmsh'], '问题描述内容');
          expect(data['ywxtmc'], 'others');
          return {'id': 1, 'jsonrpc': '2.0', 'result': {'state': true}};
        }
      }
      return Response(requestOptions: options, statusCode: 200);
    };

    final result = await service.submit(
      session,
      {'wtmsh': '问题描述内容', 'ywxtmc': 'others'},
      isDraft: true,
    );
    expect(executeCalled, isTrue);
    expect(result, 'ok');
  });

  test('submit converts date strings like 2026/09/23 to millisecond epoch timestamp integer', () async {
    final service = RepairService(auth, dio: dio);

    final catalog = RepairService.catalogs.firstWhere((c) => c.title == '后勤报修');
    final session = RepairFormSession(
      catalog: catalog,
      instanceId: 'inst-date-1',
      ciType: 'ci-type-hq',
      nodeId: 'node-start',
      submitActionId: 'submit-act-id',
      formRuleId: null,
      fields: const [
        RepairField(name: 'yyrq', label: '预约日期', editor: 'datepicker', required: true, hidden: false, readonly: false, raw: {'dataType': 'DATE'}),
      ],
      initialValues: const {'id': 'inst-date-1'},
    );

    expect(RepairService.parseDateToTimestamp('2026/09/23'), DateTime(2026, 9, 23).millisecondsSinceEpoch);
    expect(RepairService.parseDateToTimestamp('2026-09-23'), DateTime(2026, 9, 23).millisecondsSinceEpoch);
    expect(RepairService.parseDateToTimestamp(1790098560941), 1790098560941);
    expect(RepairService.parseDateToTimestamp('1790098560941'), 1790098560941);
    expect(RepairService.parseDateToTimestamp(''), isNull);
    expect(RepairService.parseDateToTimestamp(null), isNull);

    bool executeCalled = false;
    respond = (options) {
      if (options.uri.path == '/relax/mobile/rpc') {
        final method = options.data is Map ? options.data['method'] : '';
        if (method == '/v2/login/isAuthenticated') {
          return {'id': 1, 'jsonrpc': '2.0', 'result': {'id': testBxptUuid}};
        }
        if (method == '/v2/workorder/action/executeWithValidate') {
          executeCalled = true;
          final params = options.data['params'] as List;
          final data = params[1][1] as Map;
          expect(data['yyrq'], isA<int>());
          expect(data['yyrq'], DateTime(2026, 9, 23).millisecondsSinceEpoch);
          return {'id': 1, 'jsonrpc': '2.0', 'result': {'state': true}};
        }
      }
      return Response(requestOptions: options, statusCode: 200);
    };

    final result = await service.submit(session, {'yyrq': '2026/09/23'});
    expect(executeCalled, isTrue);
    expect(result, 'ok');
  });

  test('uploadAttachment uploads file via multipart and registers audit log and relation', () async {
    final service = RepairService(auth, dio: dio);

    final session = RepairFormSession(
      catalog: RepairService.catalogs[0],
      instanceId: 'inst-789',
      ciType: 'ci-type-abc',
      nodeId: 'node-start',
      submitActionId: 'submit-act',
      formRuleId: null,
      fields: const [
        RepairField(name: 'scwttp', label: '上传问题图片', editor: 'upload', required: false, hidden: false, readonly: false),
      ],
      initialValues: const {},
    );
    final field = session.fields[0];

    final tempDir = Directory.systemTemp.createTempSync('bxpt_upload_test');
    final tempFile = File('${tempDir.path}/test_photo.jpg')..writeAsBytesSync([1, 2, 3, 4]);

    bool uploadCalled = false;
    bool ciCreateCalled = false;
    bool relationCreateCalled = false;

    respond = (options) {
      final url = options.uri.toString();
      if (options.uri.path == '/relax/mobile/rpc') {
        if (url.contains('method=/v2/file/upload')) {
          uploadCalled = true;
          expect(options.data, isA<FormData>());
          final fd = options.data as FormData;
          final map = Map.fromEntries(fd.fields);
          expect(map['fileName'], 'uploadFile');
          expect(map['subsystem'], 'eui');
          expect(map['instance'], 'inst-789-scwttp');
          expect(fd.files.any((f) => f.key == 'uploadFile'), isTrue);
          return {
            'id': 'file-uuid-001',
            'upload_file_name': 'test_photo.jpg',
            'display_name': 'test_photo.jpg',
            'file_size': 4,
            'instance': 'inst-789-scwttp',
            'thumbnail': 'rpc?method=/v2/file/thumbnail&id=file-uuid-001',
            'url': 'rpc?method=/v2/file/download&id=file-uuid-001',
          };
        }
        final method = options.data is Map ? options.data['method'] : '';
        if (method == '/v2/login/isAuthenticated') {
          return {'id': 1, 'jsonrpc': '2.0', 'result': {'id': testBxptUuid}};
        }
        if (method == '/v2/cmdb/ci/create') {
          ciCreateCalled = true;
          final params = options.data['params'] as List;
          final item = params[0] as Map;
          expect(item['type'], '737fb2a0-a9a5-41fd-b36f-d32d604e2128');
          expect(item['description'], contains('test_photo.jpg'));
          expect(item['description'], contains('file-uuid-001'));
          return {'id': 1, 'jsonrpc': '2.0', 'result': 'activity-log-id-999'};
        }
        if (method == '/v2/cmdb/relation/create') {
          relationCreateCalled = true;
          final params = options.data['params'] as List;
          final item = params[0] as Map;
          expect(item['type'], '42e2bb1d-2d74-4cc7-a53b-ba5413b14792');
          expect(item['source'], 'inst-789');
          expect(item['destination'], 'activity-log-id-999');
          return {'id': 1, 'jsonrpc': '2.0', 'result': 'relation-ok'};
        }
      }
      return Response(requestOptions: options, statusCode: 200);
    };

    final attachment = await service.uploadAttachment(session, field, tempFile);
    tempDir.deleteSync(recursive: true);

    expect(uploadCalled, isTrue);
    expect(ciCreateCalled, isTrue);
    expect(relationCreateCalled, isTrue);
    expect(attachment.id, 'file-uuid-001');
    expect(attachment.fileName, 'test_photo.jpg');
    expect(attachment.thumbnailUrl, 'https://bxpt.hunau.edu.cn/relax/mobile/rpc?method=/v2/file/thumbnail&id=file-uuid-001');
  });

  test('deleteAttachment calls /v2/file/deleteById', () async {
    final service = RepairService(auth, dio: dio);

    bool deleteCalled = false;
    respond = (options) {
      if (options.uri.path == '/relax/mobile/rpc') {
        final method = options.data is Map ? options.data['method'] : '';
        if (method == '/v2/login/isAuthenticated') {
          return {'id': 1, 'jsonrpc': '2.0', 'result': {'id': testBxptUuid}};
        }
        if (method == '/v2/file/deleteById') {
          deleteCalled = true;
          expect(options.data['params'], ['file-uuid-001']);
          return {'id': 1, 'jsonrpc': '2.0', 'result': true};
        }
      }
      return Response(requestOptions: options, statusCode: 200);
    };

    await service.deleteAttachment('file-uuid-001');
    expect(deleteCalled, isTrue);
  });

  test('fetchDraftAttachments queries /v2/file/list with instance filter', () async {
    final service = RepairService(auth, dio: dio);

    bool listCalled = false;
    respond = (options) {
      if (options.uri.path == '/relax/mobile/rpc') {
        final method = options.data is Map ? options.data['method'] : '';
        if (method == '/v2/login/isAuthenticated') {
          return {'id': 1, 'jsonrpc': '2.0', 'result': {'id': testBxptUuid}};
        }
        if (method == '/v2/file/list') {
          listCalled = true;
          final params = options.data['params'] as List;
          final criteria = params[0] as Map;
          final filter = criteria['filter'] as Map;
          final simple = filter['attribute']['simple'] as Map;
          expect(simple['name'], 'instance');
          expect(simple['operator'], 'eq');
          expect(simple['value'], 'inst-789-scwttp');
          return {
            'id': 1,
            'jsonrpc': '2.0',
            'result': [
              {
                'id': 'file-1',
                'upload_file_name': 'img1.jpg',
                'thumbnail': 'rpc?method=/v2/file/thumbnail&id=file-1',
              }
            ]
          };
        }
      }
      return Response(requestOptions: options, statusCode: 200);
    };

    final list = await service.fetchDraftAttachments('inst-789', 'scwttp');
    expect(listCalled, isTrue);
    expect(list.length, 1);
    expect(list[0].id, 'file-1');
    expect(list[0].fileName, 'img1.jpg');
  });

  test('submit with upload fields passes attachment count into executeWithValidate', () async {
    final service = RepairService(auth, dio: dio);

    final session = RepairFormSession(
      catalog: RepairService.catalogs[0],
      instanceId: 'inst-789',
      ciType: 'ci-type-abc',
      nodeId: 'node-start',
      submitActionId: 'submit-act',
      formRuleId: null,
      fields: const [
        RepairField(name: 'scwttp', label: '上传问题图片', editor: 'upload', required: false, hidden: false, readonly: false),
        RepairField(name: 'wtmsh', label: '问题描述', editor: 'textarea', required: false, hidden: false, readonly: false),
      ],
      initialValues: const {'id': 'inst-789'},
    );

    bool submitCalled = false;
    respond = (options) {
      if (options.uri.path == '/relax/mobile/rpc') {
        final method = options.data is Map ? options.data['method'] : '';
        if (method == '/v2/login/isAuthenticated') {
          return {'id': 1, 'jsonrpc': '2.0', 'result': {'id': testBxptUuid}};
        }
        if (method == '/v2/workorder/action/executeWithValidate') {
          submitCalled = true;
          final data = options.data['params'][1][1] as Map;
          expect(data['scwttp'], 2);
          expect(data['wtmsh'], '问题描述');
          return {'id': 1, 'jsonrpc': '2.0', 'result': {'state': true}};
        }
      }
      return Response(requestOptions: options, statusCode: 200);
    };

    await service.submit(session, {'scwttp': 2, 'wtmsh': '问题描述'});
    expect(submitCalled, isTrue);
  });
}
