import 'package:flutter/material.dart';

/// 创建一个从下方弹出的淡入淡出路由
Route createSlideUpRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.0, 0.05); // 从下方稍微偏移
      const end = Offset.zero;
      const curve = Curves.easeOutCubic;

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: animation.drive(tween),
          child: child,
        ),
      );
    },
    // 移除硬编码的白色背景，改为透明或默认，防止深色模式闪烁
    barrierColor: null,
    opaque: true,
  );
}
