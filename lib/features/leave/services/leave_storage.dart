import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/app_logger.dart';
import '../models/leave_models.dart';

/// 请假记录本地缓存（首页“请假申请”展示用）
class LeaveStorage {
  static const String _cachedItemsKey = 'cached_leave_items';
  static final _logger = AppLogger.instance;

  static Future<List<LeaveRecord>> getCachedItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonListStr = prefs.getString(_cachedItemsKey);
      if (jsonListStr != null && jsonListStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonListStr);
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(LeaveRecord.fromJson)
            .toList();
      }
      return [];
    } catch (e) {
      _logger.w('⚠️ Failed to read cached leaves: $e');
      return [];
    }
  }

  static Future<void> saveItems(List<LeaveRecord> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cachedItemsKey,
        jsonEncode(items.map((e) => e.toJson()).toList()),
      );
      _logger.d('💾 Saved ${items.length} leaves to local cache');
    } catch (e) {
      _logger.e('❌ Failed to save leaves to cache: $e');
    }
  }

  static Future<void> clearItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedItemsKey);
      _logger.d('🗑️ Cleared leaves from local cache');
    } catch (e) {
      _logger.e('❌ Failed to clear leaves cache: $e');
    }
  }
}
