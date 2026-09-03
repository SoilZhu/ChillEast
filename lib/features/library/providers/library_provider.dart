import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/library_models.dart';
import '../services/library_service.dart';
import '../services/library_storage.dart';
import '../../profile/providers/settings_provider.dart';

final libraryServiceProvider = Provider<LibraryService>((ref) {
  return LibraryService();
});

/// 本地缓存的图书馆有效预约列表 Provider
final cachedLibraryReserveProvider = AsyncNotifierProvider<
    CachedLibraryReserveNotifier, List<LibraryReserveModel>>(() {
  return CachedLibraryReserveNotifier();
});

class CachedLibraryReserveNotifier
    extends AsyncNotifier<List<LibraryReserveModel>> {
  LibraryService get _service => ref.read(libraryServiceProvider);

  @override
  Future<List<LibraryReserveModel>> build() async {
    // 1. 先从本地缓存读取，确保 App 打开时无缝展示
    final cached = await LibraryStorage.getCachedReserves();
    // 2. 异步同步云端最新状态
    _syncWithCloud();
    return cached;
  }

  /// 与云端同步预约状态
  Future<void> _syncWithCloud() async {
    try {
      final indexData = await _service.fetchIndexData();
      final activeList = indexData.curReserves;
      state = AsyncValue.data(activeList);
      if (activeList.isNotEmpty) {
        await LibraryStorage.saveReserves(activeList);
      } else {
        await LibraryStorage.clearReserves();
      }
      ref.read(settingsProvider.notifier).rescheduleNotifications();
    } catch (_) {
      // 发生网络错误时，保留本地已有的缓存数据，不做清除
    }
  }

  /// 手动刷新
  Future<void> refresh() async {
    await _syncWithCloud();
  }

  /// 设置/新增预约（如刚预约成功时）
  Future<void> addOrUpdateReserve(LibraryReserveModel reserve) async {
    final currentList = state.value ?? [];
    final updatedList = [
      reserve,
      ...currentList.where((r) => r.id != reserve.id),
    ];
    state = AsyncValue.data(updatedList);
    await LibraryStorage.saveReserves(updatedList);
    ref.read(settingsProvider.notifier).rescheduleNotifications();
  }

  /// 取消预约（及时移除该项，下一个预约自动顶上来）
  Future<bool> cancelReservation(int reserveId) async {
    final success = await _service.cancelReservation(reserveId);
    if (success) {
      final currentList = state.value ?? [];
      final updatedList = currentList.where((r) => r.id != reserveId).toList();
      state = AsyncValue.data(updatedList);
      if (updatedList.isNotEmpty) {
        await LibraryStorage.saveReserves(updatedList);
      } else {
        await LibraryStorage.clearReserves();
      }
      // 同时通知 indexProvider 刷新并重新安排通知
      ref.read(libraryIndexProvider.notifier).refresh();
      ref.read(settingsProvider.notifier).rescheduleNotifications();
    }
    return success;
  }

  /// 本地删除（无需网络，用于幽灵清理或过期清理）
  Future<void> removeLocalReserve(int reserveId) async {
    final currentList = state.value ?? [];
    final updatedList = currentList.where((r) => r.id != reserveId).toList();
    state = AsyncValue.data(updatedList);
    if (updatedList.isNotEmpty) {
      await LibraryStorage.saveReserves(updatedList);
    } else {
      await LibraryStorage.clearReserves();
    }
    ref.read(settingsProvider.notifier).rescheduleNotifications();
  }

  /// 签到
  Future<bool> signInSeat(LibraryReserveModel reserve) async {
    final success = await _service.signInSeat(reserve);
    if (success) {
      await _syncWithCloud();
      ref.read(libraryIndexProvider.notifier).refresh();
    }
    return success;
  }

  /// 退座并同步首页缓存。
  Future<bool> signBackSeat(LibraryReserveModel reserve) async {
    final success = await _service.signBackSeat(reserve);
    if (success) {
      await _syncWithCloud();
      ref.read(libraryIndexProvider.notifier).refresh();
    }
    return success;
  }
}

/// 首页聚合数据 Provider
final libraryIndexProvider =
    AsyncNotifierProvider<LibraryIndexNotifier, LibraryIndexData>(() {
  return LibraryIndexNotifier();
});

class LibraryIndexNotifier extends AsyncNotifier<LibraryIndexData> {
  LibraryService get _service => ref.read(libraryServiceProvider);

  @override
  Future<LibraryIndexData> build() async {
    final data = await _service.fetchIndexData();
    if (data.curReserves.isNotEmpty) {
      await LibraryStorage.saveReserves(data.curReserves);
    } else {
      await LibraryStorage.clearReserves();
    }
    return data;
  }

  /// 刷新首页数据
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final data = await _service.fetchIndexData();
      if (data.curReserves.isNotEmpty) {
        await LibraryStorage.saveReserves(data.curReserves);
      } else {
        await LibraryStorage.clearReserves();
      }
      return data;
    });
  }

  /// 取消预约
  Future<bool> cancelReservation(int reserveId) async {
    final success = await _service.cancelReservation(reserveId);
    if (success) {
      await refresh();
      // 同步刷新本地缓存
      ref.read(cachedLibraryReserveProvider.notifier).refresh();
    }
    return success;
  }

  /// 签到
  Future<bool> signInSeat(LibraryReserveModel reserve) async {
    final success = await _service.signInSeat(reserve);
    if (success) {
      await refresh();
      ref.read(cachedLibraryReserveProvider.notifier).refresh();
    }
    return success;
  }

  /// 退座
  Future<bool> signBackSeat(LibraryReserveModel reserve) async {
    final success = await _service.signBackSeat(reserve);
    if (success) {
      await refresh();
      await ref.read(cachedLibraryReserveProvider.notifier).refresh();
    }
    return success;
  }
}

/// 阅览室列表 Provider (按日期入参缓存)
final libraryRoomsProvider =
    FutureProvider.family<List<LibraryRoomModel>, String>((ref, day) async {
  final service = ref.read(libraryServiceProvider);
  return service.fetchRoomList(day: day);
});
