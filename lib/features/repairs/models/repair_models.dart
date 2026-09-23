import 'package:flutter/material.dart';

class RepairCatalog {
  final String id;
  final String title;
  final String subtitle;
  final String department;
  final String processId;
  final Color color;
  final IconData icon;
  const RepairCatalog(
      {required this.id,
      required this.title,
      required this.subtitle,
      required this.department,
      required this.processId,
      required this.color,
      required this.icon});
}

class RepairChoice {
  final String id;
  final String label;
  const RepairChoice(this.id, this.label);
}

class RepairField {
  final String name;
  final String label;
  final String editor;
  final bool required;
  final bool hidden;
  final bool readonly;
  final String? referenceType;
  final String? reference;
  final Map<String, dynamic> raw;
  const RepairField(
      {required this.name,
      required this.label,
      required this.editor,
      required this.required,
      required this.hidden,
      required this.readonly,
      this.referenceType,
      this.reference,
      this.raw = const {}});

  bool get isChoice =>
      editor == 'lookup' ||
      editor == 'reference' ||
      editor == 'radiogroup' ||
      editor == 'priority';
  bool get isDate =>
      editor == 'datepicker' ||
      editor == 'datetimepicker' ||
      editor == 'date' ||
      raw['dataType'] == 'DATE' ||
      (!isChoice &&
          (label.contains('日期') || name.toLowerCase().contains('date')));
  bool get isMultiline => editor == 'textarea';
  bool get isUpload =>
      editor == 'upload' ||
      editor == 'image' ||
      editor == 'file' ||
      name == 'scwttp' ||
      name == 'uploadimage' ||
      name == 'zjsmj';
}

class RepairFormSession {
  final RepairCatalog catalog;
  final String instanceId;
  final String ciType;
  final String nodeId;
  final String submitActionId;
  final String? saveDraftActionId;
  final String? formRuleId;
  final List<RepairField> fields;
  final Map<String, dynamic> initialValues;
  const RepairFormSession(
      {required this.catalog,
      required this.instanceId,
      required this.ciType,
      required this.nodeId,
      required this.submitActionId,
      this.saveDraftActionId,
      required this.formRuleId,
      required this.fields,
      required this.initialValues});
}

class RepairActivityLog {
  final String id;
  final String description;
  final String userName;
  final DateTime? time;

  const RepairActivityLog({
    required this.id,
    required this.description,
    required this.userName,
    required this.time,
  });

  factory RepairActivityLog.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v is num) {
        return DateTime.fromMillisecondsSinceEpoch(v.toInt());
      }
      return DateTime.tryParse('$v');
    }

    final user = json['create_user'] ?? json['modify_user'];
    final userName = user is Map
        ? '${user['display_name'] ?? user['name'] ?? ''}'
        : '${user ?? ''}';
    return RepairActivityLog(
      id: '${json['id'] ?? ''}',
      description: '${json['description'] ?? ''}',
      userName: userName,
      time: parseDate(json['create_time'] ?? json['modify_time']),
    );
  }
}

class RepairAttachment {
  final String id;
  final String fileName;
  final String downloadUrl;
  final String? thumbnailUrl;
  final DateTime? createTime;

  const RepairAttachment({
    required this.id,
    required this.fileName,
    required this.downloadUrl,
    this.thumbnailUrl,
    this.createTime,
  });

  factory RepairAttachment.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v is num) {
        return DateTime.fromMillisecondsSinceEpoch(v.toInt());
      }
      return DateTime.tryParse('$v');
    }

    final id = '${json['id'] ?? ''}';
    final thumb = json['thumbnail']?.toString();
    final name = '${json['upload_file_name'] ?? json['display_name'] ?? '附件'}';
    return RepairAttachment(
      id: id,
      fileName: name,
      downloadUrl:
          'https://bxpt.hunau.edu.cn/relax/mobile/rpc?method=/v2/file/download&id=$id',
      thumbnailUrl: thumb != null && thumb.isNotEmpty
          ? (thumb.startsWith('http')
              ? thumb
              : 'https://bxpt.hunau.edu.cn/relax/mobile/$thumb')
          : null,
      createTime: parseDate(json['create_time']),
    );
  }
}

class RepairAction {
  final String id;
  final String name;
  final String displayName;
  final String possessorNode;

