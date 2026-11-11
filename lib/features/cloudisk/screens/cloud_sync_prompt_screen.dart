import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/course_live_service.dart';
import '../../../core/services/flyme_live_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/brand_switch.dart';
import '../../profile/providers/settings_provider.dart';
import '../../profile/services/backup_provider_refresh.dart';
import '../services/cloud_backup_manager.dart';

/// 登录后是否展示同步推荐页（仅手动登录成功时置 true，内存态）。
final cloudSyncPromptPendingProvider = StateProvider<bool>((ref) => false);

/// 登录后个性化功能与同步推荐配置向导：
/// 涵盖云备份同步、课表自动同步、上课提醒、作业提醒、图书馆提醒、课表订阅等设置。
class CloudSyncPromptScreen extends ConsumerStatefulWidget {
  const CloudSyncPromptScreen({super.key});

  /// 当前引导流程版本号。每次重大引导升级/加步时自增，
  /// 使得所有已登录用户在更新后均能弹出浏览一次。
  static const int kCurrentOnboardingGuideVersion = 1;
  static const String kLastSeenGuideVersionKey =
      'last_seen_onboarding_guide_version';

  /// 带有下往上淡入动画的全屏弹窗路由
  static Route route() {
    return PageRouteBuilder(
      fullscreenDialog: true,
      pageBuilder: (context, animation, secondaryAnimation) =>
          const CloudSyncPromptScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 0.1);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);

        var fadeTween = Tween<double>(begin: 0.0, end: 1.0);
        var fadeAnimation = animation.drive(fadeTween);

