import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/route_utils.dart';
import '../models/leave_models.dart';
import '../services/leave_service.dart';
import 'leave_apply_screen.dart';
import 'leave_detail_screen.dart';

enum LeaveFilter {
  all,
  pendingAudit,
  auditing,
  audited;

  String getLocalizedLabel(BuildContext context) => switch (this) {
        LeaveFilter.all => context.l10n.all,
        LeaveFilter.pendingAudit => context.l10n.statusPendingAudit,
        LeaveFilter.auditing => context.l10n.statusAuditing,
        LeaveFilter.audited => context.l10n.statusAudited,
      };

  bool matches(LeaveRecord item) => switch (this) {
        LeaveFilter.all => true,
        LeaveFilter.pendingAudit => item.auditStatus == '0',
        LeaveFilter.auditing => item.auditStatus == '8',
        LeaveFilter.audited => item.auditStatus == '9',
      };
}

/// 请假申请 - 功能页（记录列表）
class LeaveListScreen extends ConsumerStatefulWidget {
  const LeaveListScreen({super.key});

  @override
  ConsumerState<LeaveListScreen> createState() => _LeaveListScreenState();
}

class _LeaveListScreenState extends ConsumerState<LeaveListScreen> {
  List<LeaveRecord> _items = [];
  bool _loading = true;
  String? _error;
  LeaveFilter _filter = LeaveFilter.all;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _getErrorMessage(dynamic e) {
    if (e is LeaveException) {
      if (e.message.contains('统一认证已过期')) return context.l10n.ssoExpiredRelogin;
      if (e.message.contains('登录已失效')) return context.l10n.studentSystemSessionExpired;
      return e.message;
    }
    return context.l10n.loadFailedCheckNetwork;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(leaveServiceProvider);
      final items = await service.fetchList();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _getErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openApply() async {
    final changed = await Navigator.of(context).push<bool>(
      createSlideUpRoute(const LeaveApplyScreen()),
    );
    if (changed == true && mounted) _load();
  }

  Future<void> _delete(LeaveRecord item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final base = Theme.of(context);
        return Theme(
          data: ThemeData.from(
            colorScheme: base.colorScheme,
            useMaterial3: false,
          ),
          child: AlertDialog(
            title: Text(context.l10n.cancelLeavePromptTitle),
            content: Text(
              context.l10n.confirmRevokeLeaveItem(
                item.typeName.isEmpty ? context.l10n.leaveApplication : item.typeName,
                item.timeRange,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  context.l10n.revoke,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (confirm != true || _deleting) return;
    setState(() => _deleting = true);
    try {
      await ref.read(leaveServiceProvider).delete(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.revokedSuccess),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is LeaveException ? e.message : context.l10n.revokeFailedRetry),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filtered = _items.where((item) => _filter.matches(item)).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.l10n.leaveApplication),
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: theme.scaffoldBackgroundColor,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: context.l10n.refresh,
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading && _items.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF09C489)),
            )
          : RefreshIndicator(
              color: const Color(0xFF09C489),
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  if (_loading) const LinearProgressIndicator(),
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : const Color(0xFFE0E0E0),
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Column(
                          children: [
                            Text(_error!),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _load,
                              child: Text(context.l10n.retry),
                            ),
                          ],
                        ),
                      ),
                    ),
                  _buildApplyCard(isDark),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    children: LeaveFilter.values
                        .map((filter) => _buildFilterChip(filter, isDark))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty && _error == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: Text(
                          context.l10n.noLeaveRecordsFound,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white38 : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ...filtered.map((item) => _buildItemCard(item, isDark)),
                ],
              ),
            ),
    );
  }

  Widget _buildApplyCard(bool isDark) {
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
          onTap: _openApply,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(
                  Icons.edit_note_rounded,
                  color: Color(0xFF09C489),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  context.l10n.leaveApplication,
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

  Widget _buildFilterChip(LeaveFilter filter, bool isDark) {
    final isSelected = _filter == filter;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _filter = filter),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF09C489)
                  : (isDark ? Colors.white24 : const Color(0xFFDADCE0)),
            ),
          ),
          child: Text(
            filter.getLocalizedLabel(context),
            style: TextStyle(
              fontSize: 13,
              color: isSelected
                  ? const Color(0xFF09C489)
                  : (isDark ? Colors.white70 : Colors.black87),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(LeaveRecord item, bool isDark) {
    final statusColor = switch (item.auditStatus) {
      '0' => const Color(0xFFE63476),
      '8' => Colors.orange,
      '9' => const Color(0xFF09C489),
      _ => Colors.grey,
    };
    final typeTitle = item.typeName.isEmpty ? context.l10n.leaveApplication : item.typeName;
    final duration = item.getLocalizedDuration(context);
    final titleText = duration.isNotEmpty ? '$typeTitle · $duration' : typeTitle;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : const Color(0xFFE0E0E0),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () async {
            final changed = await Navigator.of(context).push<bool>(
              createSlideUpRoute(LeaveDetailScreen(item: item)),
            );
            if (changed == true && mounted) _load();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        titleText,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF222222),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (item.canDelete)
                      InkWell(
                        onTap: () => _delete(item),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Text(
                            context.l10n.revoke,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ),
                      )
                    else
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 13,
                        color: isDark ? Colors.white24 : Colors.grey[400],
                      ),
                  ],
                ),
                if (item.timeRange.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.timeRange,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
                if (item.reason.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.reason,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  item.getLocalizedStatus(context),
                  style: TextStyle(
                    fontSize: 12,
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
