import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/library_models.dart';
import '../services/library_service.dart';

final libraryServiceProvider = Provider<LibraryService>((ref) {
  return LibraryService();
});

/// 首页聚合数据 Provider
final libraryIndexProvider = AsyncNotifierProvider<LibraryIndexNotifier, LibraryIndexData>(() {
  return LibraryIndexNotifier();
});

class LibraryIndexNotifier extends AsyncNotifier<LibraryIndexData> {
  LibraryService get _service => ref.read(libraryServiceProvider);

  @override
  Future<LibraryIndexData> build() async {
    return _service.fetchIndexData();
  }

  /// 刷新首页数据
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _service.fetchIndexData());
  }

  /// 取消预约
  Future<bool> cancelReservation(int reserveId) async {
    final success = await _service.cancelReservation(reserveId);
    if (success) {
      await refresh();
    }
    return success;
  }

  /// 签到
  Future<bool> signInSeat({
    required String seatNum,
    required int roomId,
    required int reserveId,
    String? qrUrl,
  }) async {
    final success = await _service.signInSeat(
      seatNum: seatNum,
      roomId: roomId,
      reserveId: reserveId,
      qrUrl: qrUrl,
    );
    if (success) {
      await refresh();
    }
    return success;
  }
}

/// 阅览室列表 Provider (按日期族群化)
final libraryRoomsProvider = FutureProvider.family<List<LibraryRoomModel>, String>((ref, day) async {
  final service = ref.read(libraryServiceProvider);
  return service.fetchRoomList(day: day);
});
