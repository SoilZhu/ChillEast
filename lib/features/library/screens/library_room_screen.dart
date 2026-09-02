import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/route_utils.dart';
import '../models/library_models.dart';
import '../providers/library_provider.dart';
import '../utils/library_time_utils.dart';
import '../widgets/library_time_range_picker.dart';
import 'library_seat_screen.dart';

class LibraryRoomScreen extends ConsumerStatefulWidget {
  const LibraryRoomScreen({super.key});

  @override
  ConsumerState<LibraryRoomScreen> createState() => _LibraryRoomScreenState();
}

class _LibraryRoomScreenState extends ConsumerState<LibraryRoomScreen> {
  late String _selectedDay;
  late List<String> _availableDays;
  String _selectedFloor = '全部';
  String? _selectedStartTime;
  String? _selectedEndTime;

  @override
  void initState() {
    super.initState();
    _initDays();
  }

  void _initDays() {
    _availableDays = LibraryTimeUtils.availableReserveDays();
    _selectedDay = _availableDays.first;
  }

  String _formatDayTab(String dayStr) {
    return LibraryTimeUtils.formatDayLabel(dayStr);
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(libraryRoomsProvider(_selectedDay));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('选择阅览室'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _availableDays = LibraryTimeUtils.availableReserveDays();
                if (!_availableDays.contains(_selectedDay)) {
                  _selectedDay = _availableDays.first;
                  _selectedStartTime = null;
                  _selectedEndTime = null;
                }
              });
              ref.invalidate(libraryRoomsProvider(_selectedDay));
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 日期选择栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _availableDays.map((day) {
                    final isSelected = day == _selectedDay;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_formatDayTab(day)),
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
                          if (selected && _selectedDay != day) {
                            setState(() {
                              _selectedDay = day;
                              _selectedStartTime = null;
                              _selectedEndTime = null;
                            });
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          // 2. 阅览室列表
          Expanded(
            child: roomsAsync.when(
              data: (rooms) => _buildRoomList(rooms),
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF09C489)),
              ),
              error: (err, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    Text(err.toString().replaceAll('Exception:', '').trim()),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF09C489),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () =>
                          ref.invalidate(libraryRoomsProvider(_selectedDay)),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomList(List<LibraryRoomModel> rooms) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 提取全部楼层
    final floors = <String>{'全部'};
    for (final r in rooms) {
      if (r.secondLevelName.isNotEmpty) {
        floors.add(r.secondLevelName);
      }
    }

    // 过滤列表
    final filtered = rooms.where((r) {
      if (_selectedFloor != '全部' && r.secondLevelName != _selectedFloor) {
        return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 楼层快捷过滤
        if (floors.length > 2)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: floors.map((floor) {
                    final isSelected = floor == _selectedFloor;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(floor),
                        selected: isSelected,
                        selectedColor:
                            const Color(0xFF09C489).withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          fontSize: 12,
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
                          setState(() {
                            _selectedFloor = selected ? floor : '全部';
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    '暂无符合条件的阅览室',
                    style:
                        TextStyle(color: isDark ? Colors.white38 : Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final room = filtered[index];
                    return _buildRoomCard(room);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRoomCard(LibraryRoomModel room) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
          onTap: () async {
            final result = await showLibraryTimeRangePicker(
              context: context,
              day: _selectedDay,
              initialStartTime: _selectedStartTime,
              initialEndTime: _selectedEndTime,
            );
            if (!mounted || result == null) return;

            setState(() {
              _selectedStartTime = result.startTime;
              _selectedEndTime = result.endTime;
            });

            Navigator.push(
              context,
              createSlideUpRoute(LibrarySeatScreen(
                room: room,
                day: _selectedDay,
                initialStartTime: result.startTime,
                initialEndTime: result.endTime,
              )),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // 楼层图标装饰
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF09C489).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.meeting_room_rounded,
                    color: Color(0xFF09C489),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // 阅览室详细信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              room.displayName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF222222),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue
                                  .withValues(alpha: isDark ? 0.2 : 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              room.floorName,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.blue[300]
                                    : Colors.blue[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            Icons.event_seat_outlined,
                            size: 13,
                            color: isDark ? Colors.white38 : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '总座位数：${room.capacity}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: isDark ? Colors.white38 : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '07:00 - 22:00',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: isDark ? Colors.white24 : Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
