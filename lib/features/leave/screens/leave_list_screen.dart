import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/route_utils.dart';
import '../models/leave_models.dart';
import '../services/leave_service.dart';
import 'leave_apply_screen.dart';
import 'leave_detail_screen.dart';

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
  String _filter = '全部';
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _load();
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
      setState(() =>
          _error = e is LeaveException ? e.message : '加载失败,请检查网络后重试');
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
            title: const Text('撤销请假?'),
            content: Text('确定撤销《${item.typeName}》(${item.timeRange})吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('撤销',
                    style: TextStyle(color: Colors.red)),
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
        const SnackBar(content: Text('已撤销'), behavior: SnackBarBehavior.floating),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is LeaveException ? e.message : '撤销失败,请稍后重试'),
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
    final filtered = _items.where((item) {
      if (_filter == '待审核') return item.auditStatus == '0';
      if (_filter == '审核中') return item.auditStatus == '8';
      if (_filter == '已审核') return item.auditStatus == '9';
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('请假申请'),
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: theme.scaffoldBackgroundColor,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: '刷新',
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
                              child: const Text('重试'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  _buildApplyCard(isDark),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    children: ['全部', '待审核', '审核中', '已审核']
                        .map((label) => _buildFilterChip(label, isDark))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty && _error == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: Text(
                          '暂无符合条件的请假记录',
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
                  '请假申请',
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

  Widget _buildFilterChip(String label, bool isDark) {
    final isSelected = _filter == label;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _filter = label),
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
            label,
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
                        '${item.typeName.isEmpty ? '请假' : item.typeName} · ${item.durationLabel}',
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
                            '撤销',
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
                  item.statusLabel,
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
