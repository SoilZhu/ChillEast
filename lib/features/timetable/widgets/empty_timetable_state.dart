import 'package:flutter/material.dart';

/// 课表空状态组件
class EmptyTimetableState extends StatelessWidget {
  const EmptyTimetableState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_today_outlined,
                size: 64,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              '课表正在同步中',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF202124),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '系统正在为您全自动拉取教务课表\n请稍等片刻...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF5F6368),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }
}
