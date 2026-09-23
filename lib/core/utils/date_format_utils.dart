import 'package:intl/intl.dart';

/// App 自带方言 locale（wuu/gan/hsn/yue/zh_hefei 等）intl 并不支持，
/// 直接 format 会抛 `Invalid locale` 导致红屏。统一走这里，
/// 失败时回退到 zh。
String formatYMMMd(DateTime date, String locale) {
  try {
    return DateFormat.yMMMd(locale).format(date);
  } catch (_) {
    return DateFormat.yMMMd('zh').format(date);
  }
}

String formatMMMd(DateTime date, String locale) {
  try {
    return DateFormat.MMMd(locale).format(date);
  } catch (_) {
    return DateFormat.MMMd('zh').format(date);
  }
}

String formatMMMdHm(DateTime date, String locale) {
  try {
    return DateFormat.MMMd(locale).add_Hm().format(date);
  } catch (_) {
    return DateFormat.MMMd('zh').add_Hm().format(date);
  }
}

String formatHm(DateTime date, String locale) {
  try {
    return DateFormat.Hm(locale).format(date);
  } catch (_) {
    return DateFormat.Hm('zh').format(date);
  }
}
