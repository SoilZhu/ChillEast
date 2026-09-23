import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/state/auth_state.dart';
import '../models/repair_models.dart';

final repairServiceProvider = Provider<RepairService>((ref) => RepairService(
      ref.read(authStateProvider),
      reauthenticate: ref.read(authServiceProvider).silentLogin,
    ));

class RepairException implements Exception {
  final String message;
  const RepairException(this.message);
  @override
  String toString() => message;
}

class RepairService {
  static const baseUrl = 'https://bxpt.hunau.edu.cn';
  final AuthState auth;
  final Dio? _client;
  final Future<void> Function()? _reauthenticate;
  bool _repairSessionReady = false;
  Future<void>? _repairSessionFuture;
  String? _bxptUserId;

  RepairService(
    this.auth, {
    Dio? dio,
    Future<void> Function()? reauthenticate,
  })  : _client = dio,
        _reauthenticate = reauthenticate;

  static const catalogs = <RepairCatalog>[
    RepairCatalog(
        id: '5bbbaf0a-b7b7-11eb-b305-4bcc6b2984af',
        title: '后勤报修',
        subtitle: '宿舍、公共设施与生活服务',
        department: '后勤保障中心',
        processId: '4e2cc26d-08b4-4cab-a3a7-fba23a23e11d',
        color: Color(0xFFEF6C00),
        icon: Icons.home_repair_service_outlined),
    RepairCatalog(
        id: 'b4435ca0-99f6-11ec-bf7a-177427586306',
        title: '校园网络报修',
        subtitle: '无线网络、网线与校园网故障',
        department: '信息与网络中心',
        processId: 'd86a31ef-6e54-4da5-8c8f-a881986ec422',
        color: Color(0xFF1976D2),
        icon: Icons.wifi_tethering_error_rounded),
    RepairCatalog(
        id: 'f11e3e78-9ace-11ec-9f07-f7b2f4ca88d7',
        title: '一校通报修',
        subtitle: '一卡通、数字校园与信息化设备',
        department: '信息与网络中心',
        processId: 'aa21a42a-a2f7-48a7-aae6-fc374e4ebc44',
        color: Color(0xFFD84315),
        icon: Icons.devices_other_outlined),
    RepairCatalog(
        id: 'ffa62964-9539-11ec-a409-0f7763ad71f7',
        title: '业务系统报修',
        subtitle: '教务、门户及其他业务系统',
        department: '信息与网络中心',
        processId: 'f83a50f6-95f9-41d9-bf27-851f340035a4',
        color: Color(0xFF00897B),
        icon: Icons.apps_outlined),
  ];

  Dio get _dio => _client ?? DioClient().dio;
  String get _uid => _bxptUserId ?? auth.uid ?? '';
  String? get bxptUserId => _bxptUserId;

  /// The campus repair platform has its own CAS service endpoint. The normal
  /// app login establishes the SSO ticket cookie, but the ticket must still be
  /// exchanged once with bxpt.hunau.edu.cn before its /relax/mobile RPC API
  /// accepts requests. This is the same redirect chain captured in
  /// debug/登录bxpt.hunau.edu.cn.har.
  Future<void> _ensureRepairSession() async {
    if (_repairSessionReady) return;
    final running = _repairSessionFuture;
    if (running != null) return running;
    final future = _establishRepairSession();
    _repairSessionFuture = future;
    try {
      await future;
    } finally {
      if (identical(_repairSessionFuture, future)) _repairSessionFuture = null;
    }
  }

  Future<void> _establishRepairSession() async {
    // 1. 尝试复用现有会话
    try {
      final identity = await _rpcRaw('/v2/login/isAuthenticated', null);
      if (identity is Map && identity['id'] != null) {
        _bxptUserId = identity['id']?.toString();
        _repairSessionReady = true;
        return;
      }
    } catch (_) {}

    // 2. 进行 CAS 票据交换
    await _exchangeCasTicket();

    // 3. 校验并提取用户资料
    try {
      final identity = await _rpcRaw('/v2/login/isAuthenticated', null);
      if (identity is Map && identity['id'] != null) {
        _bxptUserId = identity['id']?.toString();
        _repairSessionReady = true;
        return;
      }
    } catch (_) {}

    // 4. 若换票未成功，可能是 SSO TGC 过期，尝试静默重新登录后再次换票
    final reauthenticate = _reauthenticate;
    if (reauthenticate != null) {
      try {
        await reauthenticate();
        await _exchangeCasTicket();
        final refreshedIdentity =
            await _rpcRaw('/v2/login/isAuthenticated', null);
        if (refreshedIdentity is Map && refreshedIdentity['id'] != null) {
          _bxptUserId = refreshedIdentity['id']?.toString();
          _repairSessionReady = true;
          return;
        }
      } catch (_) {}
    }

    throw const RepairException('报修平台登录凭证交换失败，请返回个人中心重新登录后重试');
  }

