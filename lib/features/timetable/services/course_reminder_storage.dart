import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/utils/atomic_storage_helper.dart';
import '../../cloudisk/services/cloud_backup_manager.dart';
import '../models/course_reminder_rule.dart';

/// 课程个性化提醒规则的存储与匹配服务
class CourseReminderStorage {
  static final CourseReminderStorage _instance = CourseReminderStorage._internal();
  factory CourseReminderStorage() => _instance;
  CourseReminderStorage._internal();

  static const String _rulesFileName = 'course_reminder_rules.json';

  Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_rulesFileName');
  }

  /// 读取所有自定义课程提醒规则
  Future<List<CourseReminderRule>> readRules() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) {
        return [];
      }
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];

      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList
          .map((item) => CourseReminderRule.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('⚠️ 读取课程提醒规则失败: $e');
      return [];
    }
  }

  /// 保存所有规则
  Future<void> saveRules(List<CourseReminderRule> rules) async {
    try {
      final file = await _getFile();
      final jsonList = rules.map((r) => r.toJson()).toList();
      await AtomicStorageHelper.atomicWriteString(
        file,
        jsonEncode(jsonList),
      );
      CloudBackupManager.instance.markDirty();
    } catch (e) {
      debugPrint('⚠️ 保存课程提醒规则失败: $e');
      throw Exception('保存课程提醒规则失败: $e');
    }
  }

  /// 添加或更新规则
  /// 如果存在完全相同维度（courseName + scope + week + dayOfWeek + startPeriod）的规则，则更新替换；否则追加
  Future<CourseReminderRule> addOrUpdateRule(CourseReminderRule rule) async {
    final rules = await readRules();
    final index = rules.indexWhere((r) =>
        r.id == rule.id ||
        (r.courseName == rule.courseName &&
            r.scope == rule.scope &&
            r.week == rule.week &&
            r.dayOfWeek == rule.dayOfWeek &&
            r.startPeriod == rule.startPeriod));

    if (index >= 0) {
      rules[index] = rule;
    } else {
      rules.add(rule);
    }

    await saveRules(rules);
    return rule;
  }

  /// 根据 ID 删除规则
  Future<bool> deleteRule(String id) async {
    final rules = await readRules();
    final originalLength = rules.length;
    rules.removeWhere((r) => r.id == id);
    if (rules.length != originalLength) {
      await saveRules(rules);
      return true;
    }
    return false;
  }

  /// 根据课程名删除相关规则（若指定了 scope，则只删该 scope）
  Future<int> deleteRulesForCourse(String courseName, {ReminderScope? scope}) async {
    final rules = await readRules();
    final originalLength = rules.length;
    rules.removeWhere((r) {
      if (r.courseName != courseName) return false;
      if (scope != null && r.scope != scope) return false;
      return true;
    });
    final removedCount = originalLength - rules.length;
    if (removedCount > 0) {
      await saveRules(rules);
    }
    return removedCount;
  }

  /// 清空所有规则
  Future<void> clearRules() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        await file.delete();
      }
      final tmp = File('${file.path}.tmp');
      if (await tmp.exists()) {
        await tmp.delete();
      }
      CloudBackupManager.instance.markDirty();
    } catch (e) {
      debugPrint('⚠️ 清空课程提醒规则失败: $e');
    }
  }

  /// 解析某一具体课次的最优先提醒规则
  ///
  /// 优先级顺序：
  /// 1. `onlyThis` (精确匹配课程名、周次、星期、节次)
  /// 2. `thisWeek` (匹配课程名、周次)
  /// 3. `thisWeekday` (匹配课程名、星期)
  /// 4. `all` (匹配课程名，全学期生效)
  ///
  /// 若无匹配规则，返回 null（调用方使用系统全局默认设置）
  static CourseReminderRule? resolveEffectiveRule({
    required List<CourseReminderRule> rules,
    required String courseName,
    required int week,
    required int dayOfWeek,
    required int startPeriod,
  }) {
    if (rules.isEmpty) return null;

    final trimmedName = courseName.trim();
    final courseRules = rules.where((r) => r.courseName.trim() == trimmedName).toList();
    if (courseRules.isEmpty) return null;

    // 1. 仅本次课 (onlyThis)
    for (final r in courseRules) {
      if (r.scope == ReminderScope.onlyThis &&
          r.week == week &&
          r.dayOfWeek == dayOfWeek &&
          (r.startPeriod == null || r.startPeriod == startPeriod)) {
        return r;
      }
    }

    // 2. 本周所有的课 (thisWeek)
    for (final r in courseRules) {
      if (r.scope == ReminderScope.thisWeek && r.week == week) {
        return r;
      }
    }

    // 3. 所有在周几的课 (thisWeekday)
    for (final r in courseRules) {
      if (r.scope == ReminderScope.thisWeekday && r.dayOfWeek == dayOfWeek) {
        return r;
      }
    }

    // 4. 全学期所有的课 (all)
    for (final r in courseRules) {
      if (r.scope == ReminderScope.all) {
        return r;
      }
    }

    return null;
  }
}
