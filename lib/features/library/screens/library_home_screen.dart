import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/utils/l10n_extension.dart';
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
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(context.l10n.checkInSuccessEnjoy),
              ],
            ),
            backgroundColor: const Color(0xFF09C489),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.checkInFailedWithReason(_errorMessage(e)))),
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
        title: Text(context.l10n.confirmCheckOutTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Text(
          context.l10n.confirmCheckOutMessage(reserve.thirdLevelName, reserve.seatNum),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.white60 : Colors.black54,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.thinkAgain, style: const TextStyle(fontSize: 14)),
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
            child: Text(context.l10n.confirmCheckOut,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
          SnackBar(content: Text(context.l10n.checkOutSuccess)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.checkOutFailedWithReason(_errorMessage(e)))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingAction = false);
      }
    }
  }

  String _errorMessage(Object error) {
    final raw = error.toString();
    if (raw.contains('统一认证已过期') ||
        raw.contains('登录会话已过期') ||
        raw.contains('登录已失效')) {
      return context.l10n.ssoExpiredRelogin;
    }
    if (raw.contains('NO_VALID_RESERVATION') ||
        raw.contains('服务器未返回') ||
        raw.contains('未返回有效')) {
      return context.l10n.reservationFailed;
    }
    return raw
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
        title: Text(context.l10n.confirmCancelReservationTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Text(
            context.l10n.confirmCancelReservationMessage(reserve.thirdLevelName, reserve.seatNum)),
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
            child: Text(context.l10n.thinkAgain, style: const TextStyle(fontSize: 14)),
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
            child: Text(
              context.l10n.confirmCancel,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
            SnackBar(content: Text(context.l10n.reservationCancelledSuccess)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    context.l10n.cancelReservationFailedWithReason(e.toString().replaceAll('Exception:', '').trim()))),
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
          content: Row(
            children: [
              const CircularProgressIndicator(color: Color(0xFF09C489)),
              const SizedBox(width: 16),
              Text(context.l10n.submittingReservation),
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
        throw const AppException('NO_VALID_RESERVATION');
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
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF09C489)),
                const SizedBox(width: 8),
                Text(context.l10n.reservationSuccess,
                    style:
                        const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.readingRoomLabel(item.fullRoomName)),
                const SizedBox(height: 4),
                Text(context.l10n.seatNumberLabel(
                    result.seatNum.isNotEmpty ? result.seatNum : item.seatNum)),
                const SizedBox(height: 4),
                Text(context.l10n.dateLabel(selection.day)),
                const SizedBox(height: 4),
                Text(context.l10n.timeValueLabel('${selection.startTime} ~ ${selection.endTime}')),
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
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.l10n.done,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
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
            title: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 8),
                Text(context.l10n.reservationFailed,
                    style:
                        const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                child: Text(context.l10n.iUnderstand,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
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
        title: Text(context.l10n.library),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.refresh,
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
                child: Text(context.l10n.retry),
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
            context.l10n.seatWithNumber(reserve.seatNum),
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
                  child: Text(context.l10n.cancelReservation, style: const TextStyle(fontSize: 13)),
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
                  label: Text(
                    context.l10n.checkIn,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
                  label: Text(context.l10n.checkOut,
                      style:
                          const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
                  context.l10n.reserveSeat,
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
      context.l10n.recentReservations,
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
          context.l10n.noReservationRecords,
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
              child: Text(
                context.l10n.reserve,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
