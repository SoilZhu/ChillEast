import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/brand_switch.dart';
import '../models/course_model.dart';
import '../models/course_reminder_rule.dart';
import '../services/course_reminder_storage.dart';
import '../services/timetable_storage.dart';
import '../utils/date_calculator.dart';

/// 课程个性化提醒设置弹窗
class CourseReminderDialog extends StatefulWidget {
  final CourseModel course;
  final int weekNumber;
  final VoidCallback? onSaved;

  const CourseReminderDialog({
    super.key,
    required this.course,
    required this.weekNumber,
    this.onSaved,
  });

  @override
  State<CourseReminderDialog> createState() => _CourseReminderDialogState();
}

enum _ReminderModeOption {
  before,
  after,
  exact,
  disable,
}

class _CourseReminderDialogState extends State<CourseReminderDialog> {
  final _storage = CourseReminderStorage();
  final _minuteController = TextEditingController();

  bool _loading = true;
  List<CourseReminderRule> _existingRules = [];
  CourseReminderRule? _currentEffectiveRule;
  int _globalDefaultMinutes = 0;

  _ReminderModeOption _selectedMode = _ReminderModeOption.before;
  ReminderBaseTime _selectedBaseTime = ReminderBaseTime.settings;
  int _selectedMinutes = 15;
  ReminderScope _selectedScope = ReminderScope.onlyThis;

  final List<int> _quickMinutes = [5, 10, 15, 20, 30, 45, 60];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _minuteController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _globalDefaultMinutes = prefs.getInt('course_reminder_minutes') ?? 0;

    _existingRules = await _storage.readRules();
    _currentEffectiveRule = CourseReminderStorage.resolveEffectiveRule(
      rules: _existingRules,
      courseName: widget.course.name,
      week: widget.weekNumber,
      dayOfWeek: widget.course.dayOfWeek,
      startPeriod: widget.course.startPeriod,
    );

