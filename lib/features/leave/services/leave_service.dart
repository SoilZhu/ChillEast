import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/network/dio_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../xgxt/services/xgxt_login_service.dart';
import '../models/leave_models.dart';

final leaveServiceProvider = Provider((ref) => LeaveService(
      reauthenticate: ref.read(authServiceProvider).silentLogin,
    ));

class LeaveException implements Exception {
  final String message;
  const LeaveException(this.message);
  @override
  String toString() => message;
}

/// 请假申请服务
///
/// 接口及字段来自 `请假xgxt.hunau.edu.cn.har` 与提交 cURL:
/// - 类别字典: GET content/json/selects?name=MsDict&paramValue=DM_SF_QJLX
/// - 省市县: GET content/json/selects/wap/ssx?xian_allow_empty=0
/// - 算时长: GET content/student/leave/calculate?kssj=..&jssj=..
/// - 列表: GET content/tabledata/student/leave/apply_stu (aaData)
/// - 单条: GET content/student/leave/apply_stu/{id}
/// - 提交: POST content/student/leave/apply_stu (无附件 urlencoded,有附件 multipart)
/// - 撤销: POST content/student/leave/apply_stu/del (dm=ID) -> true
class LeaveService {
  final Dio? _client;
  final Future<void> Function()? _reauthenticate;
  final XgxtLoginService _xgxtLogin = XgxtLoginService();

  LeaveService({
    Dio? dio,
    Future<void> Function()? reauthenticate,
  })  : _client = dio,
        _reauthenticate = reauthenticate;

  Dio get _dio => _client ?? DioClient().dio;

  Map<String, String> get _headers => {
        'Accept': '*/*',
        'X-Requested-With': 'XMLHttpRequest',
        'Referer':
            '${AppConstants.xgxtBaseUrl}/wap/menu/student/leave/qjsq',
      };

  Options _plainOptions() => Options(
        responseType: ResponseType.plain,
        followRedirects: false,
        validateStatus: (status) => status != null && status < 500,
        headers: _headers,
      );

  bool _needsRelogin(Response response) {
    final status = response.statusCode ?? 0;
    if (status == 301 ||
        status == 302 ||
        status == 303 ||
        status == 307 ||
        status == 308) {
      return true;
    }
    final data = response.data;
    if (data is String) {
      final head = data.length > 2048 ? data.substring(0, 2048) : data;
      if (head.contains('<html') || head.contains('cas/login')) return true;
    }
    return false;
  }

  /// 会话失效时走一次 XGXT CAS 重登,最多重试一次。
  Future<Response> _withXgxtAuth(Future<Response> Function() task) async {
    var response = await task();
    if (_needsRelogin(response)) {
      await _relogin();
      response = await task();
    }
    return response;
  }

  Future<void> _relogin() async {
    final reauthenticate = _reauthenticate;
    if (reauthenticate != null) {
      try {
        await reauthenticate();
      } catch (_) {
        throw const LeaveException('统一认证已过期,请返回个人中心重新登录');
      }
    }
    try {
      await _xgxtLogin.performXgxtCasLogin();
    } on NetworkException catch (e) {
      throw LeaveException(e.message);
    } catch (_) {
      throw const LeaveException('学工系统登录已失效,请返回个人中心重新登录后重试');
    }
  }

  dynamic _asJson(Response response) {
    final data = response.data;
    if (data is String) {
      try {
        return jsonDecode(data);
      } catch (_) {}
    } else if (data is! String) {
      return data;
    }
    throw const LeaveException('未能读取请假数据,请检查登录状态后重试');
  }

  Map<String, dynamic> _asObject(Response response) {
    final decoded = _asJson(response);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const LeaveException('请假数据格式异常');
  }

  String _stamp() => DateTime.now().millisecondsSinceEpoch.toString();

  /// 请假类别（事假/病假）
  Future<List<LeaveDictItem>> fetchTypes() async {
    final response = await _withXgxtAuth(() => _dio.get(
          AppConstants.leaveDictUrl,
          queryParameters: {
            'name': 'MsDict',
            'paramValue': 'DM_SF_QJLX',
            '_t_s_': _stamp(),
          },
          options: _plainOptions(),
        ));
    final decoded = _asJson(response);
    if (decoded is! List) throw const LeaveException('请假类别数据格式异常');
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(LeaveDictItem.fromJson)
        .toList();
  }

