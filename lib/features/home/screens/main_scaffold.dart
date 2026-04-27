import 'package:flutter/material.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/route_utils.dart';
import '../../../core/services/update_service.dart';
import '../../../core/state/auth_state.dart';
import '../../auth/screens/login_screen.dart';
import 'home_screen.dart';
import '../../timetable/screens/timetable_screen.dart';
import '../../homework/screens/homework_screen.dart';
import '../../notice/screens/notice_list_screen.dart';
import '../../workspace/screens/functions_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../../core/services/hitokoto_service.dart';
import '../../timetable/services/timetable_storage.dart';
import '../../timetable/providers/timetable_status_provider.dart';
import '../../timetable/providers/reminder_trigger_provider.dart';
import '../../../core/widgets/triangle_painter.dart';


/// 自定义顶部滑动指示器，圆角朝下
class MD2TopIndicator extends Decoration {
  final double indicatorHeight;
  final Color color;
  final double radius;

  const MD2TopIndicator({
    this.indicatorHeight = 3,
    required this.color,
    this.radius = 3,
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _MD2Painter(this, onChanged);
  }
}

class _MD2Painter extends BoxPainter {
  final MD2TopIndicator decoration;

  _MD2Painter(this.decoration, VoidCallback? onChanged) : super(onChanged);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    assert(configuration.size != null);

    final rect = offset & Size(configuration.size!.width, decoration.indicatorHeight);
    final paint = Paint()
      ..color = decoration.color
      ..style = PaintingStyle.fill;

    // 绘制圆角朝下的横条（顶部两个角是直角，底部两个角是圆角）
    final rrect = RRect.fromLTRBAndCorners(
      rect.left,
      rect.top,
      rect.right,
      rect.bottom,
      bottomLeft: Radius.circular(decoration.radius),
      bottomRight: Radius.circular(decoration.radius),
    );

