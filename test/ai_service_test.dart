import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/core/ai/ai_service.dart';
import 'package:ChillEast/core/mcp/services/mcp_tool_registry.dart';
import 'package:ChillEast/core/mcp/tools/timetable_tool.dart';

void main() {
  group('AI Assistant Service Tests', () {
    test('AiChatMessage serialization and deserialization', () {
      final msg = AiChatMessage(
        role: 'user',
        content: '今天有什么课？',
      );
      final json = msg.toJson();
      expect(json['role'], 'user');
      expect(json['content'], '今天有什么课？');

      final fromJson = AiChatMessage.fromJson(json);
      expect(fromJson.role, 'user');
      expect(fromJson.content, '今天有什么课？');
    });

    test('AiAssistantService prompt construction', () async {
      final service = AiAssistantService();
      final prompt = await service.buildSystemPrompt();
      expect(prompt.contains('自在东湖'), isTrue);
      expect(prompt.contains('MCP'), isTrue);
    });

    test('McpToolRegistry tool list format for AI', () {
      final registry = McpToolRegistry([TimetableTool.create()]);
      final tools = registry.getAllTools();
      expect(tools.length, 1);
      expect(tools.first.name, 'query_timetable');
    });

    test('Default model, URL normalization and environment fallback', () {
      // 默认走 Worker 中转：URL 为自建域名，模型由 Worker 端指定
      expect(AiAssistantService.defaultApiUrl, 'https://chilleast-llm-api.soilzhu.su/v1');
      expect(AiAssistantService.defaultModel, 'soilzhu-latest');

      // 旧直连默认值保留为迁移识别常量
      expect(AiAssistantService.legacyDefaultApiUrl, 'https://api.siliconflow.cn/v1');
      expect(AiAssistantService.legacyDefaultModel, 'Qwen/Qwen3.5-4B');
      expect(AiAssistantService.isLegacyDefaultApiUrl('https://api.siliconflow.cn/v1'), isTrue);
      expect(
        AiAssistantService.isLegacyDefaultApiUrl('https://api.siliconflow.cn/v1/chat/completions'),
        isTrue,
      );
      expect(AiAssistantService.isLegacyDefaultApiUrl(AiAssistantService.defaultApiUrl), isFalse);
      expect(AiAssistantService.isLegacyDefaultModel('Qwen/Qwen3.5-4B'), isTrue);
      expect(AiAssistantService.isLegacyDefaultModel('worker-default'), isTrue);
      expect(AiAssistantService.isLegacyDefaultModel('soilzhu-latest'), isFalse);

      expect(
        AiAssistantService.normalizeEndpointUrl('https://api.siliconflow.cn/v1'),
        'https://api.siliconflow.cn/v1/chat/completions',
      );

      expect(
        AiAssistantService.normalizeEndpointUrl('https://api.siliconflow.cn/v1/chat/completions'),
        'https://api.siliconflow.cn/v1/chat/completions',
      );

      expect(
        AiAssistantService.normalizeEndpointUrl('https://api.openai.com/v1/'),
        'https://api.openai.com/v1/chat/completions',
      );
    });
  });
}
