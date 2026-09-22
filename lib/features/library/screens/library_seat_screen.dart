import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/l10n_extension.dart';
import '../models/library_models.dart';
import '../providers/library_provider.dart';
import '../utils/library_time_utils.dart';
import '../widgets/library_time_range_picker.dart';

class LibrarySeatScreen extends ConsumerStatefulWidget {
  final LibraryRoomModel room;
  final String day;
  final String? initialStartTime;
  final String? initialEndTime;

  const LibrarySeatScreen({
    super.key,
    required this.room,
    required this.day,
    this.initialStartTime,
    this.initialEndTime,
  });

  @override
  ConsumerState<LibrarySeatScreen> createState() => _LibrarySeatScreenState();
}

class _LibrarySeatScreenState extends ConsumerState<LibrarySeatScreen> {
  bool _isLoadingGrid = true;
  bool _isLoadingUsed = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  LibrarySeatGridData? _gridData;
  Set<String> _usedSeats = {};

  String? _selectedSeatNum;
  String _startTime = '08:00';
  String _endTime = '12:00';

  final TransformationController _transformController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    _initTimeSlots();
    _loadSeatGrid();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _initTimeSlots() {
    final now = DateTime.now();
    final defaultStart =
        LibraryTimeUtils.defaultStartTime(widget.day, now: now);
    final defaultEnd = defaultStart == null
        ? null
        : LibraryTimeUtils.defaultEndTime(defaultStart);

    final requestedStart = widget.initialStartTime ?? defaultStart;
    final requestedEnd = widget.initialEndTime ?? defaultEnd;

    if (requestedStart != null &&
        requestedEnd != null &&
        LibraryTimeUtils.isValidRange(
          widget.day,
          requestedStart,
          requestedEnd,
          now: now,
        )) {
      _startTime = requestedStart;
      _endTime = requestedEnd;
    } else {
      _startTime = defaultStart ?? '08:00';
      _endTime = defaultEnd ?? '12:00';
    }
  }

