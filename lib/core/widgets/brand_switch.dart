import 'package:flutter/material.dart';

/// 与 App 主题色（#09C489）一致的 MD2 样式开关。
class BrandSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const BrandSwitch({super.key, required this.value, required this.onChanged});

  static const Color _brand = Color(0xFF09C489);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        useMaterial3: false,
        colorScheme: Theme.of(context).colorScheme,
      ),
      child: Switch(
        value: value,
        onChanged: onChanged,
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _brand;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _brand.withValues(alpha: 0.5);
          }
          return null;
        }),
      ),
    );
  }
}
