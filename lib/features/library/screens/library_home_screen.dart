import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/utils/route_utils.dart';
import '../../workspace/screens/scanner_screen.dart';
import '../models/library_models.dart';
import '../providers/library_provider.dart';
import 'library_room_screen.dart';

class LibraryHomeScreen extends ConsumerStatefulWidget {
  const LibraryHomeScreen({super.key});

  @override
  ConsumerState<LibraryHomeScreen> createState() => _LibraryHomeScreenState();
}

class _LibraryHomeScreenState extends ConsumerState<LibraryHomeScreen> {
  bool _isProcessingAction = false;

  Future<void> _handleScanSignIn([LibraryReserveModel? activeReserve]) async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('需要相机权限以完成扫码签到')),
        );
      }
      return;
    }

    if (!mounted) return;

    final scanResult = await Navigator.push<String>(
      context,
      createSlideUpRoute(const ScannerScreen()),
    );

    if (scanResult != null && scanResult.isNotEmpty && mounted) {
      setState(() => _isProcessingAction = true);
      try {
        final reserve = activeReserve ?? ref.read(libraryIndexProvider).value?.activeReservation;
        if (reserve == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('当前没有进行中的预约，无法直接签到')),
          );
          return;
        }

        final success = await ref.read(libraryIndexProvider.notifier).signInSeat(
              seatNum: reserve.seatNum,
              roomId: reserve.roomId,
              reserveId: reserve.id,
              qrUrl: scanResult,
            );

        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text('签到成功！祝您学习愉快。'),
                  ],
                ),
                backgroundColor: Color(0xFF09C489),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('签到失败: ${e.toString().replaceAll('Exception:', '').trim()}')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isProcessingAction = false);
        }
      }
    }
  }

  Future<void> _handleCancelReservation(LibraryReserveModel reserve) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('确认取消预约？', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Text('确定取消在【${reserve.thirdLevelName}】的 ${reserve.seatNum} 号座位预约吗？'),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.white60 : Colors.black54,
              elevation: 0,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('我再想想', style: TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D4F),
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              '确认取消',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isProcessingAction = true);
      try {
        final success = await ref.read(libraryIndexProvider.notifier).cancelReservation(reserve.id);
        if (mounted && success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已成功取消该预约')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('取消失败: ${e.toString().replaceAll('Exception:', '').trim()}')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isProcessingAction = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final indexDataAsync = ref.watch(libraryIndexProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('图书馆'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () => ref.read(libraryIndexProvider.notifier).refresh(),
          ),
        ],
      ),
      body: indexDataAsync.when(
        data: (data) => _buildContent(data),
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF09C489)),
        ),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(err.toString().replaceAll('Exception:', '').trim()),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF09C489),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () => ref.read(libraryIndexProvider.notifier).refresh(),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(LibraryIndexData data) {
    final activeList = data.curReserves;

    return RefreshIndicator(
      color: const Color(0xFF09C489),
      onRefresh: () => ref.read(libraryIndexProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. 当前预约状态看板 (Active Reservation Cards) - 有预约才显示，无预约不显示任何卡片
          if (activeList.isNotEmpty) ...[
            for (int i = 0; i < activeList.length; i++) ...[
              _buildActiveReservationCard(activeList[i]),
              const SizedBox(height: 12),
            ],
          ],

          // 2. 预约选座入口 (单个卡片)
          _buildQuickActionCard(),

          const SizedBox(height: 24),

          // 3. 历史与近期预约记录 (顶格显示，无分割线)
          _buildRecentReservationsHeader(),
          const SizedBox(height: 6),
          if (data.nearReserves.isEmpty)
            _buildEmptyHistoryCard()
          else
            ...data.nearReserves.map((item) => _buildHistoryReservationItem(item)),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildActiveReservationCard(LibraryReserveModel reserve) {
    final timeFormat = DateFormat('HH:mm');
    final startTimeStr = timeFormat.format(reserve.startTime);
    final endTimeStr = timeFormat.format(reserve.endTime);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE0E0E0),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 座位号
          Text(
            '${reserve.seatNum} 号座位',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF222222),
            ),
          ),
          const SizedBox(height: 4),

          // 位置
          Text(
            reserve.fullRoomName,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),

          // 年月日 + 时间（去掉x小时括号）
          Row(
            children: [
              Icon(Icons.access_time_rounded, size: 14, color: isDark ? Colors.white38 : Colors.grey),
              const SizedBox(width: 6),
              Text(
                '${reserve.today}  $startTimeStr - $endTimeStr',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.grey[700]),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 操作按钮 (取消预约 / 扫码签到)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: isDark ? Colors.white60 : Colors.black54,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onPressed: _isProcessingAction ? null : () => _handleCancelReservation(reserve),
                child: const Text('取消预约', style: TextStyle(fontSize: 13)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF09C489),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: const Size(0, 36),
                ),
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                label: const Text('扫码签到', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                onPressed: _isProcessingAction ? null : () => _handleScanSignIn(reserve),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE0E0E0),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () {
            Navigator.push(context, createSlideUpRoute(const LibraryRoomScreen()));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(
                  Icons.event_seat_rounded,
                  color: Color(0xFF09C489),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  '预约选座',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isDark ? Colors.white38 : Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentReservationsHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      '近期预约记录',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _buildEmptyHistoryCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '暂无历史预约记录',
          style: TextStyle(fontSize: 14, color: isDark ? Colors.white38 : Colors.grey),
        ),
      ),
    );
  }

  Widget _buildHistoryReservationItem(LibraryReserveModel item) {
    final timeFormat = DateFormat('HH:mm');
    final startTimeStr = timeFormat.format(item.startTime);
    final endTimeStr = timeFormat.format(item.endTime);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 座位号（字体加大加粗，无 #）
          Text(
            item.seatNum,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF222222),
            ),
          ),
          const SizedBox(height: 4),

          // 2. 位置
          Text(
            item.fullRoomName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),

          // 3. 时间
          Text(
            '${item.today}  $startTimeStr - $endTimeStr',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
