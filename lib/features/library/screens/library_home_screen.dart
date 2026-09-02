import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/utils/route_utils.dart';
import '../models/library_models.dart';
import '../providers/library_provider.dart';
import '../widgets/library_quick_reserve_sheet.dart';
import 'library_room_screen.dart';

class LibraryHomeScreen extends ConsumerStatefulWidget {
  const LibraryHomeScreen({super.key});

  @override
  ConsumerState<LibraryHomeScreen> createState() => _LibraryHomeScreenState();
}

class _LibraryHomeScreenState extends ConsumerState<LibraryHomeScreen> {
  bool _isProcessingAction = false;

  Future<void> _handleSignIn(LibraryReserveModel reserve) async {
    setState(() => _isProcessingAction = true);
    try {
      final success = await ref
          .read(libraryIndexProvider.notifier)
          .signInSeat(reserve);
      if (mounted && success) {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('签到失败: ${_errorMessage(e)}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingAction = false);
      }
    }
  }

  Future<void> _handleSignBack(LibraryReserveModel reserve) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('确认退座？',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Text(
          '确定结束在【${reserve.thirdLevelName}】的 ${reserve.seatNum} 号座位使用吗？',
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.white60 : Colors.black54,
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认退座',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isProcessingAction = true);
    try {
      final success =
          await ref.read(libraryIndexProvider.notifier).signBackSeat(reserve);
      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('退座成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('退座失败: ${_errorMessage(e)}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingAction = false);
      }
    }
  }

  String _errorMessage(Object error) {
    return error
        .toString()
        .replaceAll(RegExp(r'^.*?: '), '')
        .replaceAll(RegExp(r'\s*\(code:.*\)$'), '')
        .trim();
  }

  Future<void> _handleCancelReservation(LibraryReserveModel reserve) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('确认取消预约？',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Text(
            '确定取消在【${reserve.thirdLevelName}】的 ${reserve.seatNum} 号座位预约吗？'),
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
        final success = await ref
            .read(libraryIndexProvider.notifier)
            .cancelReservation(reserve.id);
        if (mounted && success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已成功取消该预约')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    '取消失败: ${e.toString().replaceAll('Exception:', '').trim()}')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isProcessingAction = false);
        }
      }
    }
  }

  Future<void> _handleQuickReserve(LibraryReserveModel item) async {
    final selection = await showLibraryQuickReserveSheet(
      context: context,
      item: item,
    );
    if (selection == null || !mounted) return;

    setState(() => _isProcessingAction = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          content: const Row(
            children: [
              CircularProgressIndicator(color: Color(0xFF09C489)),
              SizedBox(width: 16),
              Text('正在提交预约...'),
            ],
          ),
        ),
      ),
    );

    try {
      final service = ref.read(libraryServiceProvider);
      final result = await service.submitReservation(
        roomId: item.roomId,
        seatNum: item.seatNum,
        day: selection.day,
        startTime: selection.startTime,
        endTime: selection.endTime,
      );

      if (result.id <= 0 && result.seatNum.isEmpty) {
        throw const AppException('服务器未返回有效的预约信息');
      }

      // 刷新全局状态与本地缓存
      await ref
          .read(cachedLibraryReserveProvider.notifier)
          .addOrUpdateReserve(result);
      await ref.read(libraryIndexProvider.notifier).refresh();

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // 关闭 loading 弹窗

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF09C489)),
                SizedBox(width: 8),
                Text('预约成功',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('阅览室：${item.fullRoomName}'),
                const SizedBox(height: 4),
                Text(
                    '座位号：${result.seatNum.isNotEmpty ? result.seatNum : item.seatNum} 号'),
                const SizedBox(height: 4),
                Text('日期：${selection.day}'),
                const SizedBox(height: 4),
                Text('时间：${selection.startTime} ~ ${selection.endTime}'),
                const SizedBox(height: 12),
                const Text(
                  '请在规定时间内完成签到，超时未签到将视为违规。',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
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
                onPressed: () => Navigator.pop(ctx),
                child: const Text('完成',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // 关闭 loading 弹窗

        final errorMsg = _errorMessage(e);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 8),
                Text('预约失败',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              errorMsg.isNotEmpty ? errorMsg : '预约失败，服务器未返回成功预约结果',
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
                child: const Text('我知道了',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingAction = false);
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
                    ref.read(libraryIndexProvider.notifier).refresh(),
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
            ...data.nearReserves.map(
              (item) => _buildHistoryReservationItem(
                item,
                showReserveButton: activeList.isEmpty,
              ),
            ),

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
    final canSignBack = reserve.reserveStatus.canSignBack;

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
              Icon(Icons.access_time_rounded,
                  size: 14, color: isDark ? Colors.white38 : Colors.grey),
              const SizedBox(width: 6),
              Text(
                '${reserve.today}  $startTimeStr - $endTimeStr',
                style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.grey[700]),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 操作按钮：待签到时取消/签到，已入座相关状态时仅显示退座
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!canSignBack) ...[
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? Colors.white60 : Colors.black54,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onPressed: _isProcessingAction
                      ? null
                      : () => _handleCancelReservation(reserve),
                  child: const Text('取消预约', style: TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF09C489),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: const Size(0, 36),
                  ),
                  icon: const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                  ),
                  label: const Text(
                    '签到',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _isProcessingAction
                      ? null
                      : () => _handleSignIn(reserve),
                ),
              ] else
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4D4F),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: const Size(0, 36),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 16),
                  label: const Text('退座',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  onPressed: _isProcessingAction
                      ? null
                      : () => _handleSignBack(reserve),
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
          onTap: () {
            Navigator.push(
                context, createSlideUpRoute(const LibraryRoomScreen()));
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
          style: TextStyle(
              fontSize: 14, color: isDark ? Colors.white38 : Colors.grey),
        ),
      ),
    );
  }

  Widget _buildHistoryReservationItem(
    LibraryReserveModel item, {
    bool showReserveButton = false,
  }) {
    final timeFormat = DateFormat('HH:mm');
    final startTimeStr = timeFormat.format(item.startTime);
    final endTimeStr = timeFormat.format(item.endTime);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
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
          ),
          if (showReserveButton) ...[
            const SizedBox(width: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF09C489),
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                minimumSize: const Size(60, 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: _isProcessingAction
                  ? null
                  : () => _handleQuickReserve(item),
              child: const Text(
                '预约',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
