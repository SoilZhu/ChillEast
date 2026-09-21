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
    String? courseName,
    int? startPeriod,
    int? endPeriod,
  }) {
    final ruleId =
        id ?? 'rule_suspension_${DateTime.now().millisecondsSinceEpoch}';
    final weekdayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final weekStr =
        startWeek == endWeek ? '第$startWeek周' : '第$startWeek-$endWeek周';
    final dayStr = (dayOfWeek != null && dayOfWeek >= 1 && dayOfWeek <= 7)
        ? weekdayNames[dayOfWeek]
        : '';
    final courseStr = (courseName != null && courseName.trim().isNotEmpty)
        ? '《${courseName.trim()}》'
        : '';
    final periodStr = (startPeriod != null && endPeriod != null)
        ? ' $startPeriod-$endPeriod节'
        : '';
    final desc = '$courseStr$weekStr$dayStr$periodStr停课';

    return TimetableRule(
      id: ruleId,
      type: TimetableRuleType.suspension,
      description: desc,
      createdAt: DateTime.now(),
      data: {
        'startWeek': startWeek,
        'endWeek': endWeek,
        'dayOfWeek': dayOfWeek,
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
