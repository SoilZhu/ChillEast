import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/exceptions/app_exceptions.dart';
import '../../../core/network/cookie_manager.dart';
import '../../../core/utils/secure_storage_helper.dart';
import '../models/message_model.dart';
import 'package:logger/logger.dart';

class NoticeService {
  final Logger _logger = Logger();
  
  /// 获取通知列表 (超星原生方案 - 稳定版)
  /// [lastValue] 为分页标记，第一页传空，后续传上一页返回的 lastGetId
  Future<NoticeResult> fetchMessageList({String? lastValue}) async {
    try {
      _logger.i('📨 Fetching notices from Chaoxing (lastValue: $lastValue)...');
      
      // 按照抓包数据，使用 POST 请求和 Form 表单格式
      final response = await DioClient().dio.post(
        AppConstants.chaoxingNoticeListUrl,
        data: {
          'type': 2,                         
          'notice_type': '',
          'lastValue': lastValue ?? '',      
          'sort': '',
          'folderUUID': '',
          'kw': '',
          'startTime': '',
          'endTime': '',
          'gKw': '',
          'gName': '',
          'year': DateTime.now().year,       
          'tag': '',
          'fidsCode': '',
          'queryFolderNoticePrevYear': 0,
          'filterSenderPuids': '',
          'filterTags': '',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'X-Requested-With': 'XMLHttpRequest',
            'Referer': 'https://notice.chaoxing.com/pc/notice/myNotice',
          },
        ),
      );
      
      if (response.statusCode != 200) {
        throw NetworkException('获取通知列表失败: HTTP ${response.statusCode}');
      }
      
      final data = response.data as Map<String, dynamic>;
      
      // 适配超星实际返回的结构: {"notices": {"list": [...]}}
      final notices = data['notices'] as Map<String, dynamic>?;
      
      if (notices == null) {
        final errorMsg = data['errorMsg']?.toString();
        if (errorMsg != null) {
          _logger.e('Chaoxing API Error: $errorMsg');
          throw NetworkException('API 返回错误: $errorMsg');
        }
        _logger.w('No notices field found in Chaoxing response');
        return NoticeResult(messages: [], hasMore: false);
      }
      
      final list = notices['list'] as List<dynamic>?;
      if (list == null || list.isEmpty) {
        _logger.i('No messages found in Chaoxing notice list');
        return NoticeResult(messages: [], hasMore: false);
      }
      
      // ✨ 提取翻页标记
      final nextLastValue = notices['lastGetId']?.toString();
      
      // 使用之前定义的 fromChaoxingJson 进行解析
      final messages = list
          .map((item) => MessageModel.fromChaoxingJson(item as Map<String, dynamic>))
          .toList();
      
      _logger.i('✅ Successfully fetched ${messages.length} messages, next lastValue: $nextLastValue');
      
      return NoticeResult(
        messages: messages,
        nextLastValue: nextLastValue,
        hasMore: nextLastValue != null && nextLastValue.isNotEmpty,
      );
    } on DioException catch (e) {
      _logger.e('❌ Dio error fetching notices from Chaoxing: ${e.message}');
      if (e.response?.statusCode == 401) {
        throw const NetworkException('登录状态失效,请在个人中心重新登录');
      }
      throw NetworkException('网络请求失败: ${e.message}');
    } catch (e) {
      _logger.e('❌ Unexpected error fetching notices: $e');
      if (e is AppException) rethrow;
      throw ParseException('解析通知列表失败: ${e.toString()}');
    }
  }

  /// 内部方法：(已弃用) 确保融合门户会话就绪
  /// 保留空方法以兼容现有调用结构，但不执行任何操作
  Future<void> _ensureSessionReady() async {}
  
  /// 获取未读消息数量
  Future<int> getUnreadCount(List<MessageModel> messages) async {
    return messages.where((msg) => !msg.isRead).length;
  }

  /// 获取通知详情 (直接拉取数据方案)
  Future<Map<String, dynamic>> fetchNoticeDetail(String uuid) async {
    try {
      final url = '${AppConstants.chaoxingNoticeBaseUrl}/pc/notice/$uuid/getNoticeDetail?sendTag=0';
      
      // ✨ 审计日志：输出完整的请求细节
      _logger.i('🌐 HTTP GET: $url');
      
      // 获取当前将要发送的 Cookie 以便日志记录
      final uri = Uri.parse(url);
      final cookies = await AppCookieManager().dioCookieJar.loadForRequest(uri);
      final cookieString = cookies.map((c) => '${c.name}=${c.value}').join('; ');
      _logger.d('🍪 Auth Cookies: $cookieString');

      final response = await DioClient().dio.get(url);
      
      if (response.statusCode != 200) {
        throw NetworkException('获取通知详情失败: HTTP ${response.statusCode}');
      }
      
      final data = response.data as Map<String, dynamic>;
      
      if (data['status'] != true) {
        throw NetworkException('API 返回详情加载失败');
      }
      
      final msg = data['msg'] as Map<String, dynamic>?;
      if (msg == null) {
        throw NetworkException('详情数据位空');
      }
      
      return msg;
    } on DioException catch (e) {
      _logger.e('❌ Dio error fetching notice detail: ${e.message}');
      throw NetworkException('获取详情失败: ${e.message}');
    } catch (e) {
      _logger.e('❌ Unexpected error fetching detail: $e');
      rethrow;
    }
  }

  /// 标记通知为已读
  Future<void> setNoticeRead(String noticeId) async {
    try {
      final url = '${AppConstants.chaoxingNoticeBaseUrl}/mobile/notice/setNoticeRead?noticeId=$noticeId';
      _logger.i('标记已读: $url');
      
      final response = await DioClient().dio.get(url);
      
      if (response.statusCode == 200) {
        _logger.i('✅ Successfully marked notice $noticeId as read');
      }
    } catch (e) {
      _logger.e('❌ Failed to mark notice as read: $e');
    }
  }
}

