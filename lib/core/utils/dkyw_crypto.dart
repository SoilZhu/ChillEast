import 'dart:convert';
import 'dart:math';
import 'package:encrypt/encrypt.dart';

/// 湖南农业大学一卡通财务服务平台 (dkyw.js) 动态 AES 加解密工具类
class DkywCrypto {
  static const _chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

  /// 生成指定长度 (默认 16 位) 的随机 AES 密钥
  static String genKey([int length = 16]) {
    final random = Random();
    return List.generate(length, (_) => _chars[random.nextInt(_chars.length)]).join();
  }

  /// 对应前端 my-encryption.js 中的 handleKey 移位与字符反转逻辑
  static String handleKey(String key, bool isEncrypt) {
    if (isEncrypt) {
      // 0x288de ^ 0x288d4 = 10
      final rotated = key.substring(10) + key.substring(0, 10);
      return rotated.split('').reversed.join('');
    } else {
      // 0x59183 ^ 0x59185 = 6
      final reversed = key.split('').reversed.join('');
      return reversed.substring(6) + reversed.substring(0, 6);
    }
  }

  /// 请求加密：将对象或 JSON 字符串加密为 '16位编码后Key + Base64密文'
  static String encryptPayload(dynamic data) {
    final jsonStr = data is String ? data : jsonEncode(data);
    final keyStr = genKey(16);
    final key = Key.fromUtf8(keyStr);
    final encrypter = Encrypter(AES(key, mode: AESMode.ecb, padding: 'PKCS7'));
    final encrypted = encrypter.encrypt(jsonStr);
    final handledKey = handleKey(keyStr, true);
    return handledKey + encrypted.base64;
  }

  /// 响应解密：解析前 16 位 Key 并对密文执行 AES 解密，返回解码后的 Map/List/Object
  static dynamic decryptPayload(String datajson) {
    if (datajson.length <= 16) return datajson;
    final keyPart = datajson.substring(0, 16);
    final cipherPart = datajson.substring(16);
    final realKey = handleKey(keyPart, false);
    final key = Key.fromUtf8(realKey);
    final encrypter = Encrypter(AES(key, mode: AESMode.ecb, padding: 'PKCS7'));
    final decryptedStr = encrypter.decrypt(Encrypted.fromBase64(cipherPart));
    try {
      return jsonDecode(decryptedStr);
    } catch (_) {
      return decryptedStr;
    }
  }

  /// 从服务器原始响应中解密数据
  /// 兼容：
  /// 1. 标准 Map: {'datajson': '...'}
  /// 2. 标准 JSON 字符串: '{"datajson": "..."}'
  /// 3. HTML 转义字符串 (createPreThirdTrade 常见格式): '"{&quot;datajson&quot;:&quot;...&quot;}"'
  /// 4. 其它带引号包裹或格式异常的字符串
  static dynamic decryptServerResponse(dynamic responseData) {
    if (responseData == null) return null;

    // 1. 如果已经是 Map 且包含 datajson
    if (responseData is Map) {
      if (responseData.containsKey('datajson')) {
        final decrypted = decryptPayload(responseData['datajson'].toString());
        if (decrypted is String) {
          try {
            return jsonDecode(decrypted);
          } catch (_) {}
        }
        return decrypted;
      }
      return responseData;
    }

    // 2. 如果是 String
    if (responseData is String) {
      String raw = responseData.trim();
      // 处理外层可能包裹的多余引号
      if (raw.startsWith('"') && raw.endsWith('"') && raw.length > 2) {
        try {
          raw = jsonDecode(raw);
        } catch (_) {
          raw = raw.substring(1, raw.length - 1);
        }
      }

      // 处理 HTML 转义符号 &quot;
      if (raw.contains('&quot;')) {
        raw = raw.replaceAll('&quot;', '"');
      }

      // 尝试标准 JSON 反序列化
      try {
        final parsed = jsonDecode(raw);
        if (parsed is Map) {
          return decryptServerResponse(parsed);
        }
      } catch (_) {}

      // 如果反序列化仍未成功，使用正则表达式直接捕获 datajson 密文
      final match = RegExp(r'datajson["\x27]?\s*[:=]\s*["\x27]?([A-Za-z0-9+/=]+)').firstMatch(raw);
      if (match != null) {
        final cipher = match.group(1);
        if (cipher != null && cipher.isNotEmpty) {
          final decrypted = decryptPayload(cipher);
          if (decrypted is String) {
            try {
              return jsonDecode(decrypted);
            } catch (_) {}
          }
          return decrypted;
        }
      }
    }

    return responseData;
  }
}
