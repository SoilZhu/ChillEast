import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../../../core/utils/l10n_extension.dart';

/// 请假记录
/// 字段来自 HAR: content/tabledata/student/leave/apply_stu 的 aaData
@immutable
class LeaveRecord {
  final String id;
  final String typeName;
  final String startTime;
  final String endTime;
  final int days;
  final int hours;
  final String reason;
  final String auditStatus;
  final String auditStatusName;
  final String auditResultName;
  final bool hasFile;

  const LeaveRecord({
    required this.id,
    required this.typeName,
    required this.startTime,
    required this.endTime,
    this.days = 0,
    this.hours = 0,
    this.reason = '',
    this.auditStatus = '',
    this.auditStatusName = '',
    this.auditResultName = '',
    this.hasFile = false,
  });

  static int _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  factory LeaveRecord.fromJson(Map<String, dynamic> json) {
    return LeaveRecord(
      id: (json['ID'] ?? '').toString(),
      typeName: (json['LXMC'] ?? '').toString(),
      startTime: (json['KSSJ'] ?? '').toString(),
      endTime: (json['JSSJ'] ?? '').toString(),
      days: _toInt(json['TS']),
      hours: _toInt(json['HOUR']),
      reason: (json['QJSY'] ?? '').toString(),
      auditStatus: (json['SHZT'] ?? '').toString(),
      auditStatusName: (json['SHZTMC'] ?? '').toString(),
      auditResultName: (json['SHJGMC'] ?? '').toString(),
      hasFile: (json['HAS_FILE'] ?? '').toString() == '1',
    );
  }

  /// 状态文案：优先用服务端下发的 SHZTMC
  String get statusLabel {
    if (auditStatusName.isNotEmpty) {
      if (auditStatus == '9' && auditResultName.isNotEmpty) {
        return '$auditStatusName·$auditResultName';
      }
      return auditStatusName;
    }
    return switch (auditStatus) {
      '0' => '待审核',
      '8' => '审核中',
      '9' => auditResultName.isNotEmpty ? '已审核·$auditResultName' : '已审核',
      _ => '状态未知',
    };
  }

  /// 仅待审核允许撤销（HAR 验证过删待审核单）
  bool get canDelete => auditStatus == '0';

  String get durationLabel {
    final parts = <String>[];
    if (days > 0) parts.add('$days天');
    if (hours > 0) parts.add('$hours小时');
    if (parts.isEmpty) return '';
    return parts.join('');
  }

  String get timeRange {
    if (startTime.isEmpty || endTime.isEmpty) return '';
    return '$startTime ~ $endTime';
  }
}

/// 下拉字典项（请假类别等，selects 接口 id/text 结构）
@immutable
class LeaveDictItem {
  final String id;
  final String name;

  const LeaveDictItem({required this.id, required this.name});

  factory LeaveDictItem.fromJson(Map<String, dynamic> json) {
    return LeaveDictItem(
      id: (json['id'] ?? '').toString(),
      name: (json['text'] ?? '').toString(),
    );
  }
}

/// 省市县节点（ssx 接口 id/text/children 三层结构）
@immutable
class RegionNode {
  final String id;
  final String name;
  final List<RegionNode> children;

  const RegionNode({
    required this.id,
    required this.name,
    this.children = const [],
  });

  factory RegionNode.fromJson(Map<String, dynamic> json) {
    final rawChildren = json['children'];
    return RegionNode(
      id: (json['id'] ?? '').toString(),
      name: (json['text'] ?? '').toString(),
      children: rawChildren is List
          ? rawChildren
              .whereType<Map<String, dynamic>>()
              .map(RegionNode.fromJson)
              .toList()
          : const [],
    );
  }
}

/// 算时长结果（calculate 接口 {day, hour}）
@immutable
class LeaveDuration {
  final int days;
  final int hours;

  const LeaveDuration({this.days = 0, this.hours = 0});

  factory LeaveDuration.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
    return LeaveDuration(days: toInt(json['day']), hours: toInt(json['hour']));
  }
}

/// 请假单详情（GET apply_stu/{id}，字段缺失时容错展示）
@immutable
class LeaveDetail {
  final Map<String, dynamic> raw;

  const LeaveDetail(this.raw);

  String operator [](String key) => (raw[key] ?? '').toString();

  factory LeaveDetail.fromJson(Map<String, dynamic> json) =>
      LeaveDetail(Map<String, dynamic>.from(json));
}

extension LeaveRecordL10n on LeaveRecord {
  String getLocalizedStatus(BuildContext context) {
    if (auditStatus == '0') return context.l10n.statusPendingAudit;
    if (auditStatus == '8') return context.l10n.statusAuditing;
    if (auditStatus == '9') {
      if (auditResultName.isNotEmpty) {
        return '${context.l10n.statusAudited} · $auditResultName';
      }
      return context.l10n.statusAudited;
    }
    if (auditStatusName.isNotEmpty) {
      if (auditStatusName == '待审核') return context.l10n.statusPendingAudit;
      if (auditStatusName == '审核中') return context.l10n.statusAuditing;
      if (auditStatusName == '已审核') {
        return auditResultName.isNotEmpty
            ? '${context.l10n.statusAudited} · $auditResultName'
            : context.l10n.statusAudited;
      }
      return auditStatusName;
    }
    return context.l10n.statusUnknown;
  }

  String getLocalizedDuration(BuildContext context) {
    final parts = <String>[];
    if (days > 0) parts.add(context.l10n.durationDays(days.toString()));
    if (hours > 0) parts.add(context.l10n.durationHours(hours.toString()));
    if (parts.isEmpty) return '';
    return parts.join(' ');
  }
}

