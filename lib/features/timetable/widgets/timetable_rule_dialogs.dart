import 'package:flutter/material.dart';
import '../models/course_model.dart';
import '../models/timetable_rule_model.dart';
import '../services/timetable_rule_service.dart';
import '../utils/date_calculator.dart';
import '../utils/week_parser.dart';

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
                  title: '调课',
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
                  title: '停课',
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
                  title: '加课',
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
                  title: '我的调整',
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

    final weekdayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final periodChoiceNames = {
      0: '保持原节次',
      1: '第1-2节 08:00',
      3: '第3-4节 10:05',
      5: '第5-6节 14:30',
      7: '第7-8节 16:35',
      9: '第9-10节 19:30',
      11: '第11-12节 21:20',
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
              title: const Row(
                children: [
                  Icon(Icons.swap_horiz_rounded, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('调课',
                        style: TextStyle(
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
                          label: '调一节',
                          onTap: () => setState(() => rescheduleMode = 0),
                        ),
                        const SizedBox(width: 8),
                        _buildModeOption(
                          context: context,
                          selected: rescheduleMode == 1,
                          label: '调一天',
                          onTap: () => setState(() => rescheduleMode = 1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (rescheduleMode == 0) ...[
                      // --- 模式 0: 单门调课 ---
                      if (courseNames.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('暂无课程，请先同步课表',
                              style: TextStyle(color: Colors.grey)),
                        )
                      else ...[
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: singleCourseName,
                          decoration: const InputDecoration(
                              labelText: '课程',
                              filled: false,
                              border: OutlineInputBorder()),
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
                            decoration: const InputDecoration(
                                labelText: '上课时段',
                                filled: false,
                                border: OutlineInputBorder()),
                            items: List.generate(matchingSlots.length, (idx) {
                              final m = matchingSlots[idx];
                              return DropdownMenuItem(
                                value: idx,
                                child: Text(
                                    '周${weekdayNames[m.dayOfWeek]} 第${m.periods}节 (${m.weeks})',
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
                            '平时：每周${weekdayNames[slotDay]} 第${slotStartP}-${slotEndP}节 (${activeSlot.weeks})',
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
                                decoration: const InputDecoration(
                                    labelText: '原周次',
                                    filled: false,
                                    border: OutlineInputBorder()),
                                items: singleWeekOptions
                                    .map((w) => DropdownMenuItem(
                                        value: w,
                                        child: Text(
                                            '第$w周${w == currentWeek ? ' (本周)' : ''}')))
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
                                    '原${weekdayNames[slotDay]} 第$slotStartP-$slotEndP节',
                                    style: const TextStyle(fontSize: 13)),
                              ),
                            ),
                          ],
                        ),
                        if (!isSingleActiveInWeek && activeSlot != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            '第$effSingleSourceWeek周没有这节课',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                        const SizedBox(height: 16),
                        const Text('调到',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                isExpanded: true,
                                value: singleTargetWeek,
                                decoration: const InputDecoration(
                                    labelText: '新周次',
                                    filled: false,
                                    border: OutlineInputBorder()),
                                items: List.generate(
                                    25,
                                    (i) => DropdownMenuItem(
                                        value: i + 1,
                                        child: Text('第${i + 1}周'))),
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
                                decoration: const InputDecoration(
                                    labelText: '新星期',
                                    filled: false,
                                    border: OutlineInputBorder()),
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
                          decoration: const InputDecoration(
                              labelText: '新节次',
                              filled: false,
                              border: OutlineInputBorder()),
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
                            '第$effSingleSourceWeek周《$singleCourseName》：${weekdayNames[slotDay]}$slotStartP-$slotEndP节 → 第$singleTargetWeek周${weekdayNames[singleTargetDayOfWeek]}$targetStartP-$targetEndP节',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.blue),
                          ),
                        ),
                      ],
                    ] else ...[
                      // --- 模式 1: 整天调休 ---
                      const Text('调走',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              isExpanded: true,
                              value: effWholeSourceWeek,
                              decoration: const InputDecoration(
                                  labelText: '原周次',
                                  filled: false,
                                  border: OutlineInputBorder()),
                              items: List.generate(
                                  25,
                                  (i) => DropdownMenuItem(
                                      value: i + 1,
                                      child: Text(
                                          '第${i + 1}周${i + 1 == currentWeek ? ' (本周)' : ''}'))),
                              onChanged: (v) => setState(() =>
                                  wholeSourceWeek = v ?? effWholeSourceWeek),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              isExpanded: true,
                              value: wholeSourceDayOfWeek,
                              decoration: const InputDecoration(
                                  labelText: '原星期',
                                  filled: false,
                                  border: OutlineInputBorder()),
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
                        const Text(
                          '当天没有课',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                              fontWeight: FontWeight.bold),
                        ),
                      const SizedBox(height: 16),
                      const Text('调到',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              isExpanded: true,
                              value: wholeTargetWeek,
                              decoration: const InputDecoration(
                                  labelText: '目标周次',
                                  filled: false,
                                  border: OutlineInputBorder()),
                              items: List.generate(
                                  25,
                                  (i) => DropdownMenuItem(
                                      value: i + 1, child: Text('第${i + 1}周'))),
                              onChanged: (v) => setState(() =>
                                  wholeTargetWeek = v ?? effWholeSourceWeek),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              isExpanded: true,
                              value: wholeTargetDayOfWeek,
                              decoration: const InputDecoration(
                                  labelText: '目标星期',
                                  filled: false,
                                  border: OutlineInputBorder()),
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
                      const Text('调课方式',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildModeOption(
                            context: context,
                            selected: wholeDayAction == 'copy',
                            label: '复制',
                            onTap: () =>
                                setState(() => wholeDayAction = 'copy'),
                          ),
                          const SizedBox(width: 8),
                          _buildModeOption(
                            context: context,
                            selected: wholeDayAction == 'move',
                            label: '平移',
                            onTap: () =>
                                setState(() => wholeDayAction = 'move'),
                          ),
                          const SizedBox(width: 8),
                          _buildModeOption(
                            context: context,
                            selected: wholeDayAction == 'swap',
                            label: '对调',
                            onTap: () =>
                                setState(() => wholeDayAction = 'swap'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        wholeDayAction == 'copy'
                            ? '原日期的课保留，目标日原本的课会被覆盖'
                            : (wholeDayAction == 'swap'
                                ? '两天的课程互相交换'
                                : '只把课挪过去，原日期的课不保留，目标日原本的课会被覆盖'),
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
                  child: const Text('取消'),
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
                          const SnackBar(content: Text('请先选择课程')),
                        );
                        return;
                      }
                      if (!isSingleActiveInWeek) {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('确认调课'),
                            content: Text(
                                '第$effSingleSourceWeek周没有《$singleCourseName》，继续吗？'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('返回')),
                              FilledButton(
                                  style: FilledButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('继续')),
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
                          const SnackBar(
                              content: Text('调课已保存'),
                              behavior: SnackBarBehavior.floating),
                        );
                      }
                    } else {
                      // 整天调休提交
                      if (wholeSourceCourses.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('当天没有课，无法调休'),
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
                          const SnackBar(
                              content: Text('调休已保存'),
                              behavior: SnackBarBehavior.floating),
                        );
                      }
                    }
                  },
                  child: const Text('保存'),
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
    final weekdayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.event_busy_rounded, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('停课',
                        style: TextStyle(
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
                            decoration: const InputDecoration(
                                labelText: '起始周',
                                filled: false,
                                border: OutlineInputBorder()),
                            items: List.generate(
                                25,
                                (i) => DropdownMenuItem(
                                    value: i + 1,
                                    child: Text(
                                        '第${i + 1}周${i + 1 == currentWeek ? ' (本周)' : ''}'))),
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
                            decoration: const InputDecoration(
                                labelText: '星期',
                                filled: false,
                                border: OutlineInputBorder()),
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
                            decoration: const InputDecoration(
                                labelText: '结束周',
                                filled: false,
                                border: OutlineInputBorder()),
                            items: List.generate(
                                25,
                                (i) => DropdownMenuItem(
                                    value: i + 1,
                                    child: Text(
                                        '第${i + 1}周${i + 1 == currentWeek ? ' (本周)' : ''}'))),
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
                            decoration: const InputDecoration(
                                labelText: '星期',
                                filled: false,
                                border: OutlineInputBorder()),
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
                      decoration: const InputDecoration(
                        labelText: '课程',
                        filled: false,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('全部课程')),
                        ...courseNames.map((name) =>
                            DropdownMenuItem(value: name, child: Text(name))),
                      ],
                      onChanged: (v) => setState(() => selectedCourseName = v),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('指定节次', style: TextStyle(fontSize: 14)),
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
                              decoration: const InputDecoration(
                                  labelText: '开始节次',
                                  filled: false,
                                  border: OutlineInputBorder()),
                              items: List.generate(
                                  12,
                                  (i) => DropdownMenuItem(
                                      value: i + 1, child: Text('第${i + 1}节'))),
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
                              decoration: const InputDecoration(
                                  labelText: '结束节次',
                                  filled: false,
                                  border: OutlineInputBorder()),
                              items: List.generate(
                                  12,
                                  (i) => DropdownMenuItem(
                                      value: i + 1, child: Text('第${i + 1}节'))),
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
                  child: const Text('取消'),
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
                        const SnackBar(
                            content: Text('停课已保存'),
                            behavior: SnackBarBehavior.floating),
                      );
                    }
                  },
                  child: const Text('保存'),
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

    final weekdayNames = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.add_circle_outline_rounded, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('添加课程',
                        style: TextStyle(
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
                      decoration: const InputDecoration(
                          labelText: '课程名称',
                          filled: false,
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: teacherController,
                      decoration: const InputDecoration(
                          labelText: '授课教师 (选填)',
                          filled: false,
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: roomController,
                      decoration: const InputDecoration(
                          labelText: '教室 (选填)',
                          filled: false,
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            isExpanded: true,
                            value: startWeek,
                            decoration: const InputDecoration(
                                labelText: '起始周',
                                filled: false,
                                border: OutlineInputBorder()),
                            items: List.generate(
                                25,
                                (i) => DropdownMenuItem(
                                    value: i + 1, child: Text('第${i + 1}周'))),
                            onChanged: (v) =>
                                setState(() => startWeek = v ?? 1),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            isExpanded: true,
                            value: endWeek,
                            decoration: const InputDecoration(
                                labelText: '结束周',
                                filled: false,
                                border: OutlineInputBorder()),
                            items: List.generate(
                                25,
                                (i) => DropdownMenuItem(
                                    value: i + 1, child: Text('第${i + 1}周'))),
                            onChanged: (v) => setState(() => endWeek = v ?? 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      value: dayOfWeek,
                      decoration: const InputDecoration(
                          labelText: '星期',
                          filled: false,
                          border: OutlineInputBorder()),
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
                            decoration: const InputDecoration(
                                labelText: '开始节次',
                                filled: false,
                                border: OutlineInputBorder()),
                            items: List.generate(
                                12,
                                (i) => DropdownMenuItem(
                                    value: i + 1, child: Text('第${i + 1}节'))),
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
                            decoration: const InputDecoration(
                                labelText: '结束节次',
                                filled: false,
                                border: OutlineInputBorder()),
                            items: List.generate(
                                12,
                                (i) => DropdownMenuItem(
                                    value: i + 1, child: Text('第${i + 1}节'))),
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
                  child: const Text('取消'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请填写课程名称')),
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
                        const SnackBar(
                            content: Text('已添加到课表'),
                            behavior: SnackBarBehavior.floating),
                      );
                    }
                  },
                  child: const Text('添加'),
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
              title: const Row(
                children: [
                  Icon(Icons.rule_folder_outlined, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('我的调整',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: rules.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline_rounded,
                                size: 48, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('还没有任何调整',
                                style: TextStyle(color: Colors.grey)),
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
                              typeName = '调休';
                              break;
                            case TimetableRuleType.suspension:
                              typeColor = Colors.orange;
                              typeName = '停课';
                              break;
                            case TimetableRuleType.customCourse:
                              typeColor = Colors.green;
                              typeName = '加课';
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
                              rule.description,
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
                                    const SnackBar(
                                        content: Text('已删除'),
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
                          title: const Text('清空全部调整？'),
                          content: const Text('清空后课表恢复为教务原样。'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('取消')),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8))),
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('清空'),
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
                            const SnackBar(
                                content: Text('已清空'),
                                behavior: SnackBarBehavior.floating),
                          );
                        }
                      }
                    },
                    child: const Text('清空全部'),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('关闭'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
