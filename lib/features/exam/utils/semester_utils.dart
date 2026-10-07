/// 学期计算与判定工具类
class SemesterUtils {
  /// 判断指定日期是否属于参考时间所在的高校学期
  ///
  /// - [date]: 需要判定的日期（如考试时间）
  /// - [firstWeekMonday]: 课表解析出的本学期第一周周一（若有），优先以此为基准
  /// - [referenceTime]: 参考基准时间，默认为当前时间 [DateTime.now()]
  static bool isCurrentSemester(
    DateTime date, {
    DateTime? firstWeekMonday,
    DateTime? referenceTime,
  }) {
    if (firstWeekMonday != null) {
      final actualMonday = DateTime(
        firstWeekMonday.year,
        firstWeekMonday.month,
        firstWeekMonday.day,
      );
      // 开学周一往前放宽 14 天（开学前补考/报到测试），往后放宽 26 周（包含全学期及期末考试周）
      final start = actualMonday.subtract(const Duration(days: 14));
      final end = actualMonday.add(const Duration(days: 26 * 7));
      return !date.isBefore(start) && !date.isAfter(end);
    }

    final ref = referenceTime ?? DateTime.now();
    final year = ref.year;
    final month = ref.month;

    // 高校学期划分常规标准：
    // 秋季学期：当年 8月1日 ~ 次年 2月15日
    // 春季学期：当年 2月16日 ~ 当年 7月31日
    if (month >= 8 || month == 1 || (month == 2 && ref.day <= 15)) {
      final startYear = month <= 2 ? year - 1 : year;
      final start = DateTime(startYear, 8, 1);
      final end = DateTime(startYear + 1, 2, 15, 23, 59, 59);
      return !date.isBefore(start) && !date.isAfter(end);
    } else {
      final start = DateTime(year, 2, 16);
      final end = DateTime(year, 7, 31, 23, 59, 59);
      return !date.isBefore(start) && !date.isAfter(end);
    }
  }
}
