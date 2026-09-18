import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sunshine_models.dart';
import '../services/sunshine_service.dart';

class SunshineDetailScreen extends ConsumerStatefulWidget {
  final String id;
  final SunshineLetter? initialLetter;

  const SunshineDetailScreen({
    super.key,
    required this.id,
    this.initialLetter,
  });

  @override
  ConsumerState<SunshineDetailScreen> createState() =>
      _SunshineDetailScreenState();
}

class _SunshineDetailScreenState extends ConsumerState<SunshineDetailScreen> {
  SunshineTicketDetail? _detail;
  bool _loading = true;
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
      final service = ref.read(sunshineServiceProvider);
      final detail = await service.fetchTicketDetail(widget.id);
      if (!mounted) return;
      setState(() {
        _detail = detail;
      });
    } catch (e) {
      if (mounted) {
        setState(() =>
            _error = e is SunshineException ? e.message : '加载工单详情失败，请重试');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final title = _detail?.title ?? widget.initialLetter?.title ?? '诉求详情';
    final status = _detail?.status ?? widget.initialLetter?.status ?? '';
    final statusLabel = _detail?.statusLabel ??
        widget.initialLetter?.statusLabel ??
        '未知状态';
    final isCompleted = status == '2';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('诉求详情'),
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
      body: _buildBody(isDark, title, statusLabel, isCompleted),
    );
  }

  Widget _buildBody(
    bool isDark,
    String title,
    String statusLabel,
    bool isCompleted,
  ) {
    if (_loading && _detail == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF09C489)),
      );
    }

    if (_error != null && _detail == null) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : const Color(0xFFE0E0E0),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: Colors.orange.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _load,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF09C489),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('重新加载'),
              ),
            ],
          ),
        ),
      );
    }

    final detail = _detail!;
    final hasRemark = detail.remark.trim().isNotEmpty;

    return RefreshIndicator(
      color: const Color(0xFF09C489),
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          if (_loading) const LinearProgressIndicator(),

          // 1. 标题与状态（文字直接呈现，去除卡片）
          _buildHeaderSection(isDark, title, statusLabel, isCompleted, detail),

          const SizedBox(height: 24),

          // 2. 流转信息（无卡片边框、无分割线）
          _buildMetaSection(isDark, detail),

          const SizedBox(height: 24),

          // 3. 诉求内容（无卡片边框）
          _buildContentSection(isDark, detail),

          // 4. 处理结果（如果没有处理结果就不显示）
          if (hasRemark) ...[
            const SizedBox(height: 24),
            _buildRemarkSection(isDark, detail),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderSection(
    bool isDark,
    String title,
    String statusLabel,
    bool isCompleted,
    SunshineTicketDetail detail,
  ) {
    final statusColor =
        isCompleted ? const Color(0xFF09C489) : const Color(0xFFF2994A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
            if (detail.type.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isDark ? Colors.white24 : const Color(0xFFDADCE0),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  detail.type,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ],
            const Spacer(),
            // 去掉《工单》两个字，仅保留 #ID
            if (detail.id.isNotEmpty)
              Text(
                '#${detail.id}',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white38 : Colors.grey,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SelectableText(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            height: 1.35,
            color: isDark ? Colors.white : const Color(0xFF222222),
          ),
        ),
      ],
    );
  }

  Widget _buildMetaSection(bool isDark, SunshineTicketDetail detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '流转信息',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        // 提交人只保留到姓，保持正常黑灰色，不带分割线
        _buildMetaRow(
          isDark,
          icon: Icons.person_outline_rounded,
          label: '提交人',
          value: detail.submitter.isNotEmpty ? detail.submitter : '匿名',
        ),
        if (detail.expectedDepartment.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildMetaRow(
            isDark,
            icon: Icons.account_balance_outlined,
            label: '期望受理部门',
            value: detail.expectedDepartment,
          ),
        ],
        if (detail.handlingDepartment.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildMetaRow(
            isDark,
            icon: Icons.business_rounded,
            label: '受理部门',
            value: detail.handlingDepartment,
          ),
        ],
        if (detail.finishTime.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildMetaRow(
            isDark,
            icon: Icons.event_available_rounded,
            label: '期望解决时间',
            value: detail.finishTime,
          ),
        ],
        if (detail.jieTime.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildMetaRow(
            isDark,
            icon: Icons.access_time_rounded,
            label: '受理时间',
            value: detail.jieTime,
          ),
        ],
        if (detail.wanTime.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildMetaRow(
            isDark,
            icon: Icons.check_circle_outline_rounded,
            label: '办结时间',
            value: detail.wanTime,
          ),
        ],
      ],
    );
  }

  Widget _buildMetaRow(
    bool isDark, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isDark ? Colors.white38 : Colors.grey,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white54 : Colors.grey[700],
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white : const Color(0xFF333333),
          ),
        ),
      ],
    );
  }

  Widget _buildContentSection(bool isDark, SunshineTicketDetail detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.article_outlined,
              size: 18,
              color: Color(0xFF09C489),
            ),
            const SizedBox(width: 8),
            Text(
              '诉求内容',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SelectableText(
          detail.content.isNotEmpty ? detail.content : '（暂无详细问题描述）',
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: isDark ? Colors.white70 : const Color(0xFF333333),
          ),
        ),
      ],
    );
  }

  Widget _buildRemarkSection(bool isDark, SunshineTicketDetail detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.task_alt_rounded,
              size: 18,
              color: Color(0xFF09C489),
            ),
            const SizedBox(width: 8),
            Text(
              '处理结果',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SelectableText(
          detail.remark,
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: isDark ? Colors.white : const Color(0xFF222222),
          ),
        ),
      ],
    );
  }
}
