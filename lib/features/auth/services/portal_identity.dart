import 'package:html/parser.dart' as html_parser;

/// Identity rendered by the authenticated fusion portal, not by a login form.
/// Keep only parsed profile fields; do not retain signed links or the full HTML.
class PortalIdentity {
  const PortalIdentity({required this.username, required this.realName});

  final String username;
  final String realName;

  static PortalIdentity? parse(String html) {
    final document = html_parser.parse(html);
    if (document.querySelector('input[type="password"]') != null) return null;
    final containers = document.querySelectorAll('div.infoTxt');
    if (containers.length != 1) return null;
    final info = containers.single;
    final realName = info.querySelector('em')?.text.trim() ?? '';
    final account = RegExp(r'(?:学工号|学号|工号)\s*[：:]\s*([A-Za-z0-9._@-]+)')
        .firstMatch(info.text)
        ?.group(1);
    if (realName.isEmpty || account == null || account.isEmpty) return null;
    return PortalIdentity(username: account, realName: realName);
  }
}
