import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/core/utils/dkyw_crypto.dart';
import 'package:ChillEast/features/workspace/services/campus_card_service.dart';

void main() {
  group('Campus Card Recharge Crypto & Payload Tests', () {
    test('decrypt real WeChat recharge response from HAR', () {
      const rawEncryptedResponse = "{\"datajson\":\"M0tyIEsf53PqXtx9G6XyfjNHzervly9VQ7bQIMdQO4do7o5YzZVmMrjkE/W6nA2aWy8gpEOH4Bx0Gu9dyvx4AMu+xSsJv7Wi7bKcahJkKSK+xatKY3O9NE2+hjzwXLCcYiPbaKWWMSG+4RaLAxBR9AOPezm6CnetFf0hZSoPhXq09oFSG9FEONjfKaqrVkPOZl3HR0tzhnNmZfOjVf54MLEkbaUNwyOwmk7FhGI2BhB5DLQOZuOvl++rCPmzm/80uTob0zt9286+fCRho9z6/RuVP6Uiz7hoQlzwo/4ucnfk+WciqSAPvvEj2Ti+kwASB0lHr9EkZlGbhO0qSOC8HQKBxliRJVjt/tSxUn+MWzPeuY9L5S/OjEv3+D0OWxDBOlBSTpS3hx5qCszuudUl8i6IEZYfT2IL797dt0cYnF1stXHNrdmQJ1+zeTvrOIuPTBhf85RkOvAIT0quYaaV6rxud537fXM/F1NVjWAqht4LdB9Y14nV6/sbB3pze9ko/0/Eq5kVGmdHXZZPzw4vAPzs5J5ud2CvlR4tq6faAcbN5Kttb2w/EtluVLj07+evaK2G+DSfXeooTxiJ2sfIc14T534yT2hYan0Qj8eni0+4uyNwNrar8qKjZZ5KGJF3yuvrQsiTp7hub0knJma8xDz0pYjYaOYrz8wAiG9tgf1YlKGoQ3ZUy2isvYYzoQZogD3+X5nCyJSvPk8hyiNT7fyqQQrKtDnnKbA6lGlRwnSFxI5t3AHuV2IVxblm2vIPBcLIEVIGefT20/B8dkRq0wXpvviEBb/eeOCVBqKu6awwYCFj01VRZCsNXXpkNUXh+WWKCljBC/y0AvxucRmFZBGuYMsLFjRtfzgwvNP4ZKuyB+c/HuIZ1jZO5dnW/KAxUSnOD8ie3NgX6rX7pQn2Ei+zbjN5ueNnmvRJTMtybGYImPfdZ7ebbV9pQYSgVBKaHla48q762Rh3Ti/6ta9tNCE4GYgGTQpFj93p2XJET6ejXHgVYktA/aeebHKLs9hnDkq845y1zURjxc0w290re3JUFqXIH1qXbQHaIboUoc/uc3EoNsvVCptc6ymAnAFqvZCARvPhBXVeH1x6SX0yExgFGmhrVjp0BtaP1FhS+2TQ+VGsfcv677MzYKe9LTN118fsjKR+JdZ96ui+s3h1JjhOIC7jlSC90r89yA7MBjUm1kT8SLTABmWNCpk=\"}";

      final decrypted = DkywCrypto.decryptServerResponse(rawEncryptedResponse);
      expect(decrypted is Map, true);
      expect(decrypted['success'], true);
      expect(decrypted['message'], 'CORE10008');

      final resultData = decrypted['resultData'] as Map;
      expect(resultData['partnerjourno'], 'datalook2026100821442263180');
      expect(resultData['mweb_url'], startsWith('https://wx.tenpay.com/cgi-bin/mmpayweb-bin/checkmweb?prepay_id='));
      expect(resultData['returnurl'], contains('paySuccess'));

      final order = WeChatRechargeOrder(
        partnerjourno: resultData['partnerjourno'].toString(),
        mwebUrl: resultData['mweb_url'].toString(),
        returnurl: resultData['returnurl'].toString(),
      );
      expect(order.partnerjourno, 'datalook2026100821442263180');
      expect(order.mwebUrl, startsWith('https://wx.tenpay.com'));
    });

    test('decrypt real Alipay recharge response from HAR', () {
      const rawEncryptedResponse = "{\"datajson\":\"s8evTN5H8toPP7I8U50lhI9HVDBYpdcTVAgkDRXtNbZQFtCwiK5RFR1gpVr3Vtv5VndT9z8fHkfZn6GT3lFjPUedAC1xjkG6eNaU/f0fuomgeYVoxpyEEAn0tq5sA19HMIEkuiSkCqDEfhTikswDgskEQakleThUOvka4vd3eN8Bcne1QWVULmTW2FV9za8gmozscTDTBp+lUjl3oegDEwzkSHsujJJWAlRJOdLtrYuKKaSlZtv9CsZuhRmU6VSZkTMbp2ewyJtSaP88yg3J/19lYj9Pfvsy2u+aHhLTRGHLMn+IQWU7foQ8gVPRZclKIcO8x/xq+1FioZHtBygJjZer5U9BfPcELopnCL8PnVE3ggg9rpf00GN8dRsy9ESvA5goaRlqvEOR1LGVsukXqEoQnZuVIJ0I19vuXr5lXHTcmklB2Xt+FMyHy/QWN0ad0bL4S/oeG/yfPK+v2C++vZAg0lJa6OnQC4okvhG3mq1exrDX4YLLPmPkI9GpwJG+UXQWmuSULkns1RK+hV8DUtZKzCegVQ0adpe1dhAbr1iyOqxm836bXVMzmmt/1eJEWMowPTWF8jxGI+bFvlWsM6QtLoPgQUIQGARq9Lat6xKdXV8ODA8yDwpbHD6DM3nRqAfWLYJTuYdh6SZMNwNrqhBdWVp2KB/rzcHthRsFFt0C+DCsCRulqqLKidxF99NIF7YwKP70GcRVK5joR9FV6OG8EoBT1QWK8VFcahOzoeANc57Cg5Up7wOdwmdvvI/JJta0NUhmoHhpCfQRumfzBC9yr1/li+7pbqnHHPDtrrsiDPmCMUgQCLgBoVbSWF8qKwUZvLQ/cGAop7lDcR28rjNqTtniMu6Gt8p/4pGEuT1V41X5tkKLhuPY4okREAki9gsg4q2P/Q037cyej33/bXGIU7B5cDjrYcF7AnUquN5b0M8LjGqE0S0lf/UFAgAD2Pq5FTo+Sr3ILTNQKt8ivMLtnu8uKZNI6Xoj9SW8g1iIY2N5i3ltwPhEFpiUgV80l4LfQgujcZ7BmAUwa3WoJUucCCEVvIrn6v/0HyugTu/VMGVsRUCK4S8zipbk2HmLScwkP4+qCQydC1xPw4EcRFyGoHR7Rgr3TkDBSLjGEF1A2ovt/2nEfIb77DnrrAdBhKNMc/lR2iDoFealQxNEcnSiuSsS1S0uickVWjU4S+APzVx4vA8ED3syf3jMqhdo9TfHYFCkGz4Hu/mmleaDiGa2t64xY0hlFURDqgdnrvxRpCIXfqCwFyB+mbxPuLTdHlR2ZjcAuMw3De1ltjDCXsgbBGxbXQtmzwsTjza4QUkquW9ZCYnSgPcJ4a+pGa92Ef1ua+39fysSFRhSkTaW3kMzzgjpMP4w3a5ppQLZTWbwygkCrDFDbpGZ1b96U2PaGXCjtvVm05W8nMRVL0lRhvOEuw/3WgRyV64BSAiCf27Izu5n25GidKLwcHnbi8Pk6+chcPi2Wykk3WwjC/937P1pRV6i+yfVMWhfKkOidGn+dZTjXkLJAbKrzMfm+XDp7+bMp/Zh6JJuoIxfof48ighIKcHeAO7MEoCo9RO/fMVm/8NjkPR30SX8od4TurfNBhsLSyvgsef4CDtHogBlJ8ds3DTPttOwtudVTCShZrtj8X8d9IbfmAlcTdD2SM0i/S+LuucrPTnj1YhDnsvLo2a5RuI1fnR5BqRiXuFQlI+ns2ywyF0F75ynpkC8iWL3RrW9Nm4ngtv8oNvI4qOt/g1tfdU7MN3oGZyaNSH7AjGvDrAimjRObSWSudywVIf+wOYIspBuyhRWNDpshLZb1eG146mykTQO+o7UNcVo/x/2P6hOE7PWcmaDZX4wy94s0vPNxFQiUE5lAmWbOjwQe+mkHjeqTH3H2VT0wbspGa5VSW7KOWjAkX/o4T3y7pZThIy87hZOzUCKq8Iz\"}";

      final decrypted = DkywCrypto.decryptServerResponse(rawEncryptedResponse);
      expect(decrypted is Map, true);
      expect(decrypted['success'], true);
      expect(decrypted['message'], 'CORE10008');

      final resultData = decrypted['resultData'] as Map;
      expect(resultData['htmlpost'], contains('<form name="punchout_form"'));
      expect(resultData['htmlpost'], contains('https://openapi.alipay.com/gateway.do'));
      expect(resultData['htmlpost'], contains('document.forms[0].submit();'));
    });

    test('decrypt real userlastbind response from HAR', () {
      const rawEncryptedResponse = "{\"datajson\":\"27O13kjLnDNyYxO9BHI8HLC9XC9gM/oVcTnvZVektDuiF7ZzSkzPMPkw2YyZqz0RSCm15W1fvt2P/wE/hPzQKcpvOlL9lMQ+Wpmj7w==\"}";

      final decrypted = DkywCrypto.decryptServerResponse(rawEncryptedResponse);
      expect(decrypted is Map, true);
      expect(decrypted['success'], true);
      expect(decrypted['message'], '成功');
    });

    test('recharge payload roundtrip encrypts and preserves types', () {
      final wechatPayload = {
        'txamt': '10',
        'payWay': '1',
        'openid': 'TEST_OPENID_123',
        'idserial': '202440800000',
        'tradetype': 'WAP',
      };
      final encWechat = DkywCrypto.encryptPayload(wechatPayload);
      final decWechat = DkywCrypto.decryptPayload(encWechat);
      expect(decWechat, wechatPayload);

      final alipayPayload = {
        'txamt': '50',
        'payWay': '4',
        'openid': 'TEST_OPENID_123',
        'idserial': '202440800000',
      };
      final encAlipay = DkywCrypto.encryptPayload(alipayPayload);
      final decAlipay = DkywCrypto.decryptPayload(encAlipay);
      expect(decAlipay, alipayPayload);
    });
  });
}
