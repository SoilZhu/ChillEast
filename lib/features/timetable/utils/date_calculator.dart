import 'package:flutter/material.dart';

/// 日期计算工具类
class DateCalculator {
  /// 根据第一周周一和周次、星期几，计算具体日期
  /// 
  /// [firstWeekMonday] 本学期第一周的周一日期
  /// [weekNumber] 周次（1-30）
  /// [dayOfWeek] 星期几（1=周一, 7=周日）
  static DateTime calculateDate({
    required DateTime firstWeekMonday,
    required int weekNumber,
    required int dayOfWeek,
  }) {
    // 强制归一化为周一，防止用户选错日子
    final DateTime actualMonday = firstWeekMonday.subtract(Duration(days: firstWeekMonday.weekday - 1));

    // 确保 dayOfWeek 在 1-7 范围内
    dayOfWeek = ((dayOfWeek - 1) % 7) + 1;
    
    return actualMonday.add(
      Duration(days: (weekNumber - 1) * 7 + (dayOfWeek - 1)),
    );
  }
  
  /// 根据节次获取开始和结束时间
  /// 
  /// 节次时间表：
  /// 1-2节: 08:00-09:40 (第一大节)
  /// 3-4节: 10:05-11:45 (第二大节)
  /// 5-6节: 14:30-16:10 (第三大节)
  /// 7-8节: 16:35-18:15 (第四大节)
  /// 9-10节: 19:30-21:10 (第五大节)
  /// 11-12节: 21:20-23:00 (第六大节)
  static Map<String, TimeOfDay> getSectionTime(int section) {
    const sectionTimes = {
      1: {'start': TimeOfDay(hour: 8, minute: 0), 'end': TimeOfDay(hour: 8, minute: 45)},
      2: {'start': TimeOfDay(hour: 8, minute: 55), 'end': TimeOfDay(hour: 9, minute: 40)},
      3: {'start': TimeOfDay(hour: 10, minute: 5), 'end': TimeOfDay(hour: 10, minute: 50)},
      4: {'start': TimeOfDay(hour: 11, minute: 0), 'end': TimeOfDay(hour: 11, minute: 45)},
      5: {'start': TimeOfDay(hour: 14, minute: 30), 'end': TimeOfDay(hour: 15, minute: 15)},
      6: {'start': TimeOfDay(hour: 15, minute: 25), 'end': TimeOfDay(hour: 16, minute: 10)},
      7: {'start': TimeOfDay(hour: 16, minute: 35), 'end': TimeOfDay(hour: 17, minute: 20)},
      8: {'start': TimeOfDay(hour: 17, minute: 30), 'end': TimeOfDay(hour: 18, minute: 15)},
      9: {'start': TimeOfDay(hour: 19, minute: 30), 'end': TimeOfDay(hour: 20, minute: 15)},
      10: {'start': TimeOfDay(hour: 20, minute: 25), 'end': TimeOfDay(hour: 21, minute: 10)},
      11: {'start': TimeOfDay(hour: 21, minute: 20), 'end': TimeOfDay(hour: 22, minute: 5)},
      12: {'start': TimeOfDay(hour: 22, minute: 15), 'end': TimeOfDay(hour: 23, minute: 0)},
    };
    
    return sectionTimes[section] ?? {
      'start': const TimeOfDay(hour: 0, minute: 0),
      'end': const TimeOfDay(hour: 0, minute: 0),
    };
  }
  
  /// 获取大节的时间范围（用于显示）
  static String getBigSectionTimeRange(int bigSection) {
    const ranges = {
      1: '08:00-09:40',
      2: '10:05-11:45',
      3: '14:30-16:10',
      4: '16:35-18:15',
      5: '19:30-21:10',
      6: '21:20-23:00',
    };
    
    return ranges[bigSection] ?? '';
  }
  
  /// 根据节次范围计算总时长（分钟）
  static int calculateDurationMinutes(int startSection, int endSection) {
    if (startSection > endSection) {
      final temp = startSection;
      startSection = endSection;
      endSection = temp;
    }
    
    final startTime = getSectionTime(startSection)['start']!;
    final endTime = getSectionTime(endSection)['end']!;
    
    return (endTime.hour * 60 + endTime.minute) - (startTime.hour * 60 + startTime.minute);
  }
  
  /// 获取当前是第几周
  static int getCurrentWeekNumber(DateTime firstWeekMonday, [DateTime? currentDate]) {
    final now = currentDate ?? DateTime.now();
    
    // 强制归一化为周一
    final DateTime actualMonday = DateTime(firstWeekMonday.year, firstWeekMonday.month, firstWeekMonday.day);
    final DateTime normalizedMonday = actualMonday.subtract(Duration(days: actualMonday.weekday - 1));
    
    if (now.isBefore(normalizedMonday)) {
      return 0; // 还未开学
    }
    
    final difference = now.difference(normalizedMonday).inDays;
    final weekNumber = (difference / 7).floor() + 1;
    
    return weekNumber;
  }
  
  /// 获取某周的周一日期
  static DateTime getWeekMonday(DateTime firstWeekMonday, int weekNumber) {
    final DateTime normalizedMonday = firstWeekMonday.subtract(Duration(days: firstWeekMonday.weekday - 1));
    return normalizedMonday.add(Duration(days: (weekNumber - 1) * 7));
  }
  
  /// 获取某周的周日日期
  static DateTime getWeekSunday(DateTime firstWeekMonday, int weekNumber) {
    return getWeekMonday(firstWeekMonday, weekNumber).add(const Duration(days: 6));
  }
  
  /// 格式化日期范围显示
  static String formatDateRange(DateTime startDate, DateTime endDate) {
    final startStr = '${startDate.month}月${startDate.day}日';
    final endStr = '${endDate.month}月${endDate.day}日';
    return '$startStr-$endStr';
  }
}
