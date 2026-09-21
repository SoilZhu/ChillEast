import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ChillEast/core/mcp/tools/electricity_tool.dart';
import 'package:ChillEast/features/workspace/models/electricity_model.dart';
import 'package:ChillEast/features/workspace/services/electricity_service.dart';

class FakeElectricityService extends ElectricityService {
  FakeElectricityService(super.ref);

  @override
  Future<List<ElectricityRoom>> getRooms(String areaName, String buildingName) async {
    return [
      ElectricityRoom(id: '81E3C6EE733048798CC518A0FAE33A03', name: '302', mertype: 'yk'),
      ElectricityRoom(id: '99999999999999999999999999999999', name: '303', mertype: 'yk'),
    ];
  }

  @override
  Future<ElectricityBalanceInfo> getBalance({
    required String areaName,
    required String buildingName,
    required String roomId,
    required String mertype,
  }) async {
    if (roomId == '81E3C6EE733048798CC518A0FAE33A03') {
      return ElectricityBalanceInfo(balance: '56.80', detail: '已抄表');
    }
    throw Exception('未找到电表');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'saved_electricity_room': '{"areaName":"金岸公寓空调","buildingName":"金岸1栋","roomId":"81E3C6EE733048798CC518A0FAE33A03","roomName":"81E3C6EE733048798CC518A0FAE33A03","mertype":"yk"}'
    });
  });

  test('ElectricityTool automatically resolves hash roomId to human readable roomName and location', () async {
    final container = ProviderContainer(
      overrides: [
        electricityServiceProvider.overrideWith((ref) => FakeElectricityService(ref)),
      ],
    );
    final service = container.read(electricityServiceProvider);
    final tool = ElectricityTool.create(service: service);

    final result = await tool.execute({}); // default query_balance with saved room
    expect(result.isError, false);
    final text = result.content.first.text!;
    expect(text.contains('81E3C6EE'), false); // Must NOT expose raw hash!
    expect(text.contains('302'), true);
    expect(text.contains('56.80'), true);
    expect(text.contains('金岸公寓空调 - 金岸1栋 - 302'), true);
  });

  test('ElectricityTool resolves user input roomName "302" to hash ID for backend', () async {
    final container = ProviderContainer(
      overrides: [
        electricityServiceProvider.overrideWith((ref) => FakeElectricityService(ref)),
      ],
    );
    final service = container.read(electricityServiceProvider);
    final tool = ElectricityTool.create(service: service);

    final result = await tool.execute({
      'action': 'query_balance',
      'areaName': '金岸公寓空调',
      'buildingName': '金岸1栋',
      'roomId': '302',
    });
    expect(result.isError, false);
    final text = result.content.first.text!;
    expect(text.contains('302'), true);
    expect(text.contains('56.80'), true);
  });
}
