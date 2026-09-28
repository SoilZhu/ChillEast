import 'dart:convert';
import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/utils/app_logger.dart';

/// 学习通云盘操作异常
class CloudiskException implements Exception {
  final String message;
  const CloudiskException(this.message);
  @override
  String toString() => 'CloudiskException: $message';
}

/// 会话失效（需重新登录超星）
class CloudiskAuthException extends CloudiskException {
  const CloudiskAuthException(super.message);
}

/// 学习通云盘（pan-yz.cldisk.com）HTTP 封装。
///
/// 链路（见 debug/学习通网盘/*.har）：
/// 1. SSO：GET 首页后手动跟随 302（redirectWithCookies → writecookies → ?_puid）。
///    `pan-yz.chaoxing.com` 所需 Cookie 已由 HttpLoginService 在 portal/login6
///    链路中取得并保存到共享 CookieJar，直接复用，不复制或伪造 Cookie。
/// 2. 列表：GET /opt/listres（enc 必填，来自首页）。
/// 3. 上传：GET generateUploadUrl 取服务端签名 URL → multipart POST 文件。
/// 4. 删除：POST /opt/delres。
class CloudiskService {
  static const String host = 'https://pan-yz.cldisk.com';
  static const String schoolFid = '128516';
  static const String appId = '3F6410F7-344C-48C3-BC43-168936D1074B';
  static const String uploadPageUrl =
      '$host/pcuserpan/upload?bigFile=0&yunpanFidEnc=&barrierFree=false&isSuperstarfirefly=';

  final _logger = AppLogger.instance;
  CloudiskSession? _session;

  Dio get _dio => DioClient().dio;

  /// 首页 HTML → 会话常量。解析不到视为未登录/会话失效。
  ///
  /// 注意：首页模板里有 `var p_auth_token = ""`、`cx_p_token = "..."`、
  /// `<a href="...?p_auth_token=">` 等干扰串，都以 `_token` 结尾。
  /// 必须用 `\b` 词边界避免把 `p_auth_token` 误认成 `_token`
  ///（`_` 是单词字符，`h` 与 `_` 之间无边界，正好排除），
  /// 再取最后一个非空命中（真正的 `const _token = "32位hex"` 在文末 script）。
  static CloudiskSession parseSession(String html) {
    String? pick(String name) {
      final hits = RegExp(
        '(?:(?:const|var)\\s+)?\\b$name\\s*=\\s*"([^"]*)"',
      ).allMatches(html);
      String? last;
      for (final m in hits) {
        final v = m.group(1);
        if (v != null && v.isNotEmpty) last = v;
      }
      return last;
    }

    final enc = pick('encstr');
    final root = pick('rootdir');
    final puid = pick('currentPuid');
    final token = pick('_token');
    if (enc == null || root == null || puid == null || token == null) {
      throw const CloudiskAuthException('云盘会话失效，请重新登录');
    }
    return CloudiskSession(
      puid: puid,
      rootDirId: root,
      enc: enc,
      token: token,
    );
  }

  /// 丢弃首页解析出的会话参数，下次请求重新走 SSO。
  void invalidateSession() => _session = null;

