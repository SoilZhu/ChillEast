import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 一个简单的计数器 Provider，用于强制触发首页提醒气泡的刷新
final classReminderTriggerProvider = StateProvider<int>((ref) => 0);