  const RepairAction({
    required this.id,
    required this.name,
    required this.displayName,
    required this.possessorNode,
  });

  factory RepairAction.fromJson(Map<String, dynamic> json) {
    return RepairAction(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      displayName: '${json['display_name'] ?? json['name'] ?? ''}',
      possessorNode: '${json['possessor'] ?? ''}',
    );
  }

  bool get isCancel => displayName.contains('取消') || name.contains('取消');
  bool get isSubmit => displayName.contains('提交') || name.contains('提交');
  bool get isSaveDraft => displayName.contains('草稿') || name.contains('草稿');
}

class RepairOrder {
  final String id;
  final String code;
  final String title;
  final String description;
  final String catalog;
  final String status;
  final String statusId;
  final DateTime? createdAt;
  final DateTime? closedAt;
  final String department;
  final String applicant;
  final String applicantDepartment;
  final String phone;
  final String handler;
  final String handlerDepartment;
  final String handleResult;
  final String userResponse;
  final double? score;
  final String supplement;
  final String priority;
  final String currentNode;
  final List<RepairActivityLog> logs;
  final List<RepairAttachment> attachments;
  final List<RepairAction> actions;
  final Map<String, dynamic> raw;

  const RepairOrder({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.catalog,
    required this.status,
    required this.statusId,
    required this.createdAt,
    required this.closedAt,
    required this.department,
    this.applicant = '',
    this.applicantDepartment = '',
    this.phone = '',
    this.handler = '',
    this.handlerDepartment = '',
    this.handleResult = '',
    this.userResponse = '',
    this.score,
    this.supplement = '',
    this.priority = '',
    this.currentNode = '',
    this.logs = const [],
    this.attachments = const [],
    this.actions = const [],
    this.raw = const {},
  });

  String get catalogId {
    final cat = raw['service_catalog'];
    if (cat is Map) return '${cat['id'] ?? ''}';
    return '';
  }

  factory RepairOrder.fromJson(
    Map<String, dynamic> json, {
    List<RepairActivityLog> logs = const [],
    List<RepairAttachment> attachments = const [],
    List<RepairAction> actions = const [],
  }) {
    DateTime? date(dynamic value) {
      if (value is num) {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt());
      }
      return DateTime.tryParse(value?.toString() ?? '');
    }

    String pickString(dynamic val) {
      if (val == null) return '';
      if (val is Map) {
        return '${val['display_name'] ?? val['name'] ?? val['name_path'] ?? ''}';
      }
      return '$val'.trim();
    }

    String pickDescription(Map<String, dynamic> j) {
      for (final key in ['wtmsh', 'apply_description', 'description']) {
        final val = j[key]?.toString().trim() ?? '';
        if (val.isNotEmpty) return val;
      }
      return '';
    }

    final catalogRaw = json['service_catalog'];
    final catalogId = catalogRaw is Map ? '${catalogRaw['id'] ?? ''}' : '';
    String catalogName = pickString(catalogRaw);

    final processRaw = json['process'];
    final processId = processRaw is Map ? '${processRaw['id'] ?? ''}' : '';
    final typeRaw = json['type'];
    final typeName = typeRaw is Map
        ? '${typeRaw['name_path'] ?? typeRaw['display_name'] ?? ''}'
        : '$typeRaw';
    final dynamicTitle = '${json['dynamic_title'] ?? json['title'] ?? ''}';
    final candidateText =
        '$catalogName $catalogId $processId $typeName $dynamicTitle';

    if (catalogId == '5bbbaf0a-b7b7-11eb-b305-4bcc6b2984af' ||
        processId == '4e2cc26d-08b4-4cab-a3a7-fba23a23e11d' ||
        candidateText.contains('后勤')) {
      catalogName = '后勤报修';
    } else if (catalogId == 'b4435ca0-99f6-11ec-bf7a-177427586306' ||
        processId == 'd86a31ef-6e54-4da5-8c8f-a881986ec422' ||
        candidateText.contains('网络') ||
        candidateText.contains('校园网')) {
      catalogName = '校园网络报修';
    } else if (catalogId == 'f11e3e78-9ace-11ec-9f07-f7b2f4ca88d7' ||
        processId == 'aa21a42a-a2f7-48a7-aae6-fc374e4ebc44' ||
        candidateText.contains('一校通') ||
        candidateText.contains('一卡通')) {
      catalogName = '一校通报修';
    } else if (catalogId == 'ffa62964-9539-11ec-a409-0f7763ad71f7' ||
        processId == 'f83a50f6-95f9-41d9-bf27-851f340035a4' ||
        candidateText.contains('业务') ||
        candidateText.contains('信息系统')) {
      catalogName = '业务系统报修';
    }

