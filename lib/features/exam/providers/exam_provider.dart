import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../../../core/network/cookie_manager.dart';
import '../../../core/state/auth_state.dart';
import '../models/exam_schedule_model.dart';
import '../services/exam_service.dart';
import '../services/exam_storage.dart';

import 'package:intl/intl.dart';
import '../../profile/providers/settings_provider.dart';

final examServiceProvider = Provider((ref) => ExamService());
final examStorageProvider = Provider((ref) => ExamStorage());

/// 考试日程全量列表提供者
final examProvider =
    StateNotifierProvider<ExamNotifier, AsyncValue<List<ExamScheduleModel>>>((ref) {
  return ExamNotifier(ref);
});

/// 本学期考试日程列表提供者（本学期超星考试 + 手动添加的未过期考试）
final currentSemesterExamsProvider =
    Provider<AsyncValue<List<ExamScheduleModel>>>((ref) {
  final allAsync = ref.watch(examProvider);
  final filtered = allAsync.valueOrNull
      ?.where((e) =>
          ExamStorage.isUpcomingOrToday(e) &&
          (e.isCurrentSemester() || e.isManual))
      .toList();

  if (allAsync.hasError) {
    return AsyncValue<List<ExamScheduleModel>>.error(
      allAsync.error!,
      allAsync.stackTrace ?? StackTrace.current,
    ).copyWithPrevious(
      filtered != null
          ? AsyncValue.data(filtered)
          : const AsyncValue.data([]),
    );
  }

  if (allAsync.isLoading && filtered == null) {
    return const AsyncValue.loading();
  }

  return AsyncValue.data(filtered ?? []);
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
      _rescheduleReminders();
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

  /// 合并内存中的手动作业与文件存储中的手动作业，防止刷新时丢失，并清理过期手动考试
  Future<List<ExamScheduleModel>> _collectManualUnion() async {
    final fromState = (state.valueOrNull ?? [])
        .where((e) => e.isManual && !ExamStorage.isManualExamExpired(e))
        .toList();
    List<ExamScheduleModel> fromStorage = [];
    try {
      fromStorage = (await _ref.read(examStorageProvider).readExamList())
          .where((e) => e.isManual && !ExamStorage.isManualExamExpired(e))
          .toList();
    } catch (_) {}
    final storageIds = fromStorage.map((e) => e.id).toSet();
    final stateOnly = fromState.where((e) => !storageIds.contains(e.id)).toList();
    return [...fromStorage, ...stateOnly];
  }

  /// 静默刷新（不阻塞 UI）
  Future<void> _silentRefresh() async {
    try {
      try {
        await AppCookieManager().syncMultiDomainCookiesFromWebView();
      } catch (_) {}

      final storage = _ref.read(examStorageProvider);
      final scraped = await _ref
          .read(examServiceProvider)
          .fetchExams();

      final manual = await _collectManualUnion();
      // 强行同步超星云端数据，仅保留用户手动创建的考试，旧的超星缓存不合入
      final merged = [...manual, ...scraped];
      merged.sort(ExamScheduleModel.compareTime);

      await storage.saveExamList(merged);
      state = AsyncValue.data(merged);
      _rescheduleReminders();
    } catch (e) {
      _logger.w('⚠️ Silent refresh exams failed: $e');
    }
  }

  /// 手动刷新（显示 loading 状态）
  Future<void> refresh() async {
    try {
      state = const AsyncLoading<List<ExamScheduleModel>>().copyWithPrevious(state);
      try {
        await AppCookieManager().syncMultiDomainCookiesFromWebView();
      } catch (_) {}

      final storage = _ref.read(examStorageProvider);
      final scraped = await _ref
          .read(examServiceProvider)
          .fetchExams();

      final manual = await _collectManualUnion();
      final merged = [...manual, ...scraped];
      merged.sort(ExamScheduleModel.compareTime);

      await storage.saveExamList(merged);
      state = AsyncValue.data(merged);
      _rescheduleReminders();
    } catch (e, st) {
      _logger.e('❌ Refresh exams failed: $e');
      List<ExamScheduleModel>? cached = state.valueOrNull;
      if (cached == null || cached.isEmpty) {
        try {
          cached = await _ref.read(examStorageProvider).readExamList();
        } catch (_) {}
      }
      final prev = cached != null ? AsyncValue.data(cached) : state;
      state = AsyncValue<List<ExamScheduleModel>>.error(e, st).copyWithPrevious(prev);
    }
  }

  /// 手动添加一场考试
  Future<void> addManualExam({
    required String title,
    required DateTime time,
    String courseName = '',
    String location = '',
    String remarks = '',
  }) async {
    final newItem = ExamScheduleModel(
      id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
      title: title.trim(),
      courseName: courseName.trim(),
      time: time,
      allTimes: [time],
      rawTimeStrs: [DateFormat('yyyy-MM-dd HH:mm').format(time)],
      status: '待考',
      isManual: true,
      location: location.trim().isNotEmpty ? location.trim() : null,
      remarks: remarks.trim().isNotEmpty ? remarks.trim() : null,
      createdAt: DateTime.now(),
    );

    final current = state.valueOrNull ?? [];
    final updated = [...current, newItem]
        .where((e) => ExamStorage.isUpcomingOrToday(e))
        .toList();
    updated.sort(ExamScheduleModel.compareTime);

    await _ref.read(examStorageProvider).saveExamList(updated);
    state = AsyncValue.data(updated);
    _rescheduleReminders();
  }

  /// 删除考试（通常针对手动添加的考试）
  Future<void> deleteExam(String id) async {
    final current = state.valueOrNull ?? [];
    final updated = current.where((e) => e.id != id).toList();
    await _ref.read(examStorageProvider).saveExamList(updated);
    state = AsyncValue.data(updated);
    _rescheduleReminders();
  }

  /// 从存储中重新加载考试日程（用于 Agent / MCP 工具直接写文件后同步 UI）
  Future<void> reloadFromStorage() async {
    try {
      final list = await _ref.read(examStorageProvider).readExamList();
      state = AsyncValue.data(list);
      _rescheduleReminders();
    } catch (e) {
      _logger.w('⚠️ Reload exams from storage failed: $e');
    }
  }

  /// 清理所有已过期的考试（始终只保留开始时间是今天以及今天之后日期的考试）
  Future<void> pruneExpiredManualExams() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated =
        current.where((e) => ExamStorage.isUpcomingOrToday(e)).toList();
    if (updated.length != current.length) {
      await _ref.read(examStorageProvider).saveExamList(updated);
      state = AsyncValue.data(updated);
      _rescheduleReminders();
    }
  }

  /// 清除所有考试日程（保留手动添加的考试）
  Future<void> clearAll() async {
    final manual = await _collectManualUnion();
    await _ref.read(examStorageProvider).saveExamList(manual);
    state = AsyncValue.data(manual);
    _rescheduleReminders();
  }

  void _rescheduleReminders() {
    try {
      _ref.read(settingsProvider.notifier).rescheduleNotifications();
    } catch (e) {
      _logger.w('⚠️ Reschedule notifications after exam change failed: $e');
    }
  }
}
