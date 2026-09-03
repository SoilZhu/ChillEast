import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/features/workspace/services/campus_card_service.dart';

void main() {
  group('Campus Card WeChat Recharge Tests', () {
    test('1. WeChatRechargeOrder model serialization and properties', () {
      final order = WeChatRechargeOrder(
        partnerjourno: 'datalook2026090312495896868',
        mwebUrl: 'https://wx.tenpay.com/cgi-bin/mmpayweb-bin/checkmweb?prepay_id=wx126334252730900d450000034620263000',
        returnurl: 'http%3A%2F%2Ffin-serv.hunau.edu.cn%2Fcommon%2FpaySuccess',
        redirectUrl: 'http://fin-serv1.hunau.edu.cn/',
        prepayId: 'wx126334252730900d450000034620263000',
      );

      expect(order.partnerjourno, 'datalook2026090312495896868');
      expect(order.mwebUrl, contains('wx.tenpay.com'));
      expect(order.returnurl, contains('paySuccess'));
      expect(order.redirectUrl, 'http://fin-serv1.hunau.edu.cn/');
      expect(order.prepayId, 'wx126334252730900d450000034620263000');
      expect(order.toString(), contains('datalook2026090312495896868'));
    });

    test('2. Extract weixin://wap/pay deep link from Tenpay HTML correctly', () {
      const mockHtml = '''
<!DOCTYPE html>
<html>
<head><title>weixin</title></head>
<body>
<script type="text/javascript">
    window.onload=function()
    {
        var url="weixin://wap/pay?prepayid%3Dwx187094599930909c450000034620263000&package=4153149418&noncestr=1788410895&sign=BgAAsimJBNT-d4zypJ2GOwu7MK44wq9nLlmQB-uL7pEAipI";
        top.location.href=url;
    }
</script>
</body>
</html>
''';

      final match = RegExp(r'''(weixin://wap/pay\?[^"'\s<>\)]+)''').firstMatch(mockHtml);
      expect(match, isNotNull);
      final deepLink = match!.group(1);
      expect(deepLink, startsWith('weixin://wap/pay?prepayid%3Dwx187094599930909c450000034620263000'));
      expect(deepLink, contains('&package=4153149418'));
    });

    test('3. Parse transferFromWx2Card JSON response into WeChatRechargeOrder', () {
      const rawJson = '''
{
  "message": "CORE10008",
  "resultData": {
    "partnerjourno": "datalook2026090312480399372",
    "mweb_url": "https://wx.tenpay.com/cgi-bin/mmpayweb-bin/checkmweb?prepay_id=wx187094599930909c450000034620263000&ct=1788410895&sign=BgAAvqBKUn_-LjADD9wcE9j1LeBIwKq5HRFVFjc6vth99oY&package=4153149418",
    "openid": "06f1536a9362311bae112cd6651d13f0",
    "returnurl": "http%253A%252F%252Ffin-serv.hunau.edu.cn%252Fcommon%252FpaySuccess%253Fidserial%253D202440800233",
    "redirect_url": "http://fin-serv1.hunau.edu.cn/",
    "prepay_id": "wx187094599930909c450000034620263000"
  },
  "success": true
}
''';

      final Map<String, dynamic> data = jsonDecode(rawJson) as Map<String, dynamic>;
      expect(data['success'], isTrue);
      final resultData = data['resultData'] as Map<String, dynamic>;
      final order = WeChatRechargeOrder(
        partnerjourno: resultData['partnerjourno'] as String,
        mwebUrl: resultData['mweb_url'] as String,
        returnurl: resultData['returnurl'] as String,
        redirectUrl: resultData['redirect_url'] as String?,
        prepayId: resultData['prepay_id'] as String?,
      );

      expect(order.partnerjourno, 'datalook2026090312480399372');
      expect(order.prepayId, 'wx187094599930909c450000034620263000');
      expect(order.returnurl, contains('paySuccess'));
    });

    test('4. WeChatPayStatusResult validation for pending, success, and error states', () {
      final pendingResult = WeChatPayStatusResult(isSuccess: false, isPending: true);
      expect(pendingResult.isPending, isTrue);
      expect(pendingResult.isSuccess, isFalse);

      final successResult = WeChatPayStatusResult(isSuccess: true, isPending: false);
      expect(successResult.isSuccess, isTrue);
      expect(successResult.isPending, isFalse);

      final failedResult = WeChatPayStatusResult(
        isSuccess: false,
        isPending: false,
        message: '订单超时已取消',
      );
      expect(failedResult.isSuccess, isFalse);
      expect(failedResult.isPending, isFalse);
      expect(failedResult.message, '订单超时已取消');
    });

    test('5. PaymentMethod enum contains wechat and alipay', () {
      expect(PaymentMethod.values, contains(PaymentMethod.wechat));
      expect(PaymentMethod.values, contains(PaymentMethod.alipay));
    });

    test('6. Distinguish pending status when returnurl contains paySuccess', () {
      const pendingHtmlFromHar = '''
<div class="result">
    <img src="/images/icon-wait.png">
    <p class="c4">微信支付订单查询中</p>
</div>
<div class="inf01 bg12">
    <div class="bdba" style="height: 35px">
        <p class="fl c2">失败原因：</p>
        <p class="fr" id="message">微信支付订单查询中</p>
    </div>
</div>
<div class="rep-btn">
    <input class="btn01 gradient2" onClick="refreshOrderQuery()" value="刷新" type="button">
    <input id="returnurl" value="http%253A%252F%252Ffin-serv.hunau.edu.cn%252Fcommon%252FpaySuccess%253Fidserial%253D202440800233" type="hidden">
</div>
''';

      const realPathPending = '/wxpay/queryWxWapPayStatus';
      const realPathSuccess = '/common/paySuccess';

      // Logic matching CampusCardService
      WeChatPayStatusResult parseStatus(String path, String body, {String location = ''}) {
        if (location.contains('paySuccess') || path.contains('paySuccess')) {
          return WeChatPayStatusResult(isSuccess: true, isPending: false);
        }
        if (body.contains('微信支付订单查询中') || body.contains('icon-wait.png')) {
          return WeChatPayStatusResult(isSuccess: false, isPending: true);
        }
        final isBodySuccess = (body.contains('支付成功') || body.contains('充值成功')) &&
            !body.contains('失败原因') &&
            !body.contains('static.css');
        if (isBodySuccess) {
          return WeChatPayStatusResult(isSuccess: true, isPending: false);
        }
        return WeChatPayStatusResult(isSuccess: false, isPending: true);
      }

      final pendingStatus = parseStatus(realPathPending, pendingHtmlFromHar);
      expect(pendingStatus.isPending, isTrue);
      expect(pendingStatus.isSuccess, isFalse);

      final redirectStatus = parseStatus(realPathPending, '', location: 'http://fin-serv.hunau.edu.cn/common/paySuccess?idserial=123');
      expect(redirectStatus.isSuccess, isTrue);
      expect(redirectStatus.isPending, isFalse);

      final successStatus = parseStatus(realPathSuccess, '<p class="c4">支付成功</p>');
      expect(successStatus.isSuccess, isTrue);
      expect(successStatus.isPending, isFalse);
    });
  });
}
