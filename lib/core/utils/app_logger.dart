import 'dart:io';
import 'dart:convert';
import 'package:logger/logger.dart';

/// 全局日志管理器，确保在不同平台（尤其是 Windows）下的编码兼容性
class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: stdout.supportsAnsiEscapes,
      printEmojis: true,
      printTime: false,
    ),
    // 强制使用 stdout 来处理 UTF-8 编码
    output: StreamOutput(),
  );

  static Logger get instance => _logger;
}

/// 自定义输出流，确保在 Windows 上以 UTF-8 字节流格式写入
class StreamOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    for (var line in event.lines) {
      if (Platform.isWindows) {
        // Windows 下 print 默认跟随系统编码(如 GBK)，这里强制以 UTF-8 字节流写入 stdout
        stdout.add(utf8.encode('$line\n'));
      } else {
        // 其他平台默认行为
        print(line);
      }
    }
  }
}

// 辅助全局变量
final logger = AppLogger.instance;
