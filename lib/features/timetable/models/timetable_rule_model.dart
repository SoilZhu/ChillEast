import 'package:flutter/widgets.dart';
import '../../../core/utils/l10n_extension.dart';
import 'course_model.dart';

/// 课表规则类型
enum TimetableRuleType {
  /// 调休 (周次/星期挪移或对调)
  reschedule,

  /// 停课 (暂停特定周次/星期或单门课程)
  suspension,

  /// 手动添加课程 (自定义添加课程)
  customCourse,
}

/// 课表自定义规则模型
class TimetableRule {
  final String id;
  final TimetableRuleType type;
  final String description;
  final DateTime createdAt;
  final Map<String, dynamic> data;

  const TimetableRule({
    required this.id,
    required this.type,
    required this.description,
    required this.createdAt,
    required this.data,
  });

  /// 创建调休/调课规则
  factory TimetableRule.createReschedule({
    String? id,
    required int sourceWeek,
    required int sourceDayOfWeek,
    required int targetWeek,
    required int targetDayOfWeek,
    String? courseName,
    int? sourceStartPeriod,
    int? sourceEndPeriod,
    int? targetStartPeriod,
    int? targetEndPeriod,
    bool isSwap = false,
    String? action,
  }) {
    final ruleId =
        id ?? 'rule_reschedule_${DateTime.now().millisecondsSinceEpoch}';
    final effectiveAction = action ?? (isSwap ? 'swap' : 'move');
    final effectiveIsSwap = effectiveAction == 'swap' || isSwap;
    final weekdayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final sourceStr = '第$sourceWeek周${weekdayNames[sourceDayOfWeek]}';
    final targetStr = '第$targetWeek周${weekdayNames[targetDayOfWeek]}';
    final courseStr = (courseName != null && courseName.trim().isNotEmpty)
        ? '《${courseName.trim()}》'
        : '';

    final String desc;
    if (targetStartPeriod != null && targetEndPeriod != null) {
      final sPeriodStr = (sourceStartPeriod != null && sourceEndPeriod != null)
          ? '$sourceStartPeriod-$sourceEndPeriod节'
          : '';
      final tPeriodStr = '$targetStartPeriod-$targetEndPeriod节';
      desc = '$courseStr$sourceStr$sPeriodStr → $targetStr$tPeriodStr';
    } else {
      final String modeStr;
      if (effectiveAction == 'copy') {
        modeStr = '（复制）';
      } else if (effectiveAction == 'swap') {
        modeStr = '（对调）';
      } else {
        modeStr = '（平移）';
      }
      desc = '$courseStr$sourceStr → $targetStr$modeStr';
    }

    return TimetableRule(
      id: ruleId,
      type: TimetableRuleType.reschedule,
      description: desc,
      createdAt: DateTime.now(),
      data: {
        'sourceWeek': sourceWeek,
        'sourceDayOfWeek': sourceDayOfWeek,
        'targetWeek': targetWeek,
        'targetDayOfWeek': targetDayOfWeek,
        'courseName': courseName,
        'sourceStartPeriod': sourceStartPeriod,
        'sourceEndPeriod': sourceEndPeriod,
        'targetStartPeriod': targetStartPeriod,
        'targetEndPeriod': targetEndPeriod,
        'isSwap': effectiveIsSwap,
        'action': effectiveAction,
      },
    );
  }

  /// 创建停课规则
  factory TimetableRule.createSuspension({
    String? id,
    required int startWeek,
    required int endWeek,
    int? dayOfWeek,
    int? startDayOfWeek,
    int? endDayOfWeek,
    String? courseName,
    int? startPeriod,
    int? endPeriod,
  }) {
    final ruleId =
        id ?? 'rule_suspension_${DateTime.now().millisecondsSinceEpoch}';
    final weekdayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];

    final sDay = startDayOfWeek ?? dayOfWeek ?? 1;
    final eDay = endDayOfWeek ?? dayOfWeek ?? 7;

