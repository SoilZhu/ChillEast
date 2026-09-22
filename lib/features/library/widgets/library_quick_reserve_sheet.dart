import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/l10n_extension.dart';
import '../models/library_models.dart';
import '../utils/library_time_utils.dart';

/// 快速预约选择结果
class LibraryQuickReserveResult {
  final String day;
  final String startTime;
  final String endTime;

  const LibraryQuickReserveResult({
    required this.day,
    required this.startTime,
    required this.endTime,
  });
}

/// 弹出快速预约日期与时段选择面板
Future<LibraryQuickReserveResult?> showLibraryQuickReserveSheet({
  required BuildContext context,
  required LibraryReserveModel item,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showModalBottomSheet<LibraryQuickReserveResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (ctx) => LibraryQuickReserveSheet(item: item),
  );
}

class LibraryQuickReserveSheet extends StatefulWidget {
  final LibraryReserveModel item;

  const LibraryQuickReserveSheet({
    super.key,
    required this.item,
  });

  @override
  State<LibraryQuickReserveSheet> createState() =>
      _LibraryQuickReserveSheetState();
}

class _LibraryQuickReserveSheetState extends State<LibraryQuickReserveSheet> {
  late List<String> _availableDays;
  late String _selectedDay;
  String? _selectedStartTime;
  String? _selectedEndTime;

  @override
  void initState() {
    super.initState();
    _initDaysAndTimes();
  }

  void _initDaysAndTimes() {
    final now = DateTime.now();
    _availableDays = LibraryTimeUtils.availableReserveDays(now: now);

    // 如果今天已没有可约时段（比如晚上 21:30 之后），且明天可选，默认切到明天
    final todayStarts =
        LibraryTimeUtils.availableStartSlots(_availableDays[0], now: now);
    if (todayStarts.isEmpty && _availableDays.length > 1) {
      _selectedDay = _availableDays[1];
    } else {
      _selectedDay = _availableDays[0];
    }

    _initTimesForSelectedDay(now: now);
  }

  void _initTimesForSelectedDay({DateTime? now}) {
    final currentNow = now ?? DateTime.now();
    final timeFormat = DateFormat('HH:mm');
    final historyStart = timeFormat.format(widget.item.startTime);
    final historyEnd = timeFormat.format(widget.item.endTime);

    // 如果历史预约的时间段在所选日期合法，优先使用历史时间段
    if (LibraryTimeUtils.isValidRange(
      _selectedDay,
      historyStart,
      historyEnd,
      now: currentNow,
    )) {
      _selectedStartTime = historyStart;
      _selectedEndTime = historyEnd;
      return;
    }

    // 否则使用默认推荐时段
    final defaultStart =
        LibraryTimeUtils.defaultStartTime(_selectedDay, now: currentNow);
    _selectedStartTime = defaultStart;
    _selectedEndTime = defaultStart != null
        ? LibraryTimeUtils.defaultEndTime(defaultStart)
        : null;
  }

  void _onDaySelected(String day) {
    if (_selectedDay == day) return;
    setState(() {
      _selectedDay = day;
      final now = DateTime.now();
      final availableStarts =
          LibraryTimeUtils.availableStartSlots(_selectedDay, now: now);

      if (_selectedStartTime == null ||
          !availableStarts.contains(_selectedStartTime)) {
        _selectedStartTime =
            LibraryTimeUtils.defaultStartTime(_selectedDay, now: now);
      }

      if (_selectedStartTime != null) {
        final availableEnds =
            LibraryTimeUtils.availableEndSlots(_selectedStartTime!);
        if (_selectedEndTime == null ||
            !availableEnds.contains(_selectedEndTime)) {
          _selectedEndTime =
              LibraryTimeUtils.defaultEndTime(_selectedStartTime!);
        }
      } else {
        _selectedEndTime = null;
      }
    });
  }

  String _formatDayLabel(BuildContext context, String dayStr) {
    return LibraryTimeUtils.formatDayLabelLocalized(context, dayStr);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final allSlots = LibraryTimeUtils.buildTimeSlots();
    final availableStarts =
        LibraryTimeUtils.availableStartSlots(_selectedDay, now: now);
    final candidateEnds =
        LibraryTimeUtils.candidateEndSlots(_selectedDay, now: now);

    final startIndex =
        _selectedStartTime == null ? -1 : allSlots.indexOf(_selectedStartTime!);
    final canConfirm = _selectedStartTime != null &&
        _selectedEndTime != null &&
        LibraryTimeUtils.isValidRange(
          _selectedDay,
          _selectedStartTime!,
          _selectedEndTime!,
          now: now,
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部标题与关闭按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.quickReserve,
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
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          // 目标座位信息卡片
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF09C489)
                  .withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFF09C489)
                    .withValues(alpha: isDark ? 0.35 : 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.event_seat_rounded,
                  size: 18,
                  color: Color(0xFF09C489),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.seatWithNumber(widget.item.seatNum),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF09C489),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.item.fullRoomName,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 1. 选择日期
          Text(
            context.l10n.selectDate,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _availableDays.map((day) {
                final isSelected = day == _selectedDay;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_formatDayLabel(context, day)),
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
                      if (selected) {
                        _onDaySelected(day);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 14),

          // 2. 开始时间
          Text(
            context.l10n.startTime,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (availableStarts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                context.l10n.noAvailableSlotsForDate,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.orange[300] : Colors.orange[800],
                ),
              ),
            )
          else
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: availableStarts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final slot = availableStarts[index];
                  final isSelected = slot == _selectedStartTime;
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
                      setState(() {
                        _selectedStartTime = slot;
                        final slotIndex = allSlots.indexOf(slot);
                        final currentEndIndex = _selectedEndTime == null
                            ? -1
                            : allSlots.indexOf(_selectedEndTime!);
                        if (currentEndIndex <= slotIndex) {
                          _selectedEndTime =
                              LibraryTimeUtils.defaultEndTime(slot);
                        }
                      });
                    },
                  );
                },
              ),
            ),

          const SizedBox(height: 14),

          // 3. 结束时间
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
                final isSelected = slot == _selectedEndTime;
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
                            setState(() => _selectedEndTime = slot);
                          }
                        }
                      : null,
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // 确认预约按钮
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
                        context,
                        LibraryQuickReserveResult(
                          day: _selectedDay,
                          startTime: _selectedStartTime!,
                          endTime: _selectedEndTime!,
                        ),
                      )
                  : null,
              child: Text(
                canConfirm
                    ? context.l10n.confirmReservationPeriod(
                        _selectedDay,
                        _selectedStartTime!,
                        _selectedEndTime!,
                      )
                    : context.l10n.pleaseSelectValidPeriod,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
