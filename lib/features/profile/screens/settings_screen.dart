import 'package:flutter/material.dart';
import '../../../core/utils/route_utils.dart';
import 'notification_settings_screen.dart';
import 'appearance_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF202124),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      body: ListView(
        children: [
          _buildSettingItem(
            context,
            icon: Icons.palette_outlined,
            title: '外观设置',
            onTap: () {
              Navigator.push(
                context,
                createSlideUpRoute(const AppearanceSettingsScreen()),
              );
            },
          ),
          _buildSettingItem(
            context,
            icon: Icons.notifications_none_rounded,
            title: '通知设置',
            onTap: () {
              Navigator.push(
                context,
                createSlideUpRoute(const NotificationSettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 24, color: const Color(0xFF5F6368)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: isDark ? Colors.white : const Color(0xFF202124),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
