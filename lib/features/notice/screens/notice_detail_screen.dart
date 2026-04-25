import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notice_provider.dart';
import '../services/notice_service.dart';
import 'package:logger/logger.dart';
import 'dart:convert';

class NoticeDetailScreen extends ConsumerStatefulWidget {
  final String noticeId;
  
  const NoticeDetailScreen({
    super.key,
    required this.noticeId,
  });

  @override
  ConsumerState<NoticeDetailScreen> createState() => _NoticeDetailScreenState();
}

class _NoticeDetailScreenState extends ConsumerState<NoticeDetailScreen> {
  final Logger _logger = Logger();
  final NoticeService _noticeService = NoticeService();
  
  bool _isLoading = true;
  Map<String, dynamic>? _detailData;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _loadDetail();
  }
  
  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final data = await _noticeService.fetchNoticeDetail(widget.noticeId);
      if (mounted) {
        setState(() {
          _detailData = data;
          _isLoading = false;
        });
        
        // ✨ 加载成功后发送“标记已读”请求
        _noticeService.setNoticeRead(widget.noticeId);
        // ✨ 同时更新本地 Provider 状态，让列表页即时消除红点/加粗
        ref.read(noticeProvider.notifier).markAsRead(widget.noticeId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
      _logger.e('Detail load error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知详情'),
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadDetail, child: const Text('重试')),
          ],
        ),
      );
    }

    if (_detailData == null) {
      return const Center(child: Text('未找到详情数据'));
    }

    final String title = _detailData!['title'] ?? '无标题';
    final String sender = _detailData!['createrName'] ?? '系统';
    final String time = _detailData!['sendTime'] ?? '';
    
    // ✨ 使用原始 content 字段，并将 \r 转换为标准的换行符 \n
    final String rawContent = _detailData!['content'] ?? '';
    final String cleanText = rawContent.replaceAll('\r', '\n');

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题渲染
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          
          // 发布信息栏
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                child: Icon(Icons.person, size: 14, color: Theme.of(context).primaryColor),
              ),
              const SizedBox(width: 8),
              Text(
                sender,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              ),
              const Spacer(),
              Text(
                time,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(thickness: 1, height: 1),
          ),
          
          // 正文渲染 (原生 Text 实现)
          Text(
            cleanText.trim(),
            style: TextStyle(
              fontSize: 17,
              height: 1.7,
              color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
