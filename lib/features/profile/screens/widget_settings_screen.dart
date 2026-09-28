import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/home_widget_service.dart';
import '../../../core/utils/l10n_extension.dart';
import '../models/appearance_state.dart';
import '../providers/appearance_provider.dart';

/// 桌面小组件配置页：快捷功能的 4 个入口独立于首页单独配置。
class WidgetSettingsScreen extends ConsumerStatefulWidget {
  const WidgetSettingsScreen({super.key});

  @override
  ConsumerState<WidgetSettingsScreen> createState() =>
      _WidgetSettingsScreenState();
}

class _WidgetSettingsScreenState extends ConsumerState<WidgetSettingsScreen> {
  final HomeWidgetService _service = HomeWidgetService();
  List<String> _selected = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ids = await _service.getWidgetQuickIds();
    if (mounted) {
      setState(() {
        _selected = ids;
        _loading = false;
      });
    }
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else if (_selected.length < 4) {
        _selected.add(id);
      }
    });
  }

  Future<void> _save() async {
    if (_selected.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.widgetNeedFour)),
      );
      return;
    }
    setState(() => _saving = true);
    await _service.saveWidgetQuickIds(_selected);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.widgetSaved)),
    );
  }

  Future<void> _refresh() async {
    setState(() => _saving = true);
    await _service.syncWidgets();
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.widgetRefreshed)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final pool = AppearanceNotifier.masterPool;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.widgetSettings),
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
        actions: [
          TextButton(
            onPressed: _saving || _selected.length != 4 ? null : _save,
            child: Text(l10n.save),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.grey.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.widgets_outlined,
                          size: 20, color: Color(0xFF09C489)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.widgetHowToAdd,
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                isDark ? Colors.white70 : Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.widgetQuickTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${_selected.length}/4',
                      style: TextStyle(
                        fontSize: 13,
                        color: _selected.length == 4
                            ? const Color(0xFF09C489)
                            : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.widgetQuickHint,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                for (final item in pool)
                  _buildRow(context, item, isDark),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _refresh,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(l10n.widgetRefresh),
                ),
              ],
            ),
    );
  }

  Widget _buildRow(BuildContext context, FunctionItem item, bool isDark) {
    final selected = _selected.contains(item.id);
    final order = _selected.indexOf(item.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF09C489).withValues(alpha: isDark ? 0.15 : 0.08)
              : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? const Color(0xFF09C489)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : const Color(0xFFE0E0E0)),
            width: 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => _toggle(item.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.icon, color: item.color, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.getLocalizedTitle(context),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.w400,
                      color: isDark ? Colors.white : const Color(0xFF202124),
                    ),
                  ),
                ),
                if (selected)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFF09C489),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${order + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.add_circle_outline_rounded,
                    size: 22,
                    color: isDark ? Colors.white24 : Colors.grey[400],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
