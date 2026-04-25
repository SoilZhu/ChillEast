/// App 自定义异常基类
class AppException implements Exception {
  final String message;
  final String? code;
  
  const AppException(this.message, {this.code});
  
  @override
  String toString() => 'AppException: $message (code: $code)';
}

/// 认证异常
class AuthException extends AppException {
  const AuthException(super.message, {super.code});
}

/// 网络请求异常
class NetworkException extends AppException {
  const NetworkException(super.message, {super.code});
}

/// HTML 解析异常
class ParseException extends AppException {
  const ParseException(super.message, {super.code});
}

/// Cookie 管理异常
class CookieException extends AppException {
  const CookieException(super.message, {super.code});
}
