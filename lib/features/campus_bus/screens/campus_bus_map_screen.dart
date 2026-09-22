import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/utils/l10n_extension.dart';

class CampusBusMapScreen extends StatelessWidget {
  const CampusBusMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // 深色模式下采用更深沉内敛的深炭灰（比中灰更黑，但非纯黑）
      backgroundColor: isDark ? const Color(0xFF202225) : Colors.white,
      appBar: AppBar(
        title: Text(
          context.l10n.funcCampusBusRoute,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return InteractiveViewer(
            minScale: 0.8,
            maxScale: 6.0,
            // 严格限制最大平移范围，防止地图被拖出屏幕视野
            boundaryMargin: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 32,
            ),
            child: Center(
              child: SvgPicture.asset(
                'assets/images/campus_bus_map.svg',
                width: constraints.maxWidth,
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }
}
