import 'package:flutter/widgets.dart';
import 'package:html/parser.dart' as html;
import '../../../core/utils/l10n_extension.dart';

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
  final String id;
  final String title;
  final String department;
  final String type;
  final String date;
  final String status;

  SunshineLetter({
    this.id = '',
    required this.title,
    required this.department,
    required this.type,
    required this.date,
    required this.status,
  });

  SunshineLetter.fromJson(Map<String, dynamic> json)
      : id = (json['ID'] ?? '').toString(),
        title = (json['Title'] ?? '').toString(),
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

class SunshineTicketDetail {
  final String id;
  final String title;
  final String submitter;
  final String rawSubmitter;
  final String expectedDepartment;
  final String handlingDepartment;
  final String finishTime;
  final String jieTime;
  final String wanTime;
  final String status;
  final String content;
  final String remark;
  final String type;
  final String sex;

  const SunshineTicketDetail({
    this.id = '',
    required this.title,
    required this.submitter,
    this.rawSubmitter = '',
    this.expectedDepartment = '',
    this.handlingDepartment = '',
    this.finishTime = '',
    this.jieTime = '',
    this.wanTime = '',
    this.status = '',
    this.content = '',
    this.remark = '',
    this.type = '',
    this.sex = '',
  });

  factory SunshineTicketDetail.fromJson(Map<String, dynamic> json, {String id = ''}) {
    final rawName = (json['LinkName'] ?? '').toString();
    return SunshineTicketDetail(
      id: id.isNotEmpty ? id : (json['ID'] ?? '').toString(),
      title: (json['Title'] ?? '').toString(),
      submitter: extractSurname(rawName),
      rawSubmitter: rawName,
      expectedDepartment: (json['DepName'] ?? '').toString(),
      handlingDepartment: (json['CirDepName'] ?? '').toString(),
      finishTime: (json['FinishTime'] ?? '').toString(),
      jieTime: (json['JieTime'] ?? '').toString(),
      wanTime: (json['WanTime'] ?? '').toString(),
      status: (json['Status'] ?? '').toString(),
      content: (json['Content'] ?? '').toString(),
      remark: (json['Remark'] ?? '').toString(),
      type: (json['bTypeName'] ?? '').toString(),
      sex: (json['Sex'] ?? '').toString(),
    );
  }

  /// 仅保留提交人姓氏（兼容常见复姓与单姓，单字或空值安全）
  static String extractSurname(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return '';
    const compoundSurnames = {
      '欧阳', '诸葛', '司马', '上官', '皇甫', '司徒', '司空', '夏侯',
      '东方', '澹台', '公孙', '慕容', '尉迟', '宇文', '独孤', '南宫',
      '万俟', '闻人', '申屠', '赫连', '濮阳', '公羊', '淳于', '单于',
      '太史', '端木', '仲孙', '钟离', '长孙',
    };
    if (trimmed.length >= 2) {
      final prefix = trimmed.substring(0, 2);
      if (compoundSurnames.contains(prefix)) {
        return prefix;
      }
    }
    return trimmed.substring(0, 1);
  }

  String get statusLabel => switch (status) {
        '0' || '1' => '办理中',
        '2' => '已办结',
        _ => '状态未知',
      };

  bool get isCompleted => status == '2';
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

extension SunshineLetterL10n on SunshineLetter {
  String getLocalizedStatus(BuildContext context) => switch (status) {
        '0' || '1' => context.l10n.statusInProgress,
        '2' => context.l10n.statusResolved,
        _ => context.l10n.statusUnknown,
      };
}

extension SunshineTicketDetailL10n on SunshineTicketDetail {
  String getLocalizedStatus(BuildContext context) => switch (status) {
        '0' || '1' => context.l10n.statusInProgress,
        '2' => context.l10n.statusResolved,
        _ => context.l10n.statusUnknown,
      };
}
