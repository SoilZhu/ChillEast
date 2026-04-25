import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../network/dio_client.dart';

class HitokotoService {
  static const String _cacheKey = 'hitokoto_cache';
  static const String _defaultHitokoto = '自在东湖在湖东！';
  static String get _apiUrl => 'https://v1.hitokoto.cn/?c=i'; // c=i 为诗词

  final Dio _dio = Dio();

  /// 获取缓存的 Hitokoto
  Future<String?> getCachedHitokoto() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cacheKey);
  }

  /// 预取并返回新的 Hitokoto (如果成功则保存)
  Future<String?> prefetchNextHitokoto() async {
    try {
      final response = await _dio.get(_apiUrl).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = response.data;
        final String hitokoto = data['hitokoto'] ?? '';
        
        // 还原回 12 字以内
        if (hitokoto.isNotEmpty && hitokoto.length <= 12) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_cacheKey, hitokoto);
          return hitokoto;
        }
      }
    } catch (e) {
      // 忽略
    }
    return null;
  }
}
