import 'dart:convert';

/// MCP Tool definition according to Model Context Protocol specification.
class McpTool {
  /// Unique name of the tool (e.g., 'query_timetable', 'add_homework').
  final String name;

  /// Human and LLM-readable description of what the tool does and when to use it.
  final String description;

  /// JSON Schema describing the parameters accepted by this tool.
  final Map<String, dynamic> inputSchema;

  /// Execution handler for the tool.
  final Future<McpToolResult> Function(Map<String, dynamic> arguments) handler;

  const McpTool({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.handler,
  });

  /// Executes this tool with the given arguments.
  Future<McpToolResult> execute(Map<String, dynamic> arguments) async {
    try {
      return await handler(arguments);
    } catch (e, st) {
      return McpToolResult.error('执行工具 [$name] 失败: $e\n$st');
    }
  }

  /// Converts the tool definition to standard MCP Tool JSON format.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'inputSchema': inputSchema,
    };
  }
}

/// Content item inside an MCP Tool result.
class McpContent {
  final String type;
  final String? text;
  final String? data;
  final String? mimeType;

  const McpContent({
    required this.type,
    this.text,
    this.data,
    this.mimeType,
  });

  factory McpContent.text(String text) {
    return McpContent(type: 'text', text: text);
  }

  factory McpContent.json(dynamic data) {
    return McpContent(
      type: 'text',
      text: const JsonEncoder.withIndent('  ').convert(data),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'type': type};
    if (text != null) map['text'] = text;
    if (data != null) map['data'] = data;
    if (mimeType != null) map['mimeType'] = mimeType;
    return map;
  }

  factory McpContent.fromJson(Map<String, dynamic> json) {
    return McpContent(
      type: json['type'] as String? ?? 'text',
      text: json['text'] as String?,
      data: json['data'] as String?,
      mimeType: json['mimeType'] as String?,
    );
  }
}

/// Result returned by an MCP Tool execution.
class McpToolResult {
  final List<McpContent> content;
  final bool isError;
  final Map<String, dynamic>? meta;

  const McpToolResult({
    required this.content,
    this.isError = false,
    this.meta,
  });

  /// Helper factory for successful text response
  factory McpToolResult.text(String text, {Map<String, dynamic>? meta}) {
    return McpToolResult(
      content: [McpContent.text(text)],
      isError: false,
      meta: meta,
    );
  }

  /// Helper factory for successful JSON response
  factory McpToolResult.json(dynamic json, {Map<String, dynamic>? meta}) {
    return McpToolResult(
      content: [McpContent.json(json)],
      isError: false,
      meta: meta,
    );
  }

  /// Helper factory for error response
  factory McpToolResult.error(String errorMessage, {Map<String, dynamic>? meta}) {
    return McpToolResult(
      content: [McpContent.text(errorMessage)],
      isError: true,
      meta: meta,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'content': content.map((c) => c.toJson()).toList(),
      'isError': isError,
    };
    if (meta != null) map['_meta'] = meta;
    return map;
  }

  factory McpToolResult.fromJson(Map<String, dynamic> json) {
    final rawContent = json['content'] as List<dynamic>? ?? [];
    return McpToolResult(
      content: rawContent
          .map((c) => McpContent.fromJson(c as Map<String, dynamic>))
          .toList(),
      isError: json['isError'] as bool? ?? false,
      meta: json['_meta'] as Map<String, dynamic>?,
    );
  }
}