        return FadeTransition(
          opacity: fadeAnimation,
          child: SlideTransition(
            position: offsetAnimation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  @override
  ConsumerState<CloudSyncPromptScreen> createState() =>
      _CloudSyncPromptScreenState();
}

class _CloudSyncPromptScreenState
    extends ConsumerState<CloudSyncPromptScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _busy = false;

  static const int _totalSteps = 7;

  // 用户可选择的提醒时间状态（默认值与要求一致）
  int _selectedCourseMinutes = 30;
  double _selectedHwHours = 48.0;
  int _selectedLibMinutes = 30;

  bool _liveSupported = false;
  bool _isFlyme = false;
  bool _useLiveActivity = true;
  bool _analyticsEnabled = true;

  @override
  void initState() {
    super.initState();
    _checkLiveSupport();
    _loadExistingSettings();
    AnalyticsService.isEnabled().then((val) {
      if (mounted) setState(() => _analyticsEnabled = val);
    });
  }

  void _loadExistingSettings() {
    try {
      final settings = ref.read(settingsProvider);
      const courseOptions = [5, 10, 20, 30, 40, 50, 60];
      if (courseOptions.contains(settings.reminderMinutes)) {
        _selectedCourseMinutes = settings.reminderMinutes;
      }
      const hwOptions = [0.5, 1.0, 2.0, 6.0, 12.0, 24.0, 48.0];
      if (hwOptions.contains(settings.homeworkReminderHours)) {
        _selectedHwHours = settings.homeworkReminderHours;
      }
      const libOptions = [5, 10, 15, 20, 30, 60];
      if (libOptions.contains(settings.libraryReminderMinutes)) {
        _selectedLibMinutes = settings.libraryReminderMinutes;
      }
      if (settings.courseLiveEnabled || settings.flymeLiveEnabled) {
        _useLiveActivity = true;
      } else if (settings.reminderMinutes > 0) {
        _useLiveActivity = false;
      }
    } catch (e) {
      debugPrint('⚠️ 加载已有配置失败: $e');
    }
  }

  Future<void> _checkLiveSupport() async {
    final isAosp = await CourseLiveService().isSupported();
    final isFlyme = await FlymeLiveService().isSupported();
    if (mounted) {
      setState(() {
        _liveSupported = isAosp || isFlyme;
        _isFlyme = isFlyme;
      });
    }
  }

  Future<void> _recordGuideSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(CloudBackupManager.promptDecidedKey, true);
      await prefs.setInt(
        CloudSyncPromptScreen.kLastSeenGuideVersionKey,
        CloudSyncPromptScreen.kCurrentOnboardingGuideVersion,
      );
    } catch (_) {}
    ref.read(cloudSyncPromptPendingProvider.notifier).state = false;
  }

  Future<void> _dismiss() async {
    if (_busy) return;
    await _recordGuideSeen();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  void _nextPage() {
    if (_currentPage < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _dismiss();
    }
  }

  // 步骤 1：云盘自动备份
  Future<void> _handleStepCloudSync(bool enable) async {
    if (_busy) return;
    if (enable) {
      setState(() => _busy = true);
      try {
        final result = await ref
            .read(settingsProvider.notifier)
            .setCloudBackupAutoSyncEnabled(true);
        if (result?.outcome == InitialSyncOutcome.pulled &&
            result?.backup != null) {
          await BackupProviderRefresh.refreshAfterRestore(ref, result!.backup!);
        }
      } catch (e) {
        debugPrint('⚠️ 云备份初始化同步失败: $e');
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
    _nextPage();
  }

  // 步骤 2：课表自动同步
  Future<void> _handleStepTimetableSync(bool enable) async {
    if (_busy) return;
    if (enable) {
      setState(() => _busy = true);
      try {
        await ref
            .read(settingsProvider.notifier)
            .setTimetableAutoSyncEnabled(true);
      } catch (e) {
        debugPrint('⚠️ 课表自动同步开关设置失败: $e');
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
    _nextPage();
  }

  Future<void> _requestNotificationPermissionIfNeeded() async {
    try {
      if (Platform.isIOS) {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          await Permission.notification.request();
        }
        return;
      }

      if (Platform.isAndroid) {
        final notifEnabled =
            await NotificationService().areNotificationsEnabled();
        if (notifEnabled != true) {
          await NotificationService().requestNotificationsPermission();
        }

        final canExact = await NotificationService().canScheduleExactAlarms();
        if (canExact != true) {
          await NotificationService().requestExactAlarmsPermission();
        }
      }
    } catch (e) {
      debugPrint('⚠️ 请求通知权限异常: $e');
    }
  }

  // 步骤 3：上课提醒
  Future<void> _handleStepCourseReminder(bool enable) async {
    if (_busy) return;
    if (enable) {
      setState(() => _busy = true);
      try {
        await _requestNotificationPermissionIfNeeded();
        await ref
            .read(settingsProvider.notifier)
            .setReminderMinutes(_selectedCourseMinutes);
        if (_liveSupported && _useLiveActivity) {
          if (_isFlyme) {
            await ref.read(settingsProvider.notifier).setFlymeLiveEnabled(true);
          } else {
            await ref.read(settingsProvider.notifier).setCourseLiveEnabled(true);
          }
        }
      } catch (e) {
        debugPrint('⚠️ 上课提醒设置失败: $e');
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
    _nextPage();
  }

  // 步骤 4：作业截止提醒
  Future<void> _handleStepHomeworkReminder(bool enable) async {
    if (_busy) return;
    if (enable) {
      setState(() => _busy = true);
      try {
        await _requestNotificationPermissionIfNeeded();
        await ref
            .read(settingsProvider.notifier)
            .setHomeworkReminderHours(_selectedHwHours);
      } catch (e) {
        debugPrint('⚠️ 作业提醒设置失败: $e');
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
    _nextPage();
  }

  // 步骤 5：图书馆座位提醒
  Future<void> _handleStepLibraryReminder(bool enable) async {
    if (_busy) return;
    if (enable) {
      setState(() => _busy = true);
      try {
        await _requestNotificationPermissionIfNeeded();
        await ref
            .read(settingsProvider.notifier)
            .setLibraryReminderMinutes(_selectedLibMinutes);
      } catch (e) {
        debugPrint('⚠️ 图书馆提醒设置失败: $e');
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
    _nextPage();
  }

  // 步骤 6：课表日历订阅
  Future<void> _handleStepTimetableSubscription(bool enable) async {
    if (_busy) return;
    if (enable) {
      setState(() => _busy = true);
      try {
        await ref
            .read(settingsProvider.notifier)
            .setTimetableSubscriptionEnabled(true);
      } catch (e) {
        debugPrint('⚠️ 课表订阅设置失败: $e');
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
    _nextPage();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    // 备选时长列表定义
    final courseDurationOptions = [
      {'label': l10n.notifMinutesBefore(5), 'value': 5},
      {'label': l10n.notifMinutesBefore(10), 'value': 10},
      {'label': l10n.notifMinutesBefore(20), 'value': 20},
      {'label': l10n.notifMinutesBefore(30), 'value': 30},
      {'label': l10n.notifMinutesBefore(40), 'value': 40},
      {'label': l10n.notifMinutesBefore(50), 'value': 50},
      {'label': l10n.notifMinutesBefore(60), 'value': 60},
    ];

    final homeworkDurationOptions = [
      {'label': l10n.notifHoursBefore('0.5'), 'value': 0.5},
      {'label': l10n.notifHoursBefore('1'), 'value': 1.0},
      {'label': l10n.notifHoursBefore('2'), 'value': 2.0},
      {'label': l10n.notifHoursBefore('6'), 'value': 6.0},
      {'label': l10n.notifHoursBefore('12'), 'value': 12.0},
      {'label': l10n.notifHoursBefore('24'), 'value': 24.0},
      {'label': l10n.notifHoursBefore('48'), 'value': 48.0},
    ];

    final libraryDurationOptions = [
      {'label': l10n.notifMinutesBefore(5), 'value': 5},
      {'label': l10n.notifMinutesBefore(10), 'value': 10},
      {'label': l10n.notifMinutesBefore(15), 'value': 15},
      {'label': l10n.notifMinutesBefore(20), 'value': 20},
      {'label': l10n.notifMinutesBefore(30), 'value': 30},
      {'label': l10n.notifMinutesBefore(60), 'value': 60},
    ];

    return PopScope(
      canPop: !_busy,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _recordGuideSeen();
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.scaffoldBackgroundColor,
          elevation: 0,
          surfaceTintColor: theme.scaffoldBackgroundColor,
          automaticallyImplyLeading: false,
          leading: _currentPage > 0
              ? IconButton(
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: isDark ? Colors.white70 : const Color(0xFF5F6368),
                  ),
                  onPressed: _busy
                      ? null
                      : () => _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOutCubic,
                          ),
                )
              : null,
        ),
        body: SafeArea(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (index) => setState(() => _currentPage = index),
            children: [
              // 步骤 1: 云备份同步
              _buildStepPage(
                context,
                imageAsset: 'assets/images/sync.png',
                title: l10n.cloudSyncPromptTitle,
                message: l10n.cloudSyncPromptMessage,
                onEnable: () => _handleStepCloudSync(true),
                onSkip: () => _handleStepCloudSync(false),
              ),

              // 步骤 2: 课表自动同步
              _buildStepPage(
                context,
                imageAsset: 'assets/images/sync-classtable.png',
                title: l10n.timetableAutoSyncPromptTitle,
                message: l10n.timetableAutoSyncPromptMessage,
                onEnable: () => _handleStepTimetableSync(true),
                onSkip: () => _handleStepTimetableSync(false),
              ),

              // 步骤 3: 上课提醒（含时间选择框与实时活动开关）
              _buildStepPage(
                context,
                imageAsset: 'assets/images/class-notify.png',
                title: l10n.courseReminder,
                message: l10n.courseReminderPromptMessage,
                extraWidget: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTimeDropdown<int>(
                      context: context,
                      labelText: l10n.courseReminderTime,
                      value: _selectedCourseMinutes,
                      items: courseDurationOptions,
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedCourseMinutes = val);
                        }
                      },
                      isDark: isDark,
                    ),
                    if (_liveSupported) ...[
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark
                                ? Colors.white24
                                : const Color(0xFFDADCE0),
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: _busy
                                ? null
                                : () => setState(() =>
                                    _useLiveActivity = !_useLiveActivity),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.notifications_active_outlined,
                                    color: theme.primaryColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      l10n.useLiveActivityPrompt,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF202124),
                                      ),
                                    ),
                                  ),
                                  BrandSwitch(
                                    value: _useLiveActivity,
                                    onChanged: _busy
                                        ? null
                                        : (val) => setState(
                                            () => _useLiveActivity = val),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                onEnable: () => _handleStepCourseReminder(true),
                onSkip: () => _handleStepCourseReminder(false),
              ),

              // 步骤 4: 作业截止提醒（含时间选择框）
              _buildStepPage(
                context,
                imageAsset: 'assets/images/homework-notify.png',
                title: l10n.homeworkReminderPromptTitle,
                message: l10n.homeworkReminderPromptMessage,
                extraWidget: _buildTimeDropdown<double>(
                  context: context,
                  labelText: l10n.homeworkReminderTime,
                  value: _selectedHwHours,
                  items: homeworkDurationOptions,
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedHwHours = val);
                  },
                  isDark: isDark,
                ),
                onEnable: () => _handleStepHomeworkReminder(true),
                onSkip: () => _handleStepHomeworkReminder(false),
              ),

              // 步骤 5: 图书馆座位提醒（含时间选择框）
              _buildStepPage(
                context,
                imageAsset: 'assets/images/library-notify.png',
                title: l10n.libraryReminderPromptTitle,
                message: l10n.libraryReminderPromptMessage,
                extraWidget: _buildTimeDropdown<int>(
                  context: context,
                  labelText: l10n.libraryReminderTime,
                  value: _selectedLibMinutes,
                  items: libraryDurationOptions,
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedLibMinutes = val);
                  },
                  isDark: isDark,
                ),
                onEnable: () => _handleStepLibraryReminder(true),
                onSkip: () => _handleStepLibraryReminder(false),
              ),

              // 步骤 6: 课表日历订阅
              _buildStepPage(
                context,
                imageAsset: 'assets/images/sub-ics.png',
                title: l10n.timetableSubscriptionPromptTitle,
                message: l10n.timetableSubscriptionPromptMessage,
                onEnable: () => _handleStepTimetableSubscription(true),
                onSkip: () => _handleStepTimetableSubscription(false),
              ),

              // 步骤 7: 大功告成完成页
              _buildStepPage(
                context,
                imageAsset: 'assets/images/done.png',
                title: l10n.postLoginDoneTitle,
                message: l10n.postLoginDoneMessage,
                bottomLeadingWidget: _buildAnalyticsSwitch(context),
                showSkipButton: false,
                showArrowIcon: false,
                enableButtonText: l10n.postLoginDoneButton,
                onEnable: _dismiss,
                onSkip: _dismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsSwitch(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _busy
            ? null
            : () {
                final next = !_analyticsEnabled;
                setState(() => _analyticsEnabled = next);
                AnalyticsService.setEnabled(next);
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.analyticsPromptTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color:
                            isDark ? Colors.white : const Color(0xFF202124),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.analyticsPromptSubtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            isDark ? Colors.white60 : const Color(0xFF5F6368),
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              BrandSwitch(
                value: _analyticsEnabled,
                onChanged: _busy
                    ? null
                    : (val) {
                        setState(() => _analyticsEnabled = val);
                        AnalyticsService.setEnabled(val);
                      },
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeDropdown<T>({
    required BuildContext context,
    required String labelText,
    required T value,
    required List<Map<String, dynamic>> items,
    required ValueChanged<T?> onChanged,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        items: items.map((item) {
          return DropdownMenuItem<T>(
            value: item['value'] as T,
            child: Text(
              item['label'] as String,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white : const Color(0xFF202124),
              ),
            ),
          );
        }).toList(),
        onChanged: _busy ? null : onChanged,
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(
            color: theme.primaryColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: isDark ? Colors.white24 : const Color(0xFFDADCE0),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: isDark ? Colors.white24 : const Color(0xFFDADCE0),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: theme.primaryColor,
              width: 2,
            ),
          ),
          filled: true,
          fillColor: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : const Color(0xFFF8F9FA),
          prefixIcon: Icon(
            Icons.access_time_rounded,
            color: theme.primaryColor,
            size: 20,
          ),
        ),
        dropdownColor: isDark ? const Color(0xFF2A2B2E) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        icon: const Icon(Icons.arrow_drop_down_rounded),
      ),
    );
  }

  Widget _buildStepPage(
    BuildContext context, {
    required String imageAsset,
    required String title,
    required String message,
    Widget? extraWidget,
    Widget? bottomLeadingWidget,
    bool showSkipButton = true,
    bool showArrowIcon = true,
    String? enableButtonText,
    required VoidCallback onEnable,
    required VoidCallback onSkip,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 上方图片区域（限制宽高不超过 50% 且左对齐，置于标题上方一点）
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 0.5,
                alignment: Alignment.bottomLeft,
                child: Image.asset(
                  imageAsset,
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomLeft,
                ),
              ),
            ),
          ),
        ),

        // 底下内容区域（标题、副标题、选择器、底部操作按钮）
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题
              Text(
                title,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF202124),
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.left,
              ),
              const SizedBox(height: 10),

              // 副标题
              Text(
                message,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : const Color(0xFF5F6368),
                  height: 1.5,
                ),
                textAlign: TextAlign.left,
              ),

              // 额外部件（例如供用户自选时长的选择框、实时活动开关）
              if (extraWidget != null) extraWidget,

              const SizedBox(height: 24),

              // 底部操作按钮栏 (左侧可放辅助部件如统计开关，右侧为跳过和开启/完成)
              Row(
                children: [
                  if (bottomLeadingWidget != null)
                    Expanded(child: bottomLeadingWidget)
                  else
                    const Spacer(),
                  // 跳过按钮 (文字在开启按钮左边)
                  if (showSkipButton) ...[
                      TextButton(
                        onPressed: _busy ? null : onSkip,
                        style: TextButton.styleFrom(
                          foregroundColor:
                              isDark ? Colors.white60 : const Color(0xFF5F6368),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          minimumSize: const Size(64, 36),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: Text(
                          l10n.postLoginSetupSkip, // "跳过"
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // 开启/完成按钮 (名字叫开启/完成)
                    ElevatedButton(
                      onPressed: _busy ? null : onEnable,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            theme.primaryColor.withValues(alpha: 0.12),
                        disabledForegroundColor:
                            theme.primaryColor.withValues(alpha: 0.38),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        minimumSize: const Size(88, 36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_busy) ...[
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            enableButtonText ?? l10n.postLoginSetupEnable,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (showArrowIcon) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
            ],
          ),
        ),
      ],
    );
  }
}
