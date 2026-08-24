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
      expect(AiAssistantService.defaultModel, 'Qwen/Qwen3.5-4B');
      expect(AiAssistantService.defaultApiUrl, 'https://api.siliconflow.cn/v1');

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
