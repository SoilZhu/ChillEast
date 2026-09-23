import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ChillEast/core/utils/date_format_utils.dart';

/// 方言 locale（wuu/gan/hsn/yue/zh_hefei 等）intl 不认，
/// 直接 DateFormat 会抛 Invalid locale 导致红屏，helper 必须回退到 zh。
void main() {
  setUpAll(() async {
    // 与 lib/main.dart 生产初始化保持一致
    await Future.wait([
      initializeDateFormatting('zh_CN', null),
      initializeDateFormatting('en', null),
      initializeDateFormatting('ja', null),
      initializeDateFormatting('es', null),
      initializeDateFormatting('fr', null),
      initializeDateFormatting('pt', null),
      initializeDateFormatting('ru', null),
    ]);
  });

  final date = DateTime(2025, 9, 1, 8, 30);

  test('Dialect locales fall back instead of throwing', () {
    for (final locale in ['wuu', 'gan', 'hsn', 'yue', 'zh_hefei']) {
      expect(formatYMMMd(date, locale), equals('2025年9月1日'));
      expect(() => formatMMMd(date, locale), returnsNormally);
      expect(() => formatMMMdHm(date, locale), returnsNormally);
      expect(() => formatHm(date, locale), returnsNormally);
    }
  });

  test('Supported locales keep native formatting', () {
    expect(formatYMMMd(date, 'en'), equals('Sep 1, 2025'));
    expect(formatYMMMd(date, 'zh'), equals('2025年9月1日'));
  });
}
