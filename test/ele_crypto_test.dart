import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/core/utils/dkyw_crypto.dart';

void main() {
  test('decrypt real datajson from server', () {
    const s1 = "fy63Of040BbFsO9v8IWJ94D7GhVfYRyJqYin6pinkMO73vcpLSYreCfawFVdUZd2MU+hyr326ua2NDaLX1ms5Cv1eV7ccuHegyqN5Q==";
    const s2 = "xKtsJFyY99vjKhmwbXB6oVZ0mKb/yrgtXqcvtQGJbv3Zd/z6LSRhj0CPEIjoze7X4D6uAl66kcp7s8mU";

    final res1 = DkywCrypto.decryptPayload(s1);
    expect(res1['success'], true);
    expect(res1['message'], '成功');

    final res2 = DkywCrypto.decryptPayload(s2);
    expect(res2['success'], false);
    expect(res2['message'], '余额不足');

    const s3 = "gEiTknLwhx6Na3nC1wxYVPxutwrDVPtL3v3yciSaAlWXLUE5km+/AhOuJ7VOsItOWPz+4YafiqCuH1cahjZJtG7bOGpVoJWv32NmHYQmU58MVgu5K/hK8+Wf0TkFTtkp8TGTysSvEYc2cAmW5abMceMjeTTB6L+w7WpWdHecv/yf8yullkJMUtb2mfB5OXhj9kYoTF/9b7BzgjdTszwcxtGUORLQTM441N2bVtJCboR/uvPQnMiwvOm8qpECTCBeGZfO4b9EjsVE4TxsQ7uuikcUNUrvRQLGYVff9vFJxKtLMuP1zK/bMMHqtwZzJUxBru+FU16yoDZKXZjAk5GTLscmeDYgp1cCGhFWhtqZbQFsFGLnhwixMTVwrp525R5/HwnN5aePWVfcg9m0gNOM0X1eoq95N0j/+Rvk3sExnqpVTxjRHOKY3u3V3jY/frMJn0St4wGwQs0N7Mwc+6iVtGT5kSQM2AaP88ufNG61XW8SAcRuwwe6FLrLSbfE8GJE0o17bnsh9JE9sUxqw2pkBIX2iFv8tcahjZi/plcxT9917B5qvrvKj/pFZ9cVdrcEX8f+fvCyaFVSw9NPPov1bxizpRLfz/DB2uN/ZEYjVzijqz4FqjAN7dMlNhxLqqJO9YETrCF0bsnuXelgnwzuldjF0T8uF0OfP2IiWd+qPhvUpAP36wzAj54Nnyfhtl5ftB8+jsiaBRMWXsXzontvb30sZe00W5HkKfYID930ocZiIHEsbD4uhF1xw6fSl9cPAlP8XArJnyGrGO+PuHF+Q7abH34wftXCFnbJjojdrX82miFoqHqPzca8vjjSVeuXkzOkO/8gVipwNiSgvM058bR/uC9nEN1uGzdRwX1RCUOJRA5En6aXDgsv+86GIS2qZbaDp+Yt04fels16aH5OYuxYkbonaNAZ6kBFbibBfiL+3B+Utmekbqncr9U=";
    final res3 = DkywCrypto.decryptPayload(s3);
    expect(res3['success'], true);
    expect(res3['message'], '成功');
  });

  test('roundtrip encrypt and decrypt', () {
    final original = {'schoolid': '芷兰公寓照明', 'buildingid': '芷兰1栋', 'roomid': '101', 'mertype': 'yk'};
    final encrypted = DkywCrypto.encryptPayload(original);
    final decrypted = DkywCrypto.decryptPayload(encrypted);
    expect(decrypted, original);
  });

  test('decryptServerResponse handles html-escaped string', () {
    const rawHtmlEscaped = '"{&quot;datajson&quot;:&quot;gEiTknLwhx6Na3nC1wxYVPxutwrDVPtL3v3yciSaAlWXLUE5km+/AhOuJ7VOsItOWPz+4YafiqCuH1cahjZJtG7bOGpVoJWv32NmHYQmU58MVgu5K/hK8+Wf0TkFTtkp8TGTysSvEYc2cAmW5abMceMjeTTB6L+w7WpWdHecv/yf8yullkJMUtb2mfB5OXhj9kYoTF/9b7BzgjdTszwcxtGUORLQTM441N2bVtJCboR/uvPQnMiwvOm8qpECTCBeGZfO4b9EjsVE4TxsQ7uuikcUNUrvRQLGYVff9vFJxKtLMuP1zK/bMMHqtwZzJUxBru+FU16yoDZKXZjAk5GTLscmeDYgp1cCGhFWhtqZbQFsFGLnhwixMTVwrp525R5/HwnN5aePWVfcg9m0gNOM0X1eoq95N0j/+Rvk3sExnqpVTxjRHOKY3u3V3jY/frMJn0St4wGwQs0N7Mwc+6iVtGT5kSQM2AaP88ufNG61XW8SAcRuwwe6FLrLSbfE8GJE0o17bnsh9JE9sUxqw2pkBIX2iFv8tcahjZi/plcxT9917B5qvrvKj/pFZ9cVdrcEX8f+fvCyaFVSw9NPPov1bxizpRLfz/DB2uN/ZEYjVzijqz4FqjAN7dMlNhxLqqJO9YETrCF0bsnuXelgnwzuldjF0T8uF0OfP2IiWd+qPhvUpAP36wzAj54Nnyfhtl5ftB8+jsiaBRMWXsXzontvb30sZe00W5HkKfYID930ocZiIHEsbD4uhF1xw6fSl9cPAlP8XArJnyGrGO+PuHF+Q7abH34wftXCFnbJjojdrX82miFoqHqPzca8vjjSVeuXkzOkO/8gVipwNiSgvM058bR/uC9nEN1uGzdRwX1RCUOJRA5En6aXDgsv+86GIS2qZbaDp+Yt04fels16aH5OYuxYkbonaNAZ6kBFbibBfiL+3B+Utmekbqncr9U=&quot;}"';
    final res = DkywCrypto.decryptServerResponse(rawHtmlEscaped);
    expect(res is Map, true);
    expect(res['success'], true);
    expect(res['message'], '成功');
    expect(res['resultData']['paytxamt'], '100');
  });
}
