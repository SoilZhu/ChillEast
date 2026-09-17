import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:fast_gbk/fast_gbk.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/sunshine_models.dart';

final sunshineServiceProvider = Provider((ref) => SunshineService(
      reauthenticate: ref.read(authServiceProvider).silentLogin,
    ));

class SunshineException implements Exception {
  final String message;
  const SunshineException(this.message);
  @override
  String toString() => message;
}

/// 接口及字段来自阳光服务 HAR 内的请求和 form.aspx 页面脚本。
class SunshineService {
  final Dio? _client;
  final Future<void> Function()? _reauthenticate;

  SunshineService({
    Dio? dio,
    Future<void> Function()? reauthenticate,
  })  : _client = dio,
        _reauthenticate = reauthenticate;
  Dio get _dio => _client ?? DioClient().dio;
  static const baseUrl = 'https://sun.hunau.edu.cn';
  static const authorizationUrl =
      'https://sso.hunau.edu.cn/cas/oauth2.0/authorize?response_type=code&client_secret=trusfort&client_id=yg1000002&redirect_uri=http://sun.hunau.edu.cn/OAuthLogin.aspx';

  Options get _options => Options(
        responseType: ResponseType.plain,
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          'Referer': '$baseUrl/form.aspx?type=2',
          'X-Requested-With': 'XMLHttpRequest'
        },
        responseDecoder: _decodeGbk,
      );

  Map<String, dynamic> _object(Response response) {
    if (response.statusCode != 200) {
      throw const SunshineException('阳光服务暂时不可用，请稍后重试');
    }
    try {
      final data =
          response.data is String ? jsonDecode(response.data) : response.data;
      if (data is Map<String, dynamic>) return data;
    } catch (_) {
      // HTML 登录页、服务器错误页不能当作空列表。
    }
    throw const SunshineException('未能读取阳光服务数据，请检查登录状态后重试');
  }

  List<Map<String, dynamic>> _rows(Response response) {
    final rows = _object(response)['rows'];
    if (rows is! List || rows.any((row) => row is! Map<String, dynamic>)) {
      throw const SunshineException('阳光服务返回的数据格式异常');
    }
    return rows.cast<Map<String, dynamic>>();
  }

  Future<SunshineStatistics> fetchStatistics() async {
    final response = await _dio.post('$baseUrl/AJAX/index.ashx',
        queryParameters: {'AFlag': 'Statistics'}, options: _options);
    return SunshineStatistics.fromJson(_object(response));
  }

  Future<List<SunshineLetter>> fetchLetters() async {
    final response = await _dio.post('$baseUrl/AJAX/index.ashx',
        data: {'AFlag': 'Suggestion'}, options: _options);
    return _rows(response).map(SunshineLetter.fromJson).toList();
  }

  String _decodeGbk(
    List<int> responseBytes,
    RequestOptions options,
    ResponseBody responseBody,
  ) {
    try {
      return gbk.decode(responseBytes);
    } catch (_) {
      return utf8.decode(responseBytes, allowMalformed: true);
    }
  }

  Future<SunshineIdentity?> _fetchIdentity() async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await _dio.get(
          '$baseUrl/form.aspx',
          queryParameters: {'type': '2'},
          options: Options(
            responseType: ResponseType.plain,
            receiveTimeout: const Duration(seconds: 30),
            followRedirects: false,
            validateStatus: (status) => status != null && status < 500,
            // 该旧 ASP.NET 站点在 OAuth 跳转后偶尔留下不可复用连接。
            persistentConnection: false,
            headers: {'Connection': 'close'},
            responseDecoder: _decodeGbk,
          ),
        );
        if (response.statusCode != 200) return null;
        return SunshineIdentity.fromHtml(response.data.toString());
      } on DioException catch (error) {
        final retryable = error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.connectionError;
        if (!retryable) rethrow;
        if (attempt == 1) {
          throw const SunshineException('阳光服务表单响应超时，请稍后重试');
        }
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
    }
    return null;
  }

  Future<void> _authorize() async {
    var currentUri = Uri.parse(authorizationUrl);
    for (var i = 0; i < 8; i++) {
      final response = await _dio.get(
        currentUri.toString(),
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final location = response.headers.value(HttpHeaders.locationHeader);
      if (location == null || location.isEmpty) {
        break;
      }

      var nextUri = currentUri.resolve(location);
      if (nextUri.scheme == 'http' && nextUri.host == 'sun.hunau.edu.cn') {
        nextUri = nextUri.replace(scheme: 'https');
      }
      if (nextUri == currentUri) {
        break;
      }
      currentUri = nextUri;
    }
  }

  Future<SunshineFormData> fetchForm() async {
    var identity = await _fetchIdentity();
    if (identity == null) {
      // 优先复用现有 TGC，避免每次进入填报页都重新认证。
      await _authorize();
      identity = await _fetchIdentity();
    }
    final reauthenticate = _reauthenticate;
    if (identity == null && reauthenticate != null) {
      // 融合门户会话仍可能有效，但 SSO 的 TGC 已过期。此时使用用户已保存
      // 的凭据刷新完整 SSO 会话，再重新进行阳光服务 OAuth 授权。
      try {
        await reauthenticate();
      } catch (_) {
        throw const SunshineException('统一认证已过期，请返回个人中心重新登录');
      }
      await _authorize();
      identity = await _fetchIdentity();
    }
    if (identity == null) {
      throw const SunshineException('阳光服务登录已失效，请返回个人中心重新登录后重试');
    }
    final response = await _dio.post('$baseUrl/AJAX/form.ashx',
        data: {'AFlag': 'LoadCompany'}, options: _options);
    final departments = _rows(response)
        .map(SunshineDepartment.fromJson)
        .where((item) => item.code.isNotEmpty && item.name.isNotEmpty)
        .toList();
    if (departments.isEmpty) throw const SunshineException('暂无可用受理单位，请稍后重试');
    return SunshineFormData(identity, departments);
  }

  /// 不自动重试写入。响应未知时由用户到官网核实，避免重复投递。
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
    final response = await _dio.post('$baseUrl/AJAX/form.ashx',
        queryParameters: {'AFlag': 'insert'},
        data: {
          'type1': type,
          'depid': department.code,
          'depname': department.name,
          'title': title.trim(),
          'content': content.trim(),
          'username': identity.name,
          'telphone': phone.trim(),
          'email': email.trim(),
          'finishtime': finishTime,
          'captchas': '',
          'CardCode': identity.cardCode,
        },
        options: _options.copyWith(followRedirects: false));
    if (response.statusCode != 200) return 'unknown';
    final result = response.data.toString().trim();
    return ['1', '2', 'errer'].contains(result) ? result : 'unknown';
  }
}
