import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:html/parser.dart' as html_parser;
import 'package:pointycastle/export.dart' as pc;

import '../../../core/constants/app_constants.dart';
import '../../../core/exceptions/app_exceptions.dart';

/// Only the expected HTTPS SSO origin may receive credentials or CIMS signatures.
Uri trustedSsoUri(Uri uri) {
  if (uri.scheme != 'https' ||
      uri.host != Uri.parse(AppConstants.ssoBaseUrl).host ||
      uri.port != 443 ||
      uri.userInfo.isNotEmpty) {
    throw const AuthException('拒绝向非预期 HTTPS 域名发送认证请求');
  }
  return uri;
}

/// CIMS uses JavaScript decodeURI, not decodeURIComponent or form decoding.
/// In particular, base64's %3D, %2B and %2F must remain percent-encoded.
String decodeCimsUri(String value) {
  final reserved = RegExp(
    r'%(?:3B|2F|3F|3A|40|26|3D|2B|24|2C|23)',
    caseSensitive: false,
  );
  final result = StringBuffer();
  var start = 0;
  for (final match in reserved.allMatches(value)) {
    result.write(Uri.decodeComponent(value.substring(start, match.start)));
    result.write(match.group(0));
    start = match.end;
  }
  result.write(Uri.decodeComponent(value.substring(start)));
  return result.toString();
}

/// Parse only string literals; never execute JavaScript supplied by the page.
String _literalOption(String source, String name, [String? defaultValue]) {
  final pattern = RegExp(
    r'''(?:^|[,\n])\s*''' +
        RegExp.escape(name) +
        r'''\s*:\s*((?:"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'))\s*(?=,|$)''',
  );
  final match = pattern.firstMatch(source);
  if (match == null) {
    // A present non-literal option is not equivalent to an omitted option.
    if (defaultValue != null &&
        !RegExp(r'\b' + RegExp.escape(name) + r'\s*:').hasMatch(source)) {
      return defaultValue;
    }
    throw AuthException('无法解析登录页配置：$name');
  }
  final literal = match.group(1)!;
  final output = StringBuffer();
  const escapes = {
    'n': '\n',
    'r': '\r',
    't': '\t',
    'b': '\b',
    'f': '\f',
    'v': '\u000b',
    '0': '\u0000',
    '\\': '\\',
    '/': '/',
    "'": "'",
    '"': '"',
  };
  for (var i = 1; i < literal.length - 1; i++) {
    final char = literal[i];
    if (char != '\\') {
      output.write(char);
      continue;
    }
    final escaped = literal[++i];
    if (escapes.containsKey(escaped)) {
      output.write(escapes[escaped]);
    } else if (escaped == 'u' || escaped == 'x') {
      final count = escaped == 'u' ? 4 : 2;
      if (i + count >= literal.length - 1) {
        throw AuthException('无法解析登录页配置：$name');
      }
      final code =
          int.tryParse(literal.substring(i + 1, i + count + 1), radix: 16);
      if (code == null) throw AuthException('无法解析登录页配置：$name');
      output.writeCharCode(code);
      i += count;
    } else {
      throw AuthException('无法解析登录页配置：$name');
    }
  }
  return output.toString();
}

class CimsLoginBootstrap {
  final Uri parentUri;
  final Uri postUri;
  final Uri iframeUri;
  final Uri authBase;
  final List<MapEntry<String, String>> fields;
  final String signatureField;
  final String appSignature;
  final String sign;
  final String appUrl;

  const CimsLoginBootstrap({
    required this.parentUri,
    required this.postUri,
    required this.iframeUri,
    required this.authBase,
    required this.fields,
    required this.signatureField,
    required this.appSignature,
    required this.sign,
    required this.appUrl,
  });