  /// 省市县三级树（一次全量）
  Future<List<RegionNode>> fetchRegions() async {
    final response = await _withXgxtAuth(() => _dio.get(
          AppConstants.leaveRegionUrl,
          queryParameters: {
            'xian_allow_empty': '0',
            '_t_s_': _stamp(),
          },
          options: _plainOptions(),
        ));
    final decoded = _asJson(response);
    if (decoded is! List) throw const LeaveException('地区数据格式异常');
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(RegionNode.fromJson)
        .toList();
  }

  /// 按起止时间算时长，时间格式 yyyy-MM-dd HH:mm
  Future<LeaveDuration> calculate(String start, String end) async {
    final response = await _withXgxtAuth(() => _dio.get(
          AppConstants.leaveCalculateUrl,
          queryParameters: {
            'kssj': start,
            'jssj': end,
            '_t_s_': _stamp(),
          },
          options: _plainOptions(),
        ));
    return LeaveDuration.fromJson(_asObject(response));
  }

  /// 请假记录列表
  Future<List<LeaveRecord>> fetchList() async {
    final response = await _withXgxtAuth(() => _dio.get(
          AppConstants.leaveListUrl,
          queryParameters: {
            'bSortable_0': 'false',
            'bSortable_1': 'false',
            'iSortingCols': '1',
            'iDisplayStart': '0',
            'iDisplayLength': '50',
            'iSortCol_0': '3',
            'sSortDir_0': 'desc',
            '_t_s_': _stamp(),
          },
          options: _plainOptions(),
        ));
    final data = _asObject(response);
    final rows = data['aaData'];
    if (rows is! List) throw const LeaveException('请假列表数据格式异常');
    return rows
        .whereType<Map<String, dynamic>>()
        .map(LeaveRecord.fromJson)
        .toList();
  }

  /// 单条请假单（详情/回填）
  Future<LeaveDetail> fetchRecord(String id) async {
    if (id.isEmpty) throw const LeaveException('缺少请假单标识');
    final response = await _withXgxtAuth(() => _dio.get(
          '${AppConstants.leaveApplyUrl}/$id',
          queryParameters: {'_t_s_': _stamp()},
          options: _plainOptions(),
        ));
    return LeaveDetail.fromJson(_asObject(response));
  }

  /// 提交请假单。无附件用 urlencoded（与抓包一致），有附件用 multipart。
  /// [fields] 文本字段（含 qjlxM.dm/qjlx/kssj/jssj/ts/jsTs/hour/jsHour/qjsy/
  /// lxr/lxrdh/txry/lxInd/lxqx.dm/lxqx1/lxMdd/huisusheInd/lxBz/chushiInd/
  /// chushengInd/sjhdlsM/qjLocation/qjLocationZb/operationType/id 等）。
  /// 不自动重试写入，避免重复提交。
  Future<void> submit({
    required Map<String, String> fields,
    String? attachmentPath,
  }) async {
    final attachment = attachmentPath;
    final hasFile = attachment != null && attachment.isNotEmpty;
    final data = hasFile
        ? FormData.fromMap({
            ...fields,
            'pathFile': await MultipartFile.fromFile(attachment,
                filename: attachment.split('/').last),
          })
        : fields;

    final response = await _withXgxtAuth(() => _dio.post(
          AppConstants.leaveApplyUrl,
          queryParameters: {'_t_s_': _stamp()},
          data: data,
          options: Options(
            responseType: ResponseType.plain,
            followRedirects: false,
            validateStatus: (status) => status != null && status < 500,
            contentType: hasFile
                ? Headers.multipartFormDataContentType
                : Headers.formUrlEncodedContentType,
            headers: _headers,
          ),
        ));

    final result = _asObject(response);
    if (result['result'] != true) {
      final errors = result['errorInfoList'];
      if (errors is List && errors.isNotEmpty) {
        throw LeaveException(errors.first.toString());
      }
      throw LeaveException(result['msg']?.toString() ?? '提交失败,请稍后重试');
    }
  }

  /// 撤销待审核请假单
  Future<void> delete(String id) async {
    final response = await _withXgxtAuth(() => _dio.post(
          AppConstants.leaveDeleteUrl,
          queryParameters: {'_t_s_': _stamp()},
          data: {'dm': id},
          options: Options(
            responseType: ResponseType.plain,
            followRedirects: false,
            validateStatus: (status) => status != null && status < 500,
            contentType: Headers.formUrlEncodedContentType,
            headers: _headers,
          ),
        ));
    final decoded = _asJson(response);
    if (decoded != true) {
      throw LeaveException(
          decoded is Map<String, dynamic> && decoded['msg'] != null
              ? decoded['msg'].toString()
              : '撤销失败,该请假单可能已进入审核');
    }
  }
}
