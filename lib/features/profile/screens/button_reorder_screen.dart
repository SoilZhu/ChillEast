import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/appearance_provider.dart';

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
    
    // 获取当前列表并按可见性排序
    final rawItems = listType == 'home' ? appearance.homeItems : appearance.functionItems;
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
          _buildInfoBanner(isDark),
          Expanded(
            child: ReorderableListView(
              padding: const EdgeInsets.only(top: 0, bottom: 60), // 增加底部边距，方便拖拽到最后
              header: _buildSectionHeader(context, '显示中的功能', Icons.visibility_outlined, isFixed: true),
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
                  '已隐藏的功能 (拖动到此隐藏)', 
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

  Widget _buildInfoBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      width: double.infinity,
      color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey.withOpacity(0.05),
      child: Row(
        children: [
          Icon(Icons.touch_app_outlined, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '长按拖动图标，移入不同区域可显示或隐藏功能',
              style: TextStyle(fontSize: 13, color: Colors.grey),
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

  Widget _buildReorderItem(BuildContext context, WidgetRef ref, dynamic item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      key: ValueKey(item.id),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: Colors.transparent,
      child: Row(
        children: [
          const Icon(Icons.drag_indicator_rounded, color: Color(0xFFBDBDBD), size: 24),
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
              item.label,
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
