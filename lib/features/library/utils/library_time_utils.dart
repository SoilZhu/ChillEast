import 'package:flutter/widgets.dart';
import '../../../core/utils/l10n_extension.dart';

/// 图书馆预约时间选择相关的纯逻辑。
class LibraryTimeRangeSelection {
  final String startTime;
  final String endTime;

  const LibraryTimeRangeSelection({
    required this.startTime,
    required this.endTime,
  });
}

class LibraryTimeUtils {
  static const int openingHour = 7;
  static const int closingHour = 22;
  static const int intervalMinutes = 30;

  /// 获取北京时间 (UTC+8)。
  /// 若传入 [now]，则根据 [now] 计算其对应的北京时间。
  static DateTime getBeijingNow([DateTime? now]) {
    final currentUtc = (now ?? DateTime.now()).toUtc();
    return currentUtc.add(const Duration(hours: 8));
  }

  /// 构造指定北京时间的 DateTime（转换为 UTC 存储，以保证跨时区测试和比对的一致性）。
  static DateTime beijingDateTime(
    int year,
    int month,
    int day, [
    int hour = 0,
    int minute = 0,
    int second = 0,
  ]) {
    return DateTime.utc(year, month, day, hour, minute, second)
        .subtract(const Duration(hours: 8));
  }

  /// 格式化日期为 yyyy-MM-dd
  static String formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// 获取可预约的日期列表（按北京时间 UTC+8 计算）：
  /// - 只允许预约今明两天的座位；
  /// - 每天北京时间晚上 22:00 之前只有今天；
  /// - 每天北京时间晚上 22:00 及之后才会出现明天的座位预约。
  static List<String> availableReserveDays({DateTime? now}) {
    final beijing = getBeijingNow(now);
    final today = formatDate(beijing);
    if (beijing.hour >= 22) {
      final tomorrow = formatDate(beijing.add(const Duration(days: 1)));
      return [today, tomorrow];
    }
    return [today];
  }

