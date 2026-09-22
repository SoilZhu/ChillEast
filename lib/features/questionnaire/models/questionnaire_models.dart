import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../../../core/utils/l10n_extension.dart';

/// 学工问卷列表项
/// 字段来自 HAR: content/tabledata/fwk/wjdc/stu/xs_wjdc 的 aaData
@immutable
class QuestionnaireItem {
  final String dm;
  final String title;
  final String startTime;
  final String endTime;
  final String taskTimeM;
  final String doneInd;
  final String flag;
  final String zt;
  final String shzt;

  const QuestionnaireItem({
    required this.dm,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.taskTimeM,
    this.doneInd = '',
    this.flag = '',
    this.zt = '',
    this.shzt = '',
  });

  factory QuestionnaireItem.fromJson(Map<String, dynamic> json) {
    return QuestionnaireItem(
      dm: (json['DM'] ?? '').toString(),
      title: (json['MC'] ?? '').toString(),
      startTime: (json['KSSJ'] ?? '').toString(),
      endTime: (json['JSSJ'] ?? '').toString(),
      taskTimeM: (json['TASK_TIME_M'] ?? '').toString(),
      doneInd: (json['DONE_IND'] ?? '').toString(),
      flag: (json['FLAG'] ?? '').toString(),
      zt: (json['ZT'] ?? '').toString(),
      shzt: (json['SHZT'] ?? '').toString(),
    );
  }

  bool get isSubmitted => zt == '1' || shzt == '1' || doneInd == '1';

  bool get isExpired {
    if (endTime.isEmpty) return false;
    try {
      final end = DateTime.parse(endTime);
      return DateTime.now().isAfter(end);
    } catch (_) {
      return false;
    }
  }

  String get statusLabel {
    if (isSubmitted) return '已提交';
    if (isExpired) return '已截止';
    return '待填写';
  }

  String get timeRange {
    final start = startTime.isEmpty ? '' : startTime.split(' ').first;
    final end = endTime.isEmpty ? '' : endTime.split(' ').first;
    if (start.isEmpty && end.isEmpty) return '';
    return '$start ~ $end';
  }
}

/// 问卷选项
@immutable
class QuestionnaireOption {
  final String dm;
  final String name;

  const QuestionnaireOption({required this.dm, required this.name});

  factory QuestionnaireOption.fromJson(Map<String, dynamic> json) {
    return QuestionnaireOption(
      dm: (json['dm'] ?? '').toString(),
      name: (json['mc'] ?? '').toString(),
    );
  }
}

/// 问卷题目
/// stType: 1=单选 2=多选 4=填空(观察 HAR 得出)
/// txType(填空): 1=文本 2=数字/电话 3/4=日期
@immutable
class QuestionnaireQuestion {
  final String dm;
  final String title;
  final String desc;
  final String stType;
  final String txType;
  final bool required;
  final List<QuestionnaireOption> options;
  final String answer;

  const QuestionnaireQuestion({
    required this.dm,
    required this.title,
    this.desc = '',
    this.stType = '',
    this.txType = '',
    this.required = false,
    this.options = const [],
    this.answer = '',
  });

  factory QuestionnaireQuestion.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['stxxList'];
    return QuestionnaireQuestion(
      dm: (json['dm'] ?? '').toString(),
      title: (json['stmc'] ?? '').toString(),
      desc: (json['stsm'] ?? '').toString(),
      stType: (json['stType'] ?? '').toString(),
      txType: (json['txType'] ?? '').toString(),
      required: (json['btInd'] ?? '').toString() == '1',
      answer: (json['jg'] ?? '').toString(),
      options: rawOptions is List
          ? rawOptions
              .whereType<Map<String, dynamic>>()
              .map(QuestionnaireOption.fromJson)
              .toList()
          : const [],
    );
  }

  bool get isChoice => options.isNotEmpty || stType == '1' || stType == '2';
  bool get isMultiChoice => stType == '2';
  bool get isDate => stType == '4' && (txType == '3' || txType == '4');
  bool get isPhone => stType == '4' && txType == '2';
}

/// 问卷详情 (答题页数据)
/// 接口: content/json/fwk/wjdc/stu/ks_sj/sjvo?tasktime=xxx
@immutable
class QuestionnaireDetail {
  final String dm;
  final String title;
  final String desc;
  final String jgM;
  final bool canSubmit;
  final List<QuestionnaireQuestion> questions;

  const QuestionnaireDetail({
    required this.dm,
    required this.title,
    this.desc = '',
    required this.jgM,
    this.canSubmit = true,
    this.questions = const [],
  });

  factory QuestionnaireDetail.fromJson(Map<String, dynamic> json) {
    final rawList = json['stList'];
    return QuestionnaireDetail(
      dm: (json['dm'] ?? '').toString(),
      title: (json['mc'] ?? json['sm'] ?? '').toString(),
      desc: (json['sm'] ?? json['bz'] ?? '').toString(),
      jgM: (json['jgM'] ?? '').toString(),
      canSubmit: (json['canSubmit'] ?? '1').toString() == '1',
      questions: rawList is List
          ? rawList
              .whereType<Map<String, dynamic>>()
              .map(QuestionnaireQuestion.fromJson)
              .toList()
          : const [],
    );
  }
}

extension QuestionnaireItemL10n on QuestionnaireItem {
  String getLocalizedStatus(BuildContext context) {
    if (isSubmitted) return context.l10n.statusSubmitted;
    if (isExpired) return context.l10n.statusExpired;
    return context.l10n.statusPendingFill;
  }
}
