import 'package:flutter/material.dart';
import '../../../core/utils/route_utils.dart';
import '../../../core/utils/l10n_extension.dart';
import 'button_reorder_screen.dart';

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.appearanceSettings),
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
            icon: Icons.home_outlined,
            title: l10n.homeButtonsSetting,
            onTap: () {
              Navigator.push(
                context,
                createSlideUpRoute(ButtonReorderScreen(
                  title: l10n.homeButtonsTitle,
                  listType: 'home',
                )),
              );
            },
          ),
          _buildSettingItem(
            context,
            icon: Icons.grid_view_outlined,
            title: l10n.functionsButtonsSetting,
            onTap: () {
              Navigator.push(
                context,
                createSlideUpRoute(ButtonReorderScreen(
                  title: l10n.functionsButtonsTitle,
                  listType: 'functions',
                )),
              );
            },
          ),
          _buildSettingItem(
            context,
            icon: Icons.view_agenda_outlined,
            title: l10n.feedButtonsSetting,
            onTap: () {
              Navigator.push(
                context,
                createSlideUpRoute(ButtonReorderScreen(
                  title: l10n.feedButtonsTitle,
                  listType: 'feed',
                )),
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
