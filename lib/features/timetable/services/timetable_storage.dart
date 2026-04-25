import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../models/course_model.dart';

/// 课表文件存储管理
class TimetableStorage {
  static const String _fileName = 'current_timetable.ics';
  static const String _metaFileName = 'timetable_meta.json';
  static const String _courseListFileName = 'courses.json';
  
  /// 获取课表文件对象
  Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }
  
  /// 检查是否存在本地课表
  Future<bool> hasLocalTimetable() async {
    try {
      final file = await _getFile();
      return file.exists();
    } catch (e) {
      return false;
    }
  }
  
  /// 保存 ICS 文件
  Future<void> saveTimetable(String icsContent) async {
    try {
      final file = await _getFile();
      await file.writeAsString(icsContent);
    } catch (e) {
      throw Exception('保存课表失败: $e');
    }
  }
  
  /// 读取 ICS 文件
  Future<String?> readTimetable() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        return file.readAsString();
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// 删除课表文件
  Future<void> deleteTimetable() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // 忽略删除失败
    }
  }
  
  /// 获取课表文件路径（用于分享）
  Future<String?> getTimetableFilePath() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        return file.path;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// 保存课表元数据（学期和第一周周一）
  Future<void> saveMetadata({
    required String semester,
    required DateTime firstWeekMonday,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final metaFile = File('${directory.path}/$_metaFileName');
      
      final metadata = {
        'semester': semester,
        'firstWeekMonday': firstWeekMonday.toIso8601String(),
        'savedAt': DateTime.now().toIso8601String(),
      };
      
      await metaFile.writeAsString(jsonEncode(metadata));
    } catch (e) {
      throw Exception('保存课表元数据失败: $e');
    }
  }
  
  /// 读取课表元数据
  Future<Map<String, dynamic>?> readMetadata() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final metaFile = File('${directory.path}/$_metaFileName');
      
      if (await metaFile.exists()) {
        final content = await metaFile.readAsString();
        return jsonDecode(content) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// 删除课表元数据
  Future<void> deleteMetadata() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final metaFile = File('${directory.path}/$_metaFileName');
      
      if (await metaFile.exists()) {
        await metaFile.delete();
      }
    } catch (e) {
      // 忽略删除失败
    }
  }

  /// 保存课程列表（JSON）
  Future<void> saveCourseList(List<CourseModel> courses) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_courseListFileName');
      final jsonList = courses.map((c) => c.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      throw Exception('保存课程列表失败: $e');
    }
  }

  /// 读取课程列表（JSON）
  Future<List<CourseModel>> readCourseList() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_courseListFileName');
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        return jsonList.map((j) => CourseModel.fromJson(j as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 删除课程列表
  Future<void> deleteCourseList() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_courseListFileName');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // 忽略
    }
  }
}
