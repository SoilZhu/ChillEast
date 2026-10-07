import '../utils/semester_utils.dart';

/// 考试日程数据模型
class ExamScheduleModel {
  final String id;
  final String title;
  final String courseName;
  /// 日程显示的主时间（必须为 watermark 容器内第一个出现的时间）
  final DateTime time;
  /// watermark 容器内提取到的全部时间列表
  final List<DateTime> allTimes;
  /// 原始时间字符串列表（如 ["2026-05-10 17:00", "2026-05-10 23:59"]）
  final List<String> rawTimeStrs;
  /// 详情跳转链接
  final String detailUrl;
  /// 考试状态（如 "未交", "已完成", "未开始", "进行中"）
  final String status;
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
    required this.time,
    this.allTimes = const [],
    this.rawTimeStrs = const [],
    this.detailUrl = '',
    this.status = '',
    this.studentName,
    this.studentId,
    this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'courseName': courseName,
        'time': time.toIso8601String(),
        'allTimes': allTimes.map((t) => t.toIso8601String()).toList(),
        'rawTimeStrs': rawTimeStrs,
        'detailUrl': detailUrl,
        'status': status,
        'studentName': studentName,
        'studentId': studentId,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory ExamScheduleModel.fromJson(Map<String, dynamic> json) {
    return ExamScheduleModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      courseName: json['courseName'] as String? ?? '',
      time: DateTime.parse(json['time'] as String),
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
      studentName: json['studentName'] as String?,
      studentId: json['studentId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  ExamScheduleModel copyWith({
    String? id,
    String? title,
    String? courseName,
    DateTime? time,
    List<DateTime>? allTimes,
    List<String>? rawTimeStrs,
    String? detailUrl,
    String? status,
    String? studentName,
    String? studentId,
    DateTime? createdAt,
  }) {
    return ExamScheduleModel(
      id: id ?? this.id,
      title: title ?? this.title,
      courseName: courseName ?? this.courseName,
      time: time ?? this.time,
      allTimes: allTimes ?? this.allTimes,
      rawTimeStrs: rawTimeStrs ?? this.rawTimeStrs,
      detailUrl: detailUrl ?? this.detailUrl,
      status: status ?? this.status,
      studentName: studentName ?? this.studentName,
      studentId: studentId ?? this.studentId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// 判断该考试是否属于本学期
  bool isCurrentSemester({DateTime? firstWeekMonday, DateTime? referenceTime}) =>
      SemesterUtils.isCurrentSemester(
        time,
        firstWeekMonday: firstWeekMonday,
        referenceTime: referenceTime,
      );
}