  Future<void> _exchangeCasTicket() async {
    var current = Uri.parse(AppConstants.repairsSsoUrl);
    for (var i = 0; i < 8; i++) {
      final response = await _dio.getUri(
        current,
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
          receiveTimeout: const Duration(seconds: 25),
          headers: const {
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          },
        ),
      );
      final location = response.headers.value(HttpHeaders.locationHeader);
      if (location == null || location.isEmpty) break;
      var next = current.resolve(location);
      // The captured browser flow is HTTP -> HTTPS for bxpt. Browsers upgrade
      // the HTTP redirect because of HSTS, while Dio does not do that itself.
      if (next.host == Uri.parse(RepairService.baseUrl).host &&
          next.scheme == 'http') {
        next = next.replace(scheme: 'https');
      }
      if (next == current) break;
      current = next;
    }
  }

  Future<dynamic> _rpcRaw(String path, dynamic params,
      {bool batch = false}) async {
    final payload = batch
        ? params
        : {'jsonrpc': '2.0', 'method': path, 'id': '1', 'params': params};
    final response = await _dio.post(
      '$baseUrl/relax/mobile/rpc',
      queryParameters: {
        'p': path,
        't': DateTime.now().millisecondsSinceEpoch,
      },
      data: payload,
      options: Options(
        contentType: Headers.jsonContentType,
        responseType: ResponseType.plain,
        receiveTimeout: const Duration(seconds: 25),
        headers: const {
          'Origin': baseUrl,
          'Referer': '$baseUrl/relax/mobile/index.html',
          'X-Requested-With': 'XMLHttpRequest',
          'X-User-Lang': 'zh-CN',
          'Accept': '*/*',
        },
      ),
    );
    dynamic body = response.data;
    if (body is String) {
      try {
        body = jsonDecode(body);
      } catch (_) {
        try {
          body = jsonDecode(utf8.decode(base64Decode(body)));
        } catch (_) {}
      }
    }
    if (body is List) {
      return body.map((e) => e is Map ? e['result'] : e).toList();
    }
    if (body is! Map) {
      throw const RepairException('报修平台暂时不可用，请稍后重试');
    }
    if (body['error'] != null) {
      final err = body['error'];
      final msg = err is Map
          ? (err['message'] ?? err['data'] ?? '')
          : err.toString();
      throw RepairException(
          msg.isNotEmpty ? '报修服务异常: $msg' : '报修平台暂时不可用，请稍后重试');
    }
    return body['result'];
  }

  Future<dynamic> _rpc(String path, dynamic params) async {
    await _ensureRepairSession();
    return _rpcRaw(path, params);
  }

  Future<List<RepairOrder>> fetchOrders({
    required bool ongoing,
    bool isDraft = false,
    int pageIndex = 1,
    int pageSize = 10,
  }) async {
    await _ensureRepairSession();
    final userId = _bxptUserId ?? auth.uid ?? '';

    String method;
    List<String> attributes;
    Map<String, dynamic> filter;
    List<Map<String, String>> orders;

    if (isDraft) {
      method = '/v2/workorder/data/officePage';
      attributes = [
        'id',
        'type',
        'code',
        'service_catalog',
        'apply_user',
        'apply_description',
        'flow_status',
        'create_time',
        'classify',
        'dynamic_title',
        'start_time',
        'modify_time',
      ];
      filter = {
        'attribute': {
          'and': [
            {
              'simple': {
                'name': 'flow_status',
                'operator': 'eq',
                'value': 'NEW',
              }
            },
            {
              'simple': {
                'name': 'create_user',
                'operator': 'eq',
                'value': userId,
              }
            }
          ]
        },
        'query': '',
      };
      orders = [
        {'name': 'create_time', 'type': 'desc'}
      ];
    } else if (ongoing) {
      method = '/v2/service/portal/workorderData/ongoingPage';
      attributes = [
        'id',
        'type',
        'code',
        'service_catalog',
        'apply_user',
        'apply_description',
        'flow_status',
        'create_time',
        'start_time',
        'process',
        'process_instance_id',
        'classify',
        'dynamic_title',
      ];
      filter = {
        'attribute': {
          'and': [
            {
              'simple': {
                'name': 'id',
                'operator': 'in-lookup',
                'value': ['0', '1'],
              }
            },
            {
              'or': [
                {
                  'simple': {
                    'name': 'apply_user',
                    'operator': 'eq',
                    'value': userId,
                  }
                },
                {
                  'simple': {
                    'name': 'create_user',
                    'operator': 'eq',
                    'value': userId,
                  }
                }
              ]
            }
          ]
        },
        'query': '',
      };
      orders = [
        {'name': 'start_time', 'type': 'desc'}
      ];
    } else {
      method = '/v2/service/portal/workorderData/finishPage';
      attributes = [
        'id',
        'type',
        'code',
        'node_id',
        'node_name',
        'service_catalog',
        'apply_description',
        'flow_status',
        'start_time',
        'create_time',
        'close_time',
        'process',
        'process_instance_id',
        'classify',
        'dynamic_title',
      ];
      filter = {
        'attribute': {
          'and': [
            {
              'and': [
                {
                  'or': [
                    {
                      'simple': {
                        'name': 'flow_status',
                        'operator': 'ne',
                        'value': 'NEW',
                      }
                    },
                    {
                      'simple': {
                        'name': 'flow_status',
                        'operator': 'isnull',
                      }
                    }
                  ]
                },
                {
                  'simple': {
                    'name': 'apply_user',
                    'operator': 'eq',
                    'value': userId,
                  }
                }
              ]
            },
            {
              'simple': {'name': 'close_time', 'operator': 'isnotnull'}
            }
          ]
        },
        'query': '',
      };
      orders = [
        {'name': 'start_time', 'type': 'desc'}
      ];
    }

    final result = await _rpc(
      method,
      [
        '37ea4a70-af77-4c1a-9422-7582afc0de41',
        {
          'attributes': attributes,
          'filter': filter,
          'orders': orders,
          'pageSize': '$pageSize',
          'pageIndex': '$pageIndex',
        }
      ],
    );
    final data = result is Map ? result['data'] : null;
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => RepairOrder.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<RepairFormSession> loadForm(RepairCatalog catalog) async {
    final instanceId = await _rpc('/v2/cmdb/ci/id', []);
    final detail = await _rpc(
        '/v2/workorder/serviceitem/card/getMobileCatalogById', [catalog.id]);
    final formResult =
        await _rpc('/v2/workorder/view/form/getNotRelationOrderForm', [
      catalog.id,
      'apply',
      {'create_user': null, 'id': '$instanceId', 'service_catalog': catalog.id}
    ]);
    final actions = await _rpc('/v2/workorder/action/list', [
      await _rpc(
          '/v2/workorder/orderConfig/getNodeByServiceCatalog', [catalog.id]),
      ''
    ]);
    final form =
        formResult is List && formResult.isNotEmpty ? formResult.first : null;
    final construct = form is Map
        ? jsonDecode('${form['constructData'] ?? '{}'}')
        : <String, dynamic>{};
    final detailType = detail is Map && detail['type'] is Map
        ? (detail['type'] as Map)['id']
        : '';
    final ciType = '${construct['ciType'] ?? detailType}';
    final components = construct['components'] is List
        ? construct['components'] as List
        : <dynamic>[];
    final fields = <RepairField>[];
    void add(dynamic item) {
      if (item is! Map) return;
      final editor = '${item['editor'] ?? ''}';
      final name = '${item['name'] ?? ''}';
      if (name.isEmpty || editor == 'group' || editor == 'label') return;
      final validate =
          item['validate'] is Map ? item['validate'] as Map : const {};
      fields.add(RepairField(
          name: name,
          label: '${item['label'] ?? name}',
          editor: editor,
          required: item['required'] == true || validate['required'] == true,
          hidden: item['hidden'] == true,
          readonly: item['readonly'] == true,
          referenceType: item['referenceType']?.toString(),
          reference: item['reference']?.toString(),
          raw: item.cast<String, dynamic>()));
    }

    for (final item in components) {
      add(item);
    }
    final nodeId =
        '${await _rpc('/v2/workorder/orderConfig/getNodeByServiceCatalog', [
          catalog.id
        ])}';
    final actionList = actions is List ? actions : const [];
    final submit = actionList.whereType<Map>().firstWhere(
        (a) => '${a['name']}' == '提交' || '${a['display_name']}' == '提交',
        orElse: () => <String, dynamic>{'id': ''});
    final draft = actionList.whereType<Map>().firstWhere(
        (a) =>
            '${a['name']}'.contains('草稿') ||
            '${a['display_name']}'.contains('草稿'),
        orElse: () => <String, dynamic>{'id': ''});
    final rule =
        construct['rules'] is List && (construct['rules'] as List).isNotEmpty
            ? '${(construct['rules'] as List).first['rule_id']}'
            : null;
    final initial = <String, dynamic>{
      'id': '$instanceId',
      'type': ciType,
      'source': 'mobile',
      'priority_group': '2',
      'apply_user': _uid,
      'xm': auth.realName ?? '',
      'xgh': auth.username ?? ''
    };
    return RepairFormSession(
        catalog: catalog,
        instanceId: '$instanceId',
        ciType: ciType,
        nodeId: nodeId,
        submitActionId: '${submit['id'] ?? ''}',
        saveDraftActionId:
            '${draft['id'] ?? ''}'.isNotEmpty ? '${draft['id']}' : null,
        formRuleId: rule,
        fields: fields,
        initialValues: initial);
  }

  static RepairCatalog resolveCatalog(RepairOrder order) {
    if (order.catalogId.isNotEmpty) {
      final match = catalogs.where((c) => c.id == order.catalogId).firstOrNull;
      if (match != null) return match;
    }

    final processRaw = order.raw['process'];
    final processId = processRaw is Map ? '${processRaw['id'] ?? ''}' : '';
    if (processId.isNotEmpty) {
      final match = catalogs.where((c) => c.processId == processId).firstOrNull;
      if (match != null) return match;
    }

    final byCatalogTitle =
        catalogs.where((c) => c.title == order.catalog).firstOrNull;
    if (byCatalogTitle != null) return byCatalogTitle;

    final allText = [
      order.catalog,
      order.title,
      order.department,
      processRaw is Map ? '${processRaw['display_name'] ?? ''}' : '',
      order.raw['type'] is Map
          ? '${order.raw['type']['name_path'] ?? order.raw['type']['display_name'] ?? ''}'
          : '',
    ].join(' ');

    if (allText.contains('业务') || allText.contains('信息系统')) {
      return catalogs.firstWhere((c) => c.title == '业务系统报修');
    }
    if (allText.contains('一校通') || allText.contains('一卡通')) {
      return catalogs.firstWhere((c) => c.title == '一校通报修');
    }
    if (allText.contains('网络') || allText.contains('校园网')) {
      return catalogs.firstWhere((c) => c.title == '校园网络报修');
    }
    if (allText.contains('后勤')) {
      return catalogs.firstWhere((c) => c.title == '后勤报修');
    }

    return catalogs.first;
  }

  Future<RepairFormSession> loadDraftForm(RepairOrder order) async {
    final catalog = resolveCatalog(order);
    final session = await loadForm(catalog);

    final typeId = order.raw['type'] is Map
        ? '${(order.raw['type'] as Map)['id'] ?? ''}'
        : '${order.raw['type'] ?? order.raw['workorder_type'] ?? session.ciType}';

    Map<String, dynamic> draftData = {};
    if (order.id.isNotEmpty) {
      try {
        final res = await _rpc('/v2/workorder/data/getById', [
          typeId.isNotEmpty ? typeId : session.ciType,
          order.id,
        ]);
        if (res is Map) {
          draftData = res.cast<String, dynamic>();
        }
      } catch (_) {}
    }

    final existingValues = <String, dynamic>{
      ...session.initialValues,
      ...order.raw,
      ...draftData,
      'id': order.id,
      if (draftData['wtmsh'] != null)
        'wtmsh': draftData['wtmsh']
      else if (order.description.isNotEmpty)
        'wtmsh': order.description,
      if (draftData['bchshm'] != null)
        'bchshm': draftData['bchshm']
      else if (order.supplement.isNotEmpty)
        'bchshm': order.supplement,
    };
    return RepairFormSession(
      catalog: session.catalog,
      instanceId: order.id,
      ciType: session.ciType,
      nodeId: session.nodeId,
      submitActionId: session.submitActionId,
      saveDraftActionId: session.saveDraftActionId,
      formRuleId: session.formRuleId,
      fields: session.fields,
      initialValues: existingValues,
    );
  }

  Future<List<RepairChoice>> references(String type, {String query = ''}) async {
    dynamic result;
    try {
      result = await _rpc('/v2/cmdb/ci/page', [
        type,
        {
          'pageSize': 100,
          'pageIndex': 1,
          'orders': [
            {'name': 'display_name', 'type': 'asc'}
          ],
          'filter': {'query': query}
        }
      ]);
    } catch (_) {
      try {
        result = await _rpc('/v2/cmdb/ci/list', [
          type,
          {
            'attributes': ['id', 'display_name', 'name'],
            'orders': [
              {'name': 'display_name', 'type': 'asc'}
            ],
            'filter': {}
          }
        ]);
      } catch (_) {
        return [];
      }
    }

    List list = [];
    if (result is Map && result['data'] is List) {
      list = result['data'] as List;
    } else if (result is List) {
      list = result;
    }

    return list
        .whereType<Map>()
        .map((e) => RepairChoice(
            '${e['id'] ?? ''}', '${e['display_name'] ?? e['name'] ?? ''}'))
        .where((e) => e.id.isNotEmpty && e.label.isNotEmpty)
        .take(100)
        .toList();
  }

  Future<List<RepairChoice>> lookup(
    String lookupType, {
    List<String>? notInNames,
  }) async {
    try {
      final andList = <Map<String, dynamic>>[
        {
          'simple': {
            'name': 'lookup_type',
            'operator': 'eq',
            'value': lookupType,
          }
        },
        if (notInNames != null && notInNames.isNotEmpty)
          {
            'simple': {
              'name': 'name',
              'operator': 'notin',
              'value': notInNames,
            }
          },
      ];

      final result = await _rpc('/v2/cmdb/meta/lookup/page', [
        {
          'orders': [
            {'name': 'index', 'type': 'asc'}
          ],
          'filter': {
            'attribute': {
              'and': andList,
            },
            'query': '',
          },
          'pageSize': 20,
          'pageIndex': 1,
        }
      ]);
      final data = result is Map ? result['data'] : null;
      if (data is! List) return [];
      return data
          .whereType<Map>()
          .map((e) => RepairChoice('${e['name'] ?? e['id']}',
              '${e['display_name'] ?? e['name'] ?? ''}'))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static int? parseDateToTimestamp(dynamic val) {
    if (val == null) return null;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is DateTime) return val.millisecondsSinceEpoch;
    final str = val.toString().trim();
    if (str.isEmpty) return null;
    final asInt = int.tryParse(str);
    if (asInt != null) return asInt;

    final parts = str.split(RegExp(r'[/ -]'));
    if (parts.length >= 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) {
        int hour = 0;
        int minute = 0;
        int second = 0;
        if (parts.length >= 4) hour = int.tryParse(parts[3]) ?? 0;
        if (parts.length >= 5) minute = int.tryParse(parts[4]) ?? 0;
        if (parts.length >= 6) second = int.tryParse(parts[5]) ?? 0;
        return DateTime(y, m, d, hour, minute, second).millisecondsSinceEpoch;
      }
    }
    final iso = str.replaceAll('/', '-');
    final dt = DateTime.tryParse(iso);
    if (dt != null) return dt.millisecondsSinceEpoch;
    return null;
  }

  Future<String> submit(
    RepairFormSession session,
    Map<String, dynamic> values, {
    bool isDraft = false,
  }) async {
    final actionId = isDraft
        ? (session.saveDraftActionId ?? session.submitActionId)
        : session.submitActionId;

    final data = {...session.initialValues};
    for (final field in session.fields) {
      data.putIfAbsent(field.name, () => field.isUpload ? 0 : null);
    }
    data.addAll(values);

    final dateFieldNames = {
      for (final f in session.fields)
        if (f.isDate) f.name
    };

    final sanitizedData = <String, dynamic>{};
    for (final entry in data.entries) {
      final key = entry.key;
      final val = entry.value;

      if (dateFieldNames.contains(key) ||
          key == 'yyrq' ||
          key.toLowerCase().contains('date')) {
        if (val == null || (val is String && val.trim().isEmpty)) {
          sanitizedData[key] = null;
        } else {
          sanitizedData[key] = parseDateToTimestamp(val) ?? val;
        }
        continue;
      }

      if (val is Map && val.containsKey('id') && val['id'] is String) {
        sanitizedData[key] = val['id'];
      } else {
        sanitizedData[key] = val;
      }
    }
    final params = [
      actionId,
      [
        {
          'id': session.instanceId,
          'type': session.ciType,
          'node': session.nodeId
        },
        sanitizedData,
        {'service_catalog': session.catalog.id},
      ],
      if (session.formRuleId != null) [session.formRuleId]
    ];
    final result =
        await _rpc('/v2/workorder/action/executeWithValidate', params);
    if (result is Map && result['state'] == true) return 'ok';
    throw RepairException(isDraft ? '保存草稿失败，请稍后重试' : '提交失败，请检查必填项后重试');
  }

  Future<RepairAttachment> uploadAttachment(
    RepairFormSession session,
    RepairField field,
    File file,
  ) async {
    await _ensureRepairSession();

    final fileName = file.path.split(Platform.pathSeparator).last;
    final instance = '${session.instanceId}-${field.name}';
    final formData = FormData.fromMap({
      'uploadFile': await MultipartFile.fromFile(
        file.path,
        filename: fileName,
      ),
      'fileName': 'uploadFile',
      'subsystem': 'eui',
      'instance': instance,
    });

    final tm = DateTime.now().millisecondsSinceEpoch;
    final url = '$baseUrl/relax/mobile/rpc?tm=$tm&method=/v2/file/upload';

    final response = await _dio.post(
      url,
      data: formData,
      options: Options(
        headers: {
          'Origin': baseUrl,
          'Referer': '$baseUrl/relax/mobile/index.html',
          'X-Requested-With': 'XMLHttpRequest',
        },
      ),
    );

    dynamic resData = response.data;
    if (resData is String) {
      try {
        resData = jsonDecode(resData);
      } catch (_) {}
    }

    if (resData is! Map) {
      throw const RepairException('上传附件失败，服务器未返回有效数据');
    }

    final attachment =
        RepairAttachment.fromJson(resData.cast<String, dynamic>());

    // 记录节点上传附件活动日志并建立关联 (与 HAR 抓包中 Entry 12 & 13 一致)
    try {
      final user = auth.realName ?? '用户';
      final logRes = await _rpc('/v2/cmdb/ci/create', [
        {
          'type': '737fb2a0-a9a5-41fd-b36f-d32d604e2128',
          'create_user': _uid,
          'description':
              '$user在“开始“节点，上传附件\$\$"${attachment.fileName}"\$\$<<rpc?method=/v2/file/download&id=${attachment.id}>>',
        }
      ]);
      if (logRes != null) {
        final logId = '$logRes';
        await _rpc('/v2/cmdb/relation/create', [
          {
            'type': '42e2bb1d-2d74-4cc7-a53b-ba5413b14792',
            'source': session.instanceId,
            'destination': logId,
          }
        ]);
      }
    } catch (_) {}

    return attachment;
  }

  Future<void> deleteAttachment(String fileId) async {
    await _ensureRepairSession();
    try {
      await _rpc('/v2/file/deleteById', [fileId]);
    } catch (e) {
      throw RepairException('删除附件失败: $e');
    }
  }

  Future<List<RepairAttachment>> fetchDraftAttachments(
    String instanceId,
    String fieldName,
  ) async {
    await _ensureRepairSession();
    try {
      final res = await _rpc('/v2/file/list', [
        {
          'filter': {
            'attribute': {
              'simple': {
                'name': 'instance',
                'operator': 'eq',
                'value': '$instanceId-$fieldName',
              }
            }
          },
          'orders': [
            {'name': 'create_time', 'type': 'asc'}
          ]
        }
      ]);
      if (res is List) {
        return res
            .whereType<Map>()
            .map((e) => RepairAttachment.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<RepairOrder> fetchOrderDetail(RepairOrder order) async {
    await _ensureRepairSession();

    final typeId = order.raw['type'] is Map
        ? '${(order.raw['type'] as Map)['id'] ?? ''}'
        : '${order.raw['type'] ?? order.raw['workorder_type'] ?? ''}';

    // 1. 获取工单主体详情字段
    Map<String, dynamic> detailMap = {};
    try {
      final res = await _rpc('/v2/workorder/data/getById', [typeId, order.id]);
      if (res is Map) {
        detailMap = res.cast<String, dynamic>();
      }
    } catch (_) {}

    // 2. 获取当前节点 ID
    String? nodeId;
    try {
      final res =
          await _rpc('/v2/workorder/orderConfig/getNodeByOrder', [order.id]);
      if (res != null) {
        nodeId = '$res';
      }
    } catch (_) {}

    // 3. 获取可用动作列表（如取消报修）
    List<RepairAction> actions = [];
    if (nodeId != null && nodeId.isNotEmpty) {
      try {
        final res = await _rpc('/v2/workorder/action/list', [nodeId, order.id]);
        if (res is List) {
          actions = res
              .whereType<Map>()
              .map((e) => RepairAction.fromJson(e.cast<String, dynamic>()))
              .toList();
        }
      } catch (_) {}
    }

    // 4. 获取流转活动历史记录
    List<RepairActivityLog> logs = [];
    try {
      final res = await _rpc('/v2/cmdb/ci/list', [
        '737fb2a0-a9a5-41fd-b36f-d32d604e2128',
        {
          'filter': {
            'relation': [
              {
                'ids': [order.id],
                'relationType': '42e2bb1d-2d74-4cc7-a53b-ba5413b14792',
                'type': 'oneof',
              }
            ]
          },
          'orders': [
            {'name': 'create_time', 'type': 'desc'}
          ],
        }
      ]);
      if (res is List) {
        logs = res
            .whereType<Map>()
            .map((e) => RepairActivityLog.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
    } catch (_) {}

    // 5. 获取附件列表
    List<RepairAttachment> attachments = [];
    try {
      final res = await _rpc('/v2/file/list', [
        {
          'filter': {
            'attribute': {
              'simple': {
                'name': 'instance',
                'operator': 'eq',
                'value': '${order.id}-scwttp',
              }
            }
          },
          'orders': [
            {'name': 'create_time', 'type': 'desc'}
          ],
        }
      ]);
      if (res is List) {
        attachments = res
            .whereType<Map>()
            .map((e) => RepairAttachment.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
    } catch (_) {}

    final merged = {
      ...order.raw,
      ...detailMap,
      if (nodeId != null) 'node_id': nodeId,
    };

    return RepairOrder.fromJson(
      merged,
      logs: logs,
      attachments: attachments,
      actions: actions,
    );
  }

  Future<bool> executeAction(
    RepairOrder order,
    RepairAction action, {
    Map<String, dynamic>? extraValues,
  }) async {
    await _ensureRepairSession();

    final typeId = order.raw['type'] is Map
        ? '${(order.raw['type'] as Map)['id'] ?? ''}'
        : '${order.raw['type'] ?? order.raw['workorder_type'] ?? ''}';

    final catalogId = order.raw['service_catalog'] is Map
        ? '${(order.raw['service_catalog'] as Map)['id'] ?? ''}'
        : '${order.raw['service_catalog'] ?? ''}';

    final dataPayload = <String, dynamic>{
      'id': order.id,
      'type': typeId,
      'source': 'mobile',
      'priority_group': order.raw['priority_group'] is Map
          ? (order.raw['priority_group'] as Map)['name'] ?? '2'
          : '${order.raw['priority_group'] ?? '2'}',
      'xm':
          order.applicant.isNotEmpty ? order.applicant : (auth.realName ?? ''),
      'xgh': order.raw['xgh'] ?? auth.username ?? '',
      'lxfs': order.phone,
      if (order.description.isNotEmpty) 'wtmsh': order.description,
      if (order.supplement.isNotEmpty) 'bchshm': order.supplement,
      ...?extraValues,
    };

    final node = action.possessorNode.isNotEmpty
        ? action.possessorNode
        : '${order.raw['node_id'] ?? order.statusId}';

    final params = [
      action.id,
      [
        {
          'id': order.id,
          'type': typeId,
          'node': node,
        },
        dataPayload,
        {
          'service_catalog': catalogId,
        }
      ],
      [],
    ];

    final result =
        await _rpc('/v2/workorder/action/executeWithValidate', params);
    if (result is Map && result['state'] == true) {
      return true;
    }
    final msg = result is Map && result['error'] != null
        ? '${result['error']}'
        : '操作执行失败，请稍后重试';
    throw RepairException(msg);
  }

  Future<bool> cancelOrder(RepairOrder order, {RepairAction? action}) async {
    final act = action ??
        order.actions.firstWhere(
          (a) => a.isCancel,
          orElse: () => throw const RepairException('当前环节不支持取消报修'),
        );
    return executeAction(order, act);
  }
}
