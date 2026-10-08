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

# 保留应用自定义组件及小组件服务
-keep class su.soilzhu.chilleast.** { *; }

# 保留常用插件原生类与后台服务
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class dev.fluttercommunity.plus.workmanager.** { *; }
-keep class com.arn.android_package_installer.** { *; }
-keep class dev.steenbakker.mobile_scanner.** { *; }
-keep class com.baseflow.geolocator.** { *; }

# JNI 原生方法保留
-keepclasseswithmembernames class * {
    native <methods>;
}

# 常见反射与泛型属性保留
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

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
