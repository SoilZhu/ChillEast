import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../../core/utils/atomic_storage_helper.dart';
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

  /// 判断考试开始时间是否为今天或今天之后的日期（无具体时间的考试一律保留）
  static bool isUpcomingOrToday(ExamScheduleModel exam, [DateTime? now]) {
    if (exam.time == null) return true;
    final current = now ?? DateTime.now();
    final todayStart = DateTime(current.year, current.month, current.day);
    return !exam.time!.isBefore(todayStart);
  }

  /// 判断考试是否已过期（开始时间早于今天 00:00:00）
  static bool isExamExpired(ExamScheduleModel exam, [DateTime? now]) {
    return !isUpcomingOrToday(exam, now);
  }

  /// 兼容旧方法名：始终只保留开始时间是今天以及今天之后日期的考试
  static bool isManualExamExpired(ExamScheduleModel exam, [DateTime? now]) {
    return isExamExpired(exam, now);
  }

  /// 始终只保留开始时间是今天以及今天之后日期的考试
  static List<ExamScheduleModel> filterUpcomingAndToday(
    List<ExamScheduleModel> exams, [
    DateTime? now,
  ]) {
    return exams.where((e) => isUpcomingOrToday(e, now)).toList();
  }

  /// 保存考试日程列表（始终只储存开始时间是今天以及今天之后日期的考试）
  Future<void> saveExamList(List<ExamScheduleModel> exams) async {
    try {
      final validList = filterUpcomingAndToday(exams);
      final file = await _getFile();
      final jsonList = validList.map((e) => e.toJson()).toList();
      await AtomicStorageHelper.atomicWriteString(file, jsonEncode(jsonList));
      CloudBackupManager.instance.markDirty();
    } catch (_) {
      // 忽略写入失败
    }
  }

  /// 读取考试日程列表（自动清理开始时间早于今天的考试）
  Future<List<ExamScheduleModel>> readExamList() async {
    try {
      final file = await _getFile();
      final decoded = await AtomicStorageHelper.readJsonWithRecovery(file,
          logTag: 'ExamStorage');
      if (decoded is List) {
        final list = decoded
            .whereType<Map>()
            .map((j) => ExamScheduleModel.fromJson(Map<String, dynamic>.from(j)))
            .toList();
        final validList = filterUpcomingAndToday(list);
        if (validList.length != list.length) {
          await saveExamList(validList);
        }
        return validList;
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
      await AtomicStorageHelper.atomicWriteString(
          file, jsonEncode(ids.toList()));
    } catch (_) {
      // 忽略
    }
  }

  /// 读取已过期的考试 ID 集合
  Future<Set<String>> readExpiredExamIds() async {
    try {
      final file = await _getExpiredIdsFile();
      final decoded = await AtomicStorageHelper.readJsonWithRecovery(file,
          logTag: 'ExamStorage.expired');
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toSet();
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
      await AtomicStorageHelper.deleteWithBackups(file);
      final expiredFile = await _getExpiredIdsFile();
      await AtomicStorageHelper.deleteWithBackups(expiredFile);
    } catch (_) {
      // 忽略
    }
  }
}
