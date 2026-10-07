import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../cloudisk/services/cloud_backup_manager.dart';
import '../models/exam_schedule_model.dart';

class ExamStorage {
  static const String _fileName = 'exam_schedule_list.json';
  static const String _expiredIdsFileName = 'expired_exam_ids.json';

  final Directory? baseDirectory;

  ExamStorage({this.baseDirectory});

  Future<File> _getFile() async {
    final directory = baseDirectory ?? await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<File> _getExpiredIdsFile() async {
    final directory = baseDirectory ?? await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_expiredIdsFileName');
  }

  /// 保存考试日程列表
  Future<void> saveExamList(List<ExamScheduleModel> exams) async {
    try {
      final file = await _getFile();
      final jsonList = exams.map((e) => e.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
      CloudBackupManager.instance.markDirty();
    } catch (_) {
      // 忽略写入失败
    }
  }

  /// 读取考试日程列表
  Future<List<ExamScheduleModel>> readExamList() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        return jsonList
            .map((j) => ExamScheduleModel.fromJson(j as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// 保存已过期的考试 ID 集合
  Future<void> saveExpiredExamIds(Set<String> ids) async {
    try {
      final file = await _getExpiredIdsFile();
      await file.writeAsString(jsonEncode(ids.toList()));
    } catch (_) {
      // 忽略
    }
  }

  /// 读取已过期的考试 ID 集合
  Future<Set<String>> readExpiredExamIds() async {
    try {
      final file = await _getExpiredIdsFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> list = jsonDecode(content);
        return list.map((e) => e.toString()).toSet();
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  /// 清除所有考试日程缓存
  Future<void> deleteExamList() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        await file.delete();
      }
      final expiredFile = await _getExpiredIdsFile();
      if (await expiredFile.exists()) {
        await expiredFile.delete();
      }
    } catch (_) {
      // 忽略
    }
  }
}
