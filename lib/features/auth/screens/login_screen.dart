import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state/auth_state.dart';
import '../providers/auth_provider.dart';
import '../../../core/utils/secure_storage_helper.dart';
import '../../timetable/screens/timetable_sync_prompt_screen.dart';
import 'package:logger/logger.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final VoidCallback? onClose;
  const LoginScreen({super.key, this.onClose});

  /// 带有下往上淡入动画的路由
  static Route route() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 0.1); 
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);
        
        var fadeTween = Tween<double>(begin: 0.0, end: 1.0);
        var fadeAnimation = animation.drive(fadeTween);

        return FadeTransition(
          opacity: fadeAnimation,
          child: SlideTransition(
            position: offsetAnimation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final Logger _logger = Logger();
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  
  @override
  void initState() {
    super.initState();
    _loadStoredCredentials();
  }

  Future<void> _loadStoredCredentials() async {
    try {
      final storage = SecureStorageHelper();
      final username = await storage.getUsername();
      final password = await storage.getPassword();
      
      if (mounted && username != null && password != null) {
        setState(() {
          _usernameController.text = username;
          _passwordController.text = password;
        });
      }
    } catch (e) {
      _logger.e('Failed to load stored credentials: $e');
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final theme = Theme.of(context);

    // 标准 MD2 输入框装饰样式
    InputDecoration md2InputDecoration(String label, IconData icon) => InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF5F6368), 
        fontWeight: FontWeight.w400, 
        fontSize: 14
      ),
      floatingLabelStyle: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 16),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      prefixIcon: Icon(icon, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : const Color(0xFFDADCE0), 
          width: 1
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : const Color(0xFFDADCE0), 
          width: 1
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: theme.primaryColor, width: 2),
      ),
      filled: true,
      fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.white,
    );

    final isAuthenticating = authState.status == AuthStatus.authenticating;

    return PopScope(
      canPop: !isAuthenticating,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          surfaceTintColor: Theme.of(context).scaffoldBackgroundColor,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: Icon(
              Icons.close, 
              color: isAuthenticating 
                  ? (Theme.of(context).brightness == Brightness.dark ? Colors.grey[700] : Colors.grey[300]) 
                  : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF5F6368))
            ),
            onPressed: isAuthenticating ? null : () {
              if (widget.onClose != null) {
                widget.onClose!();
              } else {
                Navigator.pop(context);
              }
            },
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Text(
                  '登录',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF202124),
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 12),
                Text(
                  '请登录以继续。',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF5F6368),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.left,
                ),
              const SizedBox(height: 48),
              
              // 用户名输入框
              TextFormField(
                controller: _usernameController,
                decoration: md2InputDecoration('学号', Icons.person_outline),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return '请输入学号';
                  return null;
                },
                enabled: authState.status != AuthStatus.authenticating,
              ),
              const SizedBox(height: 24),
              
              // 密码输入框
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: md2InputDecoration('密码', Icons.lock_outline).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return '请输入密码';
                  return null;
                },
                enabled: authState.status != AuthStatus.authenticating,
              ),
              
              const SizedBox(height: 12),
              if (authState.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    authState.errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              
              const SizedBox(height: 40),
              
              // 登录按钮 (缩小并右对齐)
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (authState.status == AuthStatus.authenticating)
                      const Padding(
                        padding: EdgeInsets.only(right: 16),
                        child: SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ElevatedButton.icon(
                      onPressed: authState.status == AuthStatus.authenticating ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: theme.primaryColor.withOpacity(0.12),
                        disabledForegroundColor: theme.primaryColor.withOpacity(0.38),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        minimumSize: const Size(88, 36), // MD2 标准紧凑型按钮高度
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.login_rounded, size: 18),
                      label: const Text(
                        '登录',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
  
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    
    try {
      await ref.read(authStateProvider.notifier).login(username, password);
      
      // 登录成功后，如果是推入式路由则关闭当前页
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } catch (e) {
      // 错误已由 authStateProvider 处理
    }
  }
}