  Future<void> _loadSeatGrid() async {
    setState(() {
      _isLoadingGrid = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(libraryServiceProvider);
      final grid = await service.fetchSeatGrid(roomId: widget.room.id);
      _gridData = grid;
      await _loadUsedSeats();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isLoadingGrid = false;
        });
      }
    }
  }

  Future<void> _loadUsedSeats() async {
    if (_gridData == null) return;
    setState(() => _isLoadingUsed = true);

    try {
      final service = ref.read(libraryServiceProvider);
      final used = await service.fetchUsedSeats(
        roomId: widget.room.id,
        startTime: _startTime,
        endTime: _endTime,
        day: widget.day,
      );
      if (mounted) {
        setState(() {
          _usedSeats = used;
          if (_selectedSeatNum != null &&
              _usedSeats.contains(_selectedSeatNum)) {
            _selectedSeatNum = null;
          }
          _isLoadingGrid = false;
          _isLoadingUsed = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingGrid = false;
          _isLoadingUsed = false;
        });
      }
    }
  }

  Future<void> _submitReservation() async {
    if (_selectedSeatNum == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.pleaseSelectSeatFirst)),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final service = ref.read(libraryServiceProvider);
      final result = await service.submitReservation(
        roomId: widget.room.id,
        seatNum: _selectedSeatNum!,
        day: widget.day,
        startTime: _startTime,
        endTime: _endTime,
      );

      // 刷新全局状态与本地缓存
      ref
          .read(cachedLibraryReserveProvider.notifier)
          .addOrUpdateReserve(result);
      ref.read(libraryIndexProvider.notifier).refresh();

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF09C489)),
              const SizedBox(width: 8),
              Text(context.l10n.reservationSuccess,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.readingRoomLabel(widget.room.displayName)),
              const SizedBox(height: 4),
              Text(context.l10n.seatNumberLabel(result.seatNum)),
              const SizedBox(height: 4),
              Text(context.l10n.dateLabel(widget.day)),
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
              child: Text(context.l10n.done,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            title: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 8),
                Text(context.l10n.reservationFailed,
                    style:
                        const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(e.toString().replaceAll('Exception:', '').trim()),
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
                child: Text(context.l10n.iUnderstand,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
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

  Future<void> _showTimeRangePicker() async {
    final result = await showLibraryTimeRangePicker(
      context: context,
      day: widget.day,
      initialStartTime: _startTime,
      initialEndTime: _endTime,
    );
    if (result == null || !mounted) return;

    setState(() {
      _startTime = result.startTime;
      _endTime = result.endTime;
    });
    await _loadUsedSeats();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.room.displayName),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.refreshSeatStatus,
            onPressed: _loadUsedSeats,
          ),
        ],
      ),
      body: Column(
        children: [
          // 顶部时段与图例栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            child: Column(
              children: [
                // 时段选择卡片
                InkWell(
                  onTap: _showTimeRangePicker,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF09C489)
                          .withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: const Color(0xFF09C489)
                              .withValues(alpha: isDark ? 0.35 : 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_filled_rounded,
                            size: 16, color: Color(0xFF09C489)),
                        const SizedBox(width: 8),
                        Text(
                          context.l10n.dateAndPeriod(widget.day, '$_startTime - $_endTime'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF09C489),
                          ),
                        ),
                        const Spacer(),
                        if (_isLoadingUsed)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFF09C489)),
                          )
                        else
                          const Icon(Icons.arrow_forward_ios_rounded,
                              size: 12, color: Color(0xFF09C489)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // 图例说明
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildLegendItem(
                      color: isDark
                          ? const Color(0xFF16382B)
                          : const Color(0xFFE8F5E9),
                      borderColor: const Color(0xFF09C489),
                      label: context.l10n.seatAvailable,
                      isDark: isDark,
                    ),
                    _buildLegendItem(
                      color: const Color(0xFF09C489),
                      borderColor: const Color(0xFF09C489),
                      label: context.l10n.seatSelected,
                      isDark: isDark,
                    ),
                    _buildLegendItem(
                      color:
                          isDark ? const Color(0xFF2A2A2A) : Colors.grey[300]!,
                      borderColor:
                          isDark ? const Color(0xFF3D3D3D) : Colors.grey[400]!,
                      label: context.l10n.seatOccupied,
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? Colors.white12 : const Color(0xFFEEEEEE),
          ),

          // 中间互动座位图
          Expanded(
            child: _buildSeatGridContent(isDark),
          ),

          // 底部确认卡片
          _buildBottomActionCard(isDark),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required Color borderColor,
    required String label,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: borderColor, width: 1),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white60 : Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildSeatGridContent(bool isDark) {
    if (_isLoadingGrid) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF09C489)),
            const SizedBox(height: 12),
            Text(context.l10n.loadingSeatMap),
          ],
        ),
      );
    }

    if (_errorMessage != null || _gridData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sentiment_dissatisfied,
                size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(_errorMessage ?? context.l10n.loadFailed),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF09C489),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: _loadSeatGrid,
              child: Text(context.l10n.retry),
            ),
          ],
        ),
      );
    }

    final data = _gridData!;
    const double cellSize = 36.0;

    return InteractiveViewer(
      transformationController: _transformController,
      minScale: 0.3,
      maxScale: 3.5,
      boundaryMargin: const EdgeInsets.all(200),
      constrained: false,
      child: Container(
        padding: const EdgeInsets.all(24),
        color: isDark ? const Color(0xFF141414) : const Color(0xFFF8F9FA),
        child: SizedBox(
          width: data.cols * cellSize,
          height: data.rows * cellSize,
          child: Stack(
            children: [
              // 1. 渲染障碍物/桌子
              for (final obs in data.obstacles)
                Positioned(
                  left: (obs.x - 1) * cellSize,
                  top: (obs.y - 1) * cellSize,
                  width: cellSize - 2,
                  height: cellSize - 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          isDark ? const Color(0xFF242424) : Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.center,
                    child: obs.label.isNotEmpty
                        ? Text(
                            obs.label,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white38 : Colors.grey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          )
                        : const SizedBox(),
                  ),
                ),

              // 2. 渲染座位
              for (final seat in data.seats)
                _buildSeatWidget(seat, cellSize, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeatWidget(LibrarySeatItem seat, double cellSize, bool isDark) {
    final isOccupied =
        _usedSeats.contains(seat.seatNum) || seat.reserveStatus != 0;
    final isSelected = _selectedSeatNum == seat.seatNum;

    Color bgColor;
    Color borderColor;
    Color textColor;

    if (isOccupied) {
      bgColor = isDark ? const Color(0xFF262626) : Colors.grey[300]!;
      borderColor = isDark ? const Color(0xFF383838) : Colors.grey[400]!;
      textColor = isDark ? Colors.white24 : Colors.grey[600]!;
    } else if (isSelected) {
      bgColor = const Color(0xFF09C489);
      borderColor = const Color(0xFF09C489);
      textColor = Colors.white;
    } else {
      bgColor = isDark ? const Color(0xFF16382B) : const Color(0xFFE8F5E9);
      borderColor =
          const Color(0xFF09C489).withValues(alpha: isDark ? 0.6 : 0.5);
      textColor = isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20);
    }

    return Positioned(
      left: (seat.x - 1) * cellSize,
      top: (seat.y - 1) * cellSize,
      width: cellSize - 2,
      height: cellSize - 2,
      child: GestureDetector(
        onTap: isOccupied
            ? null
            : () {
                setState(() {
                  if (_selectedSeatNum == seat.seatNum) {
                    _selectedSeatNum = null;
                  } else {
                    _selectedSeatNum = seat.seatNum;
                  }
                });
              },
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: borderColor, width: isSelected ? 1.8 : 1),
          ),
          alignment: Alignment.center,
          child: Text(
            seat.seatNum,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : const Color(0xFFE0E0E0),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(
              height: 38,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF09C489),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                onPressed: (_selectedSeatNum != null && !_isSubmitting)
                    ? _submitReservation
                    : null,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        context.l10n.reserveNow,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
