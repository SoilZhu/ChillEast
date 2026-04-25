import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// ICS 文件导出工具
class IcsExportHelper {
  /// 保存 ICS 内容到文件并分享
  static Future<void> saveAndShareIcs(String icsContent, String filename) async {
    try {
      // 获取临时目录
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      
      // 写入文件
      await file.writeAsString(icsContent);
      
      // 分享文件
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '湖南农业大学课表',
      );
    } catch (e) {
      throw Exception('ICS 导出失败: $e');
    }
  }
  
  /// 仅保存 ICS 文件（不分享）
  static Future<String> saveIcs(String icsContent, String filename) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsString(icsContent);
      return file.path;
    } catch (e) {
      throw Exception('ICS 保存失败: $e');
    }
  }
}
