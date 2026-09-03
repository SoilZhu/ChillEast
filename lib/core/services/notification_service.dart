import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/timetable/models/course_model.dart';
import '../../features/timetable/utils/date_calculator.dart';
import '../../features/timetable/utils/week_parser.dart';
import '../../features/homework/models/homework_model.dart';
import '../../features/library/models/library_models.dart';
import 'package:logger/logger.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final _logger = Logger();

  Future<void> init() async {
    // 1. 初始化时区数据
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));

    // 2. 平台初始化设置
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    // 3. 整体初始化
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // 处理点击通知的逻辑
        debugPrint('Notification clicked: ${response.payload}');
      },
    );

    // 4. 不在启动时自动请求权限，改为在设置页开启通知时按需申请
    // 避免一启动就弹窗的 bad UX
  }

  // ==================== 权限检查与申请 (P0) ====================

  /// 检查通知总开关是否开启 (Android 侧)
  Future<bool> areNotificationsEnabled() async {
    if (kIsWeb) return true;
    if (Platform.isAndroid) {
      try {
        final android =
            _notificationsPlugin.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        final enabled = await android?.areNotificationsEnabled();
        return enabled ?? true;
      } catch (e) {
        _logger.w('⚠️ areNotificationsEnabled check failed: $e');
        return true;
      }
    }
    return true;
  }

  /// 检查是否可调度精确闹钟 (Android 12+)
  /// 返回 true 表示已授权可使用 exactAllowWhileIdle，false 表示需降级或引导用户
  Future<bool> canScheduleExactAlarms() async {
    if (kIsWeb) return true;
    if (!Platform.isAndroid) return true;
    try {
      final android =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final can = await android?.canScheduleExactNotifications();
      // can == null 表示系统版本 < S (无需此权限) 或插件未实现，视为可调度
      if (can == null) return true;
      return can;
    } catch (e) {
      _logger.w('⚠️ canScheduleExactNotifications check failed: $e');
      return true;
    }
  }

  /// 请求精确闹钟权限，跳转到系统“闹钟与提醒”设置页
  /// 返回 true 表示已发起请求（不代表用户已同意，需再次 canScheduleExactAlarms 检查）
  Future<bool> requestExactAlarmsPermission() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final android =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final result = await android?.requestExactAlarmsPermission();
      return result ?? false;
    } catch (e) {
      _logger.w('⚠️ requestExactAlarmsPermission failed: $e');
      return false;
    }
  }

  /// 请求通知权限 (Android 13+)
  Future<bool> requestNotificationsPermission() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final android =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final result = await android?.requestNotificationsPermission();
      return result ?? false;
    } catch (e) {
      _logger.w('⚠️ requestNotificationsPermission failed: $e');
      return false;
    }
  }

  /// 获取当前应使用的调度模式：有精确权限用 exact，无则降级为 inexact
  Future<AndroidScheduleMode> _resolveScheduleMode() async {
    final canExact = await canScheduleExactAlarms();
    if (canExact) return AndroidScheduleMode.exactAllowWhileIdle;
    _logger
        .w('⚠️ Exact alarm not permitted, fallback to inexactAllowWhileIdle');
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// 带降级重试的 zonedSchedule 封装
  Future<void> _zonedScheduleWithFallback({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required String payload,
  }) async {
    final mode = await _resolveScheduleMode();
    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } on Exception catch (e) {
      // SecurityException 等精确闹钟被拒时，降级为非精确重试一次
      final msg = e.toString();
      final isSecurityIssue = msg.contains('SecurityException') ||
          msg.contains('exact') ||
          msg.contains('SCHEDULE_EXACT_ALARM') ||
          msg.contains('ALARM');
      if (isSecurityIssue && mode == AndroidScheduleMode.exactAllowWhileIdle) {
        _logger.w('⚠️ exactAllowWhileIdle failed ($e), retry with inexact');
        try {
          await _notificationsPlugin.zonedSchedule(
            id,
            title,
            body,
            scheduledDate,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: payload,
          );
          return;
        } catch (e2) {
          _logger.e('❌ inexact fallback also failed: $e2');
          rethrow;
        }
      }
      _logger.e('❌ zonedSchedule failed: $e');
      rethrow;
    }
  }

  /// 获取待处理通知数量 (用于调试/体检页)
  Future<int> getPendingCount() async {
    try {
      final pending = await _notificationsPlugin.pendingNotificationRequests();
      return pending.length;
    } catch (e) {
      _logger.w('⚠️ getPendingCount failed: $e');
      return 0;
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
  Future<void> scheduleCourseReminders(List<CourseModel> courses,
      DateTime firstWeekMonday, int reminderMinutes) async {
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
        final reminderTime =
            startTime.subtract(Duration(minutes: reminderMinutes));

        // 如果提醒时间已经过了，检查是否需要补发
        if (!reminderTime.isAfter(now)) {
          // 如果现在还没有到上课时间，说明是在提醒窗口期内打开了App，我们补发一个
          if (now.isBefore(startTime)) {
            final prefs = await SharedPreferences.getInstance();
            final String makeupKey =
                'makeup_course_${course.id}_${date.year}_${date.month}_${date.day}_${startTime.hour}_${startTime.minute}';

            if (prefs.getBool(makeupKey) != true) {
              final int makeupId = 150000000 +
                  ((course.id.hashCode ^ startTime.millisecondsSinceEpoch)
                          .abs() %
                      10000000);
              final timeStr =
                  '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';

              await _notificationsPlugin.show(
                makeupId,
                '$timeStr ${course.name}',
                course.classroom,
                const NotificationDetails(
                  android: AndroidNotificationDetails(
                    'course_reminder_channel',
                    '上课提醒',
                    channelDescription: '在每节课开始前发送提醒',
                    importance: Importance.max,
                    priority: Priority.high,
                  ),
                ),
                payload: 'course_${course.id}',
              );
              await prefs.setBool(makeupKey, true);
              _logger
                  .i('📨 Makeup course notification sent for ${course.name}');
            }
          }
          continue;
        }

        // 我们只安排未来 14 天内的，防止超出安卓限制 (500个)
        if (reminderTime.isAfter(now.add(const Duration(days: 14)))) continue;

        // 生成通知 ID (课程使用1开头)
        final int notificationId = 100000000 +
            (course.id.hashCode.abs() +
                        reminderTime.millisecondsSinceEpoch ~/ 60000)
                    .toInt() %
                100000000;

        final timeStr =
            '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';

        await _zonedScheduleWithFallback(
          id: notificationId,
          title: '$timeStr ${course.name}', // 18:20 材料力学
          body: course.classroom, // [地点]
          scheduledDate: tz.TZDateTime.from(reminderTime, tz.local),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'course_reminder_channel',
              '上课提醒',
              channelDescription: '在每节课开始前发送提醒',
              importance: Importance.max,
              priority: Priority.high,
              showWhen: true,
            ),
          ),
          payload: 'course_${course.id}',
        );

        scheduledCount++;
      }
    }

    _logger.i(
        '🚀 Scheduled $scheduledCount course reminders (Pre-notify: $reminderMinutes min)');
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

      final reminderTime =
          hw.endTime!.subtract(Duration(minutes: (advanceHours * 60).toInt()));

      // 如果提醒时间已经过了，检查是否需要补发
      if (!reminderTime.isAfter(now)) {
        // 如果作业还没有截止，补发
        if (now.isBefore(hw.endTime!)) {
          final prefs = await SharedPreferences.getInstance();
          final String makeupKey =
              'makeup_hw_${hw.id}_${hw.endTime!.millisecondsSinceEpoch}';

          if (prefs.getBool(makeupKey) != true) {
            final int makeupId = 250000000 +
                ((hw.id.hashCode ^ hw.endTime!.millisecondsSinceEpoch).abs() %
                    10000000);

            String timeLabel = '';
            if (advanceHours < 1) {
              timeLabel = '${(advanceHours * 60).toInt()}分钟';
            } else if (advanceHours == advanceHours.toInt()) {
              timeLabel = '${advanceHours.toInt()}小时';
            } else {
              timeLabel = '$advanceHours小时';
            }

            await _notificationsPlugin.show(
              makeupId,
              '${hw.title} ${hw.courseName}',
              '作业将在不到$timeLabel后截止',
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  'homework_reminder_channel',
                  '作业截止提醒',
                  channelDescription: '在作业截止前发送提醒',
                  importance: Importance.max,
                  priority: Priority.high,
                ),
              ),
              payload: 'homework_${hw.id}',
            );
            await prefs.setBool(makeupKey, true);
            _logger.i('📨 Makeup homework notification sent for ${hw.title}');
          }
        }
        continue;
      }

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

      await _zonedScheduleWithFallback(
        id: notificationId,
        title: '${hw.title} ${hw.courseName}',
        body: '作业将在$timeLabel后截止',
        scheduledDate: tz.TZDateTime.from(reminderTime, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'homework_reminder_channel',
            '作业截止提醒',
            channelDescription: '在作业截止前发送提醒',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
          ),
        ),
        payload: 'homework_${hw.id}',
      );

      scheduledCount++;
    }

    _logger.i(
        '🚀 Scheduled $scheduledCount homework reminders (Advance: $advanceHours h)');
  }

  /// 为图书馆预约安排提醒
  /// [reserves]: 预约列表
  /// [reminderMinutes]: 提前多少分钟提醒
  Future<void> scheduleLibraryReminders(
    List<LibraryReserveModel> reserves,
    int reminderMinutes,
  ) async {
    if (reminderMinutes <= 0 || reserves.isEmpty) return;

    final now = DateTime.now();
    int scheduledCount = 0;

    for (var reserve in reserves) {
      final startTime = reserve.startTime;
      final reminderTime =
          startTime.subtract(Duration(minutes: reminderMinutes));

      final timeStr =
          '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
      final title = '$timeStr ${reserve.seatNum}号座位';
      final body = reserve.fullRoomName;

      // 如果提醒时间已经过了，检查是否需要补发
      if (!reminderTime.isAfter(now)) {
        // 如果在签到有效期内，补发提醒
        if (now.isBefore(startTime.add(const Duration(minutes: 15)))) {
          final prefs = await SharedPreferences.getInstance();
          final String makeupKey =
              'makeup_library_${reserve.id}_${startTime.millisecondsSinceEpoch}';

          if (prefs.getBool(makeupKey) != true) {
            final int makeupId = 350000000 +
                ((reserve.id.hashCode ^ startTime.millisecondsSinceEpoch)
                        .abs() %
                    10000000);

            await _notificationsPlugin.show(
              makeupId,
              title,
              body,
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  'library_reminder_channel',
                  '图书馆预约提醒',
                  channelDescription: '在图书馆座位预约开始前发送提醒',
                  importance: Importance.max,
                  priority: Priority.high,
                ),
              ),
              payload: 'library_${reserve.id}',
            );
            await prefs.setBool(makeupKey, true);
            _logger.i(
                '📨 Makeup library notification sent for ${reserve.seatNum}');
          }
        }
        continue;
      }

      // 只安排未来 7 天内的预约
      if (reminderTime.isAfter(now.add(const Duration(days: 7)))) continue;

      // 生成图书馆通知 ID (3开头)
      final int notificationId =
          300000000 + (reserve.id.hashCode.abs() % 100000000);

      await _zonedScheduleWithFallback(
        id: notificationId,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(reminderTime, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'library_reminder_channel',
            '图书馆预约提醒',
            channelDescription: '在图书馆座位预约开始前发送提醒',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
          ),
        ),
        payload: 'library_${reserve.id}',
      );

      scheduledCount++;
    }

    _logger.i(
        '🚀 Scheduled $scheduledCount library reminders (Pre-notify: $reminderMinutes min)');
  }
}
