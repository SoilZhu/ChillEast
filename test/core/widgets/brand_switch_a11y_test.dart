import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/core/widgets/brand_switch.dart';

void main() {
  group('BrandSwitch A11y Tests', () {
    testWidgets('exposes semantic label and toggled state correctly',
        (tester) async {
      final handle = tester.ensureSemantics();

      bool switchValue = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return BrandSwitch(
                  value: switchValue,
                  semanticLabel: '自动静音模式',
                  onChanged: (val) {
                    setState(() {
                      switchValue = val;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      // 验证未开启状态下的语义
      expect(
        tester.getSemantics(find.byType(BrandSwitch)),
        matchesSemantics(
          label: '自动静音模式',
          hasToggledState: true,
          isToggled: false,
          hasTapAction: true,
        ),
      );

      // 点击切换
      await tester.tap(find.byType(BrandSwitch));
      await tester.pumpAndSettle();

      expect(switchValue, isTrue);

      // 验证开启状态下的语义
      expect(
        tester.getSemantics(find.byType(BrandSwitch)),
        matchesSemantics(
          label: '自动静音模式',
          hasToggledState: true,
          isToggled: true,
          hasTapAction: true,
        ),
      );

      handle.dispose();
    });
  });
}
