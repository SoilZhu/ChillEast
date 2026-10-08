import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/l10n_extension.dart';
import '../models/dormitory_info.dart';
import '../services/dormitory_service.dart';

/// 我的宿舍页面（MD2 风格）
class DormitoryScreen extends ConsumerStatefulWidget {
  const DormitoryScreen({super.key});

  @override
  ConsumerState<DormitoryScreen> createState() => _DormitoryScreenState();
}

class _DormitoryScreenState extends ConsumerState<DormitoryScreen> {
  DormitoryInfo? _info;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    final service = ref.read(dormitoryServiceProvider);

    // 先读缓存秒开首帧
    if (!forceRefresh) {
      final cached = await service.getCachedDormitoryInfo();
      if (cached != null && mounted) {
        setState(() {
          _info = cached;
          _loading = false;
        });
      }
    }

    if (_info == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final fresh = await service.fetchDormitoryInfo(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _info = fresh;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final errText = e
              .toString()
              .replaceFirst('AppException: ', '')
              .replaceFirst('Exception: ', '');
          if (_info == null) {
            _error = errText;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errText),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          context.l10n.funcDormitory,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF202124),
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: theme.scaffoldBackgroundColor,
        foregroundColor: isDark ? Colors.white : const Color(0xFF202124),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: context.l10n.refresh,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _loadData(forceRefresh: true),
          ),
        ],
      ),
      body: _buildBody(context, isDark),
    );
  }

  Widget _buildBody(BuildContext context, bool isDark) {
    if (_loading && _info == null) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF09C489),
        ),
      );
    }

    if (_error != null && _info == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
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
                onPressed: () => _loadData(forceRefresh: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF09C489),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(context.l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    final info = _info ?? const DormitoryInfo(isAssigned: false);

    return RefreshIndicator(
      color: const Color(0xFF09C489),
      onRefresh: () => _loadData(forceRefresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _buildDormCard(context, info, isDark),
        ],
      ),
    );
  }

  Widget _buildDormCard(BuildContext context, DormitoryInfo info, bool isDark) {
    final building = info.building ??
        (!info.isAssigned ? context.l10n.dormitoryNotAssigned : '--');
    final floor = info.floor ?? '--';
    final room = info.room ?? '--';
    final bed = info.bed ?? '--';

    return Container(
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
        children: [
          _buildItemRow(
            label: context.l10n.dormitoryBuilding,
            value: building,
            isDark: isDark,
          ),
          _buildItemRow(
            label: context.l10n.dormitoryFloor,
            value: floor,
            isDark: isDark,
          ),
          _buildItemRow(
            label: context.l10n.dormitoryRoom,
            value: room,
            isDark: isDark,
          ),
          _buildItemRow(
            label: context.l10n.dormitoryBed,
            value: bed,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow({
    required String label,
    required String value,
    required bool isDark,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onLongPress: value != '--'
          ? () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$label 已复制: $value'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white70 : const Color(0xFF5F6368),
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : const Color(0xFF202124),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
