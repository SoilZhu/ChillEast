class CourseModel {
  final String id;
  final String name;
  final String teacher;
  final String classroom;
  final String weeks;        // 例如: "1-16(周)"
  final String periods;      // 例如: "01-02"
  final int dayOfWeek;       // 1-7 (周一到周日)
  final int startPeriod;     // 起始节次
  final int endPeriod;       // 结束节次
  
  const CourseModel({
    required this.id,
    required this.name,
    required this.teacher,
    required this.classroom,
    required this.weeks,
    required this.periods,
    required this.dayOfWeek,
    required this.startPeriod,
    required this.endPeriod,
  });
  
  factory CourseModel.fromJson(Map<String, dynamic> json) {
    return CourseModel(
      id: json['id'] as String,
      name: json['name'] as String,
      teacher: json['teacher'] as String,
      classroom: json['classroom'] as String,
      weeks: json['weeks'] as String,
      periods: json['periods'] as String,
      dayOfWeek: json['dayOfWeek'] as int,
      startPeriod: json['startPeriod'] as int,
      endPeriod: json['endPeriod'] as int,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'teacher': teacher,
    'classroom': classroom,
    'weeks': weeks,
    'periods': periods,
    'dayOfWeek': dayOfWeek,
    'startPeriod': startPeriod,
    'endPeriod': endPeriod,
  };
  
  @override
  String toString() {
    return 'CourseModel(name: $name, teacher: $teacher, classroom: $classroom, '
        'day: $dayOfWeek, periods: $startPeriod-$endPeriod, weeks: $weeks)';
  }
}
