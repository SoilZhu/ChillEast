import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../../../core/state/auth_state.dart';
import '../models/questionnaire_models.dart';
import '../services/questionnaire_service.dart';
import '../services/questionnaire_storage.dart';

/// 学工问卷列表缓存（首页“待完成的问卷”数据源）
/// 登录成功后自动静默拉取并缓存；首页只展示其中待填写的。
final questionnaireCacheProvider = StateNotifierProvider<
    QuestionnaireCacheNotifier, AsyncValue<List<QuestionnaireItem>>>((ref) {
  return QuestionnaireCacheNotifier(ref);
});

class QuestionnaireCacheNotifier
    extends StateNotifier<AsyncValue<List<QuestionnaireItem>>> {
  final Ref _ref;
  final _logger = Logger();

  QuestionnaireCacheNotifier(this._ref)
      : super(const AsyncValue.loading()) {
    _init();

    // 监听登录状态，登录成功后自动静默拉取
    _ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (previous?.status != AuthStatus.authenticated &&
          next.status == AuthStatus.authenticated) {
        _logger.i('🔐 Login success detected, auto-refreshing questionnaires...');
        _silentRefresh();
      }
    });
  }

  Future<void> _init() async {
    final cached = await QuestionnaireStorage.getCachedItems();
    if (mounted) state = AsyncValue.data(cached);

    final auth = _ref.read(authStateProvider);
    if (auth.status == AuthStatus.authenticated) {
      // 已登录时读完缓存再静默刷一下（无感）
      _silentRefresh();
    }
  }

  /// 无感刷新（登录后自动调用，失败静默保留缓存）
  Future<void> _silentRefresh() async {
    try {
      final items = await _ref.read(questionnaireServiceProvider).fetchList();
      await QuestionnaireStorage.saveItems(items);
      if (mounted) state = AsyncValue.data(items);
    } catch (e) {
      _logger.w('⚠️ Silent refresh questionnaires failed: $e');
    }
  }

  /// 手动刷新（提交问卷回来后调用）
  Future<void> refresh() => _silentRefresh();

  /// 退出登录时清空
  Future<void> clear() async {
    await QuestionnaireStorage.clearItems();
    if (mounted) state = const AsyncValue.data([]);
  }
}
