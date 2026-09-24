import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/l10n_extension.dart';
import '../models/repair_models.dart';
import '../services/repair_service.dart';
import '../utils/repair_log_parse.dart';
import '../widgets/authenticated_bxpt_image.dart';

class RepairDetailScreen extends ConsumerStatefulWidget {
  final RepairOrder order;
  const RepairDetailScreen({super.key, required this.order});
  @override
  ConsumerState<RepairDetailScreen> createState() => _RepairDetailScreenState();
}

class _RepairDetailScreenState extends ConsumerState<RepairDetailScreen> {
  RepairOrder? _detail;
  bool _loading = true;
  bool _cancelling = false;
  String? _error;

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
      final data =
          await ref.read(repairServiceProvider).fetchOrderDetail(widget.order);
      if (mounted) setState(() => _detail = data);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is RepairException
            ? e.message
            : context.l10n.loadFailedCheckNetwork);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onCancel(RepairOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.repairsCancelConfirmTitle),
        content: Text(context.l10n.repairsCancelConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await ref.read(repairServiceProvider).cancelOrder(order);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.l10n.repairsCancelSuccess),
        behavior: SnackBarBehavior.floating,
      ));
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is RepairException
              ? e.message
              : context.l10n.loadFailedCheckNetwork),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    final y = d.year;
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final h = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$y-$m-$day $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final order = _detail ?? widget.order;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: bgColor,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(context.l10n.repairsOrderDetail),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: context.l10n.refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading && _detail == null
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF09C489)),
            )
          : RefreshIndicator(
              color: const Color(0xFF09C489),
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(
                            color: theme.colorScheme.onErrorContainer),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 1. 基本信息卡片
                  _buildHeaderCard(order, theme),
                  const SizedBox(height: 14),

                  // 2. 问题描述与处理情况
                  _buildContentCard(order, theme),
                  const SizedBox(height: 14),

                  // 3. 附件图片（如有）
                  if (order.attachments.isNotEmpty) ...[
                    _buildAttachmentsCard(order, theme),
                    const SizedBox(height: 14),
                  ],

                  // 4. 流转历史记录
                  _buildTimelineCard(order, theme),
                  const SizedBox(height: 20),

                  // 5. 取消报修操作按钮（若当前节点支持）
                  if (order.canCancel) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FilledButton(
                          onPressed:
                              _cancelling ? null : () => _onCancel(order),
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 12),
                          ),
                          child: _cancelling
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(context.l10n.cancel),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard(RepairOrder order, ThemeData theme) {
    final statusColor = order.isDone
        ? Colors.blueGrey
        : (order.isDraft ? Colors.orange : const Color(0xFF09C489));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                order.title.isEmpty
                    ? context.l10n.repairsUnnamedOrder
                    : order.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                order.status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _row(context.l10n.repairsOrderNumber, order.code),
          if (order.catalog.isNotEmpty)
            _row(context.l10n.repairsOrderType, order.catalog),
          if (order.currentNode.isNotEmpty && order.currentNode != order.status)
            _row(context.l10n.repairsCurrentNode, order.currentNode),
          if (order.priority.isNotEmpty)
            _row(context.l10n.repairsPriority, order.priority),
          if (order.applicant.isNotEmpty)
            _row(context.l10n.repairsApplicant, order.applicant),
          if (order.applicantDepartment.isNotEmpty)
            _row(context.l10n.repairsApplicantDepartment,
                order.applicantDepartment),
          if (order.phone.isNotEmpty)
            _row(context.l10n.repairsPhone, order.phone),
          if (order.department.isNotEmpty)
            _row(context.l10n.repairsDepartment, order.department),
          if (order.handler.isNotEmpty)
            _row(context.l10n.repairsHandler, order.handler),
          _row(context.l10n.repairsCreatedAt, _formatDate(order.createdAt)),
          if (order.closedAt != null)
            _row(context.l10n.repairsCompletedAt, _formatDate(order.closedAt)),
      ],
    );
  }

  Widget _buildContentCard(RepairOrder order, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.repairsDescription,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        SelectableText(
          order.description.isEmpty
              ? context.l10n.repairsNoDescription
              : order.description,
          style: const TextStyle(height: 1.6),
        ),
        if (order.handleResult.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            context.l10n.repairsHandleResult,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 8),
          SelectableText(
            order.handleResult,
            style: const TextStyle(height: 1.6),
          ),
        ],
        if (order.supplement.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            context.l10n.repairsSupplement,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            order.supplement,
            style: const TextStyle(height: 1.5),
          ),
        ],
        if (order.userResponse.isNotEmpty || order.score != null) ...[
          const SizedBox(height: 14),
          Row(
              children: [
                Text(
                  context.l10n.repairsUserFeedback,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
                if (order.score != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.star_rounded, color: Colors.amber[700], size: 18),
                  Text(' ${order.score!.toStringAsFixed(1)}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ],
            ),
            if (order.userResponse.isNotEmpty) ...[
              const SizedBox(height: 4),
              SelectableText(order.userResponse),
            ],
          ],
      ],
    );
  }

  Widget _buildAttachmentsCard(RepairOrder order, ThemeData theme) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.repairsAttachments,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 10),
          ...order.attachments.map((file) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => _previewImage(file),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Row(
                      children: [
                        if (file.thumbnailUrl != null)
                          Container(
                            width: 36,
                            height: 36,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color:
                                    theme.dividerColor.withValues(alpha: 0.3),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: AuthenticatedBxptImage(
                              url: file.thumbnailUrl!,
                              fit: BoxFit.cover,
                              errorWidget: const Icon(
                                Icons.image_outlined,
                                size: 18,
                                color: Color(0xFF09C489),
                              ),
                            ),
                          )
                        else ...[
                          const Icon(Icons.image_outlined,
                              size: 18, color: Color(0xFF09C489)),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            file.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
      ],
    );
  }

  Widget _buildLogDescription(RepairActivityLog log, bool isFirst) {
    final baseStyle = TextStyle(
      fontSize: 13,
      fontWeight: isFirst ? FontWeight.w600 : FontWeight.normal,
    );
    final segments = parseRepairLogDescription(log.description);
    if (segments.isEmpty) {
      return Text(log.description, style: baseStyle);
    }
    // 流转记录只做去标记的纯文本展示，附件查看走上方的附件照片卡片。
    return Text(
      segments.map((s) => s.text).join(),
      style: baseStyle,
    );
  }

  void _previewImage(RepairAttachment attachment) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AuthenticatedBxptImage(
                  url: attachment.downloadUrl,
                  fit: BoxFit.contain,
                  loadingWidget: const Center(
                      child:
                          CircularProgressIndicator(color: Colors.white)),
                  errorWidget: const Center(
                    child: Icon(Icons.broken_image_rounded,
                        size: 48, color: Colors.white70),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard(RepairOrder order, ThemeData theme) {
    final logs = order.logs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Row(
            children: [
              const Icon(Icons.timeline_rounded, size: 20),
              const SizedBox(width: 6),
              Text(
                context.l10n.repairsActivityTimeline,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (logs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                context.l10n.repairsNoActivity,
                style: TextStyle(
                  color: theme.textTheme.bodySmall?.color
                      ?.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
            )
          else
            ...List.generate(logs.length, (index) {
              final log = logs[index];
              final isLast = index == logs.length - 1;
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: index == 0
                                ? const Color(0xFF09C489)
                                : theme.dividerColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: theme.dividerColor.withValues(alpha: 0.5),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLogDescription(log, index == 0),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                if (log.userName.isNotEmpty) ...[
                                  Text(
                                    log.userName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.textTheme.bodySmall?.color,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                if (log.time != null)
                                  Text(
                                    _formatDate(log.time),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.textTheme.bodySmall?.color
                                          ?.withValues(alpha: 0.7),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 82,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ),
            Expanded(
              child: SelectableText(
                value.isEmpty ? '—' : value,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      );
}
