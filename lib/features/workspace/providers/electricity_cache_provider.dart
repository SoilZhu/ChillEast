import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/state/auth_state.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/electricity_model.dart';
import '../services/electricity_service.dart';

class DormitoryElectricityState {
  final SavedElectricityRoom? room;
  final ElectricityBalanceInfo? balanceInfo;
  final bool isLoading;
  final String? error;

  const DormitoryElectricityState({
    this.room,
    this.balanceInfo,
    this.isLoading = false,
    this.error,
  });

  DormitoryElectricityState copyWith({
    SavedElectricityRoom? room,
    bool clearRoom = false,
    ElectricityBalanceInfo? balanceInfo,
    bool clearBalanceInfo = false,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return DormitoryElectricityState(
      room: clearRoom ? null : (room ?? this.room),
      balanceInfo: clearBalanceInfo ? null : (balanceInfo ?? this.balanceInfo),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final electricityCacheProvider = StateNotifierProvider<
    ElectricityCacheNotifier, DormitoryElectricityState>((ref) {
  return ElectricityCacheNotifier(ref);
});

class ElectricityCacheNotifier
    extends StateNotifier<DormitoryElectricityState> {
  final Ref _ref;
  final _logger = AppLogger.instance;

  ElectricityCacheNotifier(this._ref)
      : super(const DormitoryElectricityState(isLoading: true)) {
    _init();

    // 监听登录状态，登录成功后自动静默拉取电费
    _ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (previous?.status != AuthStatus.authenticated &&
          next.status == AuthStatus.authenticated) {
        _logger.i('🔐 Login success detected, auto-refreshing electricity...');
        _silentRefresh();
      }
    });
  }

  Future<void> _init() async {
    final service = _ref.read(electricityServiceProvider);
    final room = await service.getSavedRoom();
    final balance = await service.getSavedBalance();

    if (mounted) {
      state = DormitoryElectricityState(
        room: room,
        balanceInfo: balance,
        isLoading: false,
      );
    }

    final auth = _ref.read(authStateProvider);
    if (auth.status == AuthStatus.authenticated && room != null) {
      _silentRefresh();
    }
  }

  Future<void> _silentRefresh() async {
    final room =
        state.room ?? await _ref.read(electricityServiceProvider).getSavedRoom();
    if (room == null) {
      if (mounted && state.isLoading) {
        state = state.copyWith(isLoading: false);
      }
      return;
    }

    if (mounted) {
      state = state.copyWith(room: room, isLoading: true, clearError: true);
    }

    try {
      final info = await _ref.read(electricityServiceProvider).getBalance(
            areaName: room.areaName,
            buildingName: room.buildingName,
            roomId: room.roomId,
            mertype: room.mertype,
          );
      if (mounted) {
        state = state.copyWith(
          room: room,
          balanceInfo: info,
          isLoading: false,
          clearError: true,
        );
      }
    } catch (e) {
      _logger.w('⚠️ Silent refresh electricity balance failed: $e');
      if (mounted) {
        state = state.copyWith(
          room: room,
          isLoading: false,
          error: e.toString(),
        );
      }
    }
  }

  Future<void> refresh() async {
    final room = await _ref.read(electricityServiceProvider).getSavedRoom();
    if (mounted && room != state.room) {
      state = state.copyWith(room: room);
    }
    await _silentRefresh();
  }

  void updateRoomAndBalance(
      SavedElectricityRoom room, ElectricityBalanceInfo? balanceInfo) {
    if (mounted) {
      state = state.copyWith(
        room: room,
        balanceInfo: balanceInfo,
        clearBalanceInfo: balanceInfo == null,
        isLoading: false,
        clearError: true,
      );
    }
  }

  void updateBalance(ElectricityBalanceInfo balanceInfo) {
    if (mounted) {
      state = state.copyWith(
        balanceInfo: balanceInfo,
        isLoading: false,
        clearError: true,
      );
    }
  }

  void clear() {
    if (mounted) {
      state = const DormitoryElectricityState();
    }
  }
}
