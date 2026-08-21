class ScoreModel {
  final String courseName;
  final String score;
  final String? credit;
  final String? dailyScore;
  final String? examType;
  final String? curriculumAttributes;
  final String? courseNature;
  final String? courseCode;
  final String? id;

  ScoreModel({
    required this.courseName,
    required this.score,
    this.credit,
    this.dailyScore,
    this.examType,
    this.curriculumAttributes,
    this.courseNature,
    this.courseCode,
    this.id,
  });

  @override
  String toString() => 'ScoreModel(courseName: $courseName, score: $score, credit: $credit, examType: $examType)';
}

class SemesterModel {
  final String id;    // e.g. "2025-2026-2"
  final String name;  // e.g. "2025-2026-2"
  final bool isActive;

  SemesterModel({
    required this.id,
    required this.name,
    this.isActive = false,
  });

  /// 向后兼容字段
  String get value => id;
  String get xq {
    final parts = id.split('-');
    return parts.length >= 3 ? parts.last : '';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SemesterModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SemesterModel(id: $id, name: $name, isActive: $isActive)';
}
