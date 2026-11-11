import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Library Seat A11y Tests', () {
    testWidgets(
        'occupied seat exposes disabled semantic state without selected state',
        (tester) async {
      final handle = tester.ensureSemantics();

      const seatNum = '043';
      const statusText = '已被占用';
      final label = '$seatNum号座位，$statusText';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Semantics(
              button: false,
              enabled: false,
              label: label,
              excludeSemantics: true,
              child: Container(
                width: 34,
                height: 34,
                color: Colors.grey,
                child: const Text(seatNum),
              ),
            ),
          ),
        ),
      );

      final node = tester.getSemantics(find.byType(Container).first);
      expect(node.label, '043号座位，已被占用');
      expect(node.hasFlag(SemanticsFlag.hasEnabledState), isTrue);
      expect(node.hasFlag(SemanticsFlag.isEnabled), isFalse);
      expect(node.hasFlag(SemanticsFlag.hasSelectedState), isFalse);
      expect(node.hasFlag(SemanticsFlag.isButton), isFalse);

      handle.dispose();
    });

    testWidgets(
        'available and selected seat exposes button and selected states',
        (tester) async {
      final handle = tester.ensureSemantics();

      bool isSelected = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                final statusText = isSelected ? '已选中，双击取消选择' : '空闲可用，双击选择';
                final label = '042号座位，$statusText';

                return Semantics(
                  button: true,
                  enabled: true,
                  selected: isSelected,
                  label: label,
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        isSelected = !isSelected;
                      });
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      color: isSelected ? Colors.green : Colors.lightGreen,
                      child: const Text('042'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      // 验证未选中时的空闲可用语义
      final unselectedNode = tester.getSemantics(find.byType(GestureDetector));
      expect(unselectedNode.label, '042号座位，空闲可用，双击选择');
      expect(unselectedNode.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(unselectedNode.hasFlag(SemanticsFlag.isEnabled), isTrue);
      expect(unselectedNode.hasFlag(SemanticsFlag.isSelected), isFalse);

      // 点按选择
      await tester.tap(find.byType(GestureDetector));
      await tester.pumpAndSettle();

      expect(isSelected, isTrue);

      // 验证选中后的语义
      final selectedNode = tester.getSemantics(find.byType(GestureDetector));
      expect(selectedNode.label, '042号座位，已选中，双击取消选择');
      expect(selectedNode.hasFlag(SemanticsFlag.isSelected), isTrue);

      handle.dispose();
    });
  });
}
