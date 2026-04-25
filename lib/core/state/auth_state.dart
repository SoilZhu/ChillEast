import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../utils/secure_storage_helper.dart';
import '../network/cookie_manager.dart';
import '../../features/homework/providers/homework_provider.dart';
import '../../features/notice/providers/notice_provider.dart';
import '../../features/timetable/services/timetable_storage.dart';
import '../../features/workspace/services/campus_card_service.dart';
import 'package:logger/logger.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

/// 认证状态枚举
enum AuthStatus {
  unauthenticated,  // 未登录
  authenticating,   // 正在登录
  authenticated,    // 已登录
}

/// 认证状态模型
class AuthState {
  final AuthStatus status;
  final String? errorMessage;
  final String? username;
  final String? realName;
  final String? uid;
  final String? avatarUrl;
  final bool isGuestMode;
  final bool isInitialized;
  final bool needsTimetablePrompt;

  const AuthState({
    required this.status,
    this.errorMessage,
    this.username,
    this.realName,
    this.uid,
    this.avatarUrl,
    this.isGuestMode = false,
    this.isInitialized = false,
    this.needsTimetablePrompt = false,
  });
  
  /// 初始状态 - 未登录
  const AuthState.initial() : this(status: AuthStatus.unauthenticated, isGuestMode: false, isInitialized: true, needsTimetablePrompt: false);
  
  /// 正在登录状态
  const AuthState.authenticating() : this(status: AuthStatus.authenticating, isGuestMode: false, isInitialized: false, needsTimetablePrompt: false);
  
  /// 已登录状态
  const AuthState.authenticated({
    String? username,
    String? realName,
    String? uid,
    String? avatarUrl,
  }) : this(
    status: AuthStatus.authenticated, 
    username: username,
    realName: realName,
    uid: uid,
    avatarUrl: avatarUrl,
  );
  
  /// 登录失败状态
  const AuthState.error(String message) 
      : this(status: AuthStatus.unauthenticated, errorMessage: message);
  
  /// 复制并修改状态
  AuthState copyWith({
    AuthStatus? status,
    String? errorMessage,
    String? username,
    String? realName,
    String? uid,
    String? avatarUrl,
    bool? isGuestMode,
    bool? isInitialized,
    bool? needsTimetablePrompt,
  }) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      username: username ?? this.username,
      realName: realName ?? this.realName,
      uid: uid ?? this.uid,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isGuestMode: isGuestMode ?? this.isGuestMode,
      isInitialized: isInitialized ?? this.isInitialized,
      needsTimetablePrompt: needsTimetablePrompt ?? this.needsTimetablePrompt,
    );
  }
  
  @override
  String toString() => 'AuthState(status: $status, errorMessage: $errorMessage, username: $username, realName: $realName, uid: $uid, avatarUrl: $avatarUrl)';
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          errorMessage == other.errorMessage &&
          username == other.username &&
          realName == other.realName &&
          uid == other.uid &&
          avatarUrl == other.avatarUrl;
  
  @override
  int get hashCode => 
      status.hashCode ^ 
      errorMessage.hashCode ^ 
      username.hashCode ^ 
      realName.hashCode ^ 
      uid.hashCode ^ 
      avatarUrl.hashCode;

  /// 是否有本地保存的账号信息
  bool get hasAccount => username != null && username!.isNotEmpty;
}

/// AuthState Provider
final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

