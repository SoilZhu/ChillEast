import '../utils/semester_utils.dart';

/// 考试日程数据模型
class ExamScheduleModel {
  final String id;
  final String title;
  final String courseName;
  /// 日程显示的主时间（若未提取到时间，则为 null）
  final DateTime? time;
  /// 考试结束时间（watermark 容器内第二个出现的时间，若有）
  final DateTime? endTime;

  /// 开始时间（等同于 time）
  DateTime? get startTime => time;
  /// watermark 容器内提取到的全部时间列表
  final List<DateTime> allTimes;
  /// 原始时间字符串列表（如 ["2026-05-10 17:00", "2026-05-10 23:59"]）
  final List<String> rawTimeStrs;
  /// 详情跳转链接
  final String detailUrl;
  /// 考试状态（如 "未交", "已完成", "未开始", "进行中"）
  final String status;
  /// 是否为手动添加
  final bool isManual;
  /// 考场 / 教室地点
  final String? location;
  /// 备注信息
  final String? remarks;
  /// 学生姓名
  final String? studentName;
  /// 学生学号
  final String? studentId;
  /// 创建/抓取时间
  final DateTime? createdAt;

  ExamScheduleModel({
    required this.id,
    required this.title,
    this.courseName = '',
    this.time,
    this.endTime,
    this.allTimes = const [],
    this.rawTimeStrs = const [],
    this.detailUrl = '',
    this.status = '',
    this.isManual = false,
    this.location,
    this.remarks,
    this.studentName,
    this.studentId,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'courseName': courseName,
        'time': time?.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'allTimes': allTimes.map((t) => t.toIso8601String()).toList(),
        'rawTimeStrs': rawTimeStrs,
        'detailUrl': detailUrl,
        'status': status,
        'isManual': isManual,
        'location': location,
        'remarks': remarks,
        'studentName': studentName,
        'studentId': studentId,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory ExamScheduleModel.fromJson(Map<String, dynamic> json) {
    final rawTime = json['time'] ?? json['startTime'];
    return ExamScheduleModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      courseName: json['courseName'] as String? ?? '',
      time: rawTime != null ? DateTime.tryParse(rawTime as String) : null,
      endTime: json['endTime'] != null
          ? DateTime.tryParse(json['endTime'] as String)
          : null,
      allTimes: (json['allTimes'] as List<dynamic>?)
              ?.map((t) => DateTime.parse(t as String))
              .toList() ??
          [],
      rawTimeStrs: (json['rawTimeStrs'] as List<dynamic>?)
              ?.map((s) => s.toString())
              .toList() ??
          [],
      detailUrl: json['detailUrl'] as String? ?? '',
      status: json['status'] as String? ?? '',
      isManual: json['isManual'] as bool? ?? false,
      location: json['location'] as String?,
      remarks: json['remarks'] as String?,
      studentName: json['studentName'] as String?,
      studentId: json['studentId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  ExamScheduleModel copyWith({
    String? id,
    String? title,
    String? courseName,
    DateTime? time,
    DateTime? endTime,
    List<DateTime>? allTimes,
    List<String>? rawTimeStrs,
    String? detailUrl,
    String? status,
    bool? isManual,
    String? location,
    String? remarks,
    String? studentName,
    String? studentId,
    DateTime? createdAt,
  }) {
    return ExamScheduleModel(
      id: id ?? this.id,
      title: title ?? this.title,
      courseName: courseName ?? this.courseName,
      time: time ?? this.time,
      endTime: endTime ?? this.endTime,
      allTimes: allTimes ?? this.allTimes,
      rawTimeStrs: rawTimeStrs ?? this.rawTimeStrs,
      detailUrl: detailUrl ?? this.detailUrl,
      status: status ?? this.status,
      isManual: isManual ?? this.isManual,
      location: location ?? this.location,
      remarks: remarks ?? this.remarks,
      studentName: studentName ?? this.studentName,
      studentId: studentId ?? this.studentId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// 考试时间比较方法（用于排序，无时间的考试排在最后）
  static int compareTime(ExamScheduleModel a, ExamScheduleModel b) {
    if (a.time == null && b.time == null) return 0;
    if (a.time == null) return 1;
    if (b.time == null) return -1;
    return a.time!.compareTo(b.time!);
  }

  /// 判断该考试是否属于本学期（无时间的考试默认属于本学期）
  bool isCurrentSemester({DateTime? firstWeekMonday, DateTime? referenceTime}) {
    if (time == null) return true;
    return SemesterUtils.isCurrentSemester(
      time!,
      firstWeekMonday: firstWeekMonday,
      referenceTime: referenceTime,
    );
  }
}
