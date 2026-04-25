import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state/auth_state.dart';
import '../../../core/utils/route_utils.dart';
import '../../auth/screens/login_screen.dart';
import 'settings_screen.dart';
import 'about_screen.dart';
import 'help_feedback_screen.dart';



class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final isLoggedIn = authState.status == AuthStatus.authenticated;
    final isAuthenticating = authState.status == AuthStatus.authenticating;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: null,
        iconTheme: IconThemeData(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 用户信息区域
            _buildUserInfo(context, authState),
            
            const SizedBox(height: 20),
            
            // 设置项列表
            _buildListTile(
              context,
              icon: Icons.settings_outlined,
              title: '设置',
              onTap: () {
                Navigator.push(
                  context,
                  createSlideUpRoute(const SettingsScreen()),
                );
              },
            ),
            _buildListTile(
              context,
              icon: Icons.help_outline_rounded,
              title: '帮助与反馈',
              onTap: () {
                Navigator.push(
                  context,
                  createSlideUpRoute(const HelpFeedbackScreen()),
                );
              },
            ),
            _buildListTile(
              context,
              icon: Icons.info_outline_rounded,
              title: '关于',
              onTap: () {
                Navigator.push(
                  context,
                  createSlideUpRoute(const AboutScreen()),
                );
              },
            ),
            
            // 退出登录按钮 (作为列表项)
            if (isLoggedIn || isAuthenticating)
              _buildListTile(
                context,
                icon: Icons.logout_rounded,
                title: isAuthenticating ? '正在登录...' : '退出登录',
                titleColor: Colors.redAccent,
                iconColor: Colors.redAccent,
                onTap: isAuthenticating 
                    ? () {} 
                    : () => _handleLogout(context, ref),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfo(BuildContext context, AuthState authState) {
    final isLoggedIn = authState.status == AuthStatus.authenticated;
    
    ImageProvider? avatarImage;
    if (isLoggedIn && authState.avatarUrl != null) {
      if (authState.avatarUrl!.startsWith('http')) {
        avatarImage = NetworkImage(authState.avatarUrl!);
      } else {
        final file = File(authState.avatarUrl!);
        if (file.existsSync()) {
          avatarImage = FileImage(file);
        }
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      width: double.infinity,
      child: Row(
        children: [
          // 头像
          CircleAvatar(
            radius: 36,
            backgroundColor: const Color(0xFFF5F5F5),
            backgroundImage: avatarImage,
            child: avatarImage == null ? const Icon(
              Icons.person_rounded,
              size: 36,
              color: Color(0xFFBDBDBD),
            ) : null,
          ),
          const SizedBox(width: 20),
          // 姓名与学号
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLoggedIn ? (authState.realName ?? '湖南农大学子') : '未登录',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF202124),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isLoggedIn ? (authState.username ?? '') : '点击登录以访问更多功能',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          if (!isLoggedIn)
            IconButton(
              onPressed: () => _showLoginDialog(context),
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? titleColor,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 24, color: iconColor ?? const Color(0xFF5F6368)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: titleColor ?? (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF202124)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLoginDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const LoginScreen(),
    );
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), // MD2 风格圆角
        title: const Text(
          '确认退出',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '退出登录后将清除您的本地凭证并断开数据连接。',
          style: TextStyle(fontSize: 15, color: Color(0xFF5F6368), height: 1.5),
        ),
        actionsPadding: const EdgeInsets.only(right: 12, bottom: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF5F6368),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('取消', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('确认', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authStateProvider.notifier).logout();
    }
  }
}
