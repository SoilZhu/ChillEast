import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message_model.dart';
import '../providers/notice_provider.dart'; // ✅ 导入新 Provider
import 'notice_detail_screen.dart';
import '../../../core/state/auth_state.dart';
import '../../../core/widgets/login_required_placeholder.dart';
import '../../auth/screens/login_screen.dart';
import 'package:logger/logger.dart';

class NoticeListScreen extends ConsumerStatefulWidget {
  const NoticeListScreen({super.key});

  @override
  ConsumerState<NoticeListScreen> createState() => _NoticeListScreenState();
}

class _NoticeListScreenState extends ConsumerState<NoticeListScreen> with AutomaticKeepAliveClientMixin {
  final Logger _logger = Logger();
  final ScrollController _scrollController = ScrollController();
  
  @override
  bool get wantKeepAlive => true; // ✅ 保持页面状态，切换 Tab 不会销毁
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final noticeState = ref.read(noticeProvider);
      if (!noticeState.isLoading && !noticeState.isLoadingMore && noticeState.hasMore) {
        ref.read(noticeProvider.notifier).loadMore();
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用 super.build
    final authState = ref.watch(authStateProvider);
    final noticeState = ref.watch(noticeProvider);
    
    return Scaffold(
      body: _buildBody(authState, noticeState),
    );
  }
  
  Widget _buildBody(AuthState authState, NoticeState noticeState) {
    // 只有在完全没有本地账号信息时，才显示登录占位符
    if (authState.status == AuthStatus.unauthenticated && !authState.hasAccount) {
      return const LoginRequiredPlaceholder(
        title: '需要登录以接收通知',
        message: '登录后即可向您推送学校的最新通知公告',
        icon: Icons.notifications_paused_outlined,
      );
    }
    
    if (noticeState.isLoading && noticeState.messages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载通知...'),
          ],
        ),
      );
    }
    
    if (noticeState.errorMessage != null && noticeState.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                noticeState.errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.read(noticeProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }
    
    if (noticeState.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '暂无通知',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '有新消息时会在这里显示',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white38 : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      backgroundColor: Theme.of(context).cardColor,
      color: Theme.of(context).primaryColor,
      onRefresh: () => ref.read(noticeProvider.notifier).refresh(),
      child: ListView.builder(
        controller: _scrollController,
        itemCount: noticeState.messages.length + (noticeState.hasMore ? 1 : 0),
        padding: EdgeInsets.zero,
        itemBuilder: (context, index) {
          if (index == noticeState.messages.length) {
            return _buildLoadMoreIndicator(noticeState);
          }
          final message = noticeState.messages[index];
          return _buildMessageCard(message);
        },
      ),
    );
  }

  Widget _buildLoadMoreIndicator(NoticeState noticeState) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: noticeState.isLoadingMore
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('正在加载更多...', style: TextStyle(color: Colors.grey)),
                ],
              )
            : noticeState.hasMore 
                ? const SizedBox.shrink()
                : const Text('没有更多通知了', style: TextStyle(color: Colors.grey)),
      ),
    );
  }
  
  Widget _buildMessageCard(MessageModel message) {
    // 提取时间 (仅显示时分或月日)
    String timeDisplay = message.sendTime;
    try {
      final parts = message.sendTime.split(' ');
      if (parts.length > 1) {
        final date = parts[0];
        final time = parts[1];
        final now = DateTime.now();
        final today = '${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)}';
        timeDisplay = (date == today) ? time.substring(0, 5) : date.substring(5);
      }
    } catch (_) {}

    // 获取发送者首字母用于头像
    String initial = '通';
    if (message.createrName.isNotEmpty) {
      initial = message.createrName[0];
    }

    // 为不同的发送者生成固定的颜色
    final avatarColor = Colors.primaries[message.createrName.hashCode % Colors.primaries.length];

    return Column(
      children: [
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => NoticeDetailScreen(
                  noticeId: message.idCode,
                ),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  const begin = Offset(0.0, 0.05); // 从下方 5% 处开始
                  const end = Offset.zero;
                  const curve = Curves.easeOutCubic;

                  var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                  var opacityTween = Tween<double>(begin: 0.0, end: 1.0);

                  return FadeTransition(
                    opacity: animation.drive(opacityTween),
                    child: SlideTransition(
                      position: animation.drive(tween),
                      child: child,
                    ),
                  );
                },
                transitionDuration: const Duration(milliseconds: 300),
                reverseTransitionDuration: const Duration(milliseconds: 250),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左侧头像
                CircleAvatar(
                  radius: 20,
                  backgroundColor: avatarColor,
                  child: Text(
                    initial,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                // 中间内容
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              message.createrName.isEmpty ? '系统通知' : message.createrName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: message.isRead ? FontWeight.normal : FontWeight.bold,
                                color: Theme.of(context).brightness == Brightness.dark 
                                    ? (message.isRead ? Colors.white70 : Colors.white) 
                                    : (message.isRead ? const Color(0xFF5F6368) : const Color(0xFF202124)),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // 时间
                          Text(
                            timeDisplay,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // 标题
                      Text(
                        message.title,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? (message.isRead ? Colors.white60 : Colors.white) 
                              : (message.isRead ? const Color(0xFF5F6368) : const Color(0xFF202124)),
                          fontWeight: message.isRead ? FontWeight.normal : FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      // 内容摘要
                      Text(
                        message.content.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), '').trim(),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');
  
  /// 显示登录对话框
  void _showLoginDialog(BuildContext context) {
    Navigator.push(context, LoginScreen.route());
  }
}
