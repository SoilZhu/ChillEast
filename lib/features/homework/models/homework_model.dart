import 'dart:convert';

/// 作业状态枚举
enum HomeworkStatus {
  pending,   // 未完成
  completed, // 已完成
  archived,  // 已存档
}

/// 作业数据模型
class HomeworkModel {
  final String id;           
  final String courseName;
  final String title;
  final DateTime? endTime;    // 截止时间，可能为 null
  final HomeworkStatus status;
  final String studentId;
  final String rawTimeStr;   // 原始的时间字符串，如 "剩余194小时34分钟"
  final String dataUrl;      // 跳转详情的 URL
  final bool isManual;       // 是否为手动添加
  final DateTime? createdAt; // 创建时间
  final String remarks;      // 备注

  HomeworkModel({
    required this.id,
    required this.courseName,
    required this.title,
    this.endTime,
    required this.status,
    required this.studentId,
    this.rawTimeStr = '',
    this.dataUrl = '',
    this.isManual = false,
    this.createdAt,
    this.remarks = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'courseName': courseName,
    'title': title,
    'endTime': endTime?.toIso8601String(),
    'status': status.index,
    'studentId': studentId,
    'rawTimeStr': rawTimeStr,
    'dataUrl': dataUrl,
    'isManual': isManual,
    'createdAt': createdAt?.toIso8601String(),
    'remarks': remarks,
  };

  factory HomeworkModel.fromJson(Map<String, dynamic> json) {
    return HomeworkModel(
      id: json['id'],
      courseName: json['courseName'] ?? '',
      title: json['title'] ?? '',
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      status: HomeworkStatus.values[json['status'] ?? 0],
      studentId: json['studentId'] ?? '',
      rawTimeStr: json['rawTimeStr'] ?? '',
      dataUrl: json['dataUrl'] ?? '',
      isManual: json['isManual'] ?? false,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      remarks: json['remarks'] ?? '',
    );
  }

  HomeworkModel copyWith({
    String? id,
    String? courseName,
    String? title,
    DateTime? endTime,
    HomeworkStatus? status,
    String? studentId,
    String? rawTimeStr,
    String? dataUrl,
    bool? isManual,
    DateTime? createdAt,
    String? remarks,
  }) {
    return HomeworkModel(
      id: id ?? this.id,
      courseName: courseName ?? this.courseName,
      title: title ?? this.title,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      studentId: studentId ?? this.studentId,
      rawTimeStr: rawTimeStr ?? this.rawTimeStr,
      dataUrl: dataUrl ?? this.dataUrl,
      isManual: isManual ?? this.isManual,
      createdAt: createdAt ?? this.createdAt,
      remarks: remarks ?? this.remarks,
    );
  }
}
