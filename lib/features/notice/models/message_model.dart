/// 通知消息数据模型
class MessageModel {
  final String idCode;
  final String title;
  final String content;
  final String createrName;
  final String sendTime;
  final bool isRead;
  final bool hasRedDot;
  final int countAll;
  final int countRead;
  final String uuid;
  
  const MessageModel({
    required this.idCode,
    required this.title,
    required this.content,
    required this.createrName,
    required this.sendTime,
    required this.isRead,
    required this.hasRedDot,
    required this.countAll,
    required this.countRead,
    this.uuid = '', // ✨ 新增 uuid 字段支持详情跳转
  });
  
  /// 从融合门户 API 格式解析 (旧格式)
  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      idCode: json['idCode'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createrName: json['createrName'] as String? ?? '',
      sendTime: json['sendTime'] as String? ?? '',
      isRead: json['isRead'] == '1',
      hasRedDot: json['redDot'] == '0', // redDot="0" 表示未读
      countAll: json['countAll'] as int? ?? 0,
      countRead: json['countRead'] as int? ?? 0,
    );
  }
  
  /// 从超星通知 API 格式解析 (新格式)
  factory MessageModel.fromChaoxingJson(Map<String, dynamic> json) {
    // insertTime 是毫秒时间戳，需要转换为日期字符串
    final insertTime = json['insertTime'] as int? ?? 0;
    final dateTime = insertTime > 0 
        ? DateTime.fromMillisecondsSinceEpoch(insertTime)
        : DateTime.now();
    final sendTimeStr = '${dateTime.year}-${_twoDigits(dateTime.month)}-${_twoDigits(dateTime.day)} ${_twoDigits(dateTime.hour)}:${_twoDigits(dateTime.minute)}';
    
    // isread: 1=已读, 0=未读
    final isReadValue = json['isread'] as int? ?? 0;
    
    // count_all 和 count_read 可能是字符串或数字
    final countAll = _parseInt(json['count_all']);
    final countRead = _parseInt(json['count_read']);
    
    return MessageModel(
      idCode: json['idCode'] as String? ?? '',
      title: _extractTitle(json), // 从 content 或 attachment 中提取标题
      content: json['content'] as String? ?? '',
      createrName: json['createrName'] as String? ?? '',
      sendTime: sendTimeStr,
      isRead: isReadValue == 1,
      hasRedDot: isReadValue == 0, // 未读则有红点
      countAll: countAll,
      countRead: countRead,
      uuid: json['uuid'] as String? ?? '', // ✨ 提取 uuid
    );
  }
  
  /// 辅助方法：提取标题
  static String _extractTitle(Map<String, dynamic> json) {
    // 尝试从 attachment 中解析标题
    final attachment = json['attachment'] as String?;
    if (attachment != null && attachment.isNotEmpty) {
      try {
        // attachment 是 JSON 字符串数组，例如: [{"att_web":{"title":"..."},...}]
        // 使用正则提取 title
        final titleRegex = RegExp(r'"title"\s*:\s*"([^"]+)"');
        final match = titleRegex.firstMatch(attachment);
        if (match != null && match.group(1) != null) {
          return match.group(1)!;
        }
      } catch (e) {
        // 解析失败，继续使用 content
      }
    }
    
    // 如果无法从 attachment 提取，使用 content 的第一行
    final content = json['content'] as String? ?? '';
    if (content.isNotEmpty) {
      final lines = content.split('\r\n');
      if (lines.isNotEmpty && lines[0].isNotEmpty) {
        final firstLine = lines[0];
        return firstLine.length > 50 ? '${firstLine.substring(0, 50)}...' : firstLine;
      }
    }
    
    return '无标题';
  }
  
  /// 辅助方法：安全解析整数
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
  
  /// 辅助方法：两位数格式化
  static String _twoDigits(int n) => n.toString().padLeft(2, '0');
  
  Map<String, dynamic> toJson() => {
    'idCode': idCode,
    'title': title,
    'content': content,
    'createrName': createrName,
    'sendTime': sendTime,
    'isRead': isRead ? '1' : '0',
    'redDot': hasRedDot ? '0' : '1',
    'countAll': countAll,
    'countRead': countRead,
  };
  
  @override
  String toString() {
    return 'MessageModel(title: $title, sender: $createrName, time: $sendTime, read: $isRead)';
  }
}

/// 通知列表请求结果（支持分页）
class NoticeResult {
  final List<MessageModel> messages;
  final String? nextLastValue;
  final bool hasMore;

  NoticeResult({
    required this.messages,
    this.nextLastValue,
    this.hasMore = true,
  });
}

