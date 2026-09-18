import 'dart:io';
import 'package:ChillEast/features/sunshine/models/sunshine_models.dart';
import 'package:ChillEast/features/sunshine/services/sunshine_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const identityHtml = '<input id="h_CardCode" value="test-card">'
    '<input id="UserName" value="测试用户">'
    '<input id="telPhone" value="13800000000">';

void main() {
  late Dio dio;
  late SunshineService service;
  late List<RequestOptions> requests;
  late dynamic Function(RequestOptions) respond;
  setUp(() {
    requests = [];
    dio = Dio();
    service = SunshineService(dio: dio);
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

  test('statistics match HAR; WCount is not inferred as unhandled', () async {
    respond = (_) => '{"TCount":"10","WCount":"5","ZCount":"2","YCount":"8"}';
    final data = await service.fetchStatistics();
    expect([data.total, data.processing, data.completed], ['10', '2', '8']);
    expect(requests.single.queryParameters, {'AFlag': 'Statistics'});
    expect(() => SunshineStatistics.fromJson({}), throwsFormatException);
  });

  test('public letters use observed status mapping and tolerate missing fields',
      () async {
    respond = (_) =>
        '{"total":3,"rows":[{"Title":"测试","Status":"1"},{"Status":"2"},{}]}';
    final letters = await service.fetchLetters();
    expect(letters.map((l) => l.statusLabel), ['办理中', '已办结', '状态未知']);
    expect(requests.single.data, {'AFlag': 'Suggestion'});
  });

  test('HTML and malformed responses must not look like empty success',
      () async {
    for (final response in ['<html>登录</html>', '{}', '{"rows":[1]}']) {
      respond = (_) => response;
      await expectLater(
          service.fetchLetters(), throwsA(isA<SunshineException>()));
    }
  });

  test('form read retries one safe timeout with a fresh connection', () async {
    var formReads = 0;
    respond = (r) {
      if (r.path.endsWith('/form.aspx') && ++formReads == 1) {
        return DioException(
          requestOptions: r,
          type: DioExceptionType.receiveTimeout,
        );
      }
      if (r.path.endsWith('/form.aspx')) return identityHtml;
      return '{"rows":[{"Company_code":"2","Company_name":"测试单位"}]}';
    };

    final form = await service.fetchForm();

    expect(form.identity.name, '测试用户');
    expect(formReads, 2);
    final formRequests =
        requests.where((r) => r.path.endsWith('/form.aspx')).toList();
    expect(formRequests, hasLength(2));
    expect(formRequests.every((r) => r.persistentConnection == false), isTrue);
    expect(
      formRequests.every(
        (r) => r.receiveTimeout == const Duration(seconds: 30),
      ),
      isTrue,
    );
    expect(
      requests.where((r) => r.path == SunshineService.authorizationUrl),
      isEmpty,
    );
  });

  test('two form timeouts surface a specific retryable error', () async {
    respond = (r) => DioException(
          requestOptions: r,
          type: DioExceptionType.receiveTimeout,
        );

    await expectLater(
      service.fetchForm(),
      throwsA(
        isA<SunshineException>().having(
          (e) => e.message,
          'message',
          contains('响应超时'),
        ),
      ),
    );
    expect(requests, hasLength(2));
  });

  test('form refreshes identity through SSO and uses department code not id',
      () async {
    var formReads = 0;
    respond = (r) {
      if (r.path.endsWith('/form.aspx')) {
        return ++formReads == 1 ? '<html>登录</html>' : identityHtml;
      }
      if (r.path == SunshineService.authorizationUrl) return '';
      return '{"rows":[{"id":"69","Company_code":"2","Company_name":"测试单位"}]}';
    };
    final form = await service.fetchForm();
    expect(form.identity.name, '测试用户');
    expect(form.departments.single.code, '2');
    expect(
        requests
            .where((r) => r.path == SunshineService.authorizationUrl)
            .length,
        1);
    expect(formReads, 2);
  });

  test('form follows CAS OAuth redirect chain including /cas/login to completion',
      () async {
    var formReads = 0;
    respond = (r) {
      if (r.uri.path.endsWith('/form.aspx')) {
        return ++formReads == 1 ? '<html>请登录</html>' : identityHtml;
      }
      if (r.uri.toString() == SunshineService.authorizationUrl) {
        return Response(
          requestOptions: r,
          statusCode: 302,
          headers: Headers.fromMap({
            HttpHeaders.locationHeader: [
              '/cas/login?service=https%3A%2F%2Fsso.hunau.edu.cn%2Fcas%2Foauth2.0%2FcallbackAuthorize%3Fclient_name%3DCasOAuthClient%26client_id%3Dyg1000002%26redirect_uri%3Dhttp%253A%252F%252Fsun.hunau.edu.cn%252FOAuthLogin.aspx%26response_type%3Dcode'
            ]
          }),
        );
      }
      if (r.uri.path == '/cas/login') {
        return Response(
          requestOptions: r,
          statusCode: 302,
          headers: Headers.fromMap({
            HttpHeaders.locationHeader: [
              'https://sso.hunau.edu.cn/cas/oauth2.0/callbackAuthorize?client_name=CasOAuthClient&client_id=yg1000002&redirect_uri=http%3A%2F%2Fsun.hunau.edu.cn%2FOAuthLogin.aspx&response_type=code&ticket=ST-12345'
            ]
          }),
        );
      }
      if (r.uri.path == '/cas/oauth2.0/callbackAuthorize') {
        return Response(
          requestOptions: r,
          statusCode: 302,
          headers: Headers.fromMap({
            HttpHeaders.locationHeader: [
              'http://sun.hunau.edu.cn/OAuthLogin.aspx?code=OC-12345'
            ]
          }),
        );
      }
      if (r.uri.path == '/OAuthLogin.aspx') {
        return Response(
          requestOptions: r,
          statusCode: 302,
          headers: Headers.fromMap({
            HttpHeaders.locationHeader: ['/index.aspx']
          }),
        );
      }
      if (r.uri.path == '/index.aspx') {
        return '';
      }
      if (r.uri.path.endsWith('/form.ashx')) {
        return '{"rows":[{"Company_code":"2","Company_name":"测试单位"}]}';
      }
      return '';
    };

    final form = await service.fetchForm();
    expect(form.identity.name, '测试用户');
    expect(form.departments.single.name, '测试单位');
    expect(formReads, 2);
    final oauthLoginReq =
        requests.firstWhere((r) => r.uri.path == '/OAuthLogin.aspx');
    expect(oauthLoginReq.uri.scheme, 'https');
  });

  test('expired TGC refreshes saved login and retries OAuth once', () async {
    var reauthenticated = false;
    var reauthenticateCalls = 0;
    service = SunshineService(
      dio: dio,
      reauthenticate: () async {
        reauthenticateCalls++;
        reauthenticated = true;
      },
    );
    respond = (r) {
      if (r.path.endsWith('/form.aspx')) {
        return reauthenticated ? identityHtml : '<html>登录</html>';
      }
      if (r.path == SunshineService.authorizationUrl) return '';
      return '{"rows":[{"Company_code":"2","Company_name":"测试单位"}]}';
    };

    final form = await service.fetchForm();

    expect(form.identity.name, '测试用户');
    expect(reauthenticateCalls, 1);
    expect(
      requests.where((r) => r.path == SunshineService.authorizationUrl).length,
      2,
    );
  });

  test('failed saved login reports an actionable session error', () async {
    service = SunshineService(
      dio: dio,
      reauthenticate: () async => throw Exception('expired credentials'),
    );
    respond = (_) => '<html>登录</html>';

    await expectLater(
      service.fetchForm(),
      throwsA(
        isA<SunshineException>().having(
          (e) => e.message,
          'message',
          contains('个人中心重新登录'),
        ),
      ),
    );
    expect(requests.length, 3);
  });

  test('expired SSO stops form load', () async {
    respond = (_) => '<html>登录</html>';
    await expectLater(service.fetchForm(), throwsA(isA<SunshineException>()));
    expect(requests.length, 3);
  });

  test(
      'submit fields match page script; no retry or redirect on unknown result',
      () async {
    respond = (_) => '1';
    Future<String> submit() => service.submit(
          identity: const SunshineIdentity('test-card', '测试用户', '', ''),
          department: const SunshineDepartment('2', '测试单位'),
          type: '3',
          title: ' 标题 ',
          content: ' 内容 ',
          phone: '13800000000',
          email: '',
          finishTime: '',
        );
    expect(await submit(), '1');
    expect(requests.single.queryParameters, {'AFlag': 'insert'});
    expect(requests.single.followRedirects, false);
    expect(requests.single.data, {
      'type1': '3',
      'depid': '2',
      'depname': '测试单位',
      'title': '标题',
      'content': '内容',
      'username': '测试用户',
      'telphone': '13800000000',
      'email': '',
      'finishtime': '',
      'captchas': '',
      'CardCode': 'test-card',
    });
    for (final response in ['2', 'errer', '<html>登录</html>']) {
      requests.clear();
      respond = (_) => response;
      expect(await submit(), response.startsWith('<') ? 'unknown' : response);
      expect(requests.length, 1);
    }
  });

  test('fetchTicketDetail matches HAR response and submitter only retains surname',
      () async {
    const harResponse =
        '{"total":1,"rows":[{"Title":"巴士司机的驾驶素质","LinkName":"郑天塬","DepName":"后勤保障中心","CirDepName":"保卫工作部、保卫处","FinishTime":"2026-09-14","JieTime":"2026-09-16","WanTime":"2026-09-14","Status":"2","Content":"投诉9月10日11:50/11:55，修业广场偏金岸宿舍方向...","Remark":"学校保卫工作部根据校园交通车考评管理办法...","bTypeName":"咨询","cTypeName":"","dTypeName":"","Sex":""}]}';
    respond = (_) => harResponse;

    final detail = await service.fetchTicketDetail('12692');

    expect(requests.single.data, {'AFlag': 'Detail', 'ID': '12692'});
    expect(detail.id, '12692');
    expect(detail.title, '巴士司机的驾驶素质');
    // 注意提交人只保留到姓
    expect(detail.submitter, '郑');
    expect(detail.rawSubmitter, '郑天塬');
    expect(detail.expectedDepartment, '后勤保障中心');
    expect(detail.handlingDepartment, '保卫工作部、保卫处');
    expect(detail.finishTime, '2026-09-14');
    expect(detail.jieTime, '2026-09-16');
    expect(detail.wanTime, '2026-09-14');
    expect(detail.status, '2');
    expect(detail.statusLabel, '已办结');
    expect(detail.isCompleted, isTrue);
    expect(detail.type, '咨询');
    expect(detail.content, contains('投诉9月10日11:50/11:55'));
    expect(detail.remark, contains('学校保卫工作部根据校园交通车考评管理办法'));
  });

  test('fetchTicketDetail throws SunshineException when ticket not found',
      () async {
    respond = (_) => '{"total":0,"rows":[]}';
    await expectLater(
      service.fetchTicketDetail('999999'),
      throwsA(isA<SunshineException>().having(
        (e) => e.message,
        'message',
        contains('未找到诉求工单详情'),
      )),
    );
  });

  test('extractSurname correctly extracts single and compound surnames', () {
    expect(SunshineTicketDetail.extractSurname('郑天塬'), '郑');
    expect(SunshineTicketDetail.extractSurname('张三'), '张');
    expect(SunshineTicketDetail.extractSurname('李四'), '李');
    expect(SunshineTicketDetail.extractSurname('王五'), '王');
    expect(SunshineTicketDetail.extractSurname('欧阳修'), '欧阳');
    expect(SunshineTicketDetail.extractSurname('诸葛孔明'), '诸葛');
    expect(SunshineTicketDetail.extractSurname('司马光'), '司马');
    expect(SunshineTicketDetail.extractSurname('上官婉儿'), '上官');
    expect(SunshineTicketDetail.extractSurname('皇甫嵩'), '皇甫');
    expect(SunshineTicketDetail.extractSurname('赵'), '赵');
    expect(SunshineTicketDetail.extractSurname(''), '');
    expect(SunshineTicketDetail.extractSurname('   '), '');
  });
}
