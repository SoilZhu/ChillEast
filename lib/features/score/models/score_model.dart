class ScoreModel {
  final String courseName;
  final String score;
  final String? credit;
  final String? dailyScore;
  final String? examType;

  ScoreModel({
    required this.courseName,
    required this.score,
    this.credit,
    this.dailyScore,
    this.examType,
  });

  @override
  String toString() => 'ScoreModel(courseName: $courseName, score: $score)';
}

class SemesterModel {
  final String value; // e.g. "2025-2026"
  final String xq;    // e.g. "1"
  final String name;  // e.g. "2025-2026第1学期"
  final bool isActive;

  SemesterModel({
    required this.value,
    required this.xq,
    required this.name,
    this.isActive = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SemesterModel &&
          runtimeType == other.runtimeType &&
          value == other.value &&
          xq == other.xq;

  @override
  int get hashCode => value.hashCode ^ xq.hashCode;
}
