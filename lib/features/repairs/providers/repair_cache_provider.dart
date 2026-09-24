import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../../../core/state/auth_state.dart';
import '../models/repair_models.dart';
import '../services/repair_service.dart';
import '../services/repair_cache_storage.dart';

/// 处理中报修工单缓存（首页“报修工单”数据源）
/// 登录成功后自动静默拉取并缓存。
final repairCacheProvider = StateNotifierProvider<RepairCacheNotifier,
    AsyncValue<List<RepairOrder>>>((ref) {
  return RepairCacheNotifier(ref);
});

class RepairCacheNotifier
    extends StateNotifier<AsyncValue<List<RepairOrder>>> {
  final Ref _ref;
  final _logger = Logger();

  RepairCacheNotifier(this._ref) : super(const AsyncValue.loading()) {
    _init();

    // 监听登录状态，登录成功后自动静默拉取
    _ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (previous?.status != AuthStatus.authenticated &&
          next.status == AuthStatus.authenticated) {
        _logger.i('🔐 Login success detected, auto-refreshing repairs...');
        _silentRefresh();
      }
    });
  }

  Future<void> _init() async {
    final raws = await RepairCacheStorage.getCachedRaws();
    if (mounted) {
      state = AsyncValue.data(
        raws.map((raw) {
          try {
            return RepairOrder.fromJson(raw);
          } catch (_) {
            return null;
          }
        }).whereType<RepairOrder>().toList(),
      );
    }

    final auth = _ref.read(authStateProvider);
    if (auth.status == AuthStatus.authenticated) {
      _silentRefresh();
    }
  }

  Future<void> _silentRefresh() async {
    try {
      final items =
          await _ref.read(repairServiceProvider).fetchOrders(ongoing: true);
      await RepairCacheStorage.saveRaws(items.map((e) => e.raw).toList());
      if (mounted) state = AsyncValue.data(items);
    } catch (e) {
      _logger.w('⚠️ Silent refresh repairs failed: $e');
    }
  }

  Future<void> refresh() => _silentRefresh();

  Future<void> clear() async {
    await RepairCacheStorage.clearItems();
    if (mounted) state = const AsyncValue.data([]);
  }
}