    if (_currentEffectiveRule != null) {
      final rule = _currentEffectiveRule!;
      _selectedScope = rule.scope;
      _selectedBaseTime = rule.baseTime;
      if (rule.isDisabled) {
        _selectedMode = _ReminderModeOption.disable;
      } else if (rule.offsetMinutes == 0) {
        _selectedMode = _ReminderModeOption.exact;
      } else if (rule.offsetMinutes > 0) {
        _selectedMode = _ReminderModeOption.after;
        _selectedMinutes = rule.offsetMinutes;
        _minuteController.text = '$_selectedMinutes';
      } else {
        _selectedMode = _ReminderModeOption.before;
        _selectedMinutes = rule.offsetMinutes.abs();
        _minuteController.text = '$_selectedMinutes';
      }
    } else {
      _selectedBaseTime = ReminderBaseTime.settings;
      _selectedMode = _ReminderModeOption.before;
      _selectedMinutes = 0; // 默认相对于设置时间 0 分钟偏移（即直接跟随设置）
      _minuteController.text = '0';
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  String _getWeekdayName(BuildContext context, int day) {
    switch (day) {
      case 1:
        return context.l10n.weekdayMon;
      case 2:
        return context.l10n.weekdayTue;
      case 3:
        return context.l10n.weekdayWed;
      case 4:
        return context.l10n.weekdayThu;
      case 5:
        return context.l10n.weekdayFri;
      case 6:
        return context.l10n.weekdaySat;
      case 7:
        return context.l10n.weekdaySun;
      default:
        return '$day';
    }
  }

  Future<void> _triggerReschedule() async {
    try {
      final timetableStorage = TimetableStorage();
      final courses = await timetableStorage.readCourseList();
      final monday = await timetableStorage.resolveFirstWeekMonday();
      final prefs = await SharedPreferences.getInstance();
      final defMin = prefs.getInt('course_reminder_minutes') ?? 0;
      if (courses.isNotEmpty) {
        await NotificationService().scheduleCourseReminders(courses, monday, defMin);
      }
    } catch (e) {
      debugPrint('⚠️ 触发重新排程通知失败: $e');
    }
  }

  Future<void> _save() async {
    final int offsetMinutes;
    final ReminderActionType actionType;

    switch (_selectedMode) {
      case _ReminderModeOption.disable:
        actionType = ReminderActionType.disable;
        offsetMinutes = 0;
        break;
      case _ReminderModeOption.exact:
        actionType = ReminderActionType.offset;
        offsetMinutes = 0;
        break;
      case _ReminderModeOption.after:
        actionType = ReminderActionType.offset;
        offsetMinutes = _selectedMinutes.abs();
        break;
      case _ReminderModeOption.before:
        actionType = ReminderActionType.offset;
        offsetMinutes = -_selectedMinutes.abs();
        break;
    }

    final ruleId = _currentEffectiveRule != null &&
            _currentEffectiveRule!.scope == _selectedScope
        ? _currentEffectiveRule!.id
        : 'reminder_${DateTime.now().millisecondsSinceEpoch}_${widget.course.name.hashCode.abs() % 10000}';

    final rule = CourseReminderRule(
      id: ruleId,
      courseName: widget.course.name,
      scope: _selectedScope,
      actionType: actionType,
      baseTime: _selectedBaseTime,
      offsetMinutes: offsetMinutes,
      week: (_selectedScope == ReminderScope.onlyThis ||
              _selectedScope == ReminderScope.thisWeek)
          ? widget.weekNumber
          : null,
      dayOfWeek: (_selectedScope == ReminderScope.onlyThis ||
              _selectedScope == ReminderScope.thisWeekday)
          ? widget.course.dayOfWeek
          : null,
      startPeriod: _selectedScope == ReminderScope.onlyThis
          ? widget.course.startPeriod
          : null,
      createdAt: DateTime.now(),
    );

    await _storage.addOrUpdateRule(rule);
    await _triggerReschedule();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.reminderSaved),
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop(true);
      widget.onSaved?.call();
    }
  }

  Future<void> _restoreDefault() async {
    if (_currentEffectiveRule != null) {
      await _storage.deleteRule(_currentEffectiveRule!.id);
      await _triggerReschedule();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.reminderReset),
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop(true);
      widget.onSaved?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AlertDialog(
        content: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final weekdayStr = _getWeekdayName(context, widget.course.dayOfWeek);
    final theme = Theme.of(context);
    final bool isOffsetActive = _selectedMode == _ReminderModeOption.before ||
        _selectedMode == _ReminderModeOption.after;
    final bool isSwitchActive = _selectedMode != _ReminderModeOption.disable;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.alarm_rounded, color: theme.primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.reminderSettings,
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // 课程与当前课次标签
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.course.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '第${widget.weekNumber}周 $weekdayStr '
                    '${context.l10n.periodsRange(widget.course.startPeriod, widget.course.endPeriod)} '
                    '(${DateCalculator.getSectionTime(widget.course.startPeriod)['start']!.format(context)})',
                    style: TextStyle(fontSize: 12, color: theme.hintColor),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 14, color: theme.primaryColor),
                      const SizedBox(width: 4),
                      Text(
                        '${context.l10n.estimatedReminderTime}: ${_getEstimatedReminderText(context)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 当前状态说明
            if (_currentEffectiveRule != null) ...[
              Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: theme.primaryColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${context.l10n.currentRule}: ${_describeRule(_currentEffectiveRule!, context)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // 提醒方式选择
            Text(
              context.l10n.reminderMode,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildModeChip(_ReminderModeOption.before, context.l10n.reminderBefore),
                _buildModeChip(_ReminderModeOption.after, context.l10n.reminderAfter),
                _buildModeChip(_ReminderModeOption.exact, context.l10n.reminderExact),
                _buildModeChip(_ReminderModeOption.disable, context.l10n.reminderDisabled),
              ],
            ),
            const SizedBox(height: 12),

            // 分钟选择与自定义分钟（在准时或不提醒时保持占位并置灰）
            Opacity(
              opacity: isOffsetActive ? 1.0 : 0.38,
              child: IgnorePointer(
                ignoring: !isOffsetActive,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _quickMinutes.map((m) {
                        final isSel = isOffsetActive && _selectedMinutes == m;
                        return ChoiceChip(
                          label: Text(context.l10n.minutesCount(m)),
                          selected: isSel,
                          onSelected: (val) {
                            if (val) {
                              setState(() {
                                _selectedMinutes = m;
                                _minuteController.text = '$m';
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('自定义分钟: ', style: TextStyle(fontSize: 12)),
                        SizedBox(
                          width: 70,
                          height: 36,
                          child: TextField(
                            controller: _minuteController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 8),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (val) {
                              final parsed = int.tryParse(val);
                              if (parsed != null && parsed >= 0) {
                                setState(() {
                                  _selectedMinutes = parsed;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 开关：相对于设置里的提前通知时间（在不提醒时置灰禁用）
            Opacity(
              opacity: isSwitchActive ? 1.0 : 0.38,
              child: IgnorePointer(
                ignoring: !isSwitchActive,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    setState(() {
                      _selectedBaseTime =
                          _selectedBaseTime == ReminderBaseTime.settings
                              ? ReminderBaseTime.classTime
                              : ReminderBaseTime.settings;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.adjustBasedOnDefault,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _getSwitchSubtitleText(context),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.hintColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        BrandSwitch(
                          value: _selectedBaseTime == ReminderBaseTime.settings,
                          onChanged: (val) {
                            setState(() {
                              _selectedBaseTime = val
                                  ? ReminderBaseTime.settings
                                  : ReminderBaseTime.classTime;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 生效范围选择
            Text(
              context.l10n.reminderScope,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            _buildScopeTile(
              scope: ReminderScope.onlyThis,
              title: context.l10n.scopeOnlyThis,
              subtitle: '第${widget.weekNumber}周 $weekdayStr 本次课',
            ),
            _buildScopeTile(
              scope: ReminderScope.thisWeekday,
              title: context.l10n.scopeThisWeekday(weekdayStr),
              subtitle: '全学期所有周在$weekdayStr的课',
            ),
            _buildScopeTile(
              scope: ReminderScope.thisWeek,
              title: context.l10n.scopeThisWeek(widget.weekNumber),
              subtitle: '第${widget.weekNumber}周该课程的所有课时',
            ),
            _buildScopeTile(
              scope: ReminderScope.all,
              title: context.l10n.scopeAll,
              subtitle: '全学期该课程的所有课时',
            ),
          ],
        ),
      ),
    ),
      actions: [
        if (_currentEffectiveRule != null)
          TextButton(
            onPressed: _restoreDefault,
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: Text(context.l10n.restoreDefault),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.cancel),
        ),
        TextButton(
          onPressed: _save,
          child: Text(
            context.l10n.save,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildModeChip(_ReminderModeOption mode, String label) {
    final isSel = _selectedMode == mode;
    return ChoiceChip(
      label: Text(label),
      selected: isSel,
      onSelected: (val) {
        if (val) {
          setState(() {
            _selectedMode = mode;
          });
        }
      },
    );
  }

  Widget _buildScopeTile({
    required ReminderScope scope,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedScope == scope;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => setState(() => _selectedScope = scope),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Radio<ReminderScope>(
              value: scope,
              groupValue: _selectedScope,
              onChanged: (val) {
                if (val != null) setState(() => _selectedScope = val);
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSwitchSubtitleText(BuildContext context) {
    if (_selectedMode == _ReminderModeOption.disable) {
      return context.l10n.reminderDisabled;
    }

    final bool isBaseSettings = _selectedBaseTime == ReminderBaseTime.settings;

    if (_selectedMode == _ReminderModeOption.exact || _selectedMinutes == 0) {
      if (isBaseSettings) {
        return context.l10n.matchDefaultReminder;
      } else {
        return context.l10n.directClassExact;
      }
    }

    final minText = context.l10n.minutesCount(_selectedMinutes);

    if (isBaseSettings) {
      if (_selectedMode == _ReminderModeOption.before) {
        return context.l10n.adjustDefaultBefore(minText);
      } else {
        return context.l10n.adjustDefaultAfter(minText);
      }
    } else {
      if (_selectedMode == _ReminderModeOption.before) {
        return context.l10n.directClassBefore(minText);
      } else {
        return context.l10n.directClassAfter(minText);
      }
    }
  }

  String _getEstimatedReminderText(BuildContext context) {
    if (_selectedMode == _ReminderModeOption.disable) {
      return context.l10n.reminderDisabled;
    }
    final sectionTime = DateCalculator.getSectionTime(widget.course.startPeriod);
    final tod = sectionTime['start']!;
    final classDateTime = DateTime(2026, 1, 1, tod.hour, tod.minute);

    final int offset;
    switch (_selectedMode) {
      case _ReminderModeOption.disable:
      case _ReminderModeOption.exact:
        offset = 0;
        break;
      case _ReminderModeOption.after:
        offset = _selectedMinutes.abs();
        break;
      case _ReminderModeOption.before:
        offset = -_selectedMinutes.abs();
        break;
    }

    final DateTime resultTime;
    if (_selectedBaseTime == ReminderBaseTime.settings) {
      final base = classDateTime.subtract(Duration(minutes: _globalDefaultMinutes));
      resultTime = base.add(Duration(minutes: offset));
    } else {
      resultTime = classDateTime.add(Duration(minutes: offset));
    }

    final timeStr =
        '${resultTime.hour.toString().padLeft(2, '0')}:${resultTime.minute.toString().padLeft(2, '0')}';
    final diffFromClass = classDateTime.difference(resultTime).inMinutes;

    if (diffFromClass > 0) {
      return '$timeStr (课前 $diffFromClass 分钟)';
    } else if (diffFromClass < 0) {
      return '$timeStr (课后 ${diffFromClass.abs()} 分钟)';
    } else {
      return '$timeStr (准时上课)';
    }
  }

  String _describeRule(CourseReminderRule rule, BuildContext context) {
    if (rule.isDisabled) {
      return context.l10n.reminderDisabled;
    }
    final baseLabel = rule.baseTime == ReminderBaseTime.settings
        ? context.l10n.baseTimeSettings
        : context.l10n.baseTimeClassTime;
    final String offsetDesc;
    if (rule.offsetMinutes == 0) {
      offsetDesc = context.l10n.reminderExact;
    } else if (rule.offsetMinutes > 0) {
      offsetDesc =
          '${context.l10n.reminderAfter} ${context.l10n.minutesCount(rule.offsetMinutes)}';
    } else {
      offsetDesc =
          '${context.l10n.reminderBefore} ${context.l10n.minutesCount(rule.offsetMinutes.abs())}';
    }
    return '$baseLabel · $offsetDesc';
  }
}
