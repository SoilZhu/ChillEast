import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/timetable_storage.dart';

final timetableStatusProvider = StateNotifierProvider<TimetableStatusNotifier, bool>((ref) {
  return TimetableStatusNotifier();
});

class TimetableStatusNotifier extends StateNotifier<bool> {
  TimetableStatusNotifier() : super(false) {
    checkStatus();
  }

  Future<void> checkStatus() async {
    final storage = TimetableStorage();
    final has = await storage.hasLocalTimetable();
    final courses = await storage.readCourseList();
    state = has && courses.isNotEmpty;
  }

  Future<void> refresh() async {
    // 强制重置“已看过提示”标记，确保新导入后能再次看到提醒
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('has_seen_class_reminder');
    
    await checkStatus();
  }
}
