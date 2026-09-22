import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/route_utils.dart';
import '../models/questionnaire_models.dart';
import '../services/questionnaire_service.dart';
import 'questionnaire_detail_screen.dart';

enum QuestionnaireFilter {
  all,
  pending,
  submitted;

  String getLocalizedLabel(BuildContext context) => switch (this) {
        QuestionnaireFilter.all => context.l10n.all,
        QuestionnaireFilter.pending => context.l10n.statusPendingFill,
        QuestionnaireFilter.submitted => context.l10n.statusSubmitted,
      };

  bool matches(QuestionnaireItem item) => switch (this) {
        QuestionnaireFilter.all => true,
        QuestionnaireFilter.pending => !item.isSubmitted && !item.isExpired,
        QuestionnaireFilter.submitted => item.isSubmitted,
      };
}

/// 学工问卷 - 功能页
class QuestionnaireListScreen extends ConsumerStatefulWidget {
  const QuestionnaireListScreen({super.key});

  @override
  ConsumerState<QuestionnaireListScreen> createState() =>
      _QuestionnaireListScreenState();
}

class _QuestionnaireListScreenState
    extends ConsumerState<QuestionnaireListScreen> {
  List<QuestionnaireItem> _items = [];
  bool _loading = true;
  String? _error;
  QuestionnaireFilter _filter = QuestionnaireFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _getErrorMessage(dynamic e) {
    if (e is QuestionnaireException) {
      if (e.message.contains('统一认证已过期')) return context.l10n.ssoExpiredRelogin;
      if (e.message.contains('登录已失效')) return context.l10n.studentSystemSessionExpired;
      if (e.message.contains('未能读取')) return context.l10n.readQuestionnaireDataFailed;
      if (e.message.contains('格式异常')) return context.l10n.questionnaireListFormatError;
      if (e.message.contains('缺少任务标识')) return context.l10n.questionnaireMissingTaskId;
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
      final service = ref.read(questionnaireServiceProvider);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filtered = _items.where((item) => _filter.matches(item)).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.l10n.studentWorkQuestionnaire),
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
                  Wrap(
                    spacing: 8,
                    children: QuestionnaireFilter.values
                        .map((filter) => _buildFilterChip(filter, isDark))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty && _error == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: Text(
                          context.l10n.noQuestionnairesFound,
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

  Widget _buildFilterChip(QuestionnaireFilter filter, bool isDark) {
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

  Widget _buildItemCard(QuestionnaireItem item, bool isDark) {
    final statusColor = item.isSubmitted
        ? const Color(0xFF09C489)
        : (item.isExpired ? Colors.grey : const Color(0xFFE63476));
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
              createSlideUpRoute(QuestionnaireDetailScreen(item: item)),
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
                        item.title.isEmpty ? context.l10n.unnamedQuestionnaire : item.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF222222),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                const SizedBox(height: 8),
                Text(
                  item.getLocalizedStatus(context),
                  style: TextStyle(
                    fontSize: 12,
                    color: statusColor,
                    fontWeight: item.isSubmitted
                        ? FontWeight.bold
                        : FontWeight.normal,
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
