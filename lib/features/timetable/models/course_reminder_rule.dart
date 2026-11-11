/// 课程提醒的生效作用范围
enum ReminderScope {
  /// 仅本次课 (需指定 week, dayOfWeek, startPeriod)
  onlyThis,

  /// 该课程所有在周几的课 (需指定 dayOfWeek)
  thisWeekday,

  /// 该课程在本周所有的课 (需指定 week)
  thisWeek,

  /// 该课程全学期所有的课
  all;

  String toJson() => name;

  static ReminderScope fromJson(String value) {
    return ReminderScope.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ReminderScope.all,
    );
  }
}

/// 提醒动作类型
enum ReminderActionType {
  /// 时间偏移提醒 (offsetMinutes: 负数表示提前，正数表示延后，0为准时)
  offset,

  /// 单独关闭/禁用此范围的提醒
  disable;

  String toJson() => name;

  static ReminderActionType fromJson(String value) {
    return ReminderActionType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ReminderActionType.offset,
    );
  }
}

/// 提醒偏移的基准时间
enum ReminderBaseTime {
  /// 相对于应用设置里的默认提前提醒时间 (默认)
  settings,

  /// 相对于课表上的正式上课时间
  classTime;

  String toJson() => name;

  static ReminderBaseTime fromJson(String? value) {
    if (value == null) return ReminderBaseTime.settings;
    return ReminderBaseTime.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ReminderBaseTime.settings,
    );
  }
}

/// 单条课程个性化提醒规则模型
class CourseReminderRule {
  final String id;
  final String courseName;
  final ReminderScope scope;
  final ReminderActionType actionType;
  final ReminderBaseTime baseTime;

  /// 分钟偏移量：负数 = 提前 N 分钟，正数 = 延后 N 分钟，0 = 准时
  final int offsetMinutes;

  /// 目标周次 (1-20，scope 为 onlyThis 或 thisWeek 时使用)
  final int? week;

  /// 星期几 (1-7，scope 为 onlyThis 或 thisWeekday 时使用)
  final int? dayOfWeek;

  /// 起始节次 (1-12，scope 为 onlyThis 时可指定)
  final int? startPeriod;

  /// 规则创建/更新时间
  final DateTime createdAt;

  const CourseReminderRule({
    required this.id,
    required this.courseName,
    required this.scope,
    this.actionType = ReminderActionType.offset,
    this.baseTime = ReminderBaseTime.settings,
    this.offsetMinutes = 0,
    this.week,
    this.dayOfWeek,
    this.startPeriod,
    required this.createdAt,
  });

  /// 是否是提前提醒
  bool get isBefore => actionType == ReminderActionType.offset && offsetMinutes < 0;

  /// 是否是延后提醒
  bool get isAfter => actionType == ReminderActionType.offset && offsetMinutes > 0;

  /// 是否是准时提醒
  bool get isExact => actionType == ReminderActionType.offset && offsetMinutes == 0;

  /// 是否是关闭提醒
  bool get isDisabled => actionType == ReminderActionType.disable;

  /// 绝对分钟数
  int get absMinutes => offsetMinutes.abs();

  CourseReminderRule copyWith({
    String? id,
    String? courseName,
    ReminderScope? scope,
    ReminderActionType? actionType,
    ReminderBaseTime? baseTime,
    int? offsetMinutes,
    int? week,
    int? dayOfWeek,
    int? startPeriod,
    DateTime? createdAt,
  }) {
    return CourseReminderRule(
      id: id ?? this.id,
      courseName: courseName ?? this.courseName,
      scope: scope ?? this.scope,
      actionType: actionType ?? this.actionType,
      baseTime: baseTime ?? this.baseTime,
      offsetMinutes: offsetMinutes ?? this.offsetMinutes,
      week: week ?? this.week,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startPeriod: startPeriod ?? this.startPeriod,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'courseName': courseName,
        'scope': scope.toJson(),
        'actionType': actionType.toJson(),
        'baseTime': baseTime.toJson(),
        'offsetMinutes': offsetMinutes,
        'week': week,
        'dayOfWeek': dayOfWeek,
        'startPeriod': startPeriod,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CourseReminderRule.fromJson(Map<String, dynamic> json) {
    return CourseReminderRule(
      id: json['id'] as String,
      courseName: json['courseName'] as String,
      scope: ReminderScope.fromJson(json['scope'] as String),
      actionType: json['actionType'] != null
          ? ReminderActionType.fromJson(json['actionType'] as String)
          : ReminderActionType.offset,
      baseTime: ReminderBaseTime.fromJson(json['baseTime'] as String?),
      offsetMinutes: (json['offsetMinutes'] as num?)?.toInt() ?? 0,
      week: (json['week'] as num?)?.toInt(),
      dayOfWeek: (json['dayOfWeek'] as num?)?.toInt(),
      startPeriod: (json['startPeriod'] as num?)?.toInt(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'CourseReminderRule(id: $id, course: $courseName, scope: ${scope.name}, '
        'action: ${actionType.name}, base: ${baseTime.name}, offset: ${offsetMinutes}m, '
        'week: $week, day: $dayOfWeek, startPeriod: $startPeriod)';
  }
}
