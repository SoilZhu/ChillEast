import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/app_logger.dart';

/// 处理中报修工单本地缓存（首页“报修工单”展示用）
/// 直接存工单原始 JSON，恢复时走 RepairOrder.fromJson。
class RepairCacheStorage {
  static const String _cachedItemsKey = 'cached_ongoing_repair_items';
  static final _logger = AppLogger.instance;

  static Future<List<Map<String, dynamic>>> getCachedRaws() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonListStr = prefs.getString(_cachedItemsKey);
      if (jsonListStr != null && jsonListStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonListStr);
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
      return [];
    } catch (e) {
      _logger.w('⚠️ Failed to read cached repairs: $e');
      return [];
    }
  }

  static Future<void> saveRaws(List<Map<String, dynamic>> raws) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedItemsKey, jsonEncode(raws));
      _logger.d('💾 Saved ${raws.length} repairs to local cache');
    } catch (e) {
      _logger.e('❌ Failed to save repairs to cache: $e');
    }
  }

  static Future<void> clearItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedItemsKey);
      _logger.d('🗑️ Cleared repairs from local cache');
    } catch (e) {
      _logger.e('❌ Failed to clear repairs cache: $e');
    }
  }
}
