import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../state/locale_provider.dart';
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
  final String? imagePath;
  final String? toolUsed;
  final DateTime timestamp;

  AiDisplayMessage({
    required this.role,
    required this.text,
    this.imagePath,
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

  AiAssistantState({
    this.status = AiAssistantStatus.idle,
    this.conversationHistory = const [],
    this.displayMessages = const [],
    this.currentToolStatus,
    this.errorMessage,
    this.apiKey,
    this.apiUrl = '',
    this.model = '',
  });

  /// 空字符串代表“跟随当前默认”（默认走 Worker 中转）。
  String get resolvedApiUrl =>
      apiUrl.trim().isNotEmpty ? apiUrl.trim() : AiAssistantService.defaultApiUrl;

  String get resolvedModel =>
      model.trim().isNotEmpty ? model.trim() : AiAssistantService.defaultModel;

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
    bool clearApiKey = false,
    String? apiUrl,
    String? model,
  }) {
    return AiAssistantState(
      status: status ?? this.status,
      conversationHistory: conversationHistory ?? this.conversationHistory,
      displayMessages: displayMessages ?? this.displayMessages,
      currentToolStatus: currentToolStatus,
      errorMessage: errorMessage,
      apiKey: clearApiKey ? null : (apiKey ?? this.apiKey),
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

  AiAssistantNotifier(this.ref) : super(AiAssistantState()) {
    loadSettings();
  }

  /// 加载配置：存量旧直连（硅基流动）配置自动迁移到 Worker 中转
  Future<void> loadSettings() async {
    try {
      final apiKey = await _storage.getAiApiKey();
      var apiUrl = await _storage.getAiApiUrl();
      if (AiAssistantService.isLegacyDefaultApiUrl(apiUrl)) {
        await _storage.clearAiApiUrl();
        apiUrl = null;
      }
      var model = await _storage.getAiModel();
      if (AiAssistantService.isLegacyDefaultModel(model)) {
        await _storage.clearAiModel();
        model = null;
      }
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

  /// 更新并保存 API URL（空字符串表示跟随默认）
  Future<void> setApiUrl(String url) async {
    if (url.trim().isNotEmpty) {
      await _storage.saveAiApiUrl(url);
    } else {
      await _storage.clearAiApiUrl();
    }
    state = state.copyWith(apiUrl: url.trim());
  }

  /// 更新并保存模型（空字符串表示跟随默认）
  Future<void> setModel(String model) async {
    if (model.trim().isNotEmpty) {
      await _storage.saveAiModel(model);
    } else {
      await _storage.clearAiModel();
    }
    state = state.copyWith(model: model.trim());
  }

  /// 保存完整设置 (URL + Model + Key)，留空表示跟随默认（Worker 中转）
  Future<void> saveFullSettings({
    required String apiUrl,
    required String model,
    required String apiKey,
  }) async {
    if (apiUrl.trim().isNotEmpty) {
      await _storage.saveAiApiUrl(apiUrl);
    } else {
      await _storage.clearAiApiUrl();
    }
    if (model.trim().isNotEmpty) {
      await _storage.saveAiModel(model);
    } else {
      await _storage.clearAiModel();
    }
    if (apiKey.trim().isNotEmpty) {
      await _storage.saveAiApiKey(apiKey);
    } else {
      await _storage.clearAiApiKey();
    }
    final trimmedKey = apiKey.trim();
    state = state.copyWith(
      apiUrl: apiUrl.trim(),
      model: model.trim(),
      apiKey: trimmedKey.isNotEmpty ? trimmedKey : null,
      clearApiKey: trimmedKey.isEmpty,
    );
  }

  /// 恢复默认设置
  Future<void> resetToDefaults() async {
    await _storage.clearAiApiUrl();
    await _storage.clearAiModel();
    await _storage.clearAiApiKey();
    state = state.copyWith(
      apiUrl: '',
      model: '',
      clearApiKey: true,
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

  AppLocalizations _getL10n() {
    final locale = ref.read(localeProvider);
    return lookupAppLocalizations(
      locale ?? WidgetsBinding.instance.platformDispatcher.locale,
    );
  }

  String _getMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.bmp')) return 'image/bmp';
    return 'image/jpeg';
  }

  /// 发送消息给 AI（支持附带本地图片并按 MiMo/OpenAI 多模态规范转为 Base64 Data URI）
  Future<void> sendMessage(String text, {String? imagePath}) async {
    final query = text.trim();
    if (query.isEmpty && (imagePath == null || imagePath.isEmpty)) return;

    final l10n = _getL10n();

    if (!state.hasApiKey) {
      state = state.copyWith(
        status: AiAssistantStatus.error,
        errorMessage: l10n.aiApiKeyNotConfigured,
      );
      return;
    }

    final effectiveDisplayText = query.isNotEmpty
        ? query
        : (imagePath != null ? l10n.describeImagePrompt : '');

    final newHistory = List<AiChatMessage>.from(state.conversationHistory);
    final newDisplay = List<AiDisplayMessage>.from(state.displayMessages);

    if (imagePath != null && imagePath.isNotEmpty) {
      final file = File(imagePath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final base64String = base64Encode(bytes);
        final mimeType = _getMimeType(imagePath);
        final dataUri = 'data:$mimeType;base64,$base64String';

        final promptForModel = query.isNotEmpty ? query : l10n.describeImagePrompt;

        newHistory.add(AiChatMessage(
          role: 'user',
          content: [
            {
              'type': 'image_url',
              'image_url': {
                'url': dataUri,
              },
            },
            {
              'type': 'text',
              'text': promptForModel,
            },
          ],
        ));
      } else {
        newHistory.add(AiChatMessage(role: 'user', content: effectiveDisplayText));
      }
    } else {
      newHistory.add(AiChatMessage(role: 'user', content: query));
    }

    newDisplay.add(AiDisplayMessage(
      role: 'user',
      text: effectiveDisplayText,
      imagePath: imagePath,
    ));

    state = state.copyWith(
      status: AiAssistantStatus.thinking,
      conversationHistory: newHistory,
      displayMessages: newDisplay,
      currentToolStatus: l10n.aiThinking,
      errorMessage: null,
    );

    try {
      final toolRegistry = ref.read(mcpToolRegistryProvider);
      String? lastUsedTool;

      final reply = await _service.chat(
        apiKey: state.effectiveApiKey,
        apiUrl: state.resolvedApiUrl,
        model: state.resolvedModel,
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
