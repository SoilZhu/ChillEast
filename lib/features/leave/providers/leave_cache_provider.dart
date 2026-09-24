import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../../../core/state/auth_state.dart';
import '../models/leave_models.dart';
import '../services/leave_service.dart';
import '../services/leave_storage.dart';

/// 请假记录缓存（首页“请假申请”数据源）
/// 登录成功后自动静默拉取并缓存；首页只展示其中进行中的。
final leaveCacheProvider =
    StateNotifierProvider<LeaveCacheNotifier, AsyncValue<List<LeaveRecord>>>(
        (ref) {
  return LeaveCacheNotifier(ref);
});

class LeaveCacheNotifier extends StateNotifier<AsyncValue<List<LeaveRecord>>> {
  final Ref _ref;
  final _logger = Logger();

  LeaveCacheNotifier(this._ref) : super(const AsyncValue.loading()) {
    _init();

    // 监听登录状态，登录成功后自动静默拉取
    _ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (previous?.status != AuthStatus.authenticated &&
          next.status == AuthStatus.authenticated) {
        _logger.i('🔐 Login success detected, auto-refreshing leaves...');
        _silentRefresh();
      }
    });
  }

  Future<void> _init() async {
    final cached = await LeaveStorage.getCachedItems();
    if (mounted) state = AsyncValue.data(cached);

    final auth = _ref.read(authStateProvider);
    if (auth.status == AuthStatus.authenticated) {
      _silentRefresh();
    }
  }

  Future<void> _silentRefresh() async {
    try {
      final items = await _ref.read(leaveServiceProvider).fetchList();
      await LeaveStorage.saveItems(items);
      if (mounted) state = AsyncValue.data(items);
    } catch (e) {
      _logger.w('⚠️ Silent refresh leaves failed: $e');
    }
  }

  Future<void> refresh() => _silentRefresh();

  Future<void> clear() async {
    await LeaveStorage.clearItems();
    if (mounted) state = const AsyncValue.data([]);
  }
}
