import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/network/dio_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../xgxt/services/xgxt_login_service.dart';
import '../models/questionnaire_models.dart';

final questionnaireServiceProvider = Provider((ref) => QuestionnaireService(
      reauthenticate: ref.read(authServiceProvider).silentLogin,
    ));

class QuestionnaireException implements Exception {
  final String message;
  const QuestionnaireException(this.message);
  @override
  String toString() => message;
}

/// 学工问卷服务
///
/// 接口及字段来自 `问卷xgxt.hunau.edu.cn.har`:
/// - 列表: GET content/tabledata/fwk/wjdc/stu/xs_wjdc (aaData)
/// - 详情: GET content/json/fwk/wjdc/stu/ks_sj/sjvo?tasktime=xxx (stList)
/// - 提交: POST content/fwk/wjdc/stu/ks_sj/submit (form: <题dm>=<选项dm/文本>&ks_jgdm=...)
class QuestionnaireService {
  final Dio? _client;
  final Future<void> Function()? _reauthenticate;
  final XgxtLoginService _xgxtLogin = XgxtLoginService();

  QuestionnaireService({
    Dio? dio,
    Future<void> Function()? reauthenticate,
  })  : _client = dio,
        _reauthenticate = reauthenticate;

  Dio get _dio => _client ?? DioClient().dio;

  /// 业务接口正常只返回 JSON。关闭自动跟随,会话失效时的 302 跳 SSO
  /// 能被显式识别,而不是被跟进登录页后抛 JSON 解码异常。
  Options _apiOptions() => Options(
        responseType: ResponseType.plain,
        followRedirects: false,
        validateStatus: (status) => status != null && status < 500,
        headers: {
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'X-Requested-With': 'XMLHttpRequest',
          'Referer': '${AppConstants.xgxtBaseUrl}/wap/menu/fwk/wjdc/stu/xs_wjdc',
        },
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
        throw const QuestionnaireException('统一认证已过期,请返回个人中心重新登录');
      }
    }
    try {
      await _xgxtLogin.performXgxtCasLogin();
    } on NetworkException catch (e) {
      throw QuestionnaireException(e.message);
    } catch (_) {
      throw const QuestionnaireException('学工系统登录已失效,请返回个人中心重新登录后重试');
    }
  }

  Map<String, dynamic> _asObject(Response response) {
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        // 落到登录页 HTML 等非 JSON:直接报业务异常,由上层提示。
      }
    }
    throw const QuestionnaireException('未能读取问卷数据,请检查登录状态后重试');
  }

  /// 问卷列表
  Future<List<QuestionnaireItem>> fetchList() async {
    final response = await _withXgxtAuth(() => _dio.get(
          AppConstants.xgxtQuestionnaireListUrl,
          queryParameters: {
            'bSortable_0': 'false',
            'bSortable_1': 'false',
            'iSortingCols': '1',
            'iDisplayStart': '0',
            'iDisplayLength': '50',
            'iSortCol_0': '3',
            'sSortDir_0': 'desc',
            '_t_s_': DateTime.now().millisecondsSinceEpoch.toString(),
          },
          options: _apiOptions(),
        ));
    final data = _asObject(response);
    final rows = data['aaData'];
    if (rows is! List) {
      throw const QuestionnaireException('问卷列表数据格式异常');
    }
    return rows
        .whereType<Map<String, dynamic>>()
        .map(QuestionnaireItem.fromJson)
        .toList();
  }

  /// 问卷详情(含题目), taskTimeM 来自列表项的 TASK_TIME_M。
  Future<QuestionnaireDetail> fetchDetail(QuestionnaireItem item) async {
    if (item.taskTimeM.isEmpty) {
      throw const QuestionnaireException('该问卷缺少任务标识,无法打开');
    }
    final response = await _withXgxtAuth(() => _dio.get(
          AppConstants.xgxtQuestionnaireDetailUrl,
          queryParameters: {
            'tasktime': item.taskTimeM,
            'busType': '',
            '_t_s_': DateTime.now().millisecondsSinceEpoch.toString(),
          },
          options: _apiOptions(),
        ));
    return QuestionnaireDetail.fromJson(_asObject(response));
  }

  /// 提交问卷。不自动重试写入,避免重复投递。
  /// [answers] key 为题目 dm, choice 题 value 为选项 dm(多选为 List<String>),填空题 value 为文本。
  Future<void> submit({
    required QuestionnaireDetail detail,
    required Map<String, dynamic> answers,
  }) async {
    // 手工拼 form body,多选题同一 key 重复出现多次,与浏览器抓包一致。
    final pairs = <String>[];
    void add(String key, String value) {
      pairs.add(
          '${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(value)}');
    }

    for (final question in detail.questions) {
      final value = answers[question.dm];
      if (value is List) {
        if (value.isEmpty) {
          add(question.dm, '');
        } else {
          for (final item in value) {
            add(question.dm, item.toString());
          }
        }
      } else {
        add(question.dm, value?.toString() ?? '');
      }
    }
    add('ks_jgdm', detail.jgM);
    add('wzDz', '');
    add('wzZb', '');
    add('wzLy', '');
    add('operationType', '');

    final response = await _withXgxtAuth(() => _dio.post(
          AppConstants.xgxtQuestionnaireSubmitUrl,
          queryParameters: {
            '_t_s_': DateTime.now().millisecondsSinceEpoch.toString(),
          },
          data: pairs.join('&'),
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            responseType: ResponseType.plain,
            followRedirects: false,
            validateStatus: (status) => status != null && status < 500,
            headers: {
              'Accept': 'application/json, text/javascript, */*; q=0.01',
              'X-Requested-With': 'XMLHttpRequest',
              'Referer':
                  '${AppConstants.xgxtBaseUrl}/wap/menu/fwk/wjdc/stu/xs_wjdc',
            },
          ),
        ));

    final data = _asObject(response);
    if (data['result'] != true) {
      final errors = data['errorInfoList'];
      if (errors is List && errors.isNotEmpty) {
        throw QuestionnaireException(errors.first.toString());
      }
      throw QuestionnaireException(data['msg']?.toString() ?? '提交失败,请稍后重试');
    }
  }
}
