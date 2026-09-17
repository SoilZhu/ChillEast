import 'package:html/parser.dart' as html;

class SunshineStatistics {
  final String total;
  final String processing;
  final String completed;

  const SunshineStatistics(this.total, this.processing, this.completed);

  factory SunshineStatistics.fromJson(Map<String, dynamic> json) =>
      SunshineStatistics(_count(json['TCount']), _count(json['ZCount']),
          _count(json['YCount']));

  static String _count(dynamic value) {
    final count = int.tryParse(value.toString());
    if (count == null || count < 0) throw const FormatException('统计数据格式异常');
    return count.toString();
  }
}

class SunshineLetter {
  final String title;
  final String department;
  final String type;
  final String date;
  final String status;

  SunshineLetter.fromJson(Map<String, dynamic> json)
      : title = (json['Title'] ?? '').toString(),
        department = (json['CirDepName'] ?? '').toString(),
        type = (json['bTypeName'] ?? '').toString(),
        date = (json['AddTime'] ?? '').toString().split(' ').first,
        status = (json['Status'] ?? '').toString();

  String get statusLabel => switch (status) {
        '0' || '1' => '办理中',
        '2' => '已办结',
        _ => '状态未知',
      };
}

class SunshineDepartment {
  final String code;
  final String name;
  const SunshineDepartment(this.code, this.name);

  factory SunshineDepartment.fromJson(Map<String, dynamic> json) =>
      SunshineDepartment((json['Company_code'] ?? '').toString(),
          (json['Company_name'] ?? '').toString());
}

/// 身份字段只从当前会话的表单读取，不持久化抓包中的身份或 Cookie。
class SunshineIdentity {
  final String cardCode;
  final String name;
  final String phone;
  final String email;
  const SunshineIdentity(this.cardCode, this.name, this.phone, this.email);

  static SunshineIdentity? fromHtml(String source) {
    final document = html.parse(source);
    String value(String id) =>
        document.getElementById(id)?.attributes['value']?.trim() ?? '';
    final cardCode = value('h_CardCode');
    final name = value('UserName');
    if (cardCode.isEmpty || name.isEmpty) return null;
    return SunshineIdentity(cardCode, name, value('telPhone'), value('email'));
  }
}

class SunshineFormData {
  final SunshineIdentity identity;
  final List<SunshineDepartment> departments;
  const SunshineFormData(this.identity, this.departments);
}
