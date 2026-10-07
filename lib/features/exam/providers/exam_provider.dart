import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../../../core/state/auth_state.dart';
import '../models/exam_schedule_model.dart';
import '../services/exam_service.dart';
import '../services/exam_storage.dart';

final examServiceProvider = Provider((ref) => ExamService());
final examStorageProvider = Provider((ref) => ExamStorage());

/// 考试日程全量列表提供者
final examProvider =
    StateNotifierProvider<ExamNotifier, AsyncValue<List<ExamScheduleModel>>>((ref) {
  return ExamNotifier(ref);
});

/// 本学期考试日程列表提供者（过滤非本学期考试）
final currentSemesterExamsProvider =
    Provider<AsyncValue<List<ExamScheduleModel>>>((ref) {
  final allAsync = ref.watch(examProvider);
  return allAsync.whenData(
    (list) => list.where((e) => e.isCurrentSemester()).toList(),
  );
});

class ExamNotifier extends StateNotifier<AsyncValue<List<ExamScheduleModel>>> {
  final Ref _ref;
  final _logger = Logger();

  ExamNotifier(this._ref) : super(const AsyncValue.loading()) {
    _init();

    // 监听登录状态，登录成功后自动静默刷新
    _ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (previous?.status != AuthStatus.authenticated &&
          next.status == AuthStatus.authenticated) {
        _logger.i('🔐 Login success detected, auto-refreshing exams...');
        _silentRefresh();
      }
    });
  }

  Future<void> _init() async {
    final storage = _ref.read(examStorageProvider);
    final local = await storage.readExamList();

    if (local.isNotEmpty) {
      state = AsyncValue.data(local);
    }

    final auth = _ref.read(authStateProvider);
    if (auth.status == AuthStatus.authenticated) {
      _silentRefresh();
    } else {
      if (local.isEmpty) {
        state = const AsyncValue.data([]);
      }
    }
  }

  /// 静默刷新（不阻塞 UI）
  Future<void> _silentRefresh() async {
    try {
      final storage = _ref.read(examStorageProvider);
      final local = await storage.readExamList();
      final exams = await _ref
          .read(examServiceProvider)
          .fetchExams(cachedExams: local);

      await storage.saveExamList(exams);
      state = AsyncValue.data(exams);
    } catch (e) {
      _logger.w('⚠️ Silent refresh exams failed: $e');
    }
  }

  /// 手动刷新（显示 loading 状态）
  Future<void> refresh() async {
    try {
      state = const AsyncValue.loading();
      final storage = _ref.read(examStorageProvider);
      final local = await storage.readExamList();
      final exams = await _ref
          .read(examServiceProvider)
          .fetchExams(cachedExams: local);

      await storage.saveExamList(exams);
      state = AsyncValue.data(exams);
    } catch (e, st) {
      _logger.e('❌ Refresh exams failed: $e');
      state = AsyncValue.error(e, st);
    }
  }

  /// 清除所有考试日程
  Future<void> clearAll() async {
    await _ref.read(examStorageProvider).deleteExamList();
    state = const AsyncValue.data([]);
  }
}
