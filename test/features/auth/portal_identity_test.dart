import 'package:ChillEast/features/auth/services/portal_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses authenticated portal identity with HTML entities and spacing',
      () {
    final profile = PortalIdentity.parse('''
      <div class="infoTxt"><p><em>A &amp; B</em></p>
      <p>学号：<span>202600000001</span></p><p>示例学院</p></div>
    ''');
    expect(profile?.realName, 'A & B');
    expect(profile?.username, '202600000001');
  });
  test('supports staff account labels', () {
    final profile = PortalIdentity.parse(
        '<div class="infoTxt"><em>Example</em><p>工号: A12345</p></div>');
    expect(profile?.username, 'A12345');
  });
  test('rejects missing, ambiguous or reflected login identities', () {
    for (final html in [
      '<form><input name="username" value="202600000001"></form>',
      '<p>学号：202600000001</p>',
      '<div class="infoTxt"><em>Example</em></div>',
      '<div class="infoTxt"><p>学号：202600000001</p></div>',
      '<div class="infoTxt"><em>Example</em><p>学号：202600000001</p></div><input type="password">',
      '<div class="infoTxt"><em>A</em><p>学号：1</p></div><div class="infoTxt"><em>B</em><p>学号：2</p></div>',
    ]) {
      expect(PortalIdentity.parse(html), isNull);
    }
  });
}
