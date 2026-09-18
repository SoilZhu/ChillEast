import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Flyme 实况通知（Flyme 12+）的 Dart 封装。
///
/// 原生实现见 android/.../FlymeLiveManager.kt（照抄
/// Ruyue-Kinsenka/Flyme-Live-Notification-Demo），经 MethodChannel("flyme_live") 调用。
/// 非魅族 / Flyme < 12 的设备上 isSupported() 返回 false。
/// 与 AOSP Live Updates（CourseLiveService）互斥，见 SettingsNotifier。
class FlymeLiveService {
  static final FlymeLiveService _instance = FlymeLiveService._internal();
  factory FlymeLiveService() => _instance;
  FlymeLiveService._internal();

  static const MethodChannel _channel = MethodChannel('flyme_live');

  /// 测试用通知 id（与 AOSP 的 91000x 错开；正式课程/预约用另外的 id 段）
  static const int testCourseId = 920001;
  static const int testLibraryId = 920002;
  /// 测试文案里的提前分钟数（静态展示，不更新）
  static const int testLeadMinutes = 15;

  Future<bool> _callBool(String method) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final v = await _channel.invokeMethod<bool>(method);
      return v ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 是否为 Flyme 12+（魅族设备 + 主版本 >= 12）。
  Future<bool> isSupported() => _callBool('isSupported');

  /// 如 "Flyme 12 · Flyme 12.2.0.0A"，用于设置页展示，非支持设备返回空。
  Future<String> flymeLabel() async {
    if (kIsWeb || !Platform.isAndroid) return '';
    try {
      return await _channel.invokeMethod<String>('flymeLabel') ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<bool> areNotificationsEnabled() =>
      _callBool('areNotificationsEnabled');

  /// 直跳本应用的系统通知设置页。
  Future<bool> openNotificationSettings() =>
      _callBool('openNotificationSettings');

  /// 创建一条实况通知（静态卡片，不更新）。
  /// capsuleText 只放地点（如教3-201）。
  Future<bool> upsert({
    required int id,
    required String title,
    required String text,
    required String capsuleText,
    required String timeText,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final v = await _channel.invokeMethod<bool>('upsert', {
        'id': id,
        'title': title,
        'text': text,
        'capsuleText': capsuleText,
        'timeText': timeText,
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

  /// 开始测试：发两张静态卡——课程 + 图书馆座位，不更新。
  Future<bool> startTest() async {
    final okCourse = await _postCourseFrame();
    final okLibrary = await _postLibraryFrame();
    return okCourse || okLibrary;
  }

  String _timeText(String suffix) {
    final t = DateTime.now().add(const Duration(minutes: testLeadMinutes));
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm$suffix';
  }

  Future<bool> _postCourseFrame() {
    return upsert(
      id: testCourseId,
      title: '材料力学 · 教3-201',
      text: '还有 $testLeadMinutes 分钟上课',
      capsuleText: '教3-201',
      timeText: _timeText('开课'),
    );
  }

  Future<bool> _postLibraryFrame() {
    return upsert(
      id: testLibraryId,
      title: '128号座位 · 3楼自习室A区',
      text: '还有 $testLeadMinutes 分钟开始 · 请按时签到',
      capsuleText: '3楼自习室A区',
      timeText: _timeText('开始'),
    );
  }

  /// 结束测试：撤掉两张卡。
  Future<void> cancelTest() async {
    await cancel(testCourseId);
    await cancel(testLibraryId);
  }
}
