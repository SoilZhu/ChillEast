import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/state/locale_provider.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/route_utils.dart';
import '../../../core/widgets/embedded_detail_pane.dart';
import 'notification_settings_screen.dart';
import 'appearance_settings_screen.dart';
import 'button_reorder_screen.dart';
import 'ai_settings_screen.dart';
import 'data_sync_settings_screen.dart';
import 'language_settings_screen.dart';
import 'timetable_settings_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Widget? _embeddedScreen;
  String? _selectedSettingKey;
  bool _isTransitioningToRoute = false;

  void _safeNavigate(
    BuildContext context,
    Widget screen, {
    required String key,
    required bool isLargeScreen,
  }) {
    if (isLargeScreen) {
      if (_selectedSettingKey == key && _embeddedScreen != null) {
        return;
      }
      setState(() {
        _embeddedScreen = screen;
        _selectedSettingKey = key;
      });
    } else {
      Navigator.push(
        context,
        createSlideHorizontalRoute(screen),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth >= 600;

        // 当窗口宽度变窄不足以分屏，但当前有嵌入展示的子设置页时，
        // 自动清空嵌入状态并作为纯正全屏路由推入 Navigator，平滑降级
        if (!isLargeScreen &&
            _embeddedScreen != null &&
            !_isTransitioningToRoute) {
          _isTransitioningToRoute = true;
          final screenToOpen = _embeddedScreen!;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _embeddedScreen = null;
              _selectedSettingKey = null;
              _isTransitioningToRoute = false;
            });
            Navigator.of(context).push(
              createSlideHorizontalRoute(screenToOpen),
            );
          });
        }

        final masterContent =
            _buildMaster(context, isLargeScreen: isLargeScreen);

        if (isLargeScreen && _embeddedScreen != null) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              setState(() {
                _embeddedScreen = null;
                _selectedSettingKey = null;
              });
            },
            child: Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: masterContent,
                  ),
                  VerticalDivider(
                    width: 1,
                    thickness: 0.5,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0x1A000000),
                  ),
                  Expanded(
                    flex: 1,
                    child: EmbeddedDetailPane(
                      key: ValueKey(
                          _selectedSettingKey ?? _embeddedScreen.runtimeType),
                      onClose: () {
                        setState(() {
                          _embeddedScreen = null;
                          _selectedSettingKey = null;
                        });
                      },
                      child: _embeddedScreen!,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return masterContent;
      },
    );
  }

  Widget _buildMaster(BuildContext context, {required bool isLargeScreen}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final currentLocale = ref.watch(localeProvider);

    final currentCode = LocaleNotifier.localeToCode(currentLocale);
    final currentOption = LocaleNotifier.supportedLanguages.firstWhere(
      (opt) => opt.code == currentCode,
      orElse: () => LocaleNotifier.supportedLanguages.first,
    );
    final currentLanguageLabel = currentOption.getLocalizedName(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.settings),
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
        padding: isLargeScreen
            ? const EdgeInsets.symmetric(vertical: 8)
            : EdgeInsets.zero,
        children: [
          _buildSettingItem(
            context,
            icon: Icons.language_rounded,
            title: l10n.language,
            isSelected: isLargeScreen && _selectedSettingKey == 'language',
            isLargeScreen: isLargeScreen,
            trailing: Text(
              currentLanguageLabel,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : const Color(0xFF5F6368),
              ),
            ),
            onTap: () => _safeNavigate(
              context,
              const LanguageSettingsScreen(),
              key: 'language',
              isLargeScreen: isLargeScreen,
            ),
          ),
          _buildSettingItem(
            context,
            icon: Icons.code_rounded,
            title: l10n.agentSettings,
            isSelected: isLargeScreen && _selectedSettingKey == 'agent',
            isLargeScreen: isLargeScreen,
            onTap: () => _safeNavigate(
              context,
              const AiSettingsScreen(),
              key: 'agent',
              isLargeScreen: isLargeScreen,
            ),
          ),
          _buildSettingItem(
            context,
            icon: Icons.palette_outlined,
            title: l10n.appearanceSettings,
            isSelected: isLargeScreen && _selectedSettingKey == 'appearance',
            isLargeScreen: isLargeScreen,
            onTap: () => _safeNavigate(
              context,
              const AppearanceSettingsScreen(),
              key: 'appearance',
              isLargeScreen: isLargeScreen,
            ),
          ),
          _buildSettingItem(
            context,
            icon: Icons.widgets_outlined,
            title: l10n.widgetSettings,
            isSelected: isLargeScreen && _selectedSettingKey == 'widget',
            isLargeScreen: isLargeScreen,
            onTap: () => _safeNavigate(
              context,
              ButtonReorderScreen(
                title: l10n.widgetSettings,
                listType: 'widget',
              ),
              key: 'widget',
              isLargeScreen: isLargeScreen,
            ),
          ),
          _buildSettingItem(
            context,
            icon: Icons.notifications_none_rounded,
            title: l10n.notificationSettings,
            isSelected: isLargeScreen && _selectedSettingKey == 'notification',
            isLargeScreen: isLargeScreen,
            onTap: () => _safeNavigate(
              context,
              const NotificationSettingsScreen(),
              key: 'notification',
              isLargeScreen: isLargeScreen,
            ),
          ),
          _buildSettingItem(
            context,
            icon: Icons.calendar_month_outlined,
            title: l10n.timetableSettings,
            isSelected: isLargeScreen && _selectedSettingKey == 'timetable',
            isLargeScreen: isLargeScreen,
            onTap: () => _safeNavigate(
              context,
              const TimetableSettingsScreen(),
              key: 'timetable',
              isLargeScreen: isLargeScreen,
            ),
          ),
          _buildSettingItem(
            context,
            icon: Icons.sync_rounded,
            title: l10n.dataSyncSettings,
            isSelected: isLargeScreen && _selectedSettingKey == 'data_sync',
            isLargeScreen: isLargeScreen,
            onTap: () => _safeNavigate(
              context,
              const DataSyncSettingsScreen(),
              key: 'data_sync',
              isLargeScreen: isLargeScreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    bool showChevron = true,
    bool isSelected = false,
    bool isLargeScreen = false,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final itemWidget = Padding(
      padding: isLargeScreen
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 2)
          : EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : const Color(0xFFEBEBEB))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Icon(icon, size: 24, color: const Color(0xFF5F6368)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                            color:
                                isDark ? Colors.white : const Color(0xFF202124),
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white54
                                  : const Color(0xFF9E9E9E),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    trailing,
                    const SizedBox(width: 4),
                  ],
                  if (showChevron)
                    ExcludeSemantics(
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: isSelected
                            ? (isDark
                                ? Colors.white70
                                : const Color(0xFF5F6368))
                            : const Color(0xFF9E9E9E),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: isLargeScreen ? isSelected : null,
        child: itemWidget,
      ),
    );
  }
}
