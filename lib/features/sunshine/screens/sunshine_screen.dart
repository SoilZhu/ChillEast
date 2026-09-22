import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/route_utils.dart';
import '../models/sunshine_models.dart';
import '../services/sunshine_service.dart';
import 'sunshine_detail_screen.dart';
import 'sunshine_form_screen.dart';

enum SunshineFilter {
  all,
  inProgress,
  resolved;

  String getLocalizedLabel(BuildContext context) => switch (this) {
        SunshineFilter.all => context.l10n.all,
        SunshineFilter.inProgress => context.l10n.statusInProgress,
        SunshineFilter.resolved => context.l10n.statusResolved,
      };

  bool matches(SunshineLetter letter) => switch (this) {
        SunshineFilter.all => true,
        SunshineFilter.inProgress => letter.status == '0' || letter.status == '1',
        SunshineFilter.resolved => letter.status == '2',
      };
}

class SunshineScreen extends ConsumerStatefulWidget {
  const SunshineScreen({super.key});
  @override
  ConsumerState<SunshineScreen> createState() => _SunshineScreenState();
}

class _SunshineScreenState extends ConsumerState<SunshineScreen> {
  List<SunshineLetter> _letters = [];
  bool _loading = true;
  String? _error;
  SunshineFilter _filter = SunshineFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _getErrorMessage(dynamic e) {
    if (e is SunshineException) {
      if (e.message.contains('暂时不可用')) return context.l10n.sunshineServiceUnavailable;
      if (e.message.contains('未能读取')) return context.l10n.sunshineDataReadFailed;
      if (e.message.contains('格式异常')) return context.l10n.sunshineDataFormatError;
      if (e.message.contains('未找到诉求工单详情')) return context.l10n.sunshineTicketNotFound;
      if (e.message.contains('响应超时')) return context.l10n.sunshineFormTimeout;
      if (e.message.contains('统一认证已过期')) return context.l10n.ssoExpiredRelogin;
      if (e.message.contains('登录已失效')) return context.l10n.sunshineSessionExpired;
      if (e.message.contains('暂无可用受理单位')) return context.l10n.noDepartmentsAvailable;
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
      final service = ref.read(sunshineServiceProvider);
      final letters = await service.fetchLetters();
      if (!mounted) return;
      setState(() {
        _letters = letters;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = _getErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final letters = _letters
        .where((letter) => _filter.matches(letter))
        .toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.l10n.sunshineService),
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
      body: _loading && _letters.isEmpty
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
                          width: 1,
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

                  // 1. 填写诉求入口（与图书馆预约选座风格一致的卡片）
                  _buildQuickActionCard(isDark),

                  const SizedBox(height: 20),

                  // 2. 近期公开诉求模块
                  Text(
                    context.l10n.recentPublicAppeals,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: SunshineFilter.values
                        .map((filter) => _buildFilterChip(filter, isDark))
                        .toList(),
                  ),
                  const SizedBox(height: 12),

                  if (letters.isEmpty && _error == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: Text(
                          context.l10n.noPublicAppeals,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white38 : Colors.grey,
                          ),
                        ),
                      ),
                    ),

                  // 3. 诉求列表卡片（无阴影，细灰色描边）
                  ...letters.map((letter) => _buildLetterCard(letter, isDark)),
                ],
              ),
            ),
    );
  }

  Widget _buildQuickActionCard(bool isDark) {
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
          onTap: () async {
            final submitted = await Navigator.of(context).push<bool>(
              createSlideUpRoute(const SunshineFormScreen()),
            );
            if (submitted == true && mounted) _load();
          },
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
                  context.l10n.writeAppeal,
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

  Widget _buildFilterChip(SunshineFilter filter, bool isDark) {
    final isSelected = _filter == filter;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _filter = filter),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF09C489)
                  : (isDark ? Colors.white24 : const Color(0xFFDADCE0)),
              width: 1,
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

  Widget _buildLetterCard(SunshineLetter letter, bool isDark) {
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
          onTap: () {
            Navigator.of(context).push(
              createSlideUpRoute(
                SunshineDetailScreen(
                  id: letter.id,
                  initialLetter: letter,
                ),
              ),
            );
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
                        letter.title,
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
                const SizedBox(height: 8),
                Text(
                  letter.department,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      letter.type,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.grey[600],
                      ),
                    ),
                    Text(
                      letter.date,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.grey[600],
                      ),
                    ),
                    Text(
                      letter.getLocalizedStatus(context),
                      style: TextStyle(
                        fontSize: 12,
                        color: letter.status == '2'
                            ? const Color(0xFF09C489)
                            : (isDark ? Colors.white38 : Colors.grey[600]),
                        fontWeight: letter.status == '2'
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