    final String rangeStr;
    if (sDay == 1 && eDay == 7) {
      rangeStr =
          startWeek == endWeek ? '第$startWeek周' : '第$startWeek-$endWeek周';
    } else if (startWeek == endWeek && sDay == eDay) {
      rangeStr = '第$startWeek周${weekdayNames[sDay]}';
    } else if (startWeek == endWeek) {
      rangeStr = '第$startWeek周${weekdayNames[sDay]}至${weekdayNames[eDay]}';
    } else {
      rangeStr =
          '第$startWeek周${weekdayNames[sDay]}至第$endWeek周${weekdayNames[eDay]}';
    }

    final courseStr = (courseName != null && courseName.trim().isNotEmpty)
        ? '《${courseName.trim()}》'
        : '';
    final periodStr = (startPeriod != null && endPeriod != null)
        ? ' $startPeriod-$endPeriod节'
        : '';
    final desc = '$courseStr$rangeStr$periodStr停课';

    return TimetableRule(
      id: ruleId,
      type: TimetableRuleType.suspension,
      description: desc,
      createdAt: DateTime.now(),
      data: {
        'startWeek': startWeek,
        'endWeek': endWeek,
        'dayOfWeek': dayOfWeek ?? (sDay == eDay ? sDay : null),
        'startDayOfWeek': sDay,
        'endDayOfWeek': eDay,
        'courseName': courseName,
        'startPeriod': startPeriod,
        'endPeriod': endPeriod,
      },
    );
  }

  /// 创建手动添加课程规则
  factory TimetableRule.createCustomCourse({
    String? id,
    required CourseModel course,
  }) {
    final ruleId = id ?? 'rule_custom_${DateTime.now().millisecondsSinceEpoch}';
    final weekdayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final dayStr = (course.dayOfWeek >= 1 && course.dayOfWeek <= 7)
        ? weekdayNames[course.dayOfWeek]
        : '';
    final weeksStr = course.weeks.replaceAll('(周)', '周');
    final desc =
        '加课：${course.name}（$dayStr${course.startPeriod}-${course.endPeriod}节 $weeksStr）';

    return TimetableRule(
      id: ruleId,
      type: TimetableRuleType.customCourse,
      description: desc,
      createdAt: DateTime.now(),
      data: {
        'course': course.toJson(),
      },
    );
  }

  factory TimetableRule.fromJson(Map<String, dynamic> json) {
    return TimetableRule(
      id: json['id'] as String,
      type: TimetableRuleType.values.byName(json['type'] as String),
      description: json['description'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      data: Map<String, dynamic>.from(json['data'] as Map),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'data': data,
    };
  }

  /// 获取包含的自定义课程 (仅当 type == customCourse 时有效)
  CourseModel? get customCourse {
    if (type != TimetableRuleType.customCourse) return null;
    final courseMap = data['course'];
    if (courseMap is Map<String, dynamic>) {
      return CourseModel.fromJson(courseMap);
    }
    return null;
  }
}