    final flow = json['flow_status'];
    final process = json['process'];
    final handlerDept = json['actual_handler_department'];
    final applyUser = json['apply_user'];
    final applyDept = json['apply_department'];
    final actualHandler = json['actual_handler'];
    final priority = json['priority_group'];

    return RepairOrder(
      id: '${json['id'] ?? ''}',
      code: '${json['code'] ?? ''}',
      title: '${json['dynamic_title'] ?? json['title'] ?? ''}',
      description: pickDescription(json),
      catalog: catalogName,
      status: pickString(flow).isNotEmpty
          ? pickString(flow)
          : '${json['node_name'] ?? ''}',
      statusId: flow is Map
          ? '${flow['id'] ?? flow['name'] ?? ''}'
          : '${json['node_id'] ?? ''}',
      createdAt: date(json['create_time'] ?? json['start_time']),
      closedAt: date(json['close_time'] ?? json['complete_time']),
      department: pickString(handlerDept).isNotEmpty
          ? pickString(handlerDept)
          : pickString(process),
      applicant: pickString(applyUser).isNotEmpty
          ? pickString(applyUser)
          : '${json['xm'] ?? ''}',
      applicantDepartment: pickString(applyDept),
      phone: '${json['lxfs'] ?? json['phone'] ?? ''}',
      handler: pickString(actualHandler),
      handlerDepartment: pickString(handlerDept),
      handleResult: '${json['chljg'] ?? ''}',
      userResponse: '${json['user_response'] ?? ''}',
      score: json['score'] is num ? (json['score'] as num).toDouble() : null,
      supplement: '${json['bchshm'] ?? ''}',
      priority: pickString(priority),
      currentNode: '${json['node_name'] ?? ''}',
      logs: logs,
      attachments: attachments,
      actions: actions,
      raw: json,
    );
  }

  RepairOrder copyWith({
    String? id,
    String? code,
    String? title,
    String? description,
    String? catalog,
    String? status,
    String? statusId,
    DateTime? createdAt,
    DateTime? closedAt,
    String? department,
    String? applicant,
    String? applicantDepartment,
    String? phone,
    String? handler,
    String? handlerDepartment,
    String? handleResult,
    String? userResponse,
    double? score,
    String? supplement,
    String? priority,
    String? currentNode,
    List<RepairActivityLog>? logs,
    List<RepairAttachment>? attachments,
    List<RepairAction>? actions,
    Map<String, dynamic>? raw,
  }) {
    return RepairOrder(
      id: id ?? this.id,
      code: code ?? this.code,
      title: title ?? this.title,
      description: description ?? this.description,
      catalog: catalog ?? this.catalog,
      status: status ?? this.status,
      statusId: statusId ?? this.statusId,
      createdAt: createdAt ?? this.createdAt,
      closedAt: closedAt ?? this.closedAt,
      department: department ?? this.department,
      applicant: applicant ?? this.applicant,
      applicantDepartment: applicantDepartment ?? this.applicantDepartment,
      phone: phone ?? this.phone,
      handler: handler ?? this.handler,
      handlerDepartment: handlerDepartment ?? this.handlerDepartment,
      handleResult: handleResult ?? this.handleResult,
      userResponse: userResponse ?? this.userResponse,
      score: score ?? this.score,
      supplement: supplement ?? this.supplement,
      priority: priority ?? this.priority,
      currentNode: currentNode ?? this.currentNode,
      logs: logs ?? this.logs,
      attachments: attachments ?? this.attachments,
      actions: actions ?? this.actions,
      raw: raw ?? this.raw,
    );
  }

  bool get isDone =>
      statusId == 'CLOSED' || status.contains('完成') || status.contains('办结');
  bool get isDraft =>
      statusId == 'NEW' || status == 'NEW' || status.contains('草稿');
  bool get canCancel => actions.any((a) => a.isCancel);
}
