import 'package:flutter/material.dart';

class CourseColorUtils {
  static const List<Color> _palette = [
    // --- Material Design 2 Curated 40 Palette ---
    
    // Red / Pink
    Color(0xFFEF5350), // Red 400
    Color(0xFFE53935), // Red 600
    Color(0xFFD32F2F), // Red 700
    Color(0xFFEC407A), // Pink 400
    Color(0xFFD81B60), // Pink 600
    Color(0xFFC2185B), // Pink 700

    // Purple / Deep Purple
    Color(0xFFAB47BC), // Purple 400
    Color(0xFF8E24AA), // Purple 600
    Color(0xFF7B1FA2), // Purple 700
    Color(0xFF7E57C2), // Deep Purple 400
    Color(0xFF5E35B1), // Deep Purple 600
    Color(0xFF512DA8), // Deep Purple 700

    // Indigo / Blue
    Color(0xFF5C6BC0), // Indigo 400
    Color(0xFF3949AB), // Indigo 600
    Color(0xFF303F9F), // Indigo 700
    Color(0xFF42A5F5), // Blue 400
    Color(0xFF1E88E5), // Blue 600
    Color(0xFF1976D2), // Blue 700

    // Light Blue / Cyan / Teal
    Color(0xFF03A9F4), // Light Blue 500
    Color(0xFF0288D1), // Light Blue 700
    Color(0xFF00BCD4), // Cyan 500
    Color(0xFF0097A7), // Cyan 700
    Color(0xFF26A69A), // Teal 400
    Color(0xFF00897B), // Teal 600
    Color(0xFF00796B), // Teal 700

    // Green / Light Green / Lime
    Color(0xFF66BB6A), // Green 400
    Color(0xFF43A047), // Green 600
    Color(0xFF388E3C), // Green 700
    Color(0xFF8BC34A), // Light Green 500
    Color(0xFF689F38), // Light Green 700
    Color(0xFFC0CA33), // Lime 600
    Color(0xFF9E9D24), // Lime 800

    // Amber / Orange / Deep Orange
    Color(0xFFFFA000), // Amber 700
    Color(0xFFFF9800), // Orange 500
    Color(0xFFFB8C00), // Orange 600
    Color(0xFFF57C00), // Orange 700
    Color(0xFFFF7043), // Deep Orange 400
    Color(0xFFF4511E), // Deep Orange 600
    Color(0xFFE64A19), // Deep Orange 700
    
    // Brown / Blue Grey
    Color(0xFF8D6E63), // Brown 400
  ];

  static Color getColorForCourse(String courseName) {
    if (courseName.isEmpty) return _palette[0];
    
    // 使用 hashCode 决定颜色索引
    final hash = courseName.hashCode.abs();
    
    // 增加扰动确保相邻文字也有色彩区分
    final index = (hash + (hash >> 8)) % _palette.length;
    return _palette[index];
  }
}
