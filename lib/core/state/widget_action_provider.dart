import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 小组件点击带来的待处理动作（原生侧通过 MethodChannel 透出）。
/// MainScaffold 监听并消费：agenda/homework 切 tab，功能 id 走快捷入口。
final widgetActionProvider = StateProvider<String?>((ref) => null);
