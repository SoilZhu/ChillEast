import 'package:flutter/material.dart';
import '../models/course_model.dart';
import '../models/timetable_rule_model.dart';
import '../services/timetable_rule_service.dart';
import '../utils/date_calculator.dart';
import '../utils/week_parser.dart';
import '../../../core/utils/l10n_extension.dart';

/// 课表规则操作管理组件
class TimetableRuleDialogs {
  /// 底部菜单：选择要执行的规则操作
  static Future<void> showActionMenu({
    required BuildContext context,
    required List<CourseModel> currentCourses,
    DateTime? firstWeekMonday,
    required VoidCallback onRuleApplied,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentWeek = firstWeekMonday != null
        ? DateCalculator.getCurrentWeekNumber(firstWeekMonday).clamp(1, 25)
        : 1;

    await showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                _buildActionTile(
                  icon: Icons.swap_horiz_rounded,
                  iconColor: Colors.blue,
                  title: context.l10n.reschedule,
                  onTap: () {
                    Navigator.pop(ctx);
                    showRescheduleDialog(
                      context: context,
                      currentCourses: currentCourses,
                      currentWeek: currentWeek,
                      onRuleApplied: onRuleApplied,
                    );
                  },
                ),
                _buildActionTile(
                  icon: Icons.event_busy_rounded,
                  iconColor: Colors.orange,
                  title: context.l10n.suspension,
                  onTap: () {
                    Navigator.pop(ctx);
                    showSuspensionDialog(
                      context: context,
                      currentCourses: currentCourses,
                      currentWeek: currentWeek,
                      onRuleApplied: onRuleApplied,
                    );
                  },
                ),
                _buildActionTile(
                  icon: Icons.add_circle_outline_rounded,
                  iconColor: Colors.green,
                  title: context.l10n.addCourse,
                  onTap: () {
                    Navigator.pop(ctx);
                    showCustomCourseDialog(
                      context: context,
                      currentWeek: currentWeek,
                      onRuleApplied: onRuleApplied,
                    );
                  },
                ),
                _buildActionTile(
                  icon: Icons.rule_folder_outlined,
                  iconColor: Colors.redAccent,
                  title: context.l10n.myAdjustments,
                  onTap: () {
                    Navigator.pop(ctx);
                    showRulesListDialog(
                      context: context,
                      onRuleApplied: onRuleApplied,
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor.withOpacity(0.15),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  /// 阳光服务同款筛选样式：细边框圆角 chip，选中为主题色边框 + 主题色字
  static Widget _buildModeOption({
    required BuildContext context,
    required bool selected,
    required String label,
    required VoidCallback onTap,
  }) {
    final primary = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected
                  ? primary
                  : (isDark ? Colors.white24 : const Color(0xFFDADCE0)),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: selected
                  ? primary
                  : (isDark ? Colors.white70 : Colors.black87),
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  /// 1. 调休/调课对话框 (支持单门课程调课与整日调休)
  static Future<void> showRescheduleDialog({
    required BuildContext context,
    required List<CourseModel> currentCourses,
    int currentWeek = 1,
    required VoidCallback onRuleApplied,
  }) async {
    int rescheduleMode = 0; // 0: 单门调课, 1: 整天调休

    // 单门调课状态
    final courseNames = currentCourses.map((c) => c.name).toSet().toList()
      ..sort();
    String? singleCourseName =
        courseNames.isNotEmpty ? courseNames.first : null;
    int singleSlotIndex = 0;
    int singleSourceWeek = currentWeek;
    int singleTargetWeek = currentWeek;
    int singleTargetDayOfWeek = 5;
    int singleTargetPeriodChoice =
        0; // 0: 保持原节次, 1: 1-2节, 3: 3-4节, 5: 5-6节, 7: 7-8节, 9: 9-10节, 11: 11-12节

    // 整天调休状态
    int wholeSourceWeek = currentWeek;
    int wholeSourceDayOfWeek = 5; // 周五
    int wholeTargetWeek = currentWeek;
    int wholeTargetDayOfWeek = 7; // 周日
    String wholeDayAction = 'move'; // 'copy', 'move', 'swap'

    final weekdayNames = [
      '',
      context.l10n.weekdayMon,
      context.l10n.weekdayTue,
      context.l10n.weekdayWed,
      context.l10n.weekdayThu,
      context.l10n.weekdayFri,
      context.l10n.weekdaySat,
      context.l10n.weekdaySun,
    ];
    final periodChoiceNames = {
      0: context.l10n.keepOriginalPeriod,
      1: context.l10n.periodTimeRange(1, 2, '08:00'),
      3: context.l10n.periodTimeRange(3, 4, '10:05'),
      5: context.l10n.periodTimeRange(5, 6, '14:30'),
      7: context.l10n.periodTimeRange(7, 8, '16:35'),
      9: context.l10n.periodTimeRange(9, 10, '19:30'),
      11: context.l10n.periodTimeRange(11, 12, '21:20'),
    };

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            // 单门调课计算
            final matchingSlots = singleCourseName != null
                ? currentCourses
                    .where((c) => c.name == singleCourseName)
                    .toList()
                : <CourseModel>[];
            if (singleSlotIndex >= matchingSlots.length) {
              singleSlotIndex = 0;
            }
            final CourseModel? activeSlot = matchingSlots.isNotEmpty
                ? matchingSlots[singleSlotIndex]
                : null;
            final slotDay = activeSlot?.dayOfWeek ?? 1;
            final slotStartP = activeSlot?.startPeriod ?? 1;
            final slotEndP = activeSlot?.endPeriod ?? 2;
            final slotWeeks = activeSlot != null
                ? WeekParser.parseWeeks(activeSlot.weeks)
                : <int>[];
            // 原周次只列出该时段真正有课的周
            final singleWeekOptions =
                slotWeeks.isNotEmpty ? (slotWeeks.toList()..sort()) : <int>[];
            final effSingleSourceWeek =
                singleWeekOptions.contains(singleSourceWeek)
                    ? singleSourceWeek
                    : (singleWeekOptions.isNotEmpty
                        ? singleWeekOptions.first
                        : singleSourceWeek);
            final isSingleActiveInWeek =
                slotWeeks.contains(effSingleSourceWeek);

            final targetStartP = singleTargetPeriodChoice == 0
                ? slotStartP
                : singleTargetPeriodChoice;
            final targetEndP = singleTargetPeriodChoice == 0
                ? slotEndP
                : (singleTargetPeriodChoice + 1);

            // 整天调休计算
            final effWholeSourceWeek = wholeSourceWeek.clamp(1, 25);
            final wholeSourceCourses = currentCourses.where((c) {
              if (c.dayOfWeek != wholeSourceDayOfWeek) return false;
              return WeekParser.parseWeeks(c.weeks)
                  .contains(effWholeSourceWeek);
            }).toList();

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.swap_horiz_rounded, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(context.l10n.reschedule,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
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
                    // 模式选择：阳光服务同款 chip，左对齐
                    Row(
                      children: [
                        _buildModeOption(
                          context: context,
                          selected: rescheduleMode == 0,
                          label: context.l10n.rescheduleSingleClass,
                          onTap: () => setState(() => rescheduleMode = 0),
                        ),
                        const SizedBox(width: 8),
                        _buildModeOption(
                          context: context,
                          selected: rescheduleMode == 1,
                          label: context.l10n.rescheduleWholeDay,
                          onTap: () => setState(() => rescheduleMode = 1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (rescheduleMode == 0) ...[
                      // --- 模式 0: 单门调课 ---
                      if (courseNames.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(context.l10n.noCoursesSyncFirst,
                              style: const TextStyle(color: Colors.grey)),
                        )
                      else ...[
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: singleCourseName,
                          decoration: InputDecoration(
                              labelText: context.l10n.courseLabel,
                              filled: false,
                              border: const OutlineInputBorder()),
                          items: courseNames
                              .map((name) => DropdownMenuItem(
                                  value: name,
                                  child: Text(name,
                                      overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              singleCourseName = v;
                              singleSlotIndex = 0;
                              final slots = v == null
                                  ? <CourseModel>[]
                                  : currentCourses
                                      .where((c) => c.name == v)
                                      .toList();
                              final weeks = slots.isNotEmpty
                                  ? WeekParser.parseWeeks(slots.first.weeks)
                                  : <int>[];
                              singleSourceWeek = weeks.contains(currentWeek)
                                  ? currentWeek
                                  : (weeks.isNotEmpty
                                      ? weeks.first
                                      : currentWeek);
                              singleTargetWeek = singleSourceWeek;
                            });
                          },
                        ),
                        if (matchingSlots.length > 1) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            isExpanded: true,
                            value: singleSlotIndex,
                            decoration: InputDecoration(
                                labelText: context.l10n.classTimeSlot,
                                filled: false,
                                border: const OutlineInputBorder()),
                            items: List.generate(matchingSlots.length, (idx) {
                              final m = matchingSlots[idx];
                              return DropdownMenuItem(
                                value: idx,
                                child: Text(
                                    context.l10n.originalSlotFormat(weekdayNames[m.dayOfWeek], m.periods, m.weeks),
                                    style: const TextStyle(fontSize: 13)),
                              );
                            }),
                            onChanged: (v) {
                              setState(() {
                                singleSlotIndex = v ?? 0;
                                final slots = singleCourseName == null
                                    ? <CourseModel>[]
                                    : currentCourses
                                        .where(
                                            (c) => c.name == singleCourseName)
                                        .toList();
                                final weeks = (singleSlotIndex < slots.length)
                                    ? WeekParser.parseWeeks(
                                        slots[singleSlotIndex].weeks)
                                    : <int>[];
                                singleSourceWeek = weeks.contains(currentWeek)
                                    ? currentWeek
                                    : (weeks.isNotEmpty
                                        ? weeks.first
                                        : currentWeek);
                                singleTargetWeek = singleSourceWeek;
                              });
                            },
                          ),
                        ] else if (activeSlot != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            context.l10n.usualTimeFormat(weekdayNames[slotDay], slotStartP, slotEndP, activeSlot.weeks),
                            style: TextStyle(
                                fontSize: 12,
                                color:
                                    isDark ? Colors.white60 : Colors.black54),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                isExpanded: true,
                                value: effSingleSourceWeek,
                                decoration: InputDecoration(
                                    labelText: context.l10n.originalWeek,
                                    filled: false,
                                    border: const OutlineInputBorder()),
                                items: singleWeekOptions
                                    .map((w) => DropdownMenuItem(
                                        value: w,
                                        child: Text(
                                            '${context.l10n.weekNumbered(w)}${w == currentWeek ? context.l10n.currentWeekSuffix : ''}')))
                                    .toList(),
                                onChanged: (v) {
                                  setState(() {
                                    singleSourceWeek = v ?? effSingleSourceWeek;
                                    singleTargetWeek = singleSourceWeek;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: isDark
                                          ? Colors.white24
                                          : Colors.black26),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                    context.l10n.originalPeriodSummary(weekdayNames[slotDay], slotStartP, slotEndP),
                                    style: const TextStyle(fontSize: 13)),
                              ),
                            ),
                          ],
                        ),
                        if (!isSingleActiveInWeek && activeSlot != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            context.l10n.noClassInWeek(effSingleSourceWeek),
                            style: const TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(context.l10n.rescheduleTo,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                isExpanded: true,
                                value: singleTargetWeek,
                                decoration: InputDecoration(
                                    labelText: context.l10n.newWeek,
                                    filled: false,
                                    border: const OutlineInputBorder()),
                                items: List.generate(
                                    25,
                                    (i) => DropdownMenuItem(
                                        value: i + 1,
                                        child: Text(context.l10n.weekNumbered(i + 1)))),
                                onChanged: (v) => setState(() =>
                                    singleTargetWeek =
                                        v ?? effSingleSourceWeek),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                isExpanded: true,
                                value: singleTargetDayOfWeek,
                                decoration: InputDecoration(
                                    labelText: context.l10n.newWeekday,
                                    filled: false,
                                    border: const OutlineInputBorder()),
                                items: List.generate(
                                    7,
                                    (i) => DropdownMenuItem(
                                        value: i + 1,
                                        child: Text(weekdayNames[i + 1]))),
                                onChanged: (v) => setState(
                                    () => singleTargetDayOfWeek = v ?? 1),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          isExpanded: true,
                          value: singleTargetPeriodChoice,
                          decoration: InputDecoration(
                              labelText: context.l10n.newPeriod,
                              filled: false,
                              border: const OutlineInputBorder()),
                          items: periodChoiceNames.entries
                              .map((e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value,
                                      style: const TextStyle(fontSize: 13))))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => singleTargetPeriodChoice = v ?? 0),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: Colors.blue.withOpacity(0.3)),
                          ),
                          child: Text(
                            context.l10n.courseSummaryText(
                              effSingleSourceWeek,
                              singleCourseName ?? '',
                              weekdayNames[slotDay],
                              slotStartP,
                              slotEndP,
                              singleTargetWeek,
                              weekdayNames[singleTargetDayOfWeek],
                              targetStartP,
                              targetEndP,
                            ),
                            style: const TextStyle(
                                fontSize: 12, color: Colors.blue),
                          ),
                        ),
                      ],
                    ] else ...[
                      // --- 模式 1: 整天调休 ---
                      Text(context.l10n.rescheduleAway,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              isExpanded: true,
                              value: effWholeSourceWeek,
                              decoration: InputDecoration(
                                  labelText: context.l10n.originalWeek,
                                  filled: false,
                                  border: const OutlineInputBorder()),
                              items: List.generate(
                                  25,
                                  (i) => DropdownMenuItem(
                                      value: i + 1,
                                      child: Text(
                                          '${context.l10n.weekNumbered(i + 1)}${i + 1 == currentWeek ? context.l10n.currentWeekSuffix : ''}'))),
                              onChanged: (v) => setState(() =>
                                  wholeSourceWeek = v ?? effWholeSourceWeek),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              isExpanded: true,
                              value: wholeSourceDayOfWeek,
                              decoration: InputDecoration(
                                  labelText: context.l10n.originalWeekday,
                                  filled: false,
                                  border: const OutlineInputBorder()),
                              items: List.generate(
                                  7,
                                  (i) => DropdownMenuItem(
                                      value: i + 1,
                                      child: Text(weekdayNames[i + 1]))),
                              onChanged: (v) =>
                                  setState(() => wholeSourceDayOfWeek = v ?? 5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (wholeSourceCourses.isEmpty)
                        Text(
                          context.l10n.noCoursesOnDay,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                              fontWeight: FontWeight.bold),
                        ),
                      const SizedBox(height: 16),
                      Text(context.l10n.rescheduleTo,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              isExpanded: true,
                              value: wholeTargetWeek,
                              decoration: InputDecoration(
                                  labelText: context.l10n.targetWeek,
                                  filled: false,
                                  border: const OutlineInputBorder()),
                              items: List.generate(
                                  25,
                                  (i) => DropdownMenuItem(
                                      value: i + 1, child: Text(context.l10n.weekNumbered(i + 1)))),
                              onChanged: (v) => setState(() =>
                                  wholeTargetWeek = v ?? effWholeSourceWeek),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              isExpanded: true,
                              value: wholeTargetDayOfWeek,
                              decoration: InputDecoration(
                                  labelText: context.l10n.targetWeekday,
                                  filled: false,
                                  border: const OutlineInputBorder()),
                              items: List.generate(
                                  7,
                                  (i) => DropdownMenuItem(
                                      value: i + 1,
                                      child: Text(weekdayNames[i + 1]))),
                              onChanged: (v) =>
                                  setState(() => wholeTargetDayOfWeek = v ?? 7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(context.l10n.rescheduleMethod,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildModeOption(
                            context: context,
                            selected: wholeDayAction == 'copy',
                            label: context.l10n.rescheduleCopy,
                            onTap: () =>
                                setState(() => wholeDayAction = 'copy'),
                          ),
                          const SizedBox(width: 8),
                          _buildModeOption(
                            context: context,
                            selected: wholeDayAction == 'move',
                            label: context.l10n.rescheduleShift,
                            onTap: () =>
                                setState(() => wholeDayAction = 'move'),
                          ),
                          const SizedBox(width: 8),
                          _buildModeOption(
                            context: context,
                            selected: wholeDayAction == 'swap',
                            label: context.l10n.rescheduleSwap,
                            onTap: () =>
                                setState(() => wholeDayAction = 'swap'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        wholeDayAction == 'copy'
                            ? context.l10n.rescheduleCopyDesc
                            : (wholeDayAction == 'swap'
                                ? context.l10n.rescheduleSwapDesc
                                : context.l10n.rescheduleShiftDesc),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color ??
                              Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(context.l10n.cancel),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    if (rescheduleMode == 0) {
                      // 单门调课提交
                      if (singleCourseName == null ||
                          singleCourseName!.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(context.l10n.selectCourseFirst)),
                        );
                        return;
                      }
                      if (!isSingleActiveInWeek) {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: Text(context.l10n.confirmReschedule),
                            content: Text(
                                context.l10n.rescheduleWarnNoCourse(effSingleSourceWeek, singleCourseName!)),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: Text(context.l10n.goBack)),
                              FilledButton(
                                  style: FilledButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => Navigator.pop(c, true),
                                  child: Text(context.l10n.continueAction)),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                      }

                      Navigator.pop(ctx);
                      final rule = TimetableRule.createReschedule(
                        sourceWeek: effSingleSourceWeek,
                        sourceDayOfWeek: slotDay,
                        sourceStartPeriod: slotStartP,
                        sourceEndPeriod: slotEndP,
                        targetWeek: singleTargetWeek,
                        targetDayOfWeek: singleTargetDayOfWeek,
                        targetStartPeriod: targetStartP,
                        targetEndPeriod: targetEndP,
                        courseName: singleCourseName,
                        isSwap: false,
                      );
                      await TimetableRuleService().addRule(rule);
                      onRuleApplied();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(context.l10n.rescheduleSaved),
                              behavior: SnackBarBehavior.floating),
                        );
                      }
                    } else {
                      // 整天调休提交
                      if (wholeSourceCourses.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(context.l10n.noCoursesOnDayCannotReschedule),
                              backgroundColor: Colors.red),
                        );
                        return;
                      }

                      Navigator.pop(ctx);
                      final rule = TimetableRule.createReschedule(
                        sourceWeek: effWholeSourceWeek,
                        sourceDayOfWeek: wholeSourceDayOfWeek,
                        targetWeek: wholeTargetWeek,
                        targetDayOfWeek: wholeTargetDayOfWeek,
                        courseName: null,
                        action: wholeDayAction,
                        isSwap: wholeDayAction == 'swap',
                      );
                      await TimetableRuleService().addRule(rule);
                      onRuleApplied();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(context.l10n.rescheduleDaySaved),
                              behavior: SnackBarBehavior.floating),
                        );
                      }
                    }
                  },
                  child: Text(context.l10n.save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 2. 停课对话框
  static Future<void> showSuspensionDialog({
    required BuildContext context,
    required List<CourseModel> currentCourses,
    int currentWeek = 1,
    required VoidCallback onRuleApplied,
  }) async {
    int startWeek = currentWeek;
    int startDayOfWeek = 1;
    int endWeek = currentWeek;
    int endDayOfWeek = 7;
    String? selectedCourseName; // null 代表全部
    bool limitPeriod = false;
    int startPeriod = 1;
    int endPeriod = 2;

    final courseNames = currentCourses.map((c) => c.name).toSet().toList()
      ..sort();
    final weekdayNames = [
      '',
      context.l10n.weekdayMon,
      context.l10n.weekdayTue,
      context.l10n.weekdayWed,
      context.l10n.weekdayThu,
      context.l10n.weekdayFri,
      context.l10n.weekdaySat,
      context.l10n.weekdaySun,
    ];

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.event_busy_rounded, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(context.l10n.suspension,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
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
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            isExpanded: true,
                            value: startWeek,
                            decoration: InputDecoration(
                                labelText: context.l10n.startWeek,
                                filled: false,
                                border: const OutlineInputBorder()),
                            items: List.generate(
                                25,
                                (i) => DropdownMenuItem(
                                    value: i + 1,
                                    child: Text(
                                        '${context.l10n.weekNumbered(i + 1)}${i + 1 == currentWeek ? context.l10n.currentWeekSuffix : ''}'))),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                startWeek = v;
                                if (startWeek * 7 + startDayOfWeek >
                                    endWeek * 7 + endDayOfWeek) {
                                  endWeek = startWeek;
                                  endDayOfWeek = startDayOfWeek;
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            isExpanded: true,
                            value: startDayOfWeek,
                            decoration: InputDecoration(
                                labelText: context.l10n.weekday,
                                filled: false,
                                border: const OutlineInputBorder()),
                            items: List.generate(
                                7,
                                (i) => DropdownMenuItem(
                                    value: i + 1,
                                    child: Text(weekdayNames[i + 1]))),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                startDayOfWeek = v;
                                if (startWeek * 7 + startDayOfWeek >
                                    endWeek * 7 + endDayOfWeek) {
                                  endWeek = startWeek;
                                  endDayOfWeek = startDayOfWeek;
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            isExpanded: true,
                            value: endWeek,
                            decoration: InputDecoration(
                                labelText: context.l10n.endWeek,
                                filled: false,
                                border: const OutlineInputBorder()),
                            items: List.generate(
                                25,
                                (i) => DropdownMenuItem(
                                    value: i + 1,
                                    child: Text(
                                        '${context.l10n.weekNumbered(i + 1)}${i + 1 == currentWeek ? context.l10n.currentWeekSuffix : ''}'))),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                endWeek = v;
                                if (endWeek * 7 + endDayOfWeek <
                                    startWeek * 7 + startDayOfWeek) {
                                  startWeek = endWeek;
                                  startDayOfWeek = endDayOfWeek;
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            isExpanded: true,
                            value: endDayOfWeek,
                            decoration: InputDecoration(
                                labelText: context.l10n.weekday,
                                filled: false,
                                border: const OutlineInputBorder()),
                            items: List.generate(
                                7,
                                (i) => DropdownMenuItem(
                                    value: i + 1,
                                    child: Text(weekdayNames[i + 1]))),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                endDayOfWeek = v;
                                if (endWeek * 7 + endDayOfWeek <
                                    startWeek * 7 + startDayOfWeek) {
                                  startWeek = endWeek;
                                  startDayOfWeek = endDayOfWeek;
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      isExpanded: true,
                      value: selectedCourseName,
                      decoration: InputDecoration(
                        labelText: context.l10n.courseLabel,
                        filled: false,
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                            value: null, child: Text(context.l10n.allCourses)),
                        ...courseNames.map((name) =>
                            DropdownMenuItem(value: name, child: Text(name))),
                      ],
                      onChanged: (v) => setState(() => selectedCourseName = v),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.l10n.specifyPeriods, style: const TextStyle(fontSize: 14)),
                      value: limitPeriod,
                      onChanged: (v) =>
                          setState(() => limitPeriod = v ?? false),
                    ),
                    if (limitPeriod) ...[
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              isExpanded: true,
                              value: startPeriod,
                              decoration: InputDecoration(
                                  labelText: context.l10n.startPeriod,
                                  filled: false,
                                  border: const OutlineInputBorder()),
                              items: List.generate(
                                  12,
                                  (i) => DropdownMenuItem(
                                      value: i + 1, child: Text(context.l10n.periodNumbered(i + 1)))),
                              onChanged: (v) {
                                setState(() {
                                  startPeriod = v ?? 1;
                                  if (startPeriod > endPeriod) {
                                    endPeriod = startPeriod;
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              isExpanded: true,
                              value: endPeriod,
                              decoration: InputDecoration(
                                  labelText: context.l10n.endPeriod,
                                  filled: false,
                                  border: const OutlineInputBorder()),
                              items: List.generate(
                                  12,
                                  (i) => DropdownMenuItem(
                                      value: i + 1, child: Text(context.l10n.periodNumbered(i + 1)))),
                              onChanged: (v) {
                                setState(() {
                                  endPeriod = v ?? 2;
                                  if (endPeriod < startPeriod) {
                                    startPeriod = endPeriod;
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(context.l10n.cancel),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final rule = TimetableRule.createSuspension(
                      startWeek: startWeek,
                      endWeek: endWeek,
                      startDayOfWeek: startDayOfWeek,
                      endDayOfWeek: endDayOfWeek,
                      courseName: selectedCourseName,
                      startPeriod: limitPeriod ? startPeriod : null,
                      endPeriod: limitPeriod ? endPeriod : null,
                    );
                    await TimetableRuleService().addRule(rule);
                    onRuleApplied();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(context.l10n.suspensionSaved),
                            behavior: SnackBarBehavior.floating),
                      );
                    }
                  },
                  child: Text(context.l10n.save),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 3. 手动添加课程对话框
  static Future<void> showCustomCourseDialog({
    required BuildContext context,
    int currentWeek = 1,
    required VoidCallback onRuleApplied,
  }) async {
    final nameController = TextEditingController();
    final teacherController = TextEditingController();
    final roomController = TextEditingController();
    int startWeek = currentWeek;
    int endWeek = (currentWeek + 15).clamp(1, 25);
    int dayOfWeek = 1;
    int startPeriod = 1;
    int endPeriod = 2;

    final weekdayNames = [
      '',
      context.l10n.weekdayMon,
      context.l10n.weekdayTue,
      context.l10n.weekdayWed,
      context.l10n.weekdayThu,
      context.l10n.weekdayFri,
      context.l10n.weekdaySat,
      context.l10n.weekdaySun,
    ];

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.add_circle_outline_rounded, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(context.l10n.addCourseTitle,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                          labelText: context.l10n.courseNameLabel,
                          filled: false,
                          border: const OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: teacherController,
                      decoration: InputDecoration(
                          labelText: context.l10n.teacherOptional,
                          filled: false,
                          border: const OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: roomController,
                      decoration: InputDecoration(
                          labelText: context.l10n.classroomOptional,
                          filled: false,
                          border: const OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            isExpanded: true,
                            value: startWeek,
                            decoration: InputDecoration(
                                labelText: context.l10n.startWeek,
                                filled: false,
                                border: const OutlineInputBorder()),
                            items: List.generate(
                                25,
                                (i) => DropdownMenuItem(
                                    value: i + 1, child: Text(context.l10n.weekNumbered(i + 1)))),
                            onChanged: (v) =>
                                setState(() => startWeek = v ?? 1),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            isExpanded: true,
                            value: endWeek,
                            decoration: InputDecoration(
                                labelText: context.l10n.endWeek,
                                filled: false,
                                border: const OutlineInputBorder()),
                            items: List.generate(
                                25,
                                (i) => DropdownMenuItem(
                                    value: i + 1, child: Text(context.l10n.weekNumbered(i + 1)))),
                            onChanged: (v) => setState(() => endWeek = v ?? 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      value: dayOfWeek,
                      decoration: InputDecoration(
                          labelText: context.l10n.weekday,
                          filled: false,
                          border: const OutlineInputBorder()),
                      items: List.generate(
                          7,
                          (i) => DropdownMenuItem(
                              value: i + 1, child: Text(weekdayNames[i + 1]))),
                      onChanged: (v) => setState(() => dayOfWeek = v ?? 1),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            isExpanded: true,
                            value: startPeriod,
                            decoration: InputDecoration(
                                labelText: context.l10n.startPeriod,
                                filled: false,
                                border: const OutlineInputBorder()),
                            items: List.generate(
                                12,
                                (i) => DropdownMenuItem(
                                    value: i + 1, child: Text(context.l10n.periodNumbered(i + 1)))),
                            onChanged: (v) {
                              setState(() {
                                startPeriod = v ?? 1;
                                if (endPeriod < startPeriod)
                                  endPeriod = startPeriod;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            isExpanded: true,
                            value: endPeriod,
                            decoration: InputDecoration(
                                labelText: context.l10n.endPeriod,
                                filled: false,
                                border: const OutlineInputBorder()),
                            items: List.generate(
                                12,
                                (i) => DropdownMenuItem(
                                    value: i + 1, child: Text(context.l10n.periodNumbered(i + 1)))),
                            onChanged: (v) {
                              setState(() {
                                endPeriod = v ?? startPeriod;
                                if (endPeriod < startPeriod)
                                  startPeriod = endPeriod;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(context.l10n.cancel),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.l10n.pleaseEnterCourseName)),
                      );
                      return;
                    }

                    Navigator.pop(ctx);
                    final weeksStr = startWeek == endWeek
                        ? '$startWeek(周)'
                        : '$startWeek-$endWeek(周)';
                    final periodsStr = startPeriod == endPeriod
                        ? startPeriod.toString().padLeft(2, '0')
                        : '${startPeriod.toString().padLeft(2, '0')}-${endPeriod.toString().padLeft(2, '0')}';

                    final course = CourseModel(
                      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                      name: name,
                      teacher: teacherController.text.trim(),
                      classroom: roomController.text.trim(),
                      weeks: weeksStr,
                      periods: periodsStr,
                      dayOfWeek: dayOfWeek,
                      startPeriod: startPeriod,
                      endPeriod: endPeriod,
                    );

                    final rule =
                        TimetableRule.createCustomCourse(course: course);
                    await TimetableRuleService().addRule(rule);
                    onRuleApplied();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(context.l10n.addedToTimetable),
                            behavior: SnackBarBehavior.floating),
                      );
                    }
                  },
                  child: Text(context.l10n.add),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 4. 删除规则对话框
  static Future<void> showRulesListDialog({
    required BuildContext context,
    required VoidCallback onRuleApplied,
  }) async {
    final ruleService = TimetableRuleService();
    List<TimetableRule> rules = await ruleService.getRules();

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.rule_folder_outlined, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(context.l10n.myAdjustments,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: rules.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_outline_rounded,
                                size: 48, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(context.l10n.noAdjustmentsYet,
                                style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: rules.length,
                        itemBuilder: (context, index) {
                          final rule = rules[index];
                          Color typeColor;
                          String typeName;
                          switch (rule.type) {
                            case TimetableRuleType.reschedule:
                              typeColor = Colors.blue;
                              typeName = context.l10n.ruleTypeRescheduleDay;
                              break;
                            case TimetableRuleType.suspension:
                              typeColor = Colors.orange;
                              typeName = context.l10n.ruleTypeSuspension;
                              break;
                            case TimetableRuleType.customCourse:
                              typeColor = Colors.green;
                              typeName = context.l10n.ruleTypeAddCourse;
                              break;
                          }

                          return ListTile(
                            dense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 2),
                            leading: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: typeColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                typeName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: typeColor,
                                ),
                              ),
                            ),
                            title: Text(
                              rule.getLocalizedDescription(context),
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 20, color: Colors.redAccent),
                              onPressed: () async {
                                await ruleService.deleteRule(rule.id);
                                rules = await ruleService.getRules();
                                setState(() {});
                                onRuleApplied();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(context.l10n.ruleDeleted),
                                        behavior: SnackBarBehavior.floating),
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                if (rules.isNotEmpty)
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: Text(context.l10n.clearAllAdjustmentsConfirmTitle),
                          content: Text(context.l10n.clearAllAdjustmentsConfirmContent),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: Text(context.l10n.cancel)),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8))),
                              onPressed: () => Navigator.pop(c, true),
                              child: Text(context.l10n.clear),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ruleService.clearAllRules();
                        rules = [];
                        setState(() {});
                        onRuleApplied();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(context.l10n.cleared),
                                behavior: SnackBarBehavior.floating),
                          );
                        }
                      }
                    },
                    child: Text(context.l10n.clearAll),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(context.l10n.close),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
