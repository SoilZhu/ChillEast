import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/app_logger.dart';
import '../models/questionnaire_models.dart';

/// 学工问卷列表本地缓存（首页“待完成的问卷”展示用）
class QuestionnaireStorage {
  static const String _cachedItemsKey = 'cached_questionnaire_items';
  static final _logger = AppLogger.instance;

  static Future<List<QuestionnaireItem>> getCachedItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonListStr = prefs.getString(_cachedItemsKey);
      if (jsonListStr != null && jsonListStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonListStr);
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(QuestionnaireItem.fromJson)
            .toList();
      }
      return [];
    } catch (e) {
      _logger.w('⚠️ Failed to read cached questionnaires: $e');
      return [];
    }
  }

  static Future<void> saveItems(List<QuestionnaireItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cachedItemsKey,
        jsonEncode(items.map((e) => e.toJson()).toList()),
      );
      _logger.d('💾 Saved ${items.length} questionnaires to local cache');
    } catch (e) {
      _logger.e('❌ Failed to save questionnaires to cache: $e');
    }
  }

  static Future<void> clearItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedItemsKey);
      _logger.d('🗑️ Cleared questionnaires from local cache');
    } catch (e) {
      _logger.e('❌ Failed to clear questionnaires cache: $e');
    }
  }
}
