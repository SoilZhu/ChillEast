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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('确认取消预约？'),
        content: Text('确定取消在【${reserve.thirdLevelName}】的 #${reserve.seatNum} 号座位预约吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('我再想想', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认取消'),
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

  void _showRulesDialog(LibrarySeatConfig? config) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF09C489)),
            SizedBox(width: 8),
            Text('图书馆预约规则'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('• 开放时间：07:00 - 22:00', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Text('• 提前预约：可提前 ${config?.reserveBeforeDay ?? 1} 天预约（每天 ${config?.reserveBeforeTime ?? '19:00'} 开放）', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Text('• 签到时限：开始前 ${config?.preSignDuration ?? 15} 分钟至开始后 ${config?.signDuration ?? 15} 分钟内完成签到', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            const Text('• 暂离说明：暂离需在规定时间内扫码返回，超时将释放座位并记违规。', style: TextStyle(fontSize: 14)),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF09C489)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final indexDataAsync = ref.watch(libraryIndexProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('图书馆'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: '扫码签到',
            onPressed: () => _handleScanSignIn(),
          ),
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
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF09C489)),
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
    final active = data.activeReservation;

    return RefreshIndicator(
      color: const Color(0xFF09C489),
      onRefresh: () => ref.read(libraryIndexProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. 当前预约状态看板 (Active Reservation Card)
          if (active != null)
            _buildActiveReservationCard(active)
          else
            _buildNoActiveReservationCard(),

          const SizedBox(height: 20),

          // 2. 快捷功能入口
          _buildQuickActionGrid(data.config),

          const SizedBox(height: 24),

          // 3. 历史与近期预约记录
          _buildRecentReservationsHeader(),
          const SizedBox(height: 12),
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

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF09C489), Color(0xFF06A874)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF09C489).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      reserve.reserveStatus.label,
                      style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Text(
                reserve.today,
                style: const TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 座位号与阅览室
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '#${reserve.seatNum}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '号座位',
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            reserve.fullRoomName,
            style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 14, color: Colors.white70),
              const SizedBox(width: 6),
              Text(
                '$startTimeStr - $endTimeStr (时长: ${reserve.duration ?? "1.0"}小时)',
                style: const TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(height: 1, color: Colors.white24),
          const SizedBox(height: 16),

          // 操作按钮 (签到 / 取消)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF09C489),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                  label: const Text('扫码签到', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _isProcessingAction ? null : () => _handleScanSignIn(reserve),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
                onPressed: _isProcessingAction ? null : () => _handleCancelReservation(reserve),
                child: const Text('取消预约'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoActiveReservationCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF09C489).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chair_alt_rounded,
              color: Color(0xFF09C489),
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '当前暂无生效中的座位预约',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            '提前选座，开启高效专注的一天',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF09C489),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('前往预约选座', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.push(context, createSlideUpRoute(const LibraryRoomScreen()));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionGrid(LibrarySeatConfig? config) {
    return Row(
      children: [
        Expanded(
          child: _buildActionTile(
            icon: Icons.event_seat_rounded,
            title: '预约选座',
            subtitle: '全校阅览室地图',
            color: const Color(0xFF09C489),
            onTap: () {
              Navigator.push(context, createSlideUpRoute(const LibraryRoomScreen()));
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionTile(
            icon: Icons.qr_code_scanner_rounded,
            title: '扫码签到',
            subtitle: '扫描座位二维码',
            color: const Color(0xFF2196F3),
            onTap: () => _handleScanSignIn(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionTile(
            icon: Icons.menu_book_rounded,
            title: '预约规则',
            subtitle: '开放与时限说明',
            color: const Color(0xFFFF9800),
            onTap: () => _showRulesDialog(config),
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentReservationsHeader() {
    return const Row(
      children: [
        Icon(Icons.history_rounded, size: 20, color: Colors.black87),
        SizedBox(width: 8),
        Text(
          '近期预约记录',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildEmptyHistoryCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: const Text('暂无历史预约记录', style: TextStyle(color: Colors.grey)),
    );
  }

  Widget _buildHistoryReservationItem(LibraryReserveModel item) {
    final timeFormat = DateFormat('HH:mm');
    final startTimeStr = timeFormat.format(item.startTime);
    final endTimeStr = timeFormat.format(item.endTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  '#${item.seatNum}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                Text(
                  '座位',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.fullRoomName,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.today}  $startTimeStr - $endTimeStr',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: item.reserveStatus == ReserveStatus.completed
                  ? Colors.grey.withValues(alpha: 0.1)
                  : Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              item.reserveStatus.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: item.reserveStatus == ReserveStatus.completed ? Colors.grey[700] : Colors.orange[800],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