extension TimetableRuleL10n on TimetableRule {
  String getLocalizedDescription(BuildContext context) {
    String getWeekdayName(int d) {
      switch (d) {
        case 1:
          return context.l10n.weekdayMon;
        case 2:
          return context.l10n.weekdayTue;
        case 3:
          return context.l10n.weekdayWed;
        case 4:
          return context.l10n.weekdayThu;
        case 5:
          return context.l10n.weekdayFri;
        case 6:
          return context.l10n.weekdaySat;
        case 7:
          return context.l10n.weekdaySun;
        default:
          return '';
      }
    }

    try {
      if (type == TimetableRuleType.reschedule) {
        final sourceWeek = data['sourceWeek'] as int?;
        final sourceDay = data['sourceDayOfWeek'] as int?;
        final targetWeek = data['targetWeek'] as int?;
        final targetDay = data['targetDayOfWeek'] as int?;
        final courseName = data['courseName'] as String?;
        final sStart = data['sourceStartPeriod'] as int?;
        final sEnd = data['sourceEndPeriod'] as int?;
        final tStart = data['targetStartPeriod'] as int?;
        final tEnd = data['targetEndPeriod'] as int?;
        final action = data['action'] as String?;
        final isSwap = data['isSwap'] == true;

        if (sourceWeek != null &&
            sourceDay != null &&
            targetWeek != null &&
            targetDay != null) {
          final sStr =
              '${context.l10n.weekNumber(sourceWeek)}${getWeekdayName(sourceDay)}';
          final tStr =
              '${context.l10n.weekNumber(targetWeek)}${getWeekdayName(targetDay)}';
          final cStr = (courseName != null && courseName.trim().isNotEmpty)
              ? '《${courseName.trim()}》'
              : '';

          if (tStart != null && tEnd != null) {
            final sP = (sStart != null && sEnd != null)
                ? ' (${context.l10n.periodsRange(sStart, sEnd)})'
                : '';
            final tP = ' (${context.l10n.periodsRange(tStart, tEnd)})';
            return '$cStr$sStr$sP → $tStr$tP';
          } else {
            final effAction = action ?? (isSwap ? 'swap' : 'move');
            final modeStr = effAction == 'copy'
                ? ' (${context.l10n.ruleModeCopy})'
                : (effAction == 'swap'
                    ? ' (${context.l10n.ruleModeSwap})'
                    : ' (${context.l10n.ruleModeShift})');
            return '$cStr$sStr → $tStr$modeStr';
          }
        }
      } else if (type == TimetableRuleType.suspension) {
        final sWeek = data['startWeek'] as int?;
        final eWeek = data['endWeek'] as int?;
        final sDay = data['startDayOfWeek'] as int?;
        final eDay = data['endDayOfWeek'] as int?;
        final courseName = data['courseName'] as String?;
        final sPeriod = data['startPeriod'] as int?;
        final ePeriod = data['endPeriod'] as int?;

        if (sWeek != null && eWeek != null) {
          final cStr = (courseName != null && courseName.trim().isNotEmpty)
              ? '《${courseName.trim()}》'
              : '';
          final String rangeStr;
          if (sDay == null || eDay == null) {
            rangeStr = sWeek == eWeek
                ? context.l10n.weekNumber(sWeek)
                : '${context.l10n.weekNumber(sWeek)}-${context.l10n.weekNumber(eWeek)}';
          } else if (sWeek == eWeek && sDay == eDay) {
            rangeStr =
                '${context.l10n.weekNumber(sWeek)}${getWeekdayName(sDay)}';
          } else if (sWeek == eWeek) {
            rangeStr =
                '${context.l10n.weekNumber(sWeek)}${getWeekdayName(sDay)}-${getWeekdayName(eDay)}';
          } else {
            rangeStr =
                '${context.l10n.weekNumber(sWeek)}${getWeekdayName(sDay)} - ${context.l10n.weekNumber(eWeek)}${getWeekdayName(eDay)}';
          }
          final pStr = (sPeriod != null && ePeriod != null)
              ? ' ${context.l10n.periodsRange(sPeriod, ePeriod)}'
              : '';
          return '$cStr$rangeStr$pStr ${context.l10n.ruleTypeSuspension}';
        }
      } else if (type == TimetableRuleType.customCourse) {
        final courseJson = data['course'];
        if (courseJson is Map<String, dynamic>) {
          final c = CourseModel.fromJson(courseJson);
          final dayStr = getWeekdayName(c.dayOfWeek);
          final periodStr =
              context.l10n.periodsRange(c.startPeriod, c.endPeriod);
          return '${context.l10n.ruleTypeAddCourse}: ${c.name} ($dayStr $periodStr ${c.weeks})';
        }
      }
    } catch (_) {}

    return description;
  }
}
