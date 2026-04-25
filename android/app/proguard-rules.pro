# Flutter 核心保留规则
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.runtime.** { *; }

# 保留插件注册表
-keep class io.flutter.plugins.** { *; }

# 保留 PathProvider 相关的类 (解决 ClassNotFoundException: io.flutter.util.PathUtils)
-keep class io.flutter.util.PathUtils { *; }

# 保留 InAppWebView 相关的类
-keep class com.pichillilorenzo.flutter_inappwebview_android.** { *; }

# 保留 OkHttp / Dio 相关代码 (避免网络请求混淆崩溃)
-dontwarn okio.**
-dontwarn javax.annotation.**
-keepnames class com.fasterxml.jackson.** { *; }
-keepnames class retrofit2.** { *; }

# 保留 PointyCastle 加密相关 (你的作业功能需要它)
-keep class org.bouncycastle.** { *; }

# 忽略 Google Play Core 缺失警告 (解决 R8: Missing class com.google.android.play.core...)
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.gms.**