  /// 确保会话有效（内存缓存，失败时由调用方触发静默重登后 forceRefresh）。
  ///
  /// SSO 链（见 debug/学习通网盘/*.har）：
  /// GET pan-yz.cldisk.com/ → 302 pan-yz.chaoxing.com/redirectWithCookies
  ///   → 302 pan-yz.cldisk.com/writecookies（Set-Cookie 落盘 11 件套）
  ///   → 302 /?_puid=…&p_auth_token=… → 200 首页 HTML。
  /// 其中 redirectWithCookies 读的是 `.chaoxing.com` 域 Cookie，
  /// 由 HttpLoginService 在 portal/login→login6 链路中取得并存入共享 Jar，
  /// 这里直接复用，无需复制或伪造。
  ///
  /// 关键：必须 `followRedirects: false` 手动跟跳。
  /// Dio 自动跟跳时中间 302 的 Set-Cookie（writecookies 种下的盘符 Cookie）
  /// 不会过 CookieManager 拦截器，直接丢失，后续 listres/上传必失败。
  /// 每跳单独请求，拦截器逐跳存取 Cookie，才能收敛。
  Future<CloudiskSession> ensureSession({bool forceRefresh = false}) async {
    if (!forceRefresh && _session != null) return _session!;
    _session = null;
    var uri = Uri.parse('$host/');
    String? html;
    for (var i = 0; i < 10; i++) {
      final resp = await _dio.get<String>(
        uri.toString(),
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: false,
          validateStatus: (_) => true,
          headers: {'Referer': '$host/'},
        ),
      );
      final status = resp.statusCode ?? 0;
      if ([301, 302, 303, 307, 308].contains(status)) {
        final loc = resp.headers.value('location');
        if (loc == null || loc.isEmpty) {
          throw const CloudiskException('云盘登录跳转异常');
        }
        uri = uri.resolve(loc);
        _logger.d('☁️ sso $status → ${uri.host}${uri.path}');
        if (_isPassportLogin(uri)) {
          _logger.w('☁️ SSO bounced to $uri');
          throw const CloudiskAuthException('超星登录已过期，请重新登录');
        }
        continue;
      }
      if (status == 401 || status == 403) {
        throw const CloudiskAuthException('超星登录已过期，请重新登录');
      }
      if (status < 200 || status >= 400) {
        throw CloudiskException('云盘首页异常 HTTP $status');
      }
      if (_isPassportLogin(uri)) {
        _logger.w('☁️ SSO bounced to $uri');
        throw const CloudiskAuthException('超星登录已过期，请重新登录');
      }
      html = resp.data ?? '';
      break;
    }
    if (html == null) throw const CloudiskException('云盘登录跳转次数过多');
    // 未登录会被 SSO 踢到 passport 登录页，首页特征缺失
    _session = parseSession(html);
    _logger.i('☁️ Cloudisk session ready, puid=${_session!.puid}');
    return _session!;
  }

  /// passport 系登录页即视为超星会话失效。
  /// 注意 login6（passport2-api…/api/v2/login6）是 portal 绑定链路，
  /// 不会出现在云盘 SSO 中，无需特殊放行。
  static bool _isPassportLogin(Uri uri) =>
      uri.host.contains('passport') ||
      (uri.host == 'sso.hunau.edu.cn' && uri.path.contains('login'));

  /// 会话失效由 CloudBackupManager 统一静默重登后 forceRefresh 重试，
  /// 这里不再内部重试（同 Cookie 再走一遍 SSO 必败，白费一轮跳转）。
  /// 仅 401/403（Dio 抛出的场景）刷新一次会话。
  Future<T> _withSessionRetry<T>(
      Future<T> Function(CloudiskSession s) run) async {
    try {
      return await run(await ensureSession());
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 ||
          e.response?.statusCode == 403) {
        invalidateSession();
        return await run(await ensureSession(forceRefresh: true));
      }
      rethrow;
    }
  }

  static void _throwIfHttpAuth(Response resp) {
    final code = resp.statusCode ?? 0;
    if (code == 401 || code == 403) {
      throw const CloudiskAuthException('超星登录已过期，请重新登录');
    }
  }

  static dynamic _asJson(dynamic data) {
    if (data is Map) return data;
    if (data is String && data.isNotEmpty) {
      try {
        return jsonDecode(data);
      } catch (_) {}
      // 会话过期时接口可能直接回登录页 HTML，而非 JSON。
      final lower = data.toLowerCase();
      if (lower.contains('passport') &&
          (lower.contains('login') || lower.contains('登录'))) {
        throw const CloudiskAuthException('超星登录已过期，请重新登录');
      }
    }
    throw const CloudiskException('云盘返回数据格式异常');
  }

  /// 列目录。返回 (totalCount, entries)，entry 透传服务端原始 Map。
  Future<CloudiskListResult> listRes({
    required String parentId,
    int page = 1,
    int size = 60,
  }) async {
    return _withSessionRetry((s) async {
      final resp = await _dio.get(
        '$host/opt/listres',
        queryParameters: {
          'puid': s.puid,
          'shareid': 0,
          'parentId': parentId,
          'page': page,
          'size': size,
          'enc': s.enc,
          'filterType': '',
          'orderField': 'default',
          'orderType': 'desc',
        },
        options: Options(headers: {
          // HAR 实测 Referer 带完整 ?_puid…&p_auth_token…，但只带 _puid 亦可；
          // 保持最小可用，避免拼错 token 导致防盗链拦截。
          'Referer': '$host/?_puid=${s.puid}',
          'X-Requested-With': 'XMLHttpRequest',
        }),
      );
      _throwIfHttpAuth(resp);
      final body = _asJson(resp.data);
      if (body is! Map) throw const CloudiskException('目录列表格式异常');
      final list = body['list'];
      if (list is! List) throw const CloudiskException('目录列表格式异常');
      final total = body['totalCount'];
      return CloudiskListResult(
        totalCount: total is int ? total : list.length,
        entries:
            list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(),
      );
    });
  }

  /// 上传 JSON 备份字节。返回服务端 data（含 resid/encryptedId/crc/size）。
  Future<Map<String, dynamic>> uploadJson({
    required String folderId,
    required String filename,
    required List<int> bytes,
  }) async {
    return _withSessionRetry((s) async {
      final genResp = await _dio.get(
        '$host/pcuserpanUpload/generateUploadUrl',
        queryParameters: {
          'puid': s.puid,
          'folderUpload': false,
          'fldid': folderId,
          '_token': s.token,
          'fid': schoolFid,
        },
        options: Options(headers: {
          // HAR 实测此处 Referer 为上传页 upload?bigFile=…，照抄。
          'Referer': uploadPageUrl,
          'X-Requested-With': 'XMLHttpRequest',
        }),
      );
      _throwIfHttpAuth(genResp);
      final gen = _asJson(genResp.data);
      final uploadUrl = gen is Map ? gen['uploadUrl'] as String? : null;
      if (uploadUrl == null || uploadUrl.isEmpty) {
        throw const CloudiskException('获取上传地址失败');
      }
      final url =
          uploadUrl.startsWith('http') ? uploadUrl : '$host$uploadUrl';

      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });
      final upResp = await _dio.post(
        url,
        data: form,
        options: Options(headers: {
          'Origin': host,
          'Referer': uploadPageUrl,
        }),
      );
      _throwIfHttpAuth(upResp);
      final up = _asJson(upResp.data);
      if (up is! Map || up['result'] != true || up['data'] is! Map) {
        throw CloudiskException('上传失败：${up is Map ? up['msg'] : up}');
      }
      final data = Map<String, dynamic>.from(up['data'] as Map);
      // 校验回执：resid 必须存在且大小一致（服务端 size 为 int，容忍字符串形态）。
      final size = int.tryParse('${data['size']}');
      if (data['resid'] == null || size != bytes.length) {
        throw const CloudiskException('上传校验失败（回执大小不一致）');
      }
      _logger.i('☁️ Uploaded $filename resid=${data['resid']}');
      return data;
    });
  }

  /// 删除文件（需 resid + encryptedId + puid，见删除 HAR 表单）。
  Future<void> deleteRes({
    required String resid,
    required String encryptedId,
    required String puid,
  }) async {
    return _withSessionRetry((s) async {
      final resp = await _dio.post(
        '$host/opt/delres',
        data: {
          'resids': resid,
          'resourcetype': 0,
          'puids': puid,
          'encryptedids': encryptedId,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'Origin': host,
            'Referer': '$host/?_puid=${s.puid}',
            'X-Requested-With': 'XMLHttpRequest',
          },
        ),
      );
      _throwIfHttpAuth(resp);
      final body = _asJson(resp.data);
      if (body is! Map || body['success'] != true) {
        throw CloudiskException(
            '删除失败：${body is Map ? body['msg'] : body}');
      }
    });
  }

  /// 下载文件字节（见下载 HAR）。
  /// 先 GET /download/downloadFileV2 拿 302 签名地址（d0.cldisk.com），
  /// 再跟过去拿字节。签名 URL 自带鉴权，d0 域无需 Cookie。
  Future<List<int>> downloadBytes({
    required String resid,
    required String encryptedId,
    required String puid,
    required String folderId,
  }) async {
    return _withSessionRetry((s) async {
      final resp = await _dio.get(
        '$host/download/downloadFileV2',
        queryParameters: {
          'fleid': resid,
          'puid': puid,
          'currentFolderId': folderId,
          'p_auth_token': '',
          'encryptedId': encryptedId,
          'auditRecordIdEnc': '',
        },
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: false,
          validateStatus: (_) => true,
          headers: {'Referer': '$host/?_puid=${s.puid}'},
        ),
      );
      _throwIfHttpAuth(resp);
      final loc = resp.headers.value('location');
      if ((resp.statusCode ?? 0) != 302 || loc == null || loc.isEmpty) {
        throw const CloudiskException('获取下载地址失败');
      }
      final url = Uri.parse('$host/').resolve(loc).toString();
      final fileResp = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (_) => true,
          headers: {'Referer': '$host/?_puid=${s.puid}'},
        ),
      );
      _throwIfHttpAuth(fileResp);
      final bytes = fileResp.data;
      if ((fileResp.statusCode ?? 0) != 200 || bytes == null) {
        throw CloudiskException('下载失败 HTTP ${fileResp.statusCode}');
      }
      return bytes;
    });
  }
}

class CloudiskSession {
  final String puid;
  final String rootDirId;
  final String enc;
  final String token;

  const CloudiskSession({
    required this.puid,
    required this.rootDirId,
    required this.enc,
    required this.token,
  });
}

class CloudiskListResult {
  final int totalCount;
  final List<Map<String, dynamic>> entries;

  const CloudiskListResult({required this.totalCount, required this.entries});
}
