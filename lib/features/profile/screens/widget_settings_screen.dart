import 'package:flutter/material.dart';
import '../../../core/utils/l10n_extension.dart';
import 'button_reorder_screen.dart';

/// 桌面小组件配置页：复用 ButtonReorderScreen 的拖拽排序与显隐配置。
class WidgetSettingsScreen extends StatelessWidget {
  const WidgetSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ButtonReorderScreen(
      title: context.l10n.widgetSettings,
      listType: 'widget',
    );
  }
}
