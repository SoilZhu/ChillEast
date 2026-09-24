import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/appearance_provider.dart';
import '../models/appearance_state.dart';
import '../../../core/utils/l10n_extension.dart';

class ButtonReorderScreen extends ConsumerWidget {
  final String title;
  final String listType;

  const ButtonReorderScreen({
    super.key,
    required this.title,
    required this.listType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appearance = ref.watch(appearanceProvider);

    // 功能排序按支付/学习/生活/出行/工具/小程序分组展示
    if (listType == 'functions') {
      return _buildGroupedFunctions(context, ref, appearance, isDark);
    }

    // 获取当前列表并按可见性排序
    final rawItems = listType == 'home'
        ? appearance.homeItems
        : (listType == 'feed' ? appearance.feedItems : appearance.functionItems);
    final visibleItems = rawItems.where((e) => e.isVisible).toList();
    final hiddenItems = rawItems.where((e) => !e.isVisible).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF202124),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      body: Column(
        children: [
          _buildInfoBanner(context, isDark),
          Expanded(
            child: ReorderableListView(
              padding: const EdgeInsets.only(top: 0, bottom: 60), // 增加底部边距，方便拖拽到最后
              header: _buildSectionHeader(context, context.l10n.visibleFunctions, Icons.visibility_outlined, isFixed: true),
              proxyDecorator: (Widget child, int index, Animation<double> animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (BuildContext context, Widget? child) {
                    final double animValue = Curves.easeInOut.transform(animation.value);
                    final double elevation = lerpDouble(0, 6, animValue)!;
                    return Material(
                      elevation: elevation,
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(animValue * 8),
                      child: child,
                    );
                  },
                  child: child,
                );
              },
              onReorder: (oldIndex, newIndex) {
                // 将 UI 层的索引直接传递给 Notifier，由 Notifier 处理 HeaderHidden 的偏移逻辑
                ref.read(appearanceProvider.notifier).reorderItems(listType, oldIndex, newIndex);
              },
              children: [
                // 1. 显示中的项
                ...visibleItems.map((item) => _buildReorderItem(context, ref, item)),
                
                // 2. 已隐藏的功能区域标题 (分界线)
                _buildSectionHeader(
                  context, 
                  context.l10n.hiddenFunctions, 
                  Icons.visibility_off_outlined, 
                  key: const ValueKey('header_hidden'),
                ),
                
                // 3. 隐藏中的项
                ...hiddenItems.map((item) => _buildReorderItem(context, ref, item)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 功能排序：6 个大模块，拖过隐藏线切换显隐（与首页排序同手势）
  Widget _buildGroupedFunctions(BuildContext context, WidgetRef ref,
      AppearanceState appearance, bool isDark) {
    final hiddenSet = appearance.hiddenFunctionGroups.toSet();
    final visibleKeys = appearance.functionGroupOrder
        .where((k) => !hiddenSet.contains(k))
        .toList();
    final hiddenKeys = appearance.functionGroupOrder
        .where((k) => hiddenSet.contains(k))
        .toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF202124),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      body: Column(
        children: [
          _buildInfoBanner(context, isDark),
          Expanded(
            child: ReorderableListView(
              padding: const EdgeInsets.only(bottom: 60),
              proxyDecorator:
                  (Widget child, int index, Animation<double> animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (BuildContext context, Widget? child) {
                    final double animValue =
                        Curves.easeInOut.transform(animation.value);
                    final double elevation = lerpDouble(0, 6, animValue)!;
                    return Material(
                      elevation: elevation,
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(animValue * 8),
                      child: child,
                    );
                  },
                  child: child,
                );
              },
              onReorder: (oldIndex, newIndex) {
                ref
                    .read(appearanceProvider.notifier)
                    .reorderFunctionGroups(oldIndex, newIndex);
              },
              children: [
                ...visibleKeys.map((key) => _buildGroupTile(
                      context,
                      key,
                      isDark: isDark,
                    )),
                _buildSectionHeader(
                  context,
                  context.l10n.hiddenFunctions,
                  Icons.visibility_off_outlined,
                  key: const ValueKey('header_hidden'),
                ),
                ...hiddenKeys.map((key) => _buildGroupTile(
                      context,
                      key,
                      isDark: isDark,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ({IconData icon, Color color}) _groupVisual(String titleKey) {
    return switch (titleKey) {
      'groupPayment' =>
        (icon: Icons.payments_outlined, color: Colors.orange),
      'groupStudy' =>
        (icon: Icons.school_outlined, color: const Color(0xFF795548)),
      'groupLife' =>
        (icon: Icons.favorite_outline, color: const Color(0xFFE63476)),
      'groupTravel' =>
        (icon: Icons.directions_bus_outlined, color: const Color(0xFF2196F3)),
      'groupTools' =>
        (icon: Icons.build_outlined, color: const Color(0xFF607D8B)),
      _ => (icon: Icons.apps_outlined, color: const Color(0xFF09C489)),
    };
  }

  Widget _buildGroupTile(
    BuildContext context,
    String titleKey, {
    required bool isDark,
  }) {
    final visual = _groupVisual(titleKey);
    return Container(
      key: ValueKey(titleKey),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: Colors.transparent,
      child: Row(
        children: [
          const Icon(Icons.drag_indicator_rounded,
              color: Color(0xFFBDBDBD), size: 24),
          const SizedBox(width: 20),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: visual.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(visual.icon, color: visual.color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              functionGroupTitle(context, titleKey),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: isDark ? Colors.white : const Color(0xFF202124),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      width: double.infinity,
      color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.withOpacity(0.05),
      child: Row(
        children: [
          Icon(Icons.touch_app_outlined, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.dragToReorderTip,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon, {Key? key, bool isFixed = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: key,
      padding: EdgeInsets.fromLTRB(24, isFixed ? 16 : 24, 24, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: isDark ? Colors.white54 : Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white54 : Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReorderItem(
    BuildContext context,
    WidgetRef ref,
    FunctionItem item,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      key: ValueKey(item.id),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: Colors.transparent,
      child: Row(
        children: [
          const Icon(Icons.drag_indicator_rounded,
              color: Color(0xFFBDBDBD), size: 24),
          const SizedBox(width: 20),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: item.color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              item.getLocalizedTitle(context),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: isDark ? Colors.white : const Color(0xFF202124),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
