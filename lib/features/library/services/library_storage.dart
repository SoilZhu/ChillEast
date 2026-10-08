import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/app_logger.dart';
import '../models/library_models.dart';

class LibraryStorage {
  static const String _cachedReservesKey = 'cached_library_reserves';
  static const String _legacyCachedReserveKey = 'cached_library_reserve';
  static final _logger = AppLogger.instance;

  /// 读取本地缓存的所有有效预约信息
  static Future<List<LibraryReserveModel>> getCachedReserves() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonListStr = prefs.getString(_cachedReservesKey);
      if (jsonListStr != null && jsonListStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonListStr);
        return decoded
            .map((e) => LibraryReserveModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      // 兼容旧版单个缓存
      final singleJsonStr = prefs.getString(_legacyCachedReserveKey);
      if (singleJsonStr != null && singleJsonStr.isNotEmpty) {
        final Map<String, dynamic> jsonMap = jsonDecode(singleJsonStr);
        return [LibraryReserveModel.fromJson(jsonMap)];
      }

      return [];
    } catch (e) {
      _logger.w('⚠️ Failed to read cached library reserves: $e');
      return [];
    }
  }

  /// 保存有效预约列表到本地缓存
  static Future<void> saveReserves(List<LibraryReserveModel> reserves) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = reserves.map((e) => e.toJson()).toList();
      final jsonStr = jsonEncode(jsonList);
      await prefs.setString(_cachedReservesKey, jsonStr);
      _logger.d('💾 Saved ${reserves.length} library reserves to local cache');
    } catch (e) {
      _logger.e('❌ Failed to save library reserves to cache: $e');
    }
  }

  /// 清除本地缓存的预约信息
  static Future<void> clearReserves() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedReservesKey);
      await prefs.remove(_legacyCachedReserveKey);
      _logger.d('🗑️ Cleared library reserves from local cache');
    } catch (e) {
      _logger.e('❌ Failed to clear library reserves cache: $e');
    }
  }
}
