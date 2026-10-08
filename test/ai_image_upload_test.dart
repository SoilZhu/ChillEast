import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ChillEast/core/ai/ai_provider.dart';
import 'package:ChillEast/core/state/locale_provider.dart';
import 'package:ChillEast/features/home/screens/main_scaffold.dart';
import 'package:ChillEast/features/home/widgets/ai_response_card.dart';
import 'package:ChillEast/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AI Image Upload Tests', () {
    late Directory tempDir;
    late File sampleImage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        LocaleNotifier.localeKey: 'zh',
      });
      tempDir = await Directory.systemTemp.createTemp('chilleast_ai_test_');
      sampleImage = File('${tempDir.path}/test_sample.png');
      // 1x1 transparent PNG
      await sampleImage.writeAsBytes([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
      ]);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('AiDisplayMessage stores imagePath', () {
      final msg = AiDisplayMessage(
        role: 'user',
        text: '这门课什么时候上？',
        imagePath: sampleImage.path,
      );

      expect(msg.role, 'user');
      expect(msg.text, '这门课什么时候上？');
      expect(msg.imagePath, sampleImage.path);
    });

    test('AiAssistantNotifier.sendMessage handles image and formats multimodal message', () async {
      final container = ProviderContainer(
        overrides: [
          localeProvider.overrideWith((ref) => LocaleNotifier()..state = const Locale('zh')),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(aiAssistantProvider.notifier);
      await notifier.setApiKey('test_key');

      try {
        await notifier.sendMessage('请分析课表', imagePath: sampleImage.path);
      } catch (_) {}

      final state = container.read(aiAssistantProvider);
      expect(state.displayMessages.isNotEmpty, isTrue);
      final display = state.displayMessages.first;
      expect(display.text, '请分析课表');
      expect(display.imagePath, sampleImage.path);

      expect(state.conversationHistory.isNotEmpty, isTrue);
      final chatMsg = state.conversationHistory.first;
      expect(chatMsg.role, 'user');
      expect(chatMsg.content, isA<List>());

      final contentList = chatMsg.content as List;
      expect(contentList.length, 2);

      final imgPart = contentList[0] as Map<String, dynamic>;
      expect(imgPart['type'], 'image_url');
      expect(imgPart['image_url']['url'].toString().startsWith('data:image/png;base64,'), isTrue);

      final textPart = contentList[1] as Map<String, dynamic>;
      expect(textPart['type'], 'text');
      expect(textPart['text'], '请分析课表');
    });

    test('AiAssistantNotifier.sendMessage handles image without text with default prompt', () async {
      final container = ProviderContainer(
        overrides: [
          localeProvider.overrideWith((ref) => LocaleNotifier()..state = const Locale('zh')),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(aiAssistantProvider.notifier);
      await notifier.setApiKey('test_key');

      try {
        await notifier.sendMessage('', imagePath: sampleImage.path);
      } catch (_) {}

      final state = container.read(aiAssistantProvider);
      expect(state.displayMessages.isNotEmpty, isTrue);
      final display = state.displayMessages.first;
      expect(display.text, '请分析或描述这张图片');
      expect(display.imagePath, sampleImage.path);

      final chatMsg = state.conversationHistory.first;
      final contentList = chatMsg.content as List;
      final textPart = contentList[1] as Map<String, dynamic>;
      expect(textPart['text'], '请分析或描述这张图片');
    });

    testWidgets('MainScaffold AI mode displays image button to the left of send button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localeProvider.overrideWith((ref) => LocaleNotifier()..state = const Locale('zh')),
          ],
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MainScaffold(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 点击 AI 按键进入 AI 交互模式
      final aiBtnFinder = find.byKey(const ValueKey('ai_entry_button'));
      expect(aiBtnFinder, findsOneWidget);
      await tester.tap(aiBtnFinder);
      await tester.pump(const Duration(milliseconds: 300));

      // 验证图片按钮与发送按钮均已渲染
      final imageBtnFinder = find.byIcon(Icons.image_outlined);
      final sendBtnFinder = find.byIcon(Icons.arrow_upward_rounded);

      expect(imageBtnFinder, findsOneWidget);
      expect(sendBtnFinder, findsOneWidget);

      // 验证图片按钮位于发送键左侧
      final imagePos = tester.getCenter(imageBtnFinder);
      final sendPos = tester.getCenter(sendBtnFinder);
      expect(imagePos.dx, lessThan(sendPos.dx));
      expect((imagePos.dy - sendPos.dy).abs(), lessThan(5.0));

      // 验证点击之后先不展示卡片，而是直接暴露快捷提问按钮
      expect(find.byType(AiResponseCard), findsNothing);
      expect(find.byType(AiQuickPromptsList), findsOneWidget);
      expect(find.text('今天有什么课？'), findsOneWidget);
      // 验证快捷提问按钮左对齐（margin 16）且垂直间距为 2px（原 6px 的 1/3）
      final chip0 = tester.getRect(find.byType(ActionChip).at(0));
      final chip1 = tester.getRect(find.byType(ActionChip).at(1));
      expect(chip0.left, closeTo(16.0, 0.1));
      expect(chip1.left, closeTo(16.0, 0.1));
      expect(chip1.top - chip0.bottom, closeTo(2.0, 0.1));

      // 验证点击快捷提问右侧空白区域退出 AI 模式
      await tester.tapAt(const Offset(500, 130));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AiQuickPromptsList), findsNothing);

      // 重新点击 AI 按键进入 AI 交互模式
      await tester.tap(aiBtnFinder);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AiQuickPromptsList), findsOneWidget);

      // 点击快捷提问按钮后展示卡片
      await tester.tap(find.text('今天有什么课？'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AiResponseCard), findsOneWidget);
      expect(find.byType(AiQuickPromptsList), findsNothing);

      // 点击卡片内部，卡片依然保留（不误触退出）
      final cardCenter = tester.getCenter(find.byType(AiResponseCard));
      await tester.tapAt(cardCenter);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AiResponseCard), findsOneWidget);

      // 验证底栏返回按钮已被移除
      expect(find.byKey(const ValueKey('ai_back_button')), findsNothing);

      // 点击非快捷指令/底栏/卡片的外部区域退出 AI 模式
      await tester.tapAt(const Offset(400, 50));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AiResponseCard), findsNothing);

      // 确保组件内的延迟定时器跑完
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
