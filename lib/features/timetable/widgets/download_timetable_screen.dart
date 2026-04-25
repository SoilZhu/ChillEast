import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/state/auth_state.dart';
import '../../auth/screens/login_screen.dart';
import '../services/timetable_service.dart';
import '../../profile/providers/settings_provider.dart';

/// 导入课表页面
class DownloadTimetableScreen extends ConsumerStatefulWidget {
  const DownloadTimetableScreen({super.key});

  @override
  ConsumerState<DownloadTimetableScreen> createState() => _DownloadTimetableScreenState();
}

class _DownloadTimetableScreenState extends ConsumerState<DownloadTimetableScreen> {
  final TimetableService _timetableService = TimetableService();
  
  String? _selectedSemester;
  DateTime? _selectedDate;
  bool _isLoading = false;
  
  late final List<String> _semesters;

  @override
  void initState() {
    super.initState();
    _semesters = _generateSemesters();
    if (_semesters.isNotEmpty) {
      _selectedSemester = _semesters.first;
    }
  }

  List<String> _generateSemesters() {
    final now = DateTime.now();
    final x = now.year;
    final List<String> list = [];
    
    // 如果是 1-6 月，最新学期是 (x-1)-x-2
    // 如果是 7-12 月，最新学期是 x-(x+1)-1
    if (now.month <= 6) {
      // 从 (x-1)-x-2 开始往前推
      int startYear = x - 1;
      for (int i = 0; i < 5; i++) {
        int y = startYear - i;
        list.add('$y-${y + 1}-2');
        list.add('$y-${y + 1}-1');
      }
    } else {
      // 从 x-(x+1)-1 开始往前推
      int startYear = x;
      for (int i = 0; i < 5; i++) {
        int y = startYear - i;
        list.add('$y-${y + 1}-1');
        list.add('${y - 1}-$y-2');
      }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : const Color(0xFFDADCE0), 
          width: 1
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : const Color(0xFFDADCE0), 
          width: 1
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: theme.primaryColor, width: 2),
      ),
      filled: true,
      fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : Colors.white,
    );

    return PopScope(
      canPop: !_isLoading, // 加载中时禁用手势/物理返回
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          surfaceTintColor: Theme.of(context).scaffoldBackgroundColor,
          automaticallyImplyLeading: false, // 禁用默认返回
          leading: IconButton(
            icon: Icon(
              Icons.close, 
              color: _isLoading 
                  ? (Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[300]) 
                  : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF5F6368))
            ),
            onPressed: _isLoading ? null : () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              
              // 学年学期选择
              DropdownButtonFormField<String>(
                value: _selectedSemester,
                decoration: md2InputDecoration('学年学期', Icons.calendar_today_outlined),
                isExpanded: true,
                icon: Icon(
                  Icons.arrow_drop_down, 
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF5F6368)
                ),
                dropdownColor: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(6),
                items: _semesters.map((semester) {
                  return DropdownMenuItem(
                    value: semester,
                    child: Text(semester, style: const TextStyle(fontSize: 15)),
                  );
                }).toList(),
                onChanged: _isLoading ? null : (value) {
                  setState(() {
                    _selectedSemester = value;
                  });
                },
              ),
              
              const SizedBox(height: 28),
              
              // 第一周周一日期选择
              InkWell(
                onTap: _isLoading ? null : _selectDate,
                borderRadius: BorderRadius.circular(6),
                child: IgnorePointer(
                  child: TextFormField(
                    controller: TextEditingController(
                      text: _selectedDate != null 
                          ? '${_selectedDate!.year}年${_selectedDate!.month}月${_selectedDate!.day}日'
                          : '',
                    ),
                    decoration: md2InputDecoration('第一周周一', Icons.date_range_outlined).copyWith(
                      hintText: '请选择日期',
                      suffixIcon: const Icon(Icons.edit_calendar_outlined, size: 18),
                    ),
                    readOnly: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ElevatedButton.icon(
                  onPressed: (_canConfirm() && !_isLoading) ? _confirm : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: theme.primaryColor.withOpacity(0.12),
                    disabledForegroundColor: theme.primaryColor.withOpacity(0.38),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    minimumSize: const Size(88, 36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text(
                    '导入',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _canConfirm() => _selectedSemester != null && _selectedDate != null;
  
  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      helpText: '选择本学期第一周的周一',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            useMaterial3: true,
            colorScheme: Theme.of(context).brightness == Brightness.dark 
              ? const ColorScheme.dark(
                  primary: Colors.orange, // 深色模式下用亮色点缀
                  onPrimary: Colors.black,
                  surface: Color(0xFF1E1E1E),
                )
              : ColorScheme.light(
                  primary: Theme.of(context).primaryColor,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: const Color(0xFF202124),
                ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      final monday = _getMondayOfWeek(picked);
      setState(() {
        _selectedDate = monday;
      });
    }
  }
  
  DateTime _getMondayOfWeek(DateTime date) {
    final daysFromMonday = date.weekday - DateTime.monday;
    return date.subtract(Duration(days: daysFromMonday));
  }
  
  Future<void> _confirm() async {
    if (_selectedSemester == null || _selectedDate == null) return;
    
    final authState = ref.read(authStateProvider);
    if (authState.status != AuthStatus.authenticated) {
      await Navigator.push(context, LoginScreen.route());
      
      final newAuthState = ref.read(authStateProvider);
      if (newAuthState.status != AuthStatus.authenticated) return;
    }
    
    setState(() { _isLoading = true; });
    
    try {
      await _timetableService.downloadAndSaveTimetable(
        semester: _selectedSemester!,
        firstWeekMonday: _selectedDate!,
      );
      
      // ✨ 导入成功后，重新安排上课提醒通知
      await ref.read(settingsProvider.notifier).rescheduleNotifications();
      
      if (mounted) {
        // 先返回 true 给上一级页面，通知导入成功
        Navigator.of(context).pop(true);
        
        // 在全局提示成功
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 课表导入成功！'), 
            backgroundColor: Color(0xFF09C489),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }
}
