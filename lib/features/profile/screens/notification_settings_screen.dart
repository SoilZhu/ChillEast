import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    
    final courseDurations = [
      {'label': '不通知', 'value': 0},
      {'label': '5分钟前', 'value': 5},
      {'label': '10分钟前', 'value': 10},
      {'label': '20分钟前', 'value': 20},
      {'label': '30分钟前', 'value': 30},
      {'label': '40分钟前', 'value': 40},
      {'label': '50分钟前', 'value': 50},
      {'label': '60分钟前', 'value': 60},
    ];

    final homeworkDurations = [
      {'label': '不通知', 'value': 0.0},
      {'label': '0.5小时前', 'value': 0.5},
      {'label': '1小时前', 'value': 1.0},
      {'label': '2小时前', 'value': 2.0},
      {'label': '6小时前', 'value': 6.0},
      {'label': '12小时前', 'value': 12.0},
      {'label': '24小时前', 'value': 24.0},
      {'label': '48小时前', 'value': 48.0},
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('通知设置'),
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
            icon: Icons.book_outlined,
            title: '上课提醒',
            subtitle: courseDurations.firstWhere((e) => e['value'] == settings.reminderMinutes, orElse: () => courseDurations[0])['label'] as String,
            onTap: () => _showPicker(
              context, 
              title: '上课提醒时间',
              options: courseDurations,
              currentValue: settings.reminderMinutes,
              onSelected: (val) => ref.read(settingsProvider.notifier).setReminderMinutes(val as int),
            ),
          ),
          _buildSettingItem(
            context,
            icon: Icons.assignment_outlined,
            title: '作业截止提醒',
            subtitle: homeworkDurations.firstWhere((e) => (e['value'] as double) == settings.homeworkReminderHours, orElse: () => homeworkDurations[0])['label'] as String,
            onTap: () => _showPicker(
              context, 
              title: '作业提醒时间',
              options: homeworkDurations,
              currentValue: settings.homeworkReminderHours,
              onSelected: (val) => ref.read(settingsProvider.notifier).setHomeworkReminderHours(val as double),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(BuildContext context, {
    required IconData icon, 
    required String title, 
    required String subtitle,
    required VoidCallback onTap
  }) {
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: isDark ? Colors.white : const Color(0xFF202124),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context, {
    required String title,
    required List<Map<String, dynamic>> options,
    required dynamic currentValue,
    required Function(dynamic) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final opt = options[index];
                    final isSelected = opt['value'] == currentValue;
                    return ListTile(
                      title: Text(opt['label']),
                      trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF09C489)) : null,
                      onTap: () {
                        onSelected(opt['value']);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('已设置为: ${opt['label']}'),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
