import '../../library/models/library_models.dart';
import '../../leave/models/leave_models.dart';
import '../../timetable/models/course_model.dart';
import '../../timetable/utils/date_calculator.dart';
import '../../exam/models/exam_schedule_model.dart';
import '../../homework/models/homework_model.dart';
import '../../workspace/models/electricity_model.dart';

class FeedSorter {
  static const List<String> defaultFeedOrder = [
    'feed_quick',
    'feed_library',
    'feed_agenda',
    'feed_homework',
    'feed_leave',
    'feed_repair',
    'feed_questionnaire',
    'feed_balance',
  ];

  static const List<String> baselineWithoutQuick = [
    'feed_library',
    'feed_agenda',
    'feed_homework',
    'feed_leave',
    'feed_repair',
    'feed_questionnaire',
    'feed_balance',
  ];

  /// 根据自动排序规则计算信息流项 ID 列表
  static List<String> sortFeedItems({
    required bool autoSort,
    required List<String> manualOrder,
    required bool hasLibraryP0,
    required bool hasLeaveP1,
    required bool hasAgendaP2,
    required bool hasHomeworkP3,
    required bool hasBalanceP4,
  }) {
    if (!autoSort) {
      return manualOrder;
    }

    final boosted = <MapEntry<String, int>>[];
    if (hasLibraryP0) boosted.add(const MapEntry('feed_library', 0));
    if (hasLeaveP1) boosted.add(const MapEntry('feed_leave', 1));
    if (hasAgendaP2) boosted.add(const MapEntry('feed_agenda', 2));
    if (hasHomeworkP3) boosted.add(const MapEntry('feed_homework', 3));
    if (hasBalanceP4) boosted.add(const MapEntry('feed_balance', 4));

    boosted.sort((a, b) => a.value.compareTo(b.value));
    final boostedIds = boosted.map((e) => e.key).toList();

    final remaining = baselineWithoutQuick
        .where((id) => !boostedIds.contains(id))
        .toList();

    return ['feed_quick', ...boostedIds, ...remaining];
  }

  /// 规则 1: 如果当前时间是图书馆被预约时间的前10分钟-后20分钟，则优先级为 p0
  static bool checkLibraryP0({
    required List<LibraryReserveModel> reserves,
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();
    for (final reserve in reserves) {
      if (reserve.reserveStatus == ReserveStatus.cancelled ||
          reserve.reserveStatus == ReserveStatus.completed) {
        continue;
      }
      final start = reserve.startTime;
      final windowStart = start.subtract(const Duration(minutes: 10));
      final windowEnd = start.add(const Duration(minutes: 20));
      if (!now.isBefore(windowStart) && !now.isAfter(windowEnd)) {
        return true;
      }
    }
    return false;
  }

  /// 规则 2: 如果当前时间是有请假申请通过，并且在结束时间前，则优先级为 p1
  static bool checkLeaveP1({
    required List<LeaveRecord> leaves,
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();
    for (final record in leaves) {
      final isRejected = record.auditResultName.contains('不通过') ||
          record.auditResultName.contains('不同意') ||
          record.auditResultName.contains('驳回') ||
          record.auditResultName.contains('拒绝');
      if (isRejected) continue;

      final isApproved = record.auditResultName.contains('通过') ||
          record.auditResultName.contains('同意') ||
          (record.auditStatus == '9' && record.auditResultName.isEmpty);
      if (!isApproved) continue;

      final endStr = record.endTime;
      if (endStr.isEmpty) continue;
      final end = DateTime.tryParse(endStr) ??
          DateTime.tryParse(endStr.replaceFirst(' ', 'T'));
      if (end != null && now.isBefore(end)) {
        return true;
      }
    }
    return false;
  }

  /// 规则 3: 如果当前时间是上课/考试前60分钟，日程放在这里的优先级是 p2
  static bool checkAgendaP2({
    required List<CourseModel> courses,
    required List<ExamScheduleModel> exams,
    DateTime? previewDate,
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();
    final targetDate = previewDate ?? now;

    for (final course in courses) {
      final startPeriodTime =
          DateCalculator.getSectionTime(course.startPeriod)['start'];
      if (startPeriodTime != null) {
        final courseStart = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          startPeriodTime.hour,
          startPeriodTime.minute,
        );
        final windowStart = courseStart.subtract(const Duration(minutes: 60));
        if (!now.isBefore(windowStart) && !now.isAfter(courseStart)) {
          return true;
        }
      }
    }

    for (final exam in exams) {
      if (!exam.isCurrentSemester()) continue;
      final examStart = exam.time;
      if (examStart == null) continue;
      final windowStart = examStart.subtract(const Duration(minutes: 60));
      if (!now.isBefore(windowStart) && !now.isAfter(examStart)) {
        return true;
      }
    }

    return false;
  }

  /// 规则 4: 如果当前时间是作业截止前48小时，作业放在这里的优先级是 p3
  static bool checkHomeworkP3({
    required List<HomeworkModel> homeworks,
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();
    for (final hw in homeworks) {
      if (hw.status != HomeworkStatus.pending || hw.endTime == null) continue;
      final windowStart = hw.endTime!.subtract(const Duration(hours: 48));
      if (!now.isBefore(windowStart) && !now.isAfter(hw.endTime!)) {
        return true;
      }
    }
    return false;
  }

  /// 规则 5: 如果电费余额<=10，那么余额卡片放在这里的优先级是 p4
  static bool checkBalanceP4({
    required List<ElectricityBalanceInfo?> balances,
    ElectricityBalanceInfo? balanceInfo,
  }) {
    for (final b in balances) {
      if (b != null) {
        final val = double.tryParse(b.balance);
        if (val != null && val <= 10.0) return true;
      }
    }
    if (balanceInfo != null) {
      final val = double.tryParse(balanceInfo.balance);
      if (val != null && val <= 10.0) return true;
    }
    return false;
  }
}
