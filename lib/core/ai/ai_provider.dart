import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../mcp/services/mcp_tool_registry.dart';
import '../utils/secure_storage_helper.dart';
import 'ai_service.dart';

/// 交互状态
enum AiAssistantStatus {
  idle,
  thinking,
  callingTool,
  success,
  error,
}

/// 用户界面展示的消息单元
class AiDisplayMessage {
  final String role; // 'user' | 'assistant'
  final String text;
  final String? toolUsed;
  final DateTime timestamp;

  AiDisplayMessage({
    required this.role,
    required this.text,
    this.toolUsed,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// AI 助理状态
class AiAssistantState {
  final AiAssistantStatus status;
  final List<AiChatMessage> conversationHistory;
  final List<AiDisplayMessage> displayMessages;
  final String? currentToolStatus;
  final String? errorMessage;
  final String? apiKey;
  final String apiUrl;
  final String model;

  const AiAssistantState({
    this.status = AiAssistantStatus.idle,
    this.conversationHistory = const [],
    this.displayMessages = const [],
    this.currentToolStatus,
    this.errorMessage,
    this.apiKey,
    this.apiUrl = AiAssistantService.defaultApiUrl,
    this.model = AiAssistantService.defaultModel,
  });

  bool get isLoading =>
      status == AiAssistantStatus.thinking || status == AiAssistantStatus.callingTool;

  String get effectiveApiKey {
    if (apiKey != null && apiKey!.trim().isNotEmpty) {
      return apiKey!.trim();
    }
    return AiAssistantService.defaultApiKey;
  }

  bool get hasCustomApiKey => apiKey != null && apiKey!.trim().isNotEmpty;

  bool get hasApiKey =>
      (apiKey != null && apiKey!.trim().isNotEmpty) ||
      AiAssistantService.defaultApiKey.isNotEmpty;

  AiAssistantState copyWith({
    AiAssistantStatus? status,
    List<AiChatMessage>? conversationHistory,
    List<AiDisplayMessage>? displayMessages,
    String? currentToolStatus,
    String? errorMessage,
    String? apiKey,
    String? apiUrl,
    String? model,
  }) {
    return AiAssistantState(
      status: status ?? this.status,
      conversationHistory: conversationHistory ?? this.conversationHistory,
      displayMessages: displayMessages ?? this.displayMessages,
      currentToolStatus: currentToolStatus,
      errorMessage: errorMessage,
      apiKey: apiKey ?? this.apiKey,
      apiUrl: apiUrl ?? this.apiUrl,
      model: model ?? this.model,
    );
  }
}

/// AI Assistant Notifier
class AiAssistantNotifier extends StateNotifier<AiAssistantState> {
  final Ref ref;
  final AiAssistantService _service = AiAssistantService();
  final SecureStorageHelper _storage = SecureStorageHelper();

  AiAssistantNotifier(this.ref) : super(const AiAssistantState()) {
    loadSettings();
  }

  /// 加载配置
  Future<void> loadSettings() async {
    try {
      final apiKey = await _storage.getAiApiKey();
      final apiUrl = await _storage.getAiApiUrl() ?? AiAssistantService.defaultApiUrl;
      final model = await _storage.getAiModel() ?? AiAssistantService.defaultModel;
      state = state.copyWith(
        apiKey: apiKey,
        apiUrl: apiUrl,
        model: model,
      );
    } catch (_) {}
  }

  /// 更新并保存 API Key
  Future<void> setApiKey(String apiKey) async {
    await _storage.saveAiApiKey(apiKey);
    state = state.copyWith(apiKey: apiKey.trim());
  }

  /// 更新并保存 API URL
  Future<void> setApiUrl(String url) async {
    await _storage.saveAiApiUrl(url);
    state = state.copyWith(apiUrl: url.trim());
  }

  /// 更新并保存模型
  Future<void> setModel(String model) async {
    await _storage.saveAiModel(model);
    state = state.copyWith(model: model.trim());
  }

  /// 保存完整设置 (URL + Model + Key)
  Future<void> saveFullSettings({
    required String apiUrl,
    required String model,
    required String apiKey,
  }) async {
    await _storage.saveAiApiUrl(apiUrl);
    await _storage.saveAiModel(model);
    if (apiKey.trim().isNotEmpty) {
      await _storage.saveAiApiKey(apiKey);
    } else {
      await _storage.clearAiApiKey();
    }
    state = state.copyWith(
      apiUrl: apiUrl.trim().isNotEmpty ? apiUrl.trim() : AiAssistantService.defaultApiUrl,
      model: model.trim().isNotEmpty ? model.trim() : AiAssistantService.defaultModel,
      apiKey: apiKey.trim().isNotEmpty ? apiKey.trim() : null,
    );
  }

  /// 恢复默认设置
  Future<void> resetToDefaults() async {
    await _storage.clearAiApiUrl();
    await _storage.clearAiModel();
    await _storage.clearAiApiKey();
    state = state.copyWith(
      apiUrl: AiAssistantService.defaultApiUrl,
      model: AiAssistantService.defaultModel,
      apiKey: null,
    );
  }

  /// 清空当前对话上下文（点击返回或退出时调用）
  void clearSession() {
    state = state.copyWith(
      status: AiAssistantStatus.idle,
      conversationHistory: [],
      displayMessages: [],
      currentToolStatus: null,
      errorMessage: null,
    );
  }

  /// 发送消息给 AI
  Future<void> sendMessage(String text) async {
    final query = text.trim();
    if (query.isEmpty) return;

    if (!state.hasApiKey) {
      state = state.copyWith(
        status: AiAssistantStatus.error,
        errorMessage: '未配置 API Key，请先在「AI 助理设置」中填入 API Key',
      );
      return;
    }

    final newHistory = List<AiChatMessage>.from(state.conversationHistory);
    newHistory.add(AiChatMessage(role: 'user', content: query));

    final newDisplay = List<AiDisplayMessage>.from(state.displayMessages);
    newDisplay.add(AiDisplayMessage(role: 'user', text: query));

    state = state.copyWith(
      status: AiAssistantStatus.thinking,
      conversationHistory: newHistory,
      displayMessages: newDisplay,
      currentToolStatus: '正在思考中...',
      errorMessage: null,
    );

    try {
      final toolRegistry = ref.read(mcpToolRegistryProvider);
      String? lastUsedTool;

      final reply = await _service.chat(
        apiKey: state.effectiveApiKey,
        apiUrl: state.apiUrl,
        model: state.model,
        conversationHistory: newHistory,
        toolRegistry: toolRegistry,
        onToolExecuting: (toolName, statusMessage) {
          lastUsedTool = toolName;
          state = state.copyWith(
            status: AiAssistantStatus.callingTool,
            currentToolStatus: statusMessage,
          );
        },
      );

      // 追加 assistant 消息
      newHistory.add(AiChatMessage(role: 'assistant', content: reply));
      newDisplay.add(AiDisplayMessage(
        role: 'assistant',
        text: reply,
        toolUsed: lastUsedTool,
      ));

      state = state.copyWith(
        status: AiAssistantStatus.success,
        conversationHistory: newHistory,
        displayMessages: newDisplay,
        currentToolStatus: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: AiAssistantStatus.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
        currentToolStatus: null,
      );
    }
  }
}

/// Provider
final aiAssistantProvider =
    StateNotifierProvider<AiAssistantNotifier, AiAssistantState>((ref) {
  return AiAssistantNotifier(ref);
});
