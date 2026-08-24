import 'dart:convert';

/// JSON-RPC 2.0 MCP Request representation
class McpRequest {
  final String jsonrpc;
  final dynamic id;
  final String method;
  final Map<String, dynamic>? params;

  const McpRequest({
    this.jsonrpc = '2.0',
    required this.id,
    required this.method,
    this.params,
  });

  factory McpRequest.fromJson(Map<String, dynamic> json) {
    return McpRequest(
      jsonrpc: json['jsonrpc'] as String? ?? '2.0',
      id: json['id'],
      method: json['method'] as String? ?? '',
      params: json['params'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'jsonrpc': jsonrpc,
      'method': method,
    };
    if (id != null) map['id'] = id;
    if (params != null) map['params'] = params;
    return map;
  }
}

/// JSON-RPC 2.0 MCP Response representation
class McpResponse {
  final String jsonrpc;
  final dynamic id;
  final dynamic result;
  final McpError? error;

  const McpResponse({
    this.jsonrpc = '2.0',
    required this.id,
    this.result,
    this.error,
  });

  factory McpResponse.success({
    required dynamic id,
    required dynamic result,
  }) {
    return McpResponse(id: id, result: result);
  }

  factory McpResponse.error({
    required dynamic id,
    required int code,
    required String message,
    dynamic data,
  }) {
    return McpResponse(
      id: id,
      error: McpError(code: code, message: message, data: data),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'jsonrpc': jsonrpc,
      'id': id,
    };
    if (error != null) {
      map['error'] = error!.toJson();
    } else {
      map['result'] = result;
    }
    return map;
  }

  String toJsonString() => jsonEncode(toJson());
}

/// JSON-RPC Error object
class McpError {
  final int code;
  final String message;
  final dynamic data;

  const McpError({
    required this.code,
    required this.message,
    this.data,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'code': code,
      'message': message,
    };
    if (data != null) map['data'] = data;
    return map;
  }

  static const int parseError = -32700;
  static const int invalidRequest = -32600;
  static const int methodNotFound = -32601;
  static const int invalidParams = -32602;
  static const int internalError = -32603;
}
