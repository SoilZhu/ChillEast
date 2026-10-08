import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/state/auth_state.dart';
import '../../../../core/utils/app_logger.dart';
import '../services/campus_card_service.dart';

/// 校园卡信息与余额缓存（首页“校园卡余额”数据源）
final campusCardCacheProvider =
    StateNotifierProvider<CampusCardCacheNotifier, AsyncValue<CampusCardInfo?>>(
        (ref) {
  return CampusCardCacheNotifier(ref);
});

class CampusCardCacheNotifier
    extends StateNotifier<AsyncValue<CampusCardInfo?>> {
  final Ref _ref;
  final _logger = AppLogger.instance;

  CampusCardCacheNotifier(this._ref) : super(const AsyncValue.loading()) {
    _init();

    // 监听登录状态，登录成功后自动静默拉取最新校园卡信息
    _ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (previous?.status != AuthStatus.authenticated &&
          next.status == AuthStatus.authenticated) {
        _logger.i('🔐 Login success detected, auto-refreshing campus card...');
        _silentRefresh();
      }
    });
  }

  Future<void> _init() async {
    final service = _ref.read(campusCardServiceProvider);
    final cached = await service.getStoredCardInfo();
    if (mounted) {
      state = AsyncValue.data(cached);
    }

    final auth = _ref.read(authStateProvider);
    if (auth.status == AuthStatus.authenticated) {
      _silentRefresh();
    }
  }

  Future<void> _silentRefresh() async {
    try {
      final info =
          await _ref.read(campusCardServiceProvider).fetchRechargeInfo();
      if (mounted) {
        state = AsyncValue.data(info);
      }
    } catch (e) {
      _logger.w('⚠️ Silent refresh campus card info failed: $e');
    }
  }

  Future<void> refresh() => _silentRefresh();

  void update(CampusCardInfo info) {
    if (mounted) {
      state = AsyncValue.data(info);
    }
  }

  void clear() {
    if (mounted) {
      state = const AsyncValue.data(null);
    }
  }
}
