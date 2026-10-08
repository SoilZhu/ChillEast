import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/l10n_extension.dart';
import '../models/library_models.dart';
import '../providers/library_provider.dart';
import '../utils/library_time_utils.dart';
import '../widgets/library_time_range_picker.dart';

class LibraryQuickReserveScreen extends ConsumerStatefulWidget {
  const LibraryQuickReserveScreen({super.key});

  @override
  ConsumerState<LibraryQuickReserveScreen> createState() =>
      _LibraryQuickReserveScreenState();
}

class _LibraryQuickReserveScreenState
    extends ConsumerState<LibraryQuickReserveScreen> {
  late String _selectedDay;
  late String _startTime;
  late String _endTime;

  bool _isLoadingConfig = true;
  bool _isLoadingRooms = false;
  bool _isMatching = false;
  bool _isSubmitting = false;

  String _selectedFirstLevel = '图书馆';

  List<String> _secondLevels = [];
  String? _selectedSecondLevel;

  List<String> _thirdLevels = [];
  String? _selectedThirdLevel;

  LibraryMatchedSeatModel? _matchedSeat;
  String? _matchErrorMessage;

  int _cooldownRemaining = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _initTime();
    _loadConfig();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _initTime() {
    final now = DateTime.now();
    _selectedDay = LibraryTimeUtils.availableReserveDays(now: now).first;
    final defaultStart =
        LibraryTimeUtils.defaultStartTime(_selectedDay, now: now) ?? '08:00';
    final defaultEnd =
        LibraryTimeUtils.defaultEndTime(defaultStart) ?? '10:00';
    _startTime = defaultStart;
    _endTime = defaultEnd;
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoadingConfig = true);
    final service = ref.read(libraryServiceProvider);

    try {
      // 1. 同步服务器开放时间与当前日期
      final startEndData = await service.fetchLiveStartEndTime();
      if (startEndData['ymd'] != null &&
          startEndData['ymd'].toString().isNotEmpty) {
        _selectedDay = startEndData['ymd'].toString();
      }

      // 2. 获取一级分类
      final firsts = await service.fetchLevels(type: 0);
      if (firsts.isNotEmpty) {
        _selectedFirstLevel = firsts.first;
      }

      // 3. 获取二级分类（楼层）
      final seconds = await service.fetchLevels(
        type: 1,
        firstLevelName: _selectedFirstLevel,
      );

      if (mounted) {
        setState(() {
          _secondLevels = seconds;
          _isLoadingConfig = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingConfig = false);
      }
    }
  }

  Future<void> _onFloorSelected(String? floor) async {
    if (_selectedSecondLevel == floor) return;

    setState(() {
      _selectedSecondLevel = floor;
      _selectedThirdLevel = null;
      _thirdLevels = [];
      _matchedSeat = null;
      _matchErrorMessage = null;
    });

    if (floor == null) return;

    setState(() => _isLoadingRooms = true);
    try {
      final service = ref.read(libraryServiceProvider);
      final rooms = await service.fetchLevels(
        type: 2,
        firstLevelName: _selectedFirstLevel,
        secondLevelName: floor,
      );
      if (mounted) {
        setState(() {
          _thirdLevels = rooms;
          _isLoadingRooms = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingRooms = false);
      }
    }
  }

  Future<void> _pickTimeRange() async {
    final result = await showLibraryTimeRangePicker(
      context: context,
      day: _selectedDay,
      initialStartTime: _startTime,
      initialEndTime: _endTime,
    );
    if (result == null || !mounted) return;

    setState(() {
      _startTime = result.startTime;
      _endTime = result.endTime;
      _matchedSeat = null;
      _matchErrorMessage = null;
    });
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownRemaining = 3);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownRemaining <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() => _cooldownRemaining = 0);
        }
      } else {
        if (mounted) {
          setState(() => _cooldownRemaining--);
        }
      }
    });
  }

  Future<void> _handleMatchSeat({bool isReMatch = false}) async {
    if (_isMatching || _isSubmitting) return;
    if (isReMatch && _cooldownRemaining > 0) return;

    setState(() {
      _isMatching = true;
      _matchErrorMessage = null;
      if (!isReMatch) {
        _matchedSeat = null;
      }
    });

    try {
      final service = ref.read(libraryServiceProvider);
      final matched = await service.matchSeat(
        startTime: _startTime,
        endTime: _endTime,
        firstLevelName: _selectedFirstLevel,
        secondLevelName: _selectedSecondLevel ?? '',
        thirdLevelName: _selectedThirdLevel ?? '',
      );

      if (mounted) {
        setState(() {
          _matchedSeat = matched;
          _isMatching = false;
        });
        _startCooldown();
      }
    } catch (e) {
      if (mounted) {
        final errorText = e.toString().replaceAll('Exception:', '').trim();
        setState(() {
          _isMatching = false;
          _matchErrorMessage = errorText;
        });
      }
    }
  }

  Future<void> _handleSubmitReservation() async {
    if (_matchedSeat == null || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final service = ref.read(libraryServiceProvider);
      final result = await service.submitQuickReservation(
        roomId: _matchedSeat!.roomId,
        seatNum: _matchedSeat!.seatNum,
        day: _selectedDay,
        startTime: _startTime,
        endTime: _endTime,
      );

      await ref
          .read(cachedLibraryReserveProvider.notifier)
          .addOrUpdateReserve(result);
      ref.read(libraryIndexProvider.notifier).refresh();

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF09C489)),
              const SizedBox(width: 8),
              Text(
                context.l10n.reservationSuccess,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.readingRoomLabel(_matchedSeat!.fullRoomName)),
              const SizedBox(height: 4),
              Text(context.l10n.seatNumberLabel(
                  result.seatNum.isNotEmpty ? result.seatNum : _matchedSeat!.seatNum)),
              const SizedBox(height: 4),
              Text(context.l10n.dateLabel(_selectedDay)),
              const SizedBox(height: 4),
              Text(context.l10n.timeValueLabel('$_startTime ~ $_endTime')),
              const SizedBox(height: 12),
              Text(
                context.l10n.reservationNotice,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF09C489),
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(0, 36),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true);
              },
              child: Text(
                context.l10n.done,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceAll('Exception:', '').trim();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            title: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  context.l10n.reservationFailed,
                  style:
                      const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Text(
              errorMsg.isNotEmpty ? errorMsg : context.l10n.reservationFailed,
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF09C489),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  context.l10n.iUnderstand,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _calculateDurationText() {
    final startParts = _startTime.split(':');
    final endParts = _endTime.split(':');
    if (startParts.length == 2 && endParts.length == 2) {
      final sMin =
          int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
      final eMin =
          int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
      final diff = (eMin - sMin) / 60.0;
      if (diff > 0) {
        return diff % 1 == 0 ? '${diff.toInt()}h' : '${diff.toStringAsFixed(1)}h';
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final durationText = _calculateDurationText();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.l10n.quickReserve),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.refresh,
            onPressed: () {
              setState(() {
                _matchedSeat = null;
                _matchErrorMessage = null;
              });
              _loadConfig();
            },
          ),
        ],
      ),
      body: _isLoadingConfig
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF09C489)),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. 预约时段选择卡片
                _buildTimePickerCard(isDark, durationText),
                const SizedBox(height: 16),

                // 2. 位置偏好选择卡片
                _buildLocationCard(isDark),
                const SizedBox(height: 16),

                // 3. 预约匹配按钮
                _buildMatchButton(),
                const SizedBox(height: 20),

                // 4. 匹配结果或未匹配到提示
                if (_matchedSeat != null) ...[
                  _buildMatchedResultCard(isDark),
                ] else if (_matchErrorMessage != null) ...[
                  _buildErrorCard(isDark),
                ],
              ],
            ),
    );
  }

  Widget _buildTimePickerCard(bool isDark, String durationText) {
    final dayLabel =
        LibraryTimeUtils.formatDayLabelLocalized(context, _selectedDay);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : const Color(0xFFE0E0E0),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: _pickTimeRange,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      color: Color(0xFF09C489),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.selectReservationPeriod,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      dayLabel,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white38 : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: isDark ? Colors.white38 : Colors.grey,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      '$_startTime ~ $_endTime',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (durationText.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF09C489)
                              .withValues(alpha: isDark ? 0.2 : 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          durationText,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF09C489),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : const Color(0xFFE0E0E0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.place_outlined,
                color: Color(0xFF09C489),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.locationPreference,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '(${context.l10n.optionalLabel})',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 楼层选项
          Text(
            context.l10n.floorLabel,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(context.l10n.allFloors),
                    selected: _selectedSecondLevel == null,
                    selectedColor: const Color(0xFF09C489)
                        .withValues(alpha: isDark ? 0.25 : 0.15),
                    labelStyle: TextStyle(
                      fontSize: 13,
                      color: _selectedSecondLevel == null
                          ? const Color(0xFF09C489)
                          : (isDark ? Colors.white70 : Colors.black87),
                      fontWeight: _selectedSecondLevel == null
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    side: BorderSide(
                      color: _selectedSecondLevel == null
                          ? const Color(0xFF09C489)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : const Color(0xFFE0E0E0)),
                    ),
                    onSelected: (selected) {
                      if (selected) _onFloorSelected(null);
                    },
                  ),
                ),
                for (final floor in _secondLevels)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(floor),
                      selected: _selectedSecondLevel == floor,
                      selectedColor: const Color(0xFF09C489)
                          .withValues(alpha: isDark ? 0.25 : 0.15),
                      labelStyle: TextStyle(
                        fontSize: 13,
                        color: _selectedSecondLevel == floor
                            ? const Color(0xFF09C489)
                            : (isDark ? Colors.white70 : Colors.black87),
                        fontWeight: _selectedSecondLevel == floor
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      side: BorderSide(
                        color: _selectedSecondLevel == floor
                            ? const Color(0xFF09C489)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : const Color(0xFFE0E0E0)),
                      ),
                      onSelected: (selected) {
                        _onFloorSelected(selected ? floor : null);
                      },
                    ),
                  ),
              ],
            ),
          ),

          // 阅览室选项（楼层已选时展示）
          if (_selectedSecondLevel != null) ...[
            const SizedBox(height: 14),
            Text(
              context.l10n.roomLabel,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            if (_isLoadingRooms)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF09C489),
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(context.l10n.allRooms),
                        selected: _selectedThirdLevel == null,
                        selectedColor: const Color(0xFF09C489)
                            .withValues(alpha: isDark ? 0.25 : 0.15),
                        labelStyle: TextStyle(
                          fontSize: 13,
                          color: _selectedThirdLevel == null
                              ? const Color(0xFF09C489)
                              : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: _selectedThirdLevel == null
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        side: BorderSide(
                          color: _selectedThirdLevel == null
                              ? const Color(0xFF09C489)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : const Color(0xFFE0E0E0)),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedThirdLevel = null;
                              _matchedSeat = null;
                            });
                          }
                        },
                      ),
                    ),
                    for (final room in _thirdLevels)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(room),
                          selected: _selectedThirdLevel == room,
                          selectedColor: const Color(0xFF09C489)
                              .withValues(alpha: isDark ? 0.25 : 0.15),
                          labelStyle: TextStyle(
                            fontSize: 13,
                            color: _selectedThirdLevel == room
                                ? const Color(0xFF09C489)
                                : (isDark ? Colors.white70 : Colors.black87),
                            fontWeight: _selectedThirdLevel == room
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          side: BorderSide(
                            color: _selectedThirdLevel == room
                                ? const Color(0xFF09C489)
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : const Color(0xFFE0E0E0)),
                          ),
                          onSelected: (selected) {
                            setState(() {
                              _selectedThirdLevel = selected ? room : null;
                              _matchedSeat = null;
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildMatchButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF09C489),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          minimumSize: const Size(80, 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: (_isMatching || _isSubmitting)
            ? null
            : () => _handleMatchSeat(isReMatch: false),
        child: _isMatching
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                context.l10n.reserve,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildMatchedResultCard(bool isDark) {
    final seat = _matchedSeat!;
    final cooldownActive = _cooldownRemaining > 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFF09C489),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF09C489).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 座位号展示
          Text(
            context.l10n.seatNumberLabel(seat.seatNum),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF222222),
            ),
          ),
          const SizedBox(height: 6),

          // 阅览室位置
          Row(
            children: [
              Icon(
                Icons.room_rounded,
                size: 16,
                color: isDark ? Colors.white38 : Colors.grey[600],
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  seat.fullRoomName,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 时段展示
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 16,
                color: isDark ? Colors.white38 : Colors.grey[600],
              ),
              const SizedBox(width: 6),
              Text(
                '$_selectedDay  ${seat.formattedTimeRange} (${seat.duration}h)',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white38 : Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 操作按钮组：换一个（灰色文字） + 确认（长度缩短右对齐）
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: isDark ? Colors.white54 : Colors.grey[600],
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: cooldownActive || _isSubmitting
                    ? null
                    : () => _handleMatchSeat(isReMatch: true),
                child: Text(
                  cooldownActive
                      ? context.l10n
                          .changeAnotherSeatWithCooldown(_cooldownRemaining)
                      : context.l10n.changeAnotherSeat,
                  style: TextStyle(
                    fontSize: 14,
                    color: cooldownActive
                        ? (isDark ? Colors.white24 : Colors.grey[400])
                        : (isDark ? Colors.white54 : Colors.grey[600]),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF09C489),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  minimumSize: const Size(80, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: _isSubmitting ? null : _handleSubmitReservation,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        context.l10n.confirmQuickReserve,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Colors.orange,
            size: 32,
          ),
          const SizedBox(height: 10),
          Text(
            _matchErrorMessage ?? context.l10n.noMatchedSeatFound,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _handleMatchSeat(isReMatch: false),
            child: Text(
              context.l10n.retry,
              style: const TextStyle(
                color: Color(0xFF09C489),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
