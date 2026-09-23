import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/course_model.dart';
import '../models/timetable_rule_model.dart';

/// 课表文件存储管理
class TimetableStorage {
  static const String _fileName = 'current_timetable.ics';
  static const String _metaFileName = 'timetable_meta.json';
  static const String _courseListFileName = 'courses.json';
  static const String _rawCourseListFileName = 'raw_courses.json';
  static const String _rulesFileName = 'timetable_rules.json';

  /// 自动同步开关的持久化 key（默认开）
  static const String autoSyncKey = 'timetable_auto_sync_enabled';

  /// 手动指定的本学期第一周周一（仅自动同步关闭时可设置）
  static const String manualFirstWeekMondayKey =
      'timetable_first_week_monday_manual';

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
        return jsonList
            .map((j) => CourseModel.fromJson(j as Map<String, dynamic>))
            .toList();
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

  /// 保存原始课程列表（未应用规则的教务原始数据）
  Future<void> saveRawCourseList(List<CourseModel> courses) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_rawCourseListFileName');
      final jsonList = courses.map((c) => c.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      throw Exception('保存原始课程列表失败: $e');
    }
  }

  /// 是否存在原始课程列表文件（未应用规则的教务原始数据）
  Future<bool> hasRawCourseList() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_rawCourseListFileName');
      return file.exists();
    } catch (e) {
      return false;
    }
  }

  /// 读取原始课程列表（未应用规则的原始数据）
  /// 注意：仅返回 raw_courses.json 的内容，不做任何回退。
  /// 调用方需要自行决定缺失时的迁移策略，避免把已应用规则的数据写回基准。
  Future<List<CourseModel>> readRawCourseList() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_rawCourseListFileName');
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        return jsonList
            .map((j) => CourseModel.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 删除原始课程列表
  Future<void> deleteRawCourseList() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_rawCourseListFileName');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // 忽略
    }
  }

  /// 保存规则列表
  Future<void> saveRules(List<TimetableRule> rules) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_rulesFileName');
      final jsonList = rules.map((r) => r.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      throw Exception('保存课表规则失败: $e');
    }
  }

  /// 读取规则列表
  Future<List<TimetableRule>> readRules() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_rulesFileName');
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        return jsonList
            .map((j) => TimetableRule.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 删除规则文件
  Future<void> deleteRules() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_rulesFileName');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // 忽略
    }
  }

  /// 保存手动指定的本学期第一周周一（自动归一到周一）
  Future<void> saveManualFirstWeekMonday(DateTime monday) async {
    final normalized = monday.subtract(Duration(days: monday.weekday - 1));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      manualFirstWeekMondayKey,
      DateTime(normalized.year, normalized.month, normalized.day)
          .toIso8601String(),
    );
  }

  /// 读取手动指定的第一周周一（未设置返回 null）
  Future<DateTime?> readManualFirstWeekMonday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(manualFirstWeekMondayKey);
      if (raw == null) return null;
      final parsed = DateTime.tryParse(raw);
      if (parsed == null) return null;
      return DateTime(parsed.year, parsed.month, parsed.day);
    } catch (e) {
      return null;
    }
  }

  /// 清除手动指定的第一周周一
  Future<void> clearManualFirstWeekMonday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(manualFirstWeekMondayKey);
    } catch (e) {
      // 忽略
    }
  }

  /// 按月份猜测开学周一（兜底逻辑）
  static DateTime guessFirstWeekMonday() {
    final now = DateTime.now();
    DateTime guess;
    if (now.month >= 8 || now.month <= 1) {
      guess = DateTime(now.month <= 1 ? now.year - 1 : now.year, 9, 1);
    } else {
      guess = DateTime(now.year, 2, 17);
    }
    while (guess.weekday != DateTime.monday) {
      guess = guess.add(const Duration(days: 1));
    }
    return guess;
  }

  /// 解析本学期第一周周一，优先级：
  /// - 自动同步开：元数据（教务同步校准）> 手动设置 > 猜测
  /// - 自动同步关：手动设置 > 元数据 > 猜测
  /// 一定返回有效日期（最差也是猜测值）。
  Future<DateTime> resolveFirstWeekMonday() async {
    DateTime? fromMetadata;
    try {
      final metadata = await readMetadata();
      final raw = metadata?['firstWeekMonday'];
      if (raw is String) fromMetadata = DateTime.tryParse(raw);
    } catch (_) {}

    DateTime? manual;
    try {
      manual = await readManualFirstWeekMonday();
    } catch (_) {}

    bool autoSync = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      autoSync = prefs.getBool(autoSyncKey) ?? true;
    } catch (_) {}

    if (autoSync) {
      return fromMetadata ?? manual ?? guessFirstWeekMonday();
    }
    return manual ?? fromMetadata ?? guessFirstWeekMonday();
  }
}
