import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../l10n/app_localizations.dart';
import '../../features/timetable/models/course_model.dart';
import '../../features/timetable/models/course_reminder_rule.dart';
import '../../features/timetable/services/course_reminder_storage.dart';
import '../../features/timetable/utils/date_calculator.dart';
import '../../features/timetable/utils/week_parser.dart';
import '../../features/homework/models/homework_model.dart';
import '../../features/library/models/library_models.dart';
import '../../features/exam/models/exam_schedule_model.dart';
import 'package:logger/logger.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final _logger = Logger();

  Future<AppLocalizations> _getL10n() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString('app_language_code');
      if (code != null && code != 'system') {
        return lookupAppLocalizations(Locale(code));
      }
    } catch (_) {}
    try {
      final platformLocale = WidgetsBinding.instance.platformDispatcher.locale;
      return lookupAppLocalizations(platformLocale);
    } catch (_) {
      return lookupAppLocalizations(const Locale('zh'));
    }
  }

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
  /// [reminderMinutes]: 全局默认提前多少分钟提醒（<= 0 表示全局不提醒，但单课自定义规则仍生效）
  Future<void> scheduleCourseReminders(List<CourseModel> courses,
      DateTime firstWeekMonday, int reminderMinutes) async {
    final customRules = await CourseReminderStorage().readRules();
    // 如果全局不提醒且没有针对任何课程的自定义提醒规则，直接返回
    if (reminderMinutes <= 0 && customRules.isEmpty) return;

    final l10n = await _getL10n();
    final now = DateTime.now();
    int scheduledCount = 0;

    for (var course in courses) {
      // 解析周次
      final weeks = WeekParser.parseWeeks(course.weeks);

      for (final weekNum in weeks) {
        // 计算此课次的最优先提醒规则
        final rule = CourseReminderStorage.resolveEffectiveRule(
          rules: customRules,
          courseName: course.name,
          week: weekNum,
          dayOfWeek: course.dayOfWeek,
          startPeriod: course.startPeriod,
        );

        // 如果规则明确关闭了本节课提醒，跳过
        if (rule != null && rule.isDisabled) {
          continue;
        }

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

        // 计算最终提醒时间及相对于上课时间的总偏移量（负数为提前，正数为延后）
        final DateTime reminderTime;
        final int totalOffsetFromStartTime;

        if (rule != null) {
          if (rule.baseTime == ReminderBaseTime.settings) {
            // 相对于设置里的默认提前提醒时间
            final base =
                startTime.subtract(Duration(minutes: reminderMinutes));
            reminderTime = base.add(Duration(minutes: rule.offsetMinutes));
            totalOffsetFromStartTime = -reminderMinutes + rule.offsetMinutes;
          } else {
            // 相对于正式上课时间
            reminderTime = startTime.add(Duration(minutes: rule.offsetMinutes));
            totalOffsetFromStartTime = rule.offsetMinutes;
          }
        } else {
          // 无自定义规则走全局默认
          if (reminderMinutes <= 0) continue;
          reminderTime =
              startTime.subtract(Duration(minutes: reminderMinutes));
          totalOffsetFromStartTime = -reminderMinutes;
        }

        // 如果提醒时间已经过了，检查是否需要补发
        if (!reminderTime.isAfter(now)) {
          // 提前提醒在开课前打开 App 可补发；延后提醒在开课后 30 分钟内打开 App 可补发
          final shouldMakeup = totalOffsetFromStartTime <= 0
              ? now.isBefore(startTime)
              : now.isBefore(startTime.add(const Duration(minutes: 30)));

          if (shouldMakeup) {
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

              String bodyText = course.classroom;
              if (totalOffsetFromStartTime > 0) {
                final prefix = '已上课${totalOffsetFromStartTime}分钟';
                bodyText = bodyText.isNotEmpty ? '[$prefix] $bodyText' : '[$prefix]';
              }

              await _notificationsPlugin.show(
                makeupId,
                '$timeStr ${course.name}',
                bodyText,
                NotificationDetails(
                  android: AndroidNotificationDetails(
                    'course_reminder_channel',
                    l10n.classReminderChannelName,
                    channelDescription: l10n.classReminderChannelDesc,
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

        String bodyText = course.classroom;
        if (totalOffsetFromStartTime > 0) {
          final prefix = '已上课${totalOffsetFromStartTime}分钟';
          bodyText = bodyText.isNotEmpty ? '[$prefix] $bodyText' : '[$prefix]';
        } else if (rule != null && totalOffsetFromStartTime < 0) {
          final prefix = '提前${totalOffsetFromStartTime.abs()}分钟';
          bodyText = bodyText.isNotEmpty ? '[$prefix] $bodyText' : '[$prefix]';
        }

        await _zonedScheduleWithFallback(
          id: notificationId,
          title: '$timeStr ${course.name}', // 18:20 材料力学
          body: bodyText, // [地点 / 偏移备注]
          scheduledDate: tz.TZDateTime.from(reminderTime, tz.local),
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              'course_reminder_channel',
              l10n.classReminderChannelName,
              channelDescription: l10n.classReminderChannelDesc,
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
        '🚀 Scheduled $scheduledCount course reminders (Default: $reminderMinutes min, Custom rules: ${customRules.length})');
  }

  /// 格式化作业截止倒计时文案
  String _formatHomeworkRemainingTime(AppLocalizations l10n, Duration duration) {
    if (duration.inMinutes < 60) {
      final mins = duration.inMinutes <= 0 ? 1 : duration.inMinutes;
      return l10n.minutesCount(mins);
    }
    final hours = duration.inHours;
    final mins = duration.inMinutes % 60;
    if (mins == 0) {
      return l10n.hoursCount('$hours');
    }
    return '${l10n.hoursCount('$hours')}${l10n.minutesCount(mins)}';
  }

  /// 为作业列表安排提醒
  /// [homeworks]: 作业列表
  /// [advanceHours]: 提前多少小时提醒
  /// [repeatEnabled]: 是否在完成前重复提醒
  /// [repeatIntervalMinutes]: 重复提醒间隔（分钟）
  /// [remindAfterDue]: 截止后是否继续提醒
  Future<void> scheduleHomeworkReminders(
    List<HomeworkModel> homeworks,
    double advanceHours, {
    bool repeatEnabled = false,
    int repeatIntervalMinutes = 60,
    bool remindAfterDue = false,
  }) async {
    if (advanceHours <= 0) return;

    final l10n = await _getL10n();
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    int scheduledCount = 0;

    for (var hw in homeworks) {
      if (hw.status != HomeworkStatus.pending || hw.endTime == null) continue;
      final endTime = hw.endTime!;

      // 首次提醒时间
      final firstReminderTime =
          endTime.subtract(Duration(minutes: (advanceHours * 60).toInt()));

      // 确定所有提醒候选时间点
      final List<DateTime> reminderTimes = [];
      if (!repeatEnabled || repeatIntervalMinutes <= 0) {
        reminderTimes.add(firstReminderTime);
      } else {
        final interval = Duration(minutes: repeatIntervalMinutes);
        DateTime current = firstReminderTime;

        // 截止后提醒的最大上限：如果开启逾期提醒，截止后最多持续 24 小时
        final cutoffTime = remindAfterDue
            ? endTime.add(const Duration(hours: 24))
            : endTime;

        // 限制每个作业最多排程 10 个提醒槽位，防止消耗系统全局闹钟限额
        const int maxRemindersPerHw = 10;
        int count = 0;
        while (!current.isAfter(cutoffTime) && count < maxRemindersPerHw) {
          reminderTimes.add(current);
          current = current.add(interval);
          count++;
        }
      }

      // 1. 如果有过去的时间点，检查是否需要补发最新一条
      final pastTimes = reminderTimes.where((t) => !t.isAfter(now)).toList();
      if (pastTimes.isNotEmpty) {
        final latestPast = pastTimes.last;
        final isOverdue = now.isAfter(endTime);
        final canMakeup = !isOverdue ||
            (remindAfterDue &&
                now.isBefore(endTime.add(const Duration(hours: 24))));

        if (canMakeup) {
          final String makeupKey =
              'makeup_hw_${hw.id}_${latestPast.millisecondsSinceEpoch ~/ 60000}';

          if (prefs.getBool(makeupKey) != true) {
            final int makeupId = 250000000 +
                ((hw.id.hashCode ^ latestPast.millisecondsSinceEpoch).abs() %
                    10000000);

            String body;
            if (isOverdue) {
              body = l10n.homeworkOverdueNotice;
            } else {
              final remaining = endTime.difference(now);
              final timeLabel = _formatHomeworkRemainingTime(l10n, remaining);
              body = l10n.homeworkDueInLessThan(timeLabel);
            }

            await _notificationsPlugin.show(
              makeupId,
              '${hw.title} ${hw.courseName}',
              body,
              NotificationDetails(
                android: AndroidNotificationDetails(
                  'homework_reminder_channel',
                  l10n.homeworkReminderChannelName,
                  channelDescription: l10n.homeworkReminderChannelDesc,
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
      }

      // 2. 为未来的时间点安排排程
      final futureTimes = reminderTimes.where((t) => t.isAfter(now)).toList();
      for (int i = 0; i < futureTimes.length; i++) {
        final reminderTime = futureTimes[i];

        // 只安排未来 7 天内的通知
        if (reminderTime.isAfter(now.add(const Duration(days: 7)))) continue;

        // 生成通知 ID (2开头)
        // 基础作业哈希槽（每个作业分配20个slot，i对应 slotIndex）
        final int baseOffset = (hw.id.hashCode.abs() % 4000000) * 20;
        final int notificationId = 200000000 + baseOffset + (i % 20);

        String body;
        if (reminderTime.isAfter(endTime)) {
          body = l10n.homeworkOverdueNotice;
        } else {
          final remaining = endTime.difference(reminderTime);
          final timeLabel = _formatHomeworkRemainingTime(l10n, remaining);
          body = l10n.homeworkDueIn(timeLabel);
        }

        await _zonedScheduleWithFallback(
          id: notificationId,
          title: '${hw.title} ${hw.courseName}',
          body: body,
          scheduledDate: tz.TZDateTime.from(reminderTime, tz.local),
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              'homework_reminder_channel',
              l10n.homeworkReminderChannelName,
              channelDescription: l10n.homeworkReminderChannelDesc,
              importance: Importance.max,
              priority: Priority.high,
              showWhen: true,
            ),
          ),
          payload: 'homework_${hw.id}',
        );

        scheduledCount++;
      }
    }

    _logger.i(
        '🚀 Scheduled $scheduledCount homework reminders (Advance: $advanceHours h, Repeat: $repeatEnabled, Interval: $repeatIntervalMinutes min, Overdue: $remindAfterDue)');
  }

  /// 取消单条作业的所有排程通知
  Future<void> cancelHomeworkReminders(String homeworkId) async {
    final int baseOffset = (homeworkId.hashCode.abs() % 4000000) * 20;
    for (int i = 0; i < 20; i++) {
      try {
        await _notificationsPlugin.cancel(200000000 + baseOffset + i);
      } catch (_) {}
    }
  }

  /// 为图书馆预约安排提醒
  /// [reserves]: 预约列表
  /// [reminderMinutes]: 提前多少分钟提醒
  Future<void> scheduleLibraryReminders(
    List<LibraryReserveModel> reserves,
    int reminderMinutes,
  ) async {
    if (reminderMinutes <= 0 || reserves.isEmpty) return;

    final l10n = await _getL10n();
    final now = DateTime.now();
    int scheduledCount = 0;

    for (var reserve in reserves) {
      final startTime = reserve.startTime;
      final reminderTime =
          startTime.subtract(Duration(minutes: reminderMinutes));

      final timeStr =
          '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
      final title = l10n.seatNumberNotificationTitle(timeStr, reserve.seatNum);
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
              NotificationDetails(
                android: AndroidNotificationDetails(
                  'library_reminder_channel',
                  l10n.libraryReminderChannelName,
                  channelDescription: l10n.libraryReminderChannelDesc,
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
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'library_reminder_channel',
            l10n.libraryReminderChannelName,
            channelDescription: l10n.libraryReminderChannelDesc,
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

  /// 为考试日程安排提醒（跟上课通知一起走，复用课程提醒 Channel 与提前分钟数）
  /// [exams]: 考试列表
  /// [reminderMinutes]: 提前多少分钟提醒（与上课提醒保持一致）
  Future<void> scheduleExamReminders(
    List<ExamScheduleModel> exams,
    int reminderMinutes,
  ) async {
    if (reminderMinutes <= 0 || exams.isEmpty) return;

    final l10n = await _getL10n();
    final now = DateTime.now();
    int scheduledCount = 0;

    for (var exam in exams) {
      final startTime = exam.time;
      if (startTime == null) continue;
      final reminderTime =
          startTime.subtract(Duration(minutes: reminderMinutes));

      final timeStr =
          '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
      final title = '$timeStr 考试: ${exam.title}';
      final details = [
        if (exam.courseName.isNotEmpty) exam.courseName,
        if (exam.location != null && exam.location!.isNotEmpty) exam.location!,
        if (exam.remarks != null && exam.remarks!.isNotEmpty) exam.remarks!,
      ];
      final body = details.isNotEmpty ? details.join(' · ') : exam.title;

      // 如果提醒时间已经过了，检查是否需要补发
      if (!reminderTime.isAfter(now)) {
        // 如果现在还没到考试开始时间，在提醒窗口期内补发
        if (now.isBefore(startTime)) {
          final prefs = await SharedPreferences.getInstance();
          final String makeupKey =
              'makeup_exam_${exam.id}_${startTime.millisecondsSinceEpoch}';

          if (prefs.getBool(makeupKey) != true) {
            final int makeupId = 450000000 +
                ((exam.id.hashCode ^ startTime.millisecondsSinceEpoch).abs() %
                    10000000);

            await _notificationsPlugin.show(
              makeupId,
              title,
              body,
              NotificationDetails(
                android: AndroidNotificationDetails(
                  'course_reminder_channel',
                  l10n.classReminderChannelName,
                  channelDescription: l10n.classReminderChannelDesc,
                  importance: Importance.max,
                  priority: Priority.high,
                ),
              ),
              payload: 'exam_${exam.id}',
            );
            await prefs.setBool(makeupKey, true);
            _logger.i('📨 Makeup exam notification sent for ${exam.title}');
          }
        }
        continue;
      }

      // 仅安排未来 30 天以内的考试，防止超出系统通知限制
      if (reminderTime.isAfter(now.add(const Duration(days: 30)))) continue;

      // 生成考试通知 ID (4开头)
      final int notificationId = 400000000 +
          (exam.id.hashCode.abs() +
                      reminderTime.millisecondsSinceEpoch ~/ 60000)
                  .toInt() %
              100000000;

      await _zonedScheduleWithFallback(
        id: notificationId,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(reminderTime, tz.local),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'course_reminder_channel',
            l10n.classReminderChannelName,
            channelDescription: l10n.classReminderChannelDesc,
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
          ),
        ),
        payload: 'exam_${exam.id}',
      );

      scheduledCount++;
    }

    _logger.i(
        '🚀 Scheduled $scheduledCount exam reminders (Pre-notify: $reminderMinutes min)');
  }
}
