import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message_model.dart';
import '../services/notice_service.dart';
import 'package:logger/logger.dart';

class NoticeState {
  final List<MessageModel> messages;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? nextLastValue;
  final String? errorMessage;

  NoticeState({
    this.messages = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.nextLastValue,
    this.errorMessage,
  });

  NoticeState copyWith({
    List<MessageModel>? messages,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? nextLastValue,
    String? errorMessage,
  }) {
    return NoticeState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      nextLastValue: nextLastValue ?? this.nextLastValue,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class NoticeNotifier extends StateNotifier<NoticeState> {
  final NoticeService _service = NoticeService();
  final Logger _logger = Logger();

  NoticeNotifier() : super(NoticeState());

  Future<void> refresh() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, errorMessage: null, nextLastValue: null, hasMore: true);

    try {
      final result = await _service.fetchMessageList();
      state = state.copyWith(
        messages: result.messages,
        nextLastValue: result.nextLastValue,
        hasMore: result.hasMore,
        isLoading: false,
      );
      _logger.i('Notice refreshed: ${result.messages.length} messages');
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      _logger.e('Failed to refresh notices: $e');
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final result = await _service.fetchMessageList(lastValue: state.nextLastValue);
      state = state.copyWith(
        messages: [...state.messages, ...result.messages],
        nextLastValue: result.nextLastValue,
        hasMore: result.hasMore,
        isLoadingMore: false,
      );
      _logger.i('Notice loaded more: ${result.messages.length} messages');
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
      _logger.e('Failed to load more notices: $e');
    }
  }
  
  void markAsRead(String idCode) {
    state = state.copyWith(
      messages: state.messages.map((m) {
        if (m.idCode == idCode || m.uuid == idCode) {
          // 创建一个新的 MessageModel 实例并标记为已读
          return MessageModel(
            idCode: m.idCode,
            title: m.title,
            content: m.content,
            createrName: m.createrName,
            sendTime: m.sendTime,
            isRead: true,
            hasRedDot: false,
            countAll: m.countAll,
            countRead: m.countRead,
            uuid: m.uuid,
          );
        }
        return m;
      }).toList(),
    );
  }
  
  void clear() {
    state = NoticeState();
  }
}

final noticeProvider = StateNotifierProvider<NoticeNotifier, NoticeState>((ref) {
  return NoticeNotifier();
});
