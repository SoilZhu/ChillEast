import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';
import '../exceptions/app_exceptions.dart';
import 'package:logger/logger.dart';

/// 安全存储工具类
class SecureStorageHelper {
  static final SecureStorageHelper _instance = SecureStorageHelper._internal();
  factory SecureStorageHelper() => _instance;
  
  SecureStorageHelper._internal();
  
  final Logger _logger = Logger();
  late final FlutterSecureStorage _storage;
  bool _initialized = false;
  
  /// 初始化
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(
          encryptedSharedPreferences: true,
        ),
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      );
      _initialized = true;
      _logger.i('SecureStorageHelper initialized');
    } catch (e) {
      _logger.e('Failed to initialize SecureStorageHelper: $e');
      throw AuthException('安全存储初始化失败: $e');
    }
  }
  
  /// 保存用户名
  Future<void> saveUsername(String username) async {
    if (!_initialized) await initialize();
    try {
      await _storage.write(key: AppConstants.storageUsernameKey, value: username);
      _logger.d('Username saved');
    } catch (e) {
      _logger.e('Failed to save username: $e');
      throw AuthException('保存用户名失败: $e');
    }
  }
  
  /// 保存密码
  Future<void> savePassword(String password) async {
    if (!_initialized) await initialize();
    try {
      await _storage.write(key: AppConstants.storagePasswordKey, value: password);
      _logger.d('Password saved');
    } catch (e) {
      _logger.e('Failed to save password: $e');
      throw AuthException('保存密码失败: $e');
    }
  }
  
  /// 获取用户名
  Future<String?> getUsername() async {
    if (!_initialized) await initialize();
    try {
      return await _storage.read(key: AppConstants.storageUsernameKey);
    } catch (e) {
      _logger.e('Failed to read username: $e');
      return null;
    }
  }
  
  /// 获取密码
  Future<String?> getPassword() async {
    if (!_initialized) await initialize();
    try {
      return await _storage.read(key: AppConstants.storagePasswordKey);
    } catch (e) {
      _logger.e('Failed to read password: $e');
      return null;
    }
  }
  
  /// 清除凭证
  Future<void> clearCredentials() async {
    if (!_initialized) await initialize();
    try {
      await _storage.delete(key: AppConstants.storageUsernameKey);
      await _storage.delete(key: AppConstants.storagePasswordKey);
      _logger.i('Credentials cleared');
    } catch (e) {
      _logger.e('Failed to clear credentials: $e');
      throw AuthException('清除凭证失败: $e');
    }
  }
  
  /// 保存 Token
  Future<void> saveToken(String token) async {
    if (!_initialized) await initialize();
    try {
      await _storage.write(key: AppConstants.storageTokenKey, value: token);
      _logger.d('Token saved');
    } catch (e) {
      _logger.e('Failed to save token: $e');
      throw AuthException('保存 Token 失败: $e');
    }
  }
  
  /// 获取 Token
  Future<String?> getToken() async {
    if (!_initialized) await initialize();
    try {
      return await _storage.read(key: AppConstants.storageTokenKey);
    } catch (e) {
      _logger.e('Failed to read token: $e');
      return null;
    }
  }

  /// 保存 TRS 相关 Cookie (追踪 session)
  Future<void> saveTrsCookies({String? uv, String? ua}) async {
    if (!_initialized) await initialize();
    try {
      if (uv != null) await _storage.write(key: 'trs_uv', value: uv);
      if (ua != null) await _storage.write(key: 'trs_ua', value: ua);
      _logger.d('TRS cookies saved to secure storage');
    } catch (e) {
      _logger.e('Failed to save TRS cookies: $e');
    }
  }

  /// 获取 TRS 相关 Cookie
  Future<Map<String, String?>> getTrsCookies() async {
    if (!_initialized) await initialize();
    try {
      final uv = await _storage.read(key: 'trs_uv');
      final ua = await _storage.read(key: 'trs_ua');
      return {'uv': uv, 'ua': ua};
    } catch (e) {
      _logger.e('Failed to read TRS cookies: $e');
      return {};
    }
  }

  /// 保存个人资料信息
  Future<void> saveProfileInfo({
    required String realName,
    required String uid,
    String? avatarUrl,
  }) async {
    if (!_initialized) await initialize();
    try {
      await _storage.write(key: 'profile_real_name', value: realName);
      await _storage.write(key: 'profile_uid', value: uid);
      if (avatarUrl != null) {
        await _storage.write(key: 'profile_avatar_url', value: avatarUrl);
      }
      _logger.d('Profile info saved');
    } catch (e) {
      _logger.e('Failed to save profile info: $e');
    }
  }

  /// 获取个人资料信息
  Future<Map<String, String?>> getProfileInfo() async {
    if (!_initialized) await initialize();
    try {
      final realName = await _storage.read(key: 'profile_real_name');
      final uid = await _storage.read(key: 'profile_uid');
      final avatarUrl = await _storage.read(key: 'profile_avatar_url');
      return {
        'realName': realName,
        'uid': uid,
        'avatarUrl': avatarUrl,
      };
    } catch (e) {
      _logger.e('Failed to read profile info: $e');
      return {};
    }
  }

  /// 清除个人资料信息
  Future<void> clearProfileInfo() async {
    if (!_initialized) await initialize();
    try {
      await _storage.delete(key: 'profile_real_name');
      await _storage.delete(key: 'profile_uid');
      await _storage.delete(key: 'profile_avatar_url');
      _logger.d('Profile info cleared');
    } catch (e) {
      _logger.e('Failed to clear profile info: $e');
    }
  }

  /// 清除所有保存的数据 (用户名、密码、Token、个人资料)
  Future<void> clearAll() async {
    if (!_initialized) await initialize();
    try {
      await _storage.delete(key: AppConstants.storageUsernameKey);
      await _storage.delete(key: AppConstants.storagePasswordKey);
      await _storage.delete(key: AppConstants.storageTokenKey);
      await _storage.delete(key: 'trs_uv');
      await _storage.delete(key: 'trs_ua');
      await clearProfileInfo();
      _logger.i('✅ All secure storage data cleared');
    } catch (e) {
      _logger.e('Failed to clear all storage: $e');
    }
  }

  /// 检查是否有保存的凭证
  Future<bool> hasCredentials() async {
    final username = await getUsername();
    final password = await getPassword();
    return username != null && username.isNotEmpty && 
           password != null && password.isNotEmpty;
  }
}
