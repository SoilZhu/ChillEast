import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/features/workspace/models/electricity_model.dart';
import 'package:ChillEast/features/workspace/services/electricity_service.dart';
import 'package:ChillEast/core/mcp/tools/electricity_tool.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Electricity Dormitory Persistence & MCP Defaulting Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. ElectricityService saves, retrieves, and clears saved room', () async {
      final container = ProviderContainer();
      final service = container.read(electricityServiceProvider);

      // Initial state is null
      expect(await service.getSavedRoom(), isNull);

      // Save a room
      const room = SavedElectricityRoom(
        areaName: '东湖校区',
        buildingName: '东湖公寓1栋',
        roomId: '302',
        roomName: '302',
        mertype: 'yk',
      );
      await service.saveSavedRoom(room);

      final retrieved = await service.getSavedRoom();
      expect(retrieved, isNotNull);
      expect(retrieved!.areaName, '东湖校区');
      expect(retrieved.buildingName, '东湖公寓1栋');
      expect(retrieved.roomId, '302');
      expect(retrieved.roomName, '302');
      expect(retrieved.mertype, 'yk');

      // Clear saved room
      await service.clearSavedRoom();
      expect(await service.getSavedRoom(), isNull);
    });

    test('2. ElectricityTool returns error when no parameters and no remembered dormitory', () async {
      final container = ProviderContainer();
      final service = container.read(electricityServiceProvider);
      await service.clearSavedRoom();

      final tool = ElectricityTool.create(service: service);
      final res = await tool.execute({'action': 'query_balance'});

      expect(res.isError, isTrue);
      expect(res.content.first.text, contains('查询电费余额需要提供 areaName、buildingName 和 roomId'));
    });
  });
}
