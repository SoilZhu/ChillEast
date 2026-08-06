# 贡献与本地开发

## 固定工具链

为了让本地开发环境和 GitHub Actions 使用同一套构建条件，请使用：

- Flutter 3.38.5
- Dart 3.10.4（随 Flutter 3.38.5 提供）
- JDK 17
- Gradle 8.14（必须通过仓库内的 Gradle Wrapper 使用）

不要使用系统全局安装的 Gradle 代替 `android/gradlew`。

## Android Debug 构建基线

从全新的 Git checkout 开始，执行：

```bash
flutter --version
java -version
flutter pub get --enforce-lockfile
flutter build apk --debug --no-pub
```

成功后应生成：

```text
build/app/outputs/flutter-apk/app-debug.apk
```

如果 `flutter pub get --enforce-lockfile` 失败，说明当前 Flutter/Dart 版本与 `pubspec.lock` 不匹配，或者依赖声明发生变化。请不要在 CI 中忽略或自动覆盖这个问题。

## 不应提交的本地文件

以下内容不得提交：

- `android/local.properties`
- `android/key.properties`
- Android keystore 文件
- `build/` 和 `android/build/`
- `.dart_tool/`
- IDE、本地 Gradle 和 Flutter 缓存

正式发布签名和发布自动化将在后续 CI/CD 阶段单独配置。
