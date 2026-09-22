import 'package:flutter/material.dart';
import '../../../core/utils/l10n_extension.dart';
import '../utils/library_time_utils.dart';

/// 统一的预约时段选择弹窗。
///
/// 开始时间会根据 [day] 和当前时刻过滤，今天只能选择严格晚于当前时刻的
/// 半小时刻度；结束时间始终必须晚于开始时间。
Future<LibraryTimeRangeSelection?> showLibraryTimeRangePicker({
  required BuildContext context,
  required String day,
  String? initialStartTime,
  String? initialEndTime,
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final openedAt = DateTime.now();
  final allSlots = LibraryTimeUtils.buildTimeSlots();
  final availableStarts = LibraryTimeUtils.availableStartSlots(
    day,
    now: openedAt,
  );
  final candidateEnds = LibraryTimeUtils.candidateEndSlots(
    day,
    now: openedAt,
  );

  var tempStart = initialStartTime;
  if (tempStart == null || !availableStarts.contains(tempStart)) {
    tempStart = LibraryTimeUtils.defaultStartTime(day, now: openedAt);
  }

  var tempEnd = initialEndTime;
  if (tempStart == null ||
      !LibraryTimeUtils.availableEndSlots(tempStart).contains(tempEnd)) {
    tempEnd =
        tempStart == null ? null : LibraryTimeUtils.defaultEndTime(tempStart);
  }

  return showModalBottomSheet<LibraryTimeRangeSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          final startIndex =
              tempStart == null ? -1 : allSlots.indexOf(tempStart!);
          final canConfirm = tempStart != null &&
              tempEnd != null &&
              LibraryTimeUtils.isValidRange(
                day,
                tempStart!,
                tempEnd!,
                now: DateTime.now(),
              );

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.l10n.selectReservationPeriod,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.startTime,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: availableStarts.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final slot = availableStarts[index];
                      final isSelected = slot == tempStart;
                      return ChoiceChip(
                        label: Text(slot),
                        selected: isSelected,
                        selectedColor:
                            const Color(0xFF09C489).withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          fontSize: 13,
                          color: isSelected
                              ? const Color(0xFF09C489)
                              : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: BorderSide(
                            color: isSelected
                                ? const Color(0xFF09C489)
                                : (isDark ? Colors.white12 : Colors.grey[300]!),
                          ),
                        ),
                        onSelected: (selected) {
                          if (!selected) return;
                          setModalState(() {
                            tempStart = slot;
                            final slotIndex = allSlots.indexOf(slot);
                            final currentEndIndex = tempEnd == null
                                ? -1
                                : allSlots.indexOf(tempEnd!);
                            if (currentEndIndex <= slotIndex) {
                              tempEnd = LibraryTimeUtils.defaultEndTime(slot);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                if (availableStarts.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.noAvailableSlotsForDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.orange[300] : Colors.orange[800],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  context.l10n.endTime,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: candidateEnds.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final slot = candidateEnds[index];
                      final isAvailable =
                          startIndex >= 0 && allSlots.indexOf(slot) > startIndex;
                      final isSelected = slot == tempEnd;
                      return ChoiceChip(
                        label: Text(slot),
                        selected: isSelected,
                        selectedColor:
                            const Color(0xFF09C489).withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          fontSize: 13,
                          color: !isAvailable
                              ? (isDark ? Colors.white24 : Colors.grey[400])
                              : (isSelected
                                  ? const Color(0xFF09C489)
                                  : (isDark ? Colors.white70 : Colors.black87)),
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: BorderSide(
                            color: isSelected
                                ? const Color(0xFF09C489)
                                : (isDark ? Colors.white12 : Colors.grey[300]!),
                          ),
                        ),
                        onSelected: isAvailable
                            ? (selected) {
                                if (selected) {
                                  setModalState(() => tempEnd = slot);
                                }
                              }
                            : null,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF09C489),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          const Color(0xFF09C489).withValues(alpha: 0.35),
                      disabledForegroundColor: Colors.white70,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: canConfirm
                        ? () => Navigator.pop(
                              ctx,
                              LibraryTimeRangeSelection(
                                startTime: tempStart!,
                                endTime: tempEnd!,
                              ),
                            )
                        : null,
                    child: Text(
                      context.l10n.confirmPeriod,
                      style:
                          const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
