import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// AOSP Live Updates（Android 16 / API 36+）的 Dart 封装。
///
/// 原生实现见 android/.../CourseLiveManager.kt，经 MethodChannel("course_live") 调用。
/// 非 Android / API < 36 的设备上所有能力查询都返回 false，调用 upsert 为空操作。
class CourseLiveService {
  static final CourseLiveService _instance = CourseLiveService._internal();
  factory CourseLiveService() => _instance;
  CourseLiveService._internal();

  static const MethodChannel _channel = MethodChannel('course_live');

  /// 测试用通知 id（正式课程/预约用另外的 id 段，避免冲突）
  static const int testCourseId = 910001;
  static const int testLibraryId = 910002;

  Timer? _testTimer;
  void Function(int remainingMinutes)? onTestTick;

  Future<bool> _callBool(String method) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final v = await _channel.invokeMethod<bool>(method);
      return v ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 设备是否为 Android 16+（API 36+），即理论上支持 Live Updates。
  Future<bool> isSupported() => _callBool('isSupported');

  /// 系统通知总开关是否开。
  Future<bool> areNotificationsEnabled() =>
      _callBool('areNotificationsEnabled');

  /// 系统是否允许本 App 发送 promoted（Live Update）通知。
  Future<bool> canPostPromoted() => _callBool('canPostPromoted');

  /// 跳系统设置页（promoted 通知开关，失败则退回应用通知设置）。
  Future<bool> openPromotedSettings() => _callBool('openPromotedSettings');

  /// 直跳本应用的系统通知设置页。
  Future<bool> openNotificationSettings() =>
      _callBool('openNotificationSettings');

  /// 创建或更新一条实时活动（同 id 反复调用即更新）。
  Future<bool> upsert({
    required int id,
    required String title,
    required String text,
    String shortText = '',
    int progress = 0,
    int total = 100,
    int whenMs = 0,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final v = await _channel.invokeMethod<bool>('upsert', {
        'id': id,
        'title': title,
        'text': text,
        'shortText': shortText,
        'progress': progress,
        'total': total,
        'whenMs': whenMs,
      });
      return v ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> cancel(int id) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final v = await _channel.invokeMethod<bool>('cancel', {'id': id});
      return v ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 开始测试：同时发两张卡——课程倒计时 + 图书馆座位倒计时，
  /// 模拟“课前 15 分钟 / 预约开始前 15 分钟”。
  /// 每 4 秒把剩余分钟 -1（用秒模拟分钟，仅用于验证样式），到 1 分钟停住等手动撤回。
  Future<bool> startTest() async {
    stopTestTimer();
    _testTotal = 15;
    _testRemaining = 15;
    final okCourse = await _postCourseFrame();
    final okLibrary = await _postLibraryFrame();
    if (!okCourse && !okLibrary) return false;
    onTestTick?.call(_testRemaining);
    _testTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      _testRemaining -= 1;
      if (_testRemaining <= 1) {
        _testRemaining = 1;
        await _postCourseFrame();
        await _postLibraryFrame();
        onTestTick?.call(_testRemaining);
        stopTestTimer();
        return;
      }
      await _postCourseFrame();
      await _postLibraryFrame();
      onTestTick?.call(_testRemaining);
    });
    return true;
  }

  int _testTotal = 15;
  int _testRemaining = 15;

  Future<bool> _postCourseFrame() {
    // progress = 已等待时长，total = 提前量：越接近上课条越满，末尾白点即开课时刻
    final elapsed = _testTotal - _testRemaining;
    return upsert(
      id: testCourseId,
      title: '材料力学 · 教3-201',
      text: '还有 $_testRemaining 分钟上课',
      shortText: '教3-201',
      progress: elapsed,
      total: _testTotal,
      whenMs: DateTime.now()
          .add(Duration(minutes: _testRemaining))
          .millisecondsSinceEpoch,
    );
  }

  Future<bool> _postLibraryFrame() {
    final elapsed = _testTotal - _testRemaining;
    return upsert(
      id: testLibraryId,
      title: '128号座位 · 3楼自习室A区',
      text: '还有 $_testRemaining 分钟开始 · 请按时签到',
      shortText: '3楼自习室A区',
      progress: elapsed,
      total: _testTotal,
      whenMs: DateTime.now()
          .add(Duration(minutes: _testRemaining))
          .millisecondsSinceEpoch,
    );
  }

  /// 结束测试：停 timer + 撤掉两张卡。
  Future<void> cancelTest() async {
    stopTestTimer();
    await cancel(testCourseId);
    await cancel(testLibraryId);
  }

  void stopTestTimer() {
    _testTimer?.cancel();
    _testTimer = null;
  }

  int get testRemaining => _testRemaining;
  bool get isTesting => _testTimer != null;
}
