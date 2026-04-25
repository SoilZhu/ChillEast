import 'package:flutter/material.dart';
import '../../../core/utils/route_utils.dart';
import '../../../core/services/update_service.dart';
import 'oss_licenses_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const String version = '1.0.0';
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo - 圆角矩形 + 固定大小 (80x80)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: const DecorationImage(
                    image: AssetImage('assets/images/logo.png'),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // 应用名称
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                '自在东湖',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF202124),
                  letterSpacing: -0.5,
                ),
              ),
            ),
            
            // 版本号
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                'Version $version',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  letterSpacing: 0.2,
                ),
              ),
            ),
            
            const SizedBox(height: 48),
            
            // 列表项 - 无分割线，涟漪延伸到两侧
            _buildAboutItem(
              context,
              title: '检查更新',
              onTap: () => UpdateService().checkUpdate(context, showNoUpdate: true),
            ),
            _buildAboutItem(
              context,
              title: '开源声明',
              onTap: () {
                Navigator.push(
                  context,
                  createSlideUpRoute(const OssLicensesScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutItem(BuildContext context, {required String title, required VoidCallback onTap}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: isDark ? Colors.white.withOpacity(0.9) : const Color(0xFF202124),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
