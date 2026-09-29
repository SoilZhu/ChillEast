import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/library_models.dart';
import '../models/library_book_models.dart';
import '../services/library_service.dart';
import '../services/library_book_service.dart';
import '../services/library_storage.dart';
import '../../profile/providers/settings_provider.dart';

final libraryServiceProvider = Provider<LibraryService>((ref) {
  return LibraryService();
});

final libraryBookServiceProvider = Provider<LibraryBookService>((ref) {
  return LibraryBookService();
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

class LibraryBookSearchState {
  final String keyword;
  final String searchType;
  final bool isLoading;
  final int currentProgressPage;
  final int totalProgressPages;
  final LibraryBookSearchResult? result;
  final String? error;

  const LibraryBookSearchState({
    this.keyword = '',
    this.searchType = 'title',
    this.isLoading = false,
    this.currentProgressPage = 0,
    this.totalProgressPages = 0,
    this.result,
    this.error,
  });

  LibraryBookSearchState copyWith({
    String? keyword,
    String? searchType,
    bool? isLoading,
    int? currentProgressPage,
    int? totalProgressPages,
    LibraryBookSearchResult? result,
    String? error,
    bool clearError = false,
    bool clearResult = false,
  }) {
    return LibraryBookSearchState(
      keyword: keyword ?? this.keyword,
      searchType: searchType ?? this.searchType,
      isLoading: isLoading ?? this.isLoading,
      currentProgressPage: currentProgressPage ?? this.currentProgressPage,
      totalProgressPages: totalProgressPages ?? this.totalProgressPages,
      result: clearResult ? null : (result ?? this.result),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class LibraryBookSearchNotifier extends StateNotifier<LibraryBookSearchState> {
  final LibraryBookService _service;
  CancelToken? _cancelToken;

  LibraryBookSearchNotifier(this._service) : super(const LibraryBookSearchState());

  void setSearchType(String searchType) {
    state = state.copyWith(searchType: searchType);
  }

  /// 取消当前正在进行的搜索请求
  void cancel() {
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('Search cancelled');
    }
    _cancelToken = null;
    if (state.isLoading) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> search(String keyword, {String? searchType}) async {
    final kw = keyword.trim();
    if (kw.isEmpty) return;

    // 若已有搜索正在进行，立即取消旧的搜索
    cancel();

    final type = searchType ?? state.searchType;
    final currentCancelToken = CancelToken();
    _cancelToken = currentCancelToken;

    state = state.copyWith(
      keyword: kw,
      searchType: type,
      isLoading: true,
      currentProgressPage: 1,
      totalProgressPages: 1,
      clearError: true,
      clearResult: true,
    );

    try {
      final result = await _service.searchBooks(
        keyword: kw,
        searchType: type,
        cancelToken: currentCancelToken,
        onProgress: (current, total) {
          if (currentCancelToken.isCancelled || _cancelToken != currentCancelToken) {
            return;
          }
          state = state.copyWith(
            currentProgressPage: current,
            totalProgressPages: total,
          );
        },
      );

      // 若当前请求已被取消或已被更新的请求覆盖，则不更新状态
      if (currentCancelToken.isCancelled || _cancelToken != currentCancelToken) {
        return;
      }

      state = state.copyWith(
        isLoading: false,
        result: result,
      );
    } catch (e) {
      // 若当前请求已被取消或已被更新的请求覆盖，则静默忽略不报错误
      if (currentCancelToken.isCancelled || _cancelToken != currentCancelToken) {
        return;
      }
      if (e is DioException &&
          (e.type == DioExceptionType.cancel || currentCancelToken.isCancelled)) {
        return;
      }
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception:', '').trim(),
      );
    } finally {
      if (_cancelToken == currentCancelToken) {
        _cancelToken = null;
      }
    }
  }

  void clear() {
    cancel();
    state = const LibraryBookSearchState();
  }

  @override
  void dispose() {
    cancel();
    super.dispose();
  }
}

final libraryBookSearchProvider =
    StateNotifierProvider<LibraryBookSearchNotifier, LibraryBookSearchState>((ref) {
  final service = ref.read(libraryBookServiceProvider);
  return LibraryBookSearchNotifier(service);
});