    canvas.drawRRect(rrect, paint);
  }
}

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _hitokoto = '自在东湖在湖东！';
  final HitokotoService _hitokotoService = HitokotoService();
  bool _hasSeenReminder = false;

  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {}); // 重绘以更新 AppBar 状态
      }
    });

    _initHitokoto();
    _loadReminderState();
    
    // 延迟检查更新，避免干扰启动
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        UpdateService().checkUpdate(context);
      }
    });
  }

  Future<void> _loadReminderState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _hasSeenReminder = prefs.getBool('has_seen_class_reminder') ?? false;
      });
    }
  }

  Future<void> _dismissReminder() async {
    if (_hasSeenReminder) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_class_reminder', true);
    if (mounted) {
      setState(() {
        _hasSeenReminder = true;
      });
    }
  }

  Future<void> _initHitokoto() async {
    // 1. 获取并显示上一次缓存的结果
    final cached = await _hitokotoService.getCachedHitokoto();
    if (cached != null) {
      if (mounted) {
        setState(() {
          _hitokoto = cached;
        });
      }
    }
    
    // 2. 异步获取下一次要显示的内容 (后台执行)
    final fresh = await _hitokotoService.prefetchNextHitokoto();
    
    // 3. 如果当前还是默认值且获取到了新值，则立即刷新
    if (cached == null && fresh != null) {
      if (mounted) {
        setState(() {
          _hitokoto = fresh;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 提供切换 Tab 的方法
  void switchToTab(int index) {
    final authState = ref.read(authStateProvider);
    
    // 如果正在登录中，拦截通知页的访问 (index 3)
    if (authState.status == AuthStatus.authenticating && index == 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正在登录，请稍候...'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _tabController.animateTo(index);
  }
  
  // 根据登录状态动态生成页面列表
  List<Widget> _getPages(AuthStatus status) {
    return [
      HomeScreen(onNavigateToTab: switchToTab),
      const TimetableScreen(),
      const HomeworkScreen(), // ✅ 作业待办
      const NoticeListScreen(),
      const FunctionsScreen(),
    ];
  }
  
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final hasTimetable = ref.watch(timetableStatusProvider);
    
    // 监听强制触发器，当课表导入完成时，重置状态并展示提醒
    ref.listen(classReminderTriggerProvider, (previous, next) {
      if (next > 0) {
        _loadReminderState();
      }
    });

    // 监听课表状态变化（针对删除等操作）
    ref.listen(timetableStatusProvider, (previous, next) {
      if (next == true) {
        _loadReminderState();
      }
    });

    return Scaffold(
      appBar: _buildGlobalTopBar(context, authState, hasTimetable),
      drawer: Drawer(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.8),
              ),
              accountName: const Text('自在东湖'),
              accountEmail: const Text('v1.0.0'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Theme.of(context).cardColor,
                child: Icon(Icons.school, color: Theme.of(context).primaryColor),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('设置'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) {
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.0, 0.05), // 从下方稍微偏移
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey<int>(_tabController.index),
                child: _getPages(authState.status)[_tabController.index],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: Material(
        color: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
        elevation: 8,
        child: SafeArea(
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.05) : const Color(0x0D000000), 
                  width: 0.5
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: MD2TopIndicator(
                color: const Color(0xFF09C489),
                indicatorHeight: 3,
                radius: 3,
              ),
              indicatorSize: TabBarIndicatorSize.label,
              // 这里不再需要 hacky 的 padding，因为自定义指示器就在顶部绘制
              indicatorPadding: EdgeInsets.zero,
              labelColor: const Color(0xFF09C489),
              unselectedLabelColor: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.grey,
              labelPadding: EdgeInsets.zero,
              labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontSize: 10),
              onTap: (index) {
                // 如果正在登录中，拦截通知页的访问 (index 3)
                if (authState.status == AuthStatus.authenticating && index == 3) {
                  _tabController.index = _tabController.previousIndex;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('正在登录，请稍候...'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
              },
              tabs: const [
                Tab(
                  icon: Icon(Icons.home_outlined),
                  text: '首页',
                  iconMargin: EdgeInsets.only(bottom: 4),
                ),
                Tab(
                  icon: Icon(Icons.calendar_month_outlined),
                  text: '课表',
                  iconMargin: EdgeInsets.only(bottom: 4),
                ),
                Tab(
                  icon: Icon(Icons.assignment_outlined),
                  text: '作业',
                  iconMargin: EdgeInsets.only(bottom: 4),
                ),
                Tab(
                  icon: Icon(Icons.inbox_outlined),
                  text: '通知',
                  iconMargin: EdgeInsets.only(bottom: 4),
                ),
                Tab(
                  icon: Icon(Icons.dashboard_outlined),
                  text: '功能',
                  iconMargin: EdgeInsets.only(bottom: 4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildGlobalTopBar(BuildContext context, AuthState authState, bool hasTimetable) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(88),
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).appBarTheme.backgroundColor,
              borderRadius: BorderRadius.circular(8), // 圆角矩形 8
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.black.withOpacity(0.4) 
                      : Colors.black.withOpacity(0.2),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
              ),
            ),
            child: Row(
              children: [
                Padding(
                  padding: EdgeInsets.zero,
                  child: Icon(
                    Icons.nature_outlined, 
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.grey, 
                    size: 24
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _hitokoto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.grey[500],
                  ),
                ),
                const Spacer(),
                // 暂时放一个搜索占位
                const Expanded(
                  child: SizedBox(),
                ),
                
                // 用户头像
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    GestureDetector(
                      onTap: () {
                        _dismissReminder(); // 点击后标记为已看
                        Navigator.push(
                          context,
                          createSlideUpRoute(const ProfileScreen()),
                        );
                      },
                      child: SizedBox(
                        width: 40, height: 40,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (authState.status == AuthStatus.authenticating)
                              const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.orange)))
                            else
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: _getAuthStatusColor(authState.status), width: 2),
                                ),
                              ),
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFEEEEEE),
                              backgroundImage: _getAvatarImage(authState),
                              child: _getAvatarImage(authState) == null ? const Icon(Icons.person, size: 20, color: Colors.grey) : null,
                            ),
                            // 登录失败/身份过期显示感叹号
                            if (authState.status == AuthStatus.unauthenticated && authState.hasAccount)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.priority_high_rounded,
                                    color: Colors.white,
                                    size: 10,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (hasTimetable && !_hasSeenReminder && authState.status == AuthStatus.authenticated)
                      Positioned(
                        top: 42,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CustomPaint(
                              size: const Size(10, 6),
                              painter: TrianglePainter(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.withOpacity(0.4) : Colors.black54),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.withOpacity(0.4) : Colors.black54,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '在这里开启上课提醒',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ImageProvider? _getAvatarImage(AuthState authState) {
    if (authState.avatarUrl == null) {
      return null;
    }
    
    if (authState.avatarUrl!.startsWith('http')) {
      return NetworkImage(authState.avatarUrl!);
    } else {
      final file = File(authState.avatarUrl!);
      if (file.existsSync()) {
        return FileImage(file);
      }
    }
    return null;
  }
  
  void _showLoginDialog(BuildContext context) {
    if (ref.read(authStateProvider).status == AuthStatus.authenticating) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正在登录，请稍候...'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const LoginScreen(),
    );
  }

  Color _getAuthStatusColor(AuthStatus status) {
    switch (status) {
      case AuthStatus.authenticated:
        return Colors.green;
      case AuthStatus.unauthenticated:
        return Colors.red;
      case AuthStatus.authenticating:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
