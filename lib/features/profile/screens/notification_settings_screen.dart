import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/services/course_live_service.dart';
import '../../../core/services/flyme_live_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/brand_switch.dart';
import '../providers/settings_provider.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  /// 开启时自动申请缺失的权限，不展示任何卡片
  Future<void> _ensurePermissionsIfNeeded() async {
    try {
      // iOS：仅需通知权限（已在 NotificationService init 时设为不自动申请）
      if (Platform.isIOS) {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          await Permission.notification.request();
        }
        return;
      }

      if (!Platform.isAndroid) return;

      // Android：1. 通知总开关（Android 13+）
      final notifEnabled =
          await NotificationService().areNotificationsEnabled();
      if (notifEnabled != true) {
        await NotificationService().requestNotificationsPermission();
      }

      // 2. 精确闹钟（Android 12+）
      final canExact = await NotificationService().canScheduleExactAlarms();
      if (canExact != true) {
        await NotificationService().requestExactAlarmsPermission();
      }

      // 3. 后台运行 / 忽略省电优化（国产 ROM 关键）
      try {
        final status = await Permission.ignoreBatteryOptimizations.status;
        if (!status.isGranted) {
          await Permission.ignoreBatteryOptimizations.request();
        }
      } catch (_) {}
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    final courseDurations = [
      {'label': context.l10n.notifDurationNone, 'value': 0},
      {'label': context.l10n.notifMinutesBefore(5), 'value': 5},
      {'label': context.l10n.notifMinutesBefore(10), 'value': 10},
      {'label': context.l10n.notifMinutesBefore(20), 'value': 20},
      {'label': context.l10n.notifMinutesBefore(30), 'value': 30},
      {'label': context.l10n.notifMinutesBefore(40), 'value': 40},
      {'label': context.l10n.notifMinutesBefore(50), 'value': 50},
      {'label': context.l10n.notifMinutesBefore(60), 'value': 60},
    ];

    final homeworkDurations = [
      {'label': context.l10n.notifDurationNone, 'value': 0.0},
      {'label': context.l10n.notifHoursBefore('0.5'), 'value': 0.5},
      {'label': context.l10n.notifHoursBefore('1'), 'value': 1.0},
      {'label': context.l10n.notifHoursBefore('2'), 'value': 2.0},
      {'label': context.l10n.notifHoursBefore('6'), 'value': 6.0},
      {'label': context.l10n.notifHoursBefore('12'), 'value': 12.0},
      {'label': context.l10n.notifHoursBefore('24'), 'value': 24.0},
      {'label': context.l10n.notifHoursBefore('48'), 'value': 48.0},
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.l10n.notificationSettings),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF202124),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      body: ListView(
        children: [
          // 实时活动置顶（仅 Android 可见；iOS 直接隐藏）
          if (Platform.isAndroid) const CourseLiveSection(),
          // Flyme 实况通知：紧跟实时活动，仅 Flyme 12+ 可见
          if (Platform.isAndroid) const FlymeLiveSection(),
          _buildSettingItem(
            context,
            icon: Icons.book_outlined,
            title: context.l10n.courseReminder,
            subtitle: courseDurations.firstWhere(
                (e) => e['value'] == settings.reminderMinutes,
                orElse: () => courseDurations[0])['label'] as String,
            onTap: () => _showPicker(
              context,
              title: context.l10n.courseReminderTime,
              options: courseDurations,
              currentValue: settings.reminderMinutes,
              onSelected: (val) async {
                final v = val as int;
                if (v != 0) {
                  // 先申请权限，再排程；否则首次开启时排程会在 POST_NOTIFICATIONS
                  // 授权前执行，授权后系统不会自动补回已失败的排程。
                  await _ensurePermissionsIfNeeded();
                }
                await ref.read(settingsProvider.notifier).setReminderMinutes(v);
              },
            ),
          ),
          _buildSettingItem(
            context,
            icon: Icons.assignment_outlined,
            title: context.l10n.homeworkReminder,
            subtitle: homeworkDurations.firstWhere(
                (e) => (e['value'] as double) == settings.homeworkReminderHours,
                orElse: () => homeworkDurations[0])['label'] as String,
            onTap: () => _showPicker(
              context,
              title: context.l10n.homeworkReminderTime,
              options: homeworkDurations,
              currentValue: settings.homeworkReminderHours,
              onSelected: (val) async {
                final v = val as double;
                if (v != 0) {
                  await _ensurePermissionsIfNeeded();
                }
                await ref
                    .read(settingsProvider.notifier)
                    .setHomeworkReminderHours(v);
              },
            ),
          ),
          _buildSettingItem(
            context,
            icon: Icons.event_seat_outlined,
            title: context.l10n.libraryReminder,
            subtitle: courseDurations.firstWhere(
                (e) => e['value'] == settings.libraryReminderMinutes,
                orElse: () => courseDurations[0])['label'] as String,
            onTap: () => _showPicker(
              context,
              title: context.l10n.libraryReminderTime,
              options: courseDurations,
              currentValue: settings.libraryReminderMinutes,
              onSelected: (val) async {
                final v = val as int;
                if (v != 0) {
                  await _ensurePermissionsIfNeeded();
                }
                await ref
                    .read(settingsProvider.notifier)
                    .setLibraryReminderMinutes(v);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 24, color: const Color(0xFF5F6368)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: isDark ? Colors.white : const Color(0xFF202124),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPicker(
    BuildContext context, {
    required String title,
    required List<Map<String, dynamic>> options,
    required dynamic currentValue,
    required Future<void> Function(dynamic) onSelected,
  }) {    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final opt = options[index];
                    final isSelected = opt['value'] == currentValue;
                    return ListTile(
                      title: Text(opt['label']),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Color(0xFF09C489))
                          : null,
                      onTap: () async {
                        Navigator.pop(context);
                        try {
                          await onSelected(opt['value']);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(context.l10n.setSuccessfully(opt['label'] as String)),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(context.l10n.setNotificationFailed(e.toString())),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 实时活动：Android 16+ Live Updates 开关 + 点行发送/撤回测试。
///
/// - 非 A16 设备：显示不支持，开关置灰，点行只提示。
/// - A16 设备：点整行发一次测试（含课程卡 + 图书馆座位卡），再点一次撤回。
class CourseLiveSection extends ConsumerStatefulWidget {
  const CourseLiveSection({super.key});

  @override
  ConsumerState<CourseLiveSection> createState() => _CourseLiveSectionState();
}

class _CourseLiveSectionState extends ConsumerState<CourseLiveSection> {
  bool? _supported; // null = 检测中（只按 AOSP 版本：Android 16+ 即支持）
  bool _notifOn = false;
  bool _busy = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final supported = await CourseLiveService().isSupported();
    bool notifOn = false;
    if (supported) {
      notifOn = await CourseLiveService().areNotificationsEnabled();
    }
    if (mounted) {
      setState(() {
        _supported = supported;
        _notifOn = notifOn;
      });
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? Colors.red : null,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _onToggle(bool value) async {
    final l10n = context.l10n;
    if (_supported != true) {
      _snack(l10n.liveUpdatesNotSupported, error: true);
      return;
    }
    if (value) {
      // 开启前确保通知总开关已给，避免开了也弹不出。
      final on = await CourseLiveService().areNotificationsEnabled();
      if (!on) {
        final granted =
            await NotificationService().requestNotificationsPermission();
        await _refreshStatus();
        if (granted != true) {
          _snack(l10n.needNotificationPermission, error: true);
          return;
        }
      }
    }
    final flymeWasOn = ref.read(settingsProvider).flymeLiveEnabled;
    await ref.read(settingsProvider.notifier).setCourseLiveEnabled(value);
    if (value && flymeWasOn) {
      _snack(l10n.liveActivityEnabledFlymeDisabled);
    } else {
      _snack(value ? l10n.liveActivityEnabled : l10n.liveActivityDisabled);
    }
  }

  /// 单击整行：跳本应用的系统通知设置页。
  Future<void> _onRowTap() async {
    if (_busy || _supported != true) return;
    final l10n = context.l10n;
    final ok = await CourseLiveService().openNotificationSettings();
    if (!ok) {
      _snack(l10n.openSystemSettingsFailed, error: true);
    } else {
      // 从设置页返回后刷新通知开关状态
      await _refreshStatus();
    }
  }

  /// 双击整行：没在测就发一次测试，在测就撤回。
  Future<void> _onRowDoubleTap() async {
    if (_busy) return;
    final l10n = context.l10n;
    if (_supported != true) {
      _snack(l10n.liveUpdatesNotSupported, error: true);
      return;
    }
    if (_testing) {
      await CourseLiveService().cancelTest();
      if (mounted) {
        setState(() {
          _testing = false;
        });
      }
      _snack(l10n.testRetracted);
      return;
    }
    setState(() => _busy = true);
    try {
      final on = await CourseLiveService().areNotificationsEnabled();
      if (!on) {
        await NotificationService().requestNotificationsPermission();
      }
      final ok = await CourseLiveService().startTest();
      await _refreshStatus();
      if (!mounted) return;
      if (ok) {
        setState(() {
          _testing = true;
        });
        _snack(l10n.testSent);
      } else {
        _snack(l10n.sendFailedCheckPermission, error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(settingsProvider).courseLiveEnabled;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // A16 以下直接整条隐藏（检测中也先不占位，避免闪一下再消失）
    if (_supported != true) return const SizedBox.shrink();

    String subtitle = context.l10n.liveActivitySubtitle;
    if (_testing) {
      subtitle += ' · ${context.l10n.doubleTapToRetract}';
    } else if (!_notifOn) {
      subtitle += ' · ${context.l10n.systemNotificationDisabled}';
    }

    return InkWell(
      onTap: _busy ? null : _onRowTap,
      onDoubleTap: _busy ? null : _onRowDoubleTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            const Icon(Icons.timeline_outlined,
                size: 24, color: Color(0xFF5F6368)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(context.l10n.liveActivity,
                          style: const TextStyle(fontSize: 16)),
                      if (_testing) ...[
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isDark ? Colors.white : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            // 与 App 主题色一致的 MD2 样式开关
            BrandSwitch(
              value: enabled && _supported == true,
              onChanged: (_supported == null || _busy) ? null : _onToggle,
            ),
          ],
        ),
      ),
    );
  }
}

/// 实况通知：Flyme 12+ 专属，紧跟“实时活动”下面，与之互斥（不能同开）。
///
/// - 非 Flyme 12+：整条隐藏。
/// - 点整行发一次测试（含课程卡 + 图书馆座位卡），再点一次撤回。
class FlymeLiveSection extends ConsumerStatefulWidget {
  const FlymeLiveSection({super.key});

  @override
  ConsumerState<FlymeLiveSection> createState() => _FlymeLiveSectionState();
}

class _FlymeLiveSectionState extends ConsumerState<FlymeLiveSection> {
  bool? _supported; // null = 检测中
  bool _notifOn = false;
  bool _busy = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final supported = await FlymeLiveService().isSupported();
    bool notifOn = false;
    if (supported) {
      notifOn = await FlymeLiveService().areNotificationsEnabled();
    }
    if (mounted) {
      setState(() {
        _supported = supported;
        _notifOn = notifOn;
      });
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? Colors.red : null,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _onToggle(bool value) async {
    if (_supported != true) return;
    final l10n = context.l10n;
    if (value) {
      final on = await FlymeLiveService().areNotificationsEnabled();
      if (!on) {
        final granted =
            await NotificationService().requestNotificationsPermission();
        await _refreshStatus();
        if (granted != true) {
          _snack(l10n.needNotificationPermission, error: true);
          return;
        }
      }
    }
    final courseWasOn = ref.read(settingsProvider).courseLiveEnabled;
    await ref.read(settingsProvider.notifier).setFlymeLiveEnabled(value);
    if (value && courseWasOn) {
      _snack(l10n.flymeLiveEnabledActivityDisabled);
    } else {
      _snack(value ? l10n.flymeLiveEnabled : l10n.flymeLiveDisabled);
    }
  }

  /// 单击整行：跳本应用的系统通知设置页。
  Future<void> _onRowTap() async {
    if (_busy || _supported != true) return;
    final l10n = context.l10n;
    final ok = await FlymeLiveService().openNotificationSettings();
    if (!ok) {
      _snack(l10n.openSystemSettingsFailed, error: true);
    } else {
      await _refreshStatus();
    }
  }

  /// 双击整行：没在测就发一次测试，在测就撤回。
  Future<void> _onRowDoubleTap() async {
    if (_busy) return;
    if (_supported != true) return;
    final l10n = context.l10n;
    if (_testing) {
      await FlymeLiveService().cancelTest();
      if (mounted) {
        setState(() {
          _testing = false;
        });
      }
      _snack(l10n.testRetracted);
      return;
    }
    setState(() => _busy = true);
    try {
      final on = await FlymeLiveService().areNotificationsEnabled();
      if (!on) {
        await NotificationService().requestNotificationsPermission();
      }
      final ok = await FlymeLiveService().startTest();
      await _refreshStatus();
      if (!mounted) return;
      if (ok) {
        setState(() {
          _testing = true;
        });
        _snack(l10n.testSent);
      } else {
        _snack(l10n.sendFailedCheckPermission, error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(settingsProvider).flymeLiveEnabled;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 非 Flyme 12+ 直接整条隐藏
    if (_supported != true) return const SizedBox.shrink();

    String subtitle = context.l10n.flymeLiveSubtitle;
    if (_testing) {
      subtitle += ' · ${context.l10n.doubleTapToRetract}';
    } else if (!_notifOn) {
      subtitle += ' · ${context.l10n.systemNotificationDisabled}';
    }

    return InkWell(
      onTap: _busy ? null : _onRowTap,
      onDoubleTap: _busy ? null : _onRowDoubleTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            const Icon(Icons.notifications_active_outlined,
                size: 24, color: Color(0xFF5F6368)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(context.l10n.flymeLive,
                          style: const TextStyle(fontSize: 16)),
                      if (_testing) ...[
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isDark ? Colors.white : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            // 与 App 主题色一致的 MD2 样式开关
            BrandSwitch(
              value: enabled && _supported == true,
              onChanged: (_supported == null || _busy) ? null : _onToggle,
            ),
          ],
        ),
      ),
    );
  }
}