  /// 格式化日期标签（例如：今天 (9月2日)、明天 (9月3日)）。
  /// 基于北京时间判断今天与明天。
  static String formatDayLabel(String dayStr, {DateTime? now}) {
    try {
      final dateParts = dayStr.split('-');
      if (dateParts.length != 3) return dayStr;
      final year = int.tryParse(dateParts[0]);
      final month = int.tryParse(dateParts[1]);
      final day = int.tryParse(dateParts[2]);
      if (year == null || month == null || day == null) return dayStr;

      final beijing = getBeijingNow(now);
      final today = DateTime.utc(beijing.year, beijing.month, beijing.day);
      final target = DateTime.utc(year, month, day);

      final diff = target.difference(today).inDays;
      final date = DateTime(year, month, day);
      final weekdayStr =
          ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][date.weekday - 1];
      final monthDay = '$month月$day日';

      if (diff == 0) return '今天 ($monthDay)';
      if (diff == 1) return '明天 ($monthDay)';
      return '$weekdayStr ($monthDay)';
    } catch (_) {
      return dayStr;
    }
  }

  /// 国际化格式化日期标签
  static String formatDayLabelLocalized(BuildContext context, String dayStr, {DateTime? now}) {
    try {
      final dateParts = dayStr.split('-');
      if (dateParts.length != 3) return dayStr;
      final year = int.tryParse(dateParts[0]);
      final month = int.tryParse(dateParts[1]);
      final day = int.tryParse(dateParts[2]);
      if (year == null || month == null || day == null) return dayStr;

      final beijing = getBeijingNow(now);
      final today = DateTime.utc(beijing.year, beijing.month, beijing.day);
      final target = DateTime.utc(year, month, day);

      final diff = target.difference(today).inDays;
      final date = DateTime(year, month, day);
      final weekdayStr = switch (date.weekday) {
        1 => context.l10n.weekdayMon,
        2 => context.l10n.weekdayTue,
        3 => context.l10n.weekdayWed,
        4 => context.l10n.weekdayThu,
        5 => context.l10n.weekdayFri,
        6 => context.l10n.weekdaySat,
        _ => context.l10n.weekdaySun,
      };
      final monthDay = context.l10n.monthDayFormat(month, day);

      if (diff == 0) return context.l10n.todayWithDate(monthDay);
      if (diff == 1) return context.l10n.tomorrowWithDate(monthDay);
      return '$weekdayStr ($monthDay)';
    } catch (_) {
      return dayStr;
    }
  }

  /// 生成图书馆页面使用的半小时刻度，包含 22:00 作为最后的结束时间。
  static List<String> buildTimeSlots() {
    final slots = <String>[];
    for (var hour = openingHour; hour <= closingHour; hour++) {
      slots.add('${hour.toString().padLeft(2, '0')}:00');
      if (hour < closingHour) {
        slots.add('${hour.toString().padLeft(2, '0')}:30');
      }
    }
    return slots;
  }

  /// 今天的开始时间必须严格晚于当前时刻（按北京时间比对）；未来日期的所有营业时段均可选。
  static List<String> availableStartSlots(
    String day, {
    DateTime? now,
  }) {
    final current = getBeijingNow(now);
    final slots = buildTimeSlots();

    // 最后一个 22:00 没有可用的结束时段，不能作为开始时间。
    return [
      for (var i = 0; i < slots.length - 1; i++)
        if (dateTimeAt(day, slots[i])?.isAfter(current) ?? false) slots[i],
    ];
  }

  /// 今天的结束时间候选列表不包含早于或等于当前时刻的半小时刻度，和开始时间保持一致；
  /// 未来日期的所有营业结束时段均可选。
  static List<String> candidateEndSlots(
    String day, {
    DateTime? now,
  }) {
    final current = getBeijingNow(now);
    final slots = buildTimeSlots();

    return [
      for (final slot in slots)
        if (dateTimeAt(day, slot)?.isAfter(current) ?? false) slot,
    ];
  }

  static String? defaultStartTime(
    String day, {
    DateTime? now,
  }) {
    final available = availableStartSlots(day, now: now);
    if (available.isEmpty) return null;

    final today = formatDate(getBeijingNow(now));
    if (day != today && available.contains('08:00')) {
      return '08:00';
    }
    return available.first;
  }

  static String? defaultEndTime(String startTime) {
    final slots = buildTimeSlots();
    final startIndex = slots.indexOf(startTime);
    if (startIndex < 0 || startIndex >= slots.length - 1) return null;

    final endIndex =
        (startIndex + 4 < slots.length) ? startIndex + 4 : slots.length - 1;
    return endIndex > startIndex ? slots[endIndex] : null;
  }

  static List<String> availableEndSlots(String startTime) {
    final slots = buildTimeSlots();
    final startIndex = slots.indexOf(startTime);
    if (startIndex < 0) return const [];
    return slots.sublist(startIndex + 1);
  }

  static bool isValidRange(
    String day,
    String startTime,
    String endTime, {
    DateTime? now,
  }) {
    final start = dateTimeAt(day, startTime);
    final end = dateTimeAt(day, endTime);
    if (start == null || end == null) return false;
    final slots = buildTimeSlots();
    if (!slots.contains(startTime) || !slots.contains(endTime)) return false;
    if (!start.isAfter(getBeijingNow(now))) return false;
    return end.isAfter(start);
  }

  static DateTime? dateTimeAt(String day, String time) {
    final dateParts = day.split('-');
    final timeParts = time.split(':');
    if (dateParts.length != 3 || timeParts.length < 2) return null;

    final year = int.tryParse(dateParts[0]);
    final month = int.tryParse(dateParts[1]);
    final date = int.tryParse(dateParts[2]);
    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    if ([year, month, date, hour, minute].any((value) => value == null)) {
      return null;
    }

    final value = DateTime.utc(year!, month!, date!, hour!, minute!);
    if (value.year != year ||
        value.month != month ||
        value.day != date ||
        value.hour != hour ||
        value.minute != minute) {
      return null;
    }
    return value;
  }
}