  factory CimsLoginBootstrap.parse(String html, Uri uri) {
    trustedSsoUri(uri);
    final document = html_parser.parse(html);
    final scripts = document
        .querySelectorAll('script:not([src])')
        .map((script) => script.text)
        .join('\n');
    final match = RegExp(r'CIMS\.init\s*\(\s*\{(.*?)\}\s*\)', dotAll: true)
        .firstMatch(scripts);
    if (match == null) {
      throw const AuthException('未找到 CIMS 登录配置，登录入口可能已变化');
    }
    final config = match.group(1)!;
    if (RegExp(r'\bsubmit_callback\s*:').hasMatch(config)) {
      throw const AuthException('登录页使用了尚未支持的自定义提交回调');
    }
    if (_literalOption(config, 'username', '').isNotEmpty) {
      throw const AuthException('本次登录需要二次认证，请在官方页面完成验证');
    }
    final signatures = _literalOption(config, 'sig_request').split(':');
    if (signatures.length != 2 ||
        signatures.any((s) => s.isEmpty) ||
        signatures.first.startsWith('ERR|')) {
      throw const AuthException('服务端未返回有效的初始签名');
    }
    final host =
        _literalOption(config, 'host').replaceFirst(RegExp(r'/+$'), '');
    final authBase = trustedSsoUri(Uri.parse('$host/'));
    final postUri =
        trustedSsoUri(uri.resolve(_literalOption(config, 'postaction')));
    final form = document.getElementById(_literalOption(config, 'formid'));
    if (form == null || form.localName != 'form') {
      throw const AuthException('未找到 CAS 登录表单');
    }
    final fields = form
        .querySelectorAll('input')
        .where((input) =>
            (input.attributes['name'] ?? '').isNotEmpty &&
            input.attributes['type']?.toLowerCase() == 'hidden' &&
            !input.attributes.containsKey('disabled'))
        .map((input) => MapEntry(
              input.attributes['name']!,
              input.attributes['value'] ?? '',
            ))
        .toList();
    if (!fields
        .any((field) => field.key == 'execution' && field.value.isNotEmpty)) {
      throw const AuthException('CAS 登录表单缺少 execution');
    }
    final params = {
      'view': 'frame',
      'type': '0',
      'sign': signatures.first,
      'parent': uri.toString(),
      'version': _literalOption(config, 'version', 'v2'),
      'email': _literalOption(config, 'email', ''),
      'reAuthError': _literalOption(config, 'reAuthError', ''),
    };
    final iframeUri = authBase.resolve('login.html').replace(
          query: params.entries
              .map((e) =>
                  '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
              .join('&'),
        );
    // Match the SDK's query parser and its second decode of parent exactly.
    final query = <String, String>{};
    for (final pair in iframeUri.query.split('&')) {
      final bits = pair.split('=');
      if (bits.first.isNotEmpty) {
        query[bits.first] = bits.length > 1 && bits[1].isNotEmpty
            ? decodeCimsUri(bits[1])
            : 'true';
      }
    }
    final parent = Uri.decodeComponent(query['parent']!);
    final serviceIndex = parent.indexOf('service=');
    return CimsLoginBootstrap(
      parentUri: uri,
      postUri: postUri,
      iframeUri: iframeUri,
      authBase: authBase,
      fields: fields,
      signatureField: _literalOption(config, 'postArgument', 'sig_response'),
      appSignature: signatures.last,
      sign: query['sign']!,
      appUrl: serviceIndex < 0 ? '' : parent.substring(serviceIndex + 8),
    );
  }
}

/// RSA PKCS#1 v1.5 over password|token, matching legacy JSEncrypt's UTF-16
/// code-unit encoding (including separate encodings of surrogate pairs).
String encryptCimsPassword(
    String publicKey, String encryptor, String password, String token) {
  if (encryptor == 'NATIONAL') {
    throw const AuthException('服务端要求 SM2 加密，暂不支持，请使用官方登录页面');
  }
  if (encryptor != 'INTERNATIONAL') {
    throw const AuthException('未知密码加密配置，已停止认证');
  }
  try {
    final compact = publicKey.replaceAll(RegExp(r'-----[^-]+-----|\s+'), '');
    // Both SPKI and PKCS#1 public keys are accepted, including bare DER base64.
    pc.RSAPublicKey? key;
    for (final label in ['PUBLIC KEY', 'RSA PUBLIC KEY']) {
      try {
        key = encrypt.RSAKeyParser().parse(
          '-----BEGIN $label-----\n$compact\n-----END $label-----',
        ) as pc.RSAPublicKey;
        break;
      } catch (_) {
        // Try the other public-key container, never a different algorithm.
      }
    }
    if (key == null) throw const FormatException('Invalid RSA key');
    final bytes = <int>[];
    for (final code in '$password|$token'.codeUnits) {
      if (code < 0x80) {
        bytes.add(code);
      } else if (code < 0x800) {
        bytes.addAll([0xc0 | (code >> 6), 0x80 | (code & 0x3f)]);
      } else {
        bytes.addAll([
          0xe0 | (code >> 12),
          0x80 | ((code >> 6) & 0x3f),
          0x80 | (code & 0x3f)
        ]);
      }
    }
    final cipher = pc.PKCS1Encoding(pc.RSAEngine())
      ..init(true, pc.PublicKeyParameter<pc.RSAPublicKey>(key));
    if (bytes.length > cipher.inputBlockSize) {
      throw const FormatException('RSA plaintext too long');
    }
    return base64Encode(cipher.process(Uint8List.fromList(bytes)));
  } catch (_) {
    throw const AuthException('公钥格式无效，或密码与 token 超过 RSA 单块长度');
  }
}