/// AuthNotifier - 管理认证状态
class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  final _logger = Logger();

  AuthNotifier(this._ref) : super(const AuthState.authenticating()) {
    // 创建 Provider 时立即触发检查
    Future.microtask(() => checkAuthStatus());
  }

  Future<void> checkAuthStatus() async {
    _logger.i('🔍 Initializing auth status...');
    
    // 1. 仅清除旧 Cookie，不清除保存的用户名密码
    await AppCookieManager().clearSsoCookies();

    // 2. 读取凭据和缓存的资料
    final storage = SecureStorageHelper();
    final hasCreds = await storage.hasCredentials();
    final profile = await storage.getProfileInfo();
    final username = await storage.getUsername();

    if (!hasCreds) {
      _logger.i('👋 No credentials found, stay unauthenticated');
      state = const AuthState.initial().copyWith(isInitialized: true);
      FlutterNativeSplash.remove();
      return;
    }

    // 🚀 优化：先读取资料完成初始化，展示 UI，不要在白屏等登录结果
    state = AuthState.authenticated(
      username: username,
      realName: profile['realName'],
      uid: profile['uid'],
      avatarUrl: profile['avatarUrl'],
    ).copyWith(isInitialized: true);
    _logger.i('📱 Profile restored, marked as initialized');
    FlutterNativeSplash.remove();
    
    // 3. 异步尝试自动登录 (不影响/阻塞初始化状态)
    try {
      state = state.copyWith(status: AuthStatus.authenticating);
      await _ref.read(authServiceProvider).silentLogin();
      
      _logger.i('✅ Auto-login success, refreshing info...');
      state = state.copyWith(status: AuthStatus.authenticated);

      // ✨ 在登录成功的第一时间发起作业和通知同步
      if (username != null) {
        Future.microtask(() {
          _ref.read(homeworkProvider.notifier).refresh(username);
          _ref.read(noticeProvider.notifier).refresh();
        });
      }
      
      // 资料刷新可以异步进行
      _refreshUserInfo();
      
      // ✨ 校园卡静默授权
      Future.microtask(() => _ref.read(campusCardServiceProvider).authenticate());
      
    } catch (e) {
      _logger.e('❌ Auto-login failed: $e');
      
      // 4. 失败处理 - 保持已有资料，仅更新状态和错误信息
      String errorMsg = '登录异常: $e';
      if (e.toString().contains('AuthException') || e.toString().contains('Unauthorized') || e.toString().contains('密码错误')) {
        _logger.w('Credentials invalid, clearing storage');
        errorMsg = '凭据已失效，请重新登录';
      } else if (e.toString().contains('TimeoutException') || e.toString().contains('timeout')) {
        _logger.w('Auto-login timeout');
        errorMsg = '登录超时(网速慢)，请尝试手动刷新';
      }

      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: errorMsg,
        isInitialized: true,
      );
    }
  }

  /// 刷新用户资料
  Future<void> _refreshUserInfo() async {
    try {
      final info = await _ref.read(authServiceProvider).fetchFullUserInfo();
      if (info.isNotEmpty) {
        final realName = info['realName'];
        final username = info['username'];
        final uid = info['uid'];
        final avatarUrl = info['avatarUrl'];
        
        // 更新状态
        state = state.copyWith(
          username: username,
          realName: realName,
          uid: uid,
          avatarUrl: avatarUrl,
        );
        
        // 持久化到本地
        if (realName != null && uid != null) {
          await SecureStorageHelper().saveProfileInfo(
            realName: realName,
            uid: uid,
            avatarUrl: avatarUrl,
          );
        }
      }
    } catch (e) {
      _logger.w('⚠️ Refresh user info failed: $e');
    }
  }

  /// 退出登录
  Future<void> logout() async {
    await _ref.read(authServiceProvider).logout();
    _ref.read(noticeProvider.notifier).clear();
    
    // 退出登录时删除本地课表数据
    final storage = TimetableStorage();
    await storage.deleteTimetable();
    await storage.deleteMetadata();
    
    // 退出登录时删除本地作业数据
    await _ref.read(homeworkProvider.notifier).clearAll();
    
    state = const AuthState.initial();
  }

  /// 设置状态为正在登录
  void setAuthenticating() {
    state = const AuthState.authenticating();
  }
  
  /// 设置状态为已登录并保存凭据 (由 LoginScreen 调用)
  Future<void> login(String username, String password) async {
    try {
      state = state.copyWith(status: AuthStatus.authenticating);
      await _ref.read(authServiceProvider).login(username, password);
      
      // 检查是否有本地课表
      final hasTimetable = await TimetableStorage().hasLocalTimetable();
      
      // 手动登录成功且没有本地课表，标记为需要弹出课表提示
      state = AuthState.authenticated(username: username).copyWith(
        needsTimetablePrompt: !hasTimetable,
        isInitialized: true,
      );
      
      // ✨ 登录成功的第一时间发起作业和通知同步
      Future.microtask(() {
        _ref.read(homeworkProvider.notifier).refresh(username);
        _ref.read(noticeProvider.notifier).refresh();
      });
      
      // 登录成功后刷新资料 (后台异步执行，不阻塞跳转)
      _refreshUserInfo();

      // ✨ 校园卡静默授权
      Future.microtask(() => _ref.read(campusCardServiceProvider).authenticate());
    } catch (e) {
      state = AuthState.error(e.toString());
      rethrow;
    }
  }

  /// 设置状态为已登录
  void setAuthenticated() {
    state = state.copyWith(status: AuthStatus.authenticated);
  }
  
  /// 设置状态为未登录(带错误信息)
  void setUnauthenticated([String? errorMessage]) {
    state = errorMessage != null 
        ? AuthState.error(errorMessage)
        : const AuthState.initial();
  }
  
  /// 清除错误信息
  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(errorMessage: null);
    }
  }

  /// 进入访客模式 (跳过登录)
  void enterGuestMode() {
    state = state.copyWith(isGuestMode: true);
  }

  /// 完成/关闭课表同步提示
  void completeTimetablePrompt() {
    state = state.copyWith(needsTimetablePrompt: false);
  }
}
