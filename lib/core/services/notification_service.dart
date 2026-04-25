import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import '../../features/timetable/models/course_model.dart';
import '../../features/timetable/utils/date_calculator.dart';
import '../../features/timetable/utils/week_parser.dart';
import '../../features/homework/models/homework_model.dart';
import 'package:logger/logger.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final _logger = Logger();

  Future<void> init() async {
    // 1. 初始化时区数据
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));

    // 2. 安卓初始化设置
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // 3. 整体初始化
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // 处理点击通知的逻辑
        debugPrint('Notification clicked: ${response.payload}');
      },
    );

    // 4. 请求权限 (安卓 13+)
    if (!kIsWeb) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  /// 取消所有已安排的通知
  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
    _logger.i('✅ All scheduled notifications cancelled');
  }

  /// 为课程列表安排提醒
  /// [courses]: 课程列表
  /// [firstWeekMonday]: 本学期第一周周一
  /// [reminderMinutes]: 提前多少分钟提醒
  Future<void> scheduleCourseReminders(
    List<CourseModel> courses, 
    DateTime firstWeekMonday,
    int reminderMinutes
  ) async {
    // 这里我们先不 cancelAll，避免误删作业通知
    // 我们手动取消课程 Channel 的通知 (如果有记录的话)
    // 暂时简单处理：如果不通知，直接返回
    if (reminderMinutes <= 0) return;

    final now = DateTime.now();
    int scheduledCount = 0;

    for (var course in courses) {
      // 解析周次
      final weeks = WeekParser.parseWeeks(course.weeks);
      
      for (final weekNum in weeks) {
        // 计算这一周这一天的日期
        final date = DateCalculator.calculateDate(
          firstWeekMonday: firstWeekMonday,
          weekNumber: weekNum,
          dayOfWeek: course.dayOfWeek,
        );

        // 获取该节次的开始时间
        final timeMap = DateCalculator.getSectionTime(course.startPeriod);
        final tod = timeMap['start']!;

        final startTime = DateTime(
          date.year,
          date.month,
          date.day,
          tod.hour,
          tod.minute,
        );
        
        // 计算提醒时间
        final reminderTime = startTime.subtract(Duration(minutes: reminderMinutes));

        // 如果提醒时间已经过了，就不安排
        if (reminderTime.isBefore(now)) continue;

        // 我们只安排未来 14 天内的，防止超出安卓限制 (500个)
        if (reminderTime.isAfter(now.add(const Duration(days: 14)))) continue;

        // 生成通知 ID (课程使用1开头)
        final int notificationId = 100000000 + (course.hashCode.abs() + reminderTime.millisecondsSinceEpoch ~/ 60000).toInt() % 100000000;

        final timeStr = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';

        await _notificationsPlugin.zonedSchedule(
          notificationId,
          '$timeStr ${course.name}', // 18:20 材料力学
          course.classroom, // [地点]
          tz.TZDateTime.from(reminderTime, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'course_reminder_channel',
              '上课提醒',
              channelDescription: '在每节课开始前发送提醒',
              importance: Importance.max,
              priority: Priority.high,
              showWhen: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'course_${course.id}',
        );
        
        scheduledCount++;
      }
    }

    _logger.i('🚀 Scheduled $scheduledCount course reminders (Pre-notify: $reminderMinutes min)');
  }

  /// 为作业列表安排提醒
  /// [homeworks]: 作业列表
  /// [advanceHours]: 提前多少小时提醒
  Future<void> scheduleHomeworkReminders(
    List<HomeworkModel> homeworks,
    double advanceHours,
  ) async {
    if (advanceHours <= 0) return;

    final now = DateTime.now();
    int scheduledCount = 0;

    for (var hw in homeworks) {
      if (hw.status != HomeworkStatus.pending || hw.endTime == null) continue;

      final reminderTime = hw.endTime!.subtract(Duration(minutes: (advanceHours * 60).toInt()));

      // 如果提醒时间已经过了，就不安排
      if (reminderTime.isBefore(now)) continue;

      // 我们只安排未来 7 天内的
      if (reminderTime.isAfter(now.add(const Duration(days: 7)))) continue;

      // 生成作业通知 ID (2开头)
      final int notificationId = 200000000 + (hw.id.hashCode.abs() % 100000000);

      String timeLabel = '';
      if (advanceHours < 1) {
        timeLabel = '${(advanceHours * 60).toInt()}分钟';
      } else if (advanceHours == advanceHours.toInt()) {
        timeLabel = '${advanceHours.toInt()}小时';
      } else {
        timeLabel = '$advanceHours小时';
      }

      await _notificationsPlugin.zonedSchedule(
        notificationId,
        '${hw.title} ${hw.courseName}',
        '作业将在$timeLabel后截止',
        tz.TZDateTime.from(reminderTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'homework_reminder_channel',
            '作业截止提醒',
            channelDescription: '在作业截止前发送提醒',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'homework_${hw.id}',
      );
      
      scheduledCount++;
    }

    _logger.i('🚀 Scheduled $scheduledCount homework reminders (Advance: $advanceHours h)');
  }
}
