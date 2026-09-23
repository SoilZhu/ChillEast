import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/route_utils.dart';
import '../models/repair_models.dart';
import '../services/repair_service.dart';
import 'repair_detail_screen.dart';
import 'repair_form_screen.dart';

class RepairScreen extends ConsumerStatefulWidget {
  const RepairScreen({super.key});
  @override
  ConsumerState<RepairScreen> createState() => _RepairScreenState();
}

class _RepairScreenState extends ConsumerState<RepairScreen> {
  int _selectedTab = 0; // 0: 处理中, 1: 已完成, 2: 草稿箱
  List<RepairOrder> _ongoing = [], _finished = [], _drafts = [];
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
      final service = ref.read(repairServiceProvider);
      final result = await Future.wait([
        service.fetchOrders(ongoing: true),
        service.fetchOrders(ongoing: false),
        service.fetchOrders(ongoing: false, isDraft: true),
      ]);
      if (!mounted) return;
      setState(() {
        _ongoing = result[0];
        _finished = result[1];
        _drafts = result[2];
      });
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? theme.scaffoldBackgroundColor : Colors.white;

    final currentOrders = _selectedTab == 0
        ? _ongoing
        : (_selectedTab == 1 ? _finished : _drafts);

    final isDraftTab = _selectedTab == 2;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(context.l10n.repairsTitle),
        backgroundColor: bgColor,
        surfaceTintColor: bgColor,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: context.l10n.refresh,
            icon: const Icon(Icons.refresh_rounded),
          )
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF09C489),
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
          children: [
            // 1. 四大报修分类 2x2 卡片（无箭头，与图书馆风格一致）
            _buildCatalogGrid(isDark),
            const SizedBox(height: 24),

            // 2. 我的工单（纯标题）
            Text(
              context.l10n.repairsMyOrders,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 10),

            // 3. 处理中 / 已完成 / 草稿箱 筛选标签（与阳光服务风格一致）
            Wrap(
              spacing: 8,
              children: [
                _buildTabChip(0, context.l10n.repairsInProgress, isDark),
                _buildTabChip(1, context.l10n.repairsCompleted, isDark),
                _buildTabChip(2, context.l10n.repairsDrafts, isDark),
              ],
            ),
            const SizedBox(height: 12),

            if (_loading)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(
                    minHeight: 2, color: Color(0xFF09C489)),
              ),

            if (_error != null) _buildError(theme),

            // 4. 工单列表
            if (_loading && currentOrders.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF09C489)),
                ),
              )
            else if (currentOrders.isEmpty)
              _buildEmptyState(isDark)
            else
              ...currentOrders
                  .map((order) => _buildOrderItem(order, isDark, isDraftTab)),
          ],
        ),
      ),
    );
  }

  Widget _buildCatalogGrid(bool isDark) {
    const catalogs = RepairService.catalogs;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildCatalogCard(catalogs[0], isDark)),
            const SizedBox(width: 10),
            Expanded(child: _buildCatalogCard(catalogs[1], isDark)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildCatalogCard(catalogs[2], isDark)),
            const SizedBox(width: 10),
            Expanded(child: _buildCatalogCard(catalogs[3], isDark)),
          ],
        ),
      ],
    );
  }

  Widget _buildCatalogCard(RepairCatalog catalog, bool isDark) {
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
            await Navigator.push(
              context,
              createSlideUpRoute(RepairFormScreen(catalog: catalog)),
            );
            if (mounted) _load();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(
                  catalog.icon,
                  color: const Color(0xFF09C489),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    catalog.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabChip(int index, String label, bool isDark) {
    final isSelected = _selectedTab == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedTab = index),
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

  Widget _buildEmptyState(bool isDark) {
    final emptyText = _selectedTab == 0
        ? context.l10n.repairsNoOngoing
        : (_selectedTab == 1
            ? context.l10n.repairsNoCompleted
            : context.l10n.repairsNoDrafts);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          emptyText,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white38 : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderItem(RepairOrder order, bool isDark, bool isDraftTab) {
    final catalog = RepairService.resolveCatalog(order);

    String dateStr = '';
    if (order.createdAt != null) {
      final y = order.createdAt!.year;
      final m = order.createdAt!.month.toString().padLeft(2, '0');
      final d = order.createdAt!.day.toString().padLeft(2, '0');
      dateStr = '$y/$m/$d';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
          onTap: () {
            if (isDraftTab) {
              Navigator.push(
                context,
                createSlideUpRoute(
                    RepairFormScreen(catalog: catalog, draftOrder: order)),
              ).then((_) => _load());
            } else {
              Navigator.push(
                context,
                createSlideUpRoute(RepairDetailScreen(order: order)),
              ).then((_) => _load());
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: catalog.color.withValues(alpha: .12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(catalog.icon, color: catalog.color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.title.isEmpty
                            ? context.l10n.repairsUnnamedOrder
                            : order.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (dateStr.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
          ),
        ),
      ),
    );
  }

  Widget _buildError(ThemeData theme) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)));
}
