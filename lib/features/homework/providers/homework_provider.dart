import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../../../core/state/auth_state.dart';
import '../../../core/services/notification_service.dart';
import '../../profile/providers/settings_provider.dart';
import '../models/homework_model.dart';
import '../services/homework_service.dart';
import '../services/homework_storage.dart';

final homeworkServiceProvider = Provider((ref) => HomeworkService());
final homeworkStorageProvider = Provider((ref) => HomeworkStorage());

/// 作业列表提供者
final homeworkProvider = StateNotifierProvider<HomeworkNotifier, AsyncValue<List<HomeworkModel>>>((ref) {
  return HomeworkNotifier(ref);
});

class HomeworkNotifier extends StateNotifier<AsyncValue<List<HomeworkModel>>> {
  final Ref _ref;
  final _logger = Logger();

  HomeworkNotifier(this._ref) : super(const AsyncValue.loading()) {
    _init();
    
    // 监听登录状态，如果登录成功则自动刷新
    _ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (previous?.status != AuthStatus.authenticated && next.status == AuthStatus.authenticated) {
        if (next.username != null) {
          _logger.i('🔐 Login success detected, auto-refreshing homework...');
          _silentRefresh(next.username!);
        }
      }
    });
  }

  Future<void> _init() async {
    final storage = _ref.read(homeworkStorageProvider);
    final local = await storage.readHomeworkList();
    
    if (local.isNotEmpty) {
      state = AsyncValue.data(local);
      // 读完本地后，触发一次通知安排（补偿）
      _scheduleReminders(local);
    }

    final auth = _ref.read(authStateProvider);
    if (auth.status == AuthStatus.authenticated && auth.username != null) {
      // 如果已登录，在读完本地后静默刷一下（无感）
      _silentRefresh(auth.username!);
    } else {
      if (local.isEmpty) {
        state = const AsyncValue.data([]);
      }
    }
  }

  /// 无感刷新
  Future<void> _silentRefresh(String studentId) async {
    try {
      final current = state.value ?? [];
      final manual = current.where((e) => e.isManual).toList();
      final scraped = await _ref.read(homeworkServiceProvider).fetchHomeworkList(studentId);
      
      final merged = [...manual, ...scraped];
      await _ref.read(homeworkStorageProvider).saveHomeworkList(merged);
      state = AsyncValue.data(merged);
      _scheduleReminders(merged);
    } catch (e) {
      _logger.w('⚠️ Silent refresh homework failed: $e');
    }
  }

  /// 手动刷新 (显示 loading)
  Future<void> refresh(String studentId) async {
    try {
      final current = state.value ?? [];
      final manual = current.where((e) => e.isManual).toList();
      
      state = const AsyncValue.loading();
      final scraped = await _ref.read(homeworkServiceProvider).fetchHomeworkList(studentId);
      
      final merged = [...manual, ...scraped];
      await _ref.read(homeworkStorageProvider).saveHomeworkList(merged);
      state = AsyncValue.data(merged);
      _scheduleReminders(merged);
    } catch (e, st) {
      _logger.e('❌ Refresh homework failed: $e');
      state = AsyncValue.error(e, st);
    }
  }

  /// 退出登录时清除 (仅清除爬取的，保留手动的)
  Future<void> clearAll() async {
    final current = state.value ?? [];
    final manual = current.where((e) => e.isManual).toList();
    await _ref.read(homeworkStorageProvider).saveHomeworkList(manual);
    state = AsyncValue.data(manual);
  }

  /// 添加手动作业
  Future<void> addManualHomework({
    required String title,
    String courseName = '',
    DateTime? endTime,
    String remarks = '',
  }) async {
    final newItem = HomeworkModel(
      id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      courseName: courseName,
      endTime: endTime,
      status: HomeworkStatus.pending,
      studentId: 'manual',
      isManual: true,
      createdAt: DateTime.now(),
      remarks: remarks,
    );

    final current = state.value ?? [];
    final updated = [newItem, ...current];
    await _ref.read(homeworkStorageProvider).saveHomeworkList(updated);
    state = AsyncValue.data(updated);
    _scheduleReminders(updated);
  }

  /// 删除作业
  Future<void> deleteHomework(String id) async {
    final current = state.value ?? [];
    final updated = current.where((e) => e.id != id).toList();
    await _ref.read(homeworkStorageProvider).saveHomeworkList(updated);
    state = AsyncValue.data(updated);
  }

  /// 切换完成状态
  Future<void> toggleStatus(String id) async {
    final current = state.value ?? [];
    final updated = current.map((e) {
      if (e.id == id) {
        final newStatus = e.status == HomeworkStatus.completed 
            ? HomeworkStatus.pending 
            : HomeworkStatus.completed;
        return e.copyWith(status: newStatus);
      }
      return e;
    }).toList();
    await _ref.read(homeworkStorageProvider).saveHomeworkList(updated);
    state = AsyncValue.data(updated);
  }

  /// 存档/撤销存档
  Future<void> setArchived(String id, bool archived) async {
    final current = state.value ?? [];
    final updated = current.map((e) {
      if (e.id == id) {
        return e.copyWith(status: archived ? HomeworkStatus.archived : HomeworkStatus.pending);
      }
      return e;
    }).toList();
    await _ref.read(homeworkStorageProvider).saveHomeworkList(updated);
    state = AsyncValue.data(updated);
  }

  /// 撤销删除 (恢复之前的状态)
  Future<void> restoreList(List<HomeworkModel> oldList) async {
    await _ref.read(homeworkStorageProvider).saveHomeworkList(oldList);
    state = AsyncValue.data(oldList);
  }

  void _scheduleReminders(List<HomeworkModel> list) {
    if (list.isEmpty) return;
    final settings = _ref.read(settingsProvider);
    NotificationService().scheduleHomeworkReminders(
      list,
      settings.homeworkReminderHours,
    );
  }
}
