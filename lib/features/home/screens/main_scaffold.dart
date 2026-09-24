import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
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
import '../widgets/ai_response_card.dart';
import '../../../core/ai/ai_provider.dart';
import '../../profile/providers/settings_provider.dart';
import '../../../core/utils/l10n_extension.dart';


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

class _MainScaffoldState extends ConsumerState<MainScaffold> with TickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  late AnimationController _aiAnimController;
  String? _hitokoto;
  final HitokotoService _hitokotoService = HitokotoService();
  bool _hasSeenReminder = false;
  DateTime _lastReschedule = DateTime.fromMillisecondsSinceEpoch(0);

  // AI 助理交互状态
  bool _isAiMode = false;
  String? _selectedImagePath;
  final TextEditingController _aiInputController = TextEditingController();
  final FocusNode _aiInputFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 5, vsync: this);
    // 无条件重绘：点击帧 controller 就同步翻 index 并 notify，
    // 顶栏要和这一帧一起重绘，一言动画才能与页面动画严格并行。
    // （作业页同款写法，见 homework_screen.dart）
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    _aiAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 220),
    );

    _aiInputController.addListener(() {
      setState(() {});
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

  void _enterAiMode() {
    setState(() {
      _isAiMode = true;
    });
    _aiAnimController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _aiInputFocusNode.requestFocus();
    });
  }

  void _exitAiMode() {
    _aiInputFocusNode.unfocus();
    _aiAnimController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isAiMode = false;
          _aiInputController.clear();
          _selectedImagePath = null;
        });
        ref.read(aiAssistantProvider.notifier).clearSession();
      }
    });
  }

  Future<void> _pickImage() async {
    _aiInputFocusNode.unfocus();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(context.l10n.chooseFromGallery),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(context.l10n.takePhoto),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      try {
        final picker = ImagePicker();
        final file = await picker.pickImage(
          source: source,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
        if (file != null && mounted) {
          setState(() {
            _selectedImagePath = file.path;
          });
        }
      } catch (e) {
        debugPrint('Failed to pick image: $e');
      }
    }
  }

  void _submitAiQuery(String text) {
    final query = text.trim();
    final imagePath = _selectedImagePath;
    if (query.isEmpty && (imagePath == null || imagePath.isEmpty)) return;
    _aiInputController.clear();
    setState(() {
      _selectedImagePath = null;
    });
    ref.read(aiAssistantProvider.notifier).sendMessage(query, imagePath: imagePath);
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeRescheduleOnResume();
    }
  }

  Future<void> _maybeRescheduleOnResume() async {
    // 节流：5分钟内不重复重调度，避免频繁 cancelAll
    final now = DateTime.now();
    if (now.difference(_lastReschedule).inMinutes < 5) return;
    _lastReschedule = now;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTs = prefs.getInt('last_notification_reschedule_ts') ?? 0;
      final last = DateTime.fromMillisecondsSinceEpoch(lastTs);
      // 长时间未重调度，或系统中已没有待处理通知时，强制补排。
      final pendingCount = await ref.read(settingsProvider.notifier).getPendingNotificationCount();
      if (now.difference(last).inHours >= 12 || pendingCount == 0) {
        // 动态 import 避免循环依赖，用 ref 读取
        // 延迟一帧确保 ref 可用
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
        try {
          await ref.read(settingsProvider.notifier).rescheduleNotifications();
          await prefs.setInt('last_notification_reschedule_ts', now.millisecondsSinceEpoch);
        } catch (_) {
          // ignore, 下次 resumed 再试
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _aiAnimController.dispose();
    _aiInputController.dispose();
    _aiInputFocusNode.dispose();
    super.dispose();
  }

  // 提供切换 Tab 的方法
  void switchToTab(int index) {
    final authState = ref.read(authStateProvider);
    
    // 如果正在登录中，拦截通知页的访问 (index 3)
    if (authState.status == AuthStatus.authenticating && index == 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.loggingInPleaseWait),
          duration: const Duration(seconds: 2),
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

    return PopScope(
      canPop: !_isAiMode,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_isAiMode) {
          _exitAiMode();
        }
      },
      child: Stack(
        children: [
          Scaffold(
            appBar: _buildGlobalTopBar(context, authState, hasTimetable),
            drawer: Drawer(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              child: Column(
                children: [
                  UserAccountsDrawerHeader(
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.8),
                    ),
                    accountName: Text(context.l10n.appTitle),
                    accountEmail: const Text('v1.0.0'),
                    currentAccountPicture: CircleAvatar(
                      backgroundColor: Theme.of(context).cardColor,
                      child: Icon(Icons.school, color: Theme.of(context).primaryColor),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: Text(context.l10n.settings),
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
                    indicator: const MD2TopIndicator(
                      color: Color(0xFF09C489),
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
                          SnackBar(
                            content: Text(context.l10n.loggingInWait),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                    },
                    tabs: [
                      Tab(
                        icon: const Icon(Icons.home_outlined),
                        text: context.l10n.tabHome,
                        iconMargin: const EdgeInsets.only(bottom: 4),
                      ),
                      Tab(
                        icon: const Icon(Icons.calendar_month_outlined),
                        text: context.l10n.tabTimetable,
                        iconMargin: const EdgeInsets.only(bottom: 4),
                      ),
                      Tab(
                        icon: const Icon(Icons.assignment_outlined),
                        text: context.l10n.tabHomework,
                        iconMargin: const EdgeInsets.only(bottom: 4),
                      ),
                      Tab(
                        icon: const Icon(Icons.inbox_outlined),
                        text: context.l10n.tabNotice,
                        iconMargin: const EdgeInsets.only(bottom: 4),
                      ),
                      Tab(
                        icon: const Icon(Icons.dashboard_outlined),
                        text: context.l10n.tabFunctions,
                        iconMargin: const EdgeInsets.only(bottom: 4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // AI 模式下：全屏统一暗色背景遮罩（覆盖底栏与顶栏四周）+ 唯一点亮的漂浮顶栏与下方卡片
          if (_isAiMode) ...[
            Positioned.fill(
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _aiAnimController,
                  curve: Curves.easeOutCubic,
                ),
                child: GestureDetector(
                  onTap: _exitAiMode,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    color: Colors.black.withOpacity(0.54),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Material(
                type: MaterialType.transparency,
                child: _buildExpandedTopBar(context, authState, hasTimetable),
              ),
            ),
            Positioned(
              // 顶栏白条已展开到 120（2 倍），总高 134，卡片紧跟其下保持 2px 间隙
              top: MediaQuery.of(context).padding.top + 136,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _aiAnimController,
                  curve: Curves.easeOutCubic,
                ),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, -0.05), // 自顶栏平滑下移淡入
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _aiAnimController,
                    curve: Curves.easeOutCubic,
                  )),
                  child: Material(
                    type: MaterialType.transparency,
                    child: AiResponseCard(
                      onClose: _exitAiMode,
                      onQuickQuerySelected: (query) {
                        _aiInputController.clear();
                        setState(() {
                          _selectedImagePath = null;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  PreferredSizeWidget _buildGlobalTopBar(BuildContext context, AuthState authState, bool hasTimetable, [double? overrideBarHeight]) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 非 AI 模式：去掉白色卡片顶栏，一言左对齐（无左侧 icon），头像右对齐
    // 注：正常顶栏不区分 AI 模式，永远 plain；AI 浮层输入条走下面的卡片分支
    if (overrideBarHeight == null) {
      // 一言只在主页 tab 显示。controller 在点击帧就同步翻 index，
      // listener 无条件重绘，所以这里与页面翻页是同一帧，并行动画。
      final isHomeTab = _tabController.index == 0;
      return PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    // 注意：不要在这里设 switchIn/OutCurve，出场动画 t 是从 1→0，
                    // 套 easeOut 会让前半段几乎不动（t=0.9 时 opacity 还有 0.999），
                    // 看起来就像“过一小会才动”。方向曲线在下面按进/出分别指定。
                    // 左对齐堆叠（默认 layoutBuilder 是居中的，会把一言挤到中间）
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        alignment: Alignment.centerLeft,
                        clipBehavior: Clip.none,
                        children: [
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      );
                    },
                    // 进场从下方滑入，出场向上滑出（各走各的方向，非反播）。
                    // 方向按目标 tab + 子项 key 判定：只有一言文本可见，
                    // 回主页=文本进场，离主页=文本出场。
                    transitionBuilder: (child, animation) {
                      final isText =
                          child.key == const ValueKey('hitokoto_text');
                      if (!isText) {
                        // 空占位不可见，线性淡入淡出即可
                        return FadeTransition(
                          opacity: animation,
                          child: child,
                        );
                      }
                      // 进场用 easeOut、出场用 easeIn，保证两边都是“快起”：
                      // 出场 t 从 1→0，若用 easeOut 则前半段几乎不动。
                      final curve =
                          isHomeTab ? Curves.easeOutCubic : Curves.easeInCubic;
                      final curved = CurvedAnimation(
                        parent: animation,
                        curve: curve,
                      );
                      final slide = isHomeTab
                          // 回主页：从下方滑入
                          ? Tween<Offset>(
                              begin: const Offset(0, 0.5), end: Offset.zero)
                              .animate(curved)
                          // 离主页：向上滑出
                          : Tween<Offset>(
                              begin: const Offset(0, -0.5),
                              end: Offset.zero)
                              .animate(curved);
                      return FadeTransition(
                        opacity: curved,
                        child: SlideTransition(
                          position: slide,
                          child: child,
                        ),
                      );
                    },
                    child: isHomeTab
                        ? Text(
                            _hitokoto ?? context.l10n.defaultHitokoto,
                            key: const ValueKey('hitokoto_text'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.2,
                              color:
                                  isDark ? Colors.white54 : Colors.grey[800],
                            ),
                          )
                        : const SizedBox.shrink(
                            key: ValueKey('hitokoto_empty')),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _enterAiMode,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/images/ai_button.svg',
                        width: 24,
                        height: 24,
                        colorFilter: ColorFilter.mode(
                          isDark ? Colors.white54 : Colors.grey,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 40,
                  height: 40,
                  child:
                      _buildAvatar(context, authState, hasTimetable, isDark),
                ),
              ],
            ),
          ),
        ),
      );
    }
    // 白条高度：默认 60，点击后展开到 120（2 倍）；整体高度联动 +60，保持边距不变
    // 能走到这里 overrideBarHeight 必非空（空已在 plain 分支返回）
    final double barHeight = overrideBarHeight;
    final prefHeight = 88.0 + (barHeight - 60.0);

    return PreferredSize(
      preferredSize: Size.fromHeight(prefHeight),
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: GestureDetector(
            onTap: _isAiMode ? null : _enterAiMode,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: barHeight,
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(8), // MD2 圆角 8
                boxShadow: [
                  BoxShadow(
                    color: isDark 
                        ? Colors.black.withOpacity(0.5) 
                        : Colors.black.withOpacity(0.2),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.12)
                      : Colors.grey.withOpacity(0.1),
                  width: 1.0,
                ),
              ),
              // 首行固定 60px 置顶：展开时返回按钮/输入框保持原位，发送按钮下移到底部
              child: SizedBox(
                height: barHeight,
                child: Stack(
                  children: [
                    SizedBox(
                      height: 60,
                      child: Row(
                      children: [
                  // 左侧图标：位置绝对固定，原地纯渐变切换（返回按钮 <-> 自然图标）
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeOutCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: child,
                        );
                      },
                      child: _isAiMode
                          ? GestureDetector(
                              key: const ValueKey('ai_back_button'),
                              onTap: _exitAiMode,
                              behavior: HitTestBehavior.opaque,
                              child: const Center(
                                child: Icon(
                                  Icons.arrow_back_rounded,
                                  color: Color(0xFF09C489),
                                  size: 24,
                                ),
                              ),
                            )
                          : Center(
                              key: const ValueKey('nature_icon'),
                              child: Icon(
                                Icons.nature_outlined, 
                                color: isDark ? Colors.white60 : Colors.grey, 
                                size: 24,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // 中间区域：位置基准线完全一致，原地平滑交叉淡化（输入框 <-> 一言文本）
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeOutCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: child,
                        );
                      },
                      child: _isAiMode
                          ? Align(
                              key: const ValueKey('ai_text_field'),
                              alignment: Alignment.centerLeft,
                              child: TextField(
                                controller: _aiInputController,
                                focusNode: _aiInputFocusNode,
                                textInputAction: TextInputAction.send,
                                onSubmitted: _submitAiQuery,
                                cursorColor: const Color(0xFF09C489),
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.2,
                                  color: isDark ? Colors.white : const Color(0xFF202124),
                                ),
                                decoration: InputDecoration(
                                  hintText: context.l10n.whatsNewHint,
                                  hintStyle: TextStyle(
                                    fontSize: 16,
                                    height: 1.2,
                                    color: isDark ? Colors.white38 : Colors.grey[400],
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  filled: false,
                                  fillColor: Colors.transparent,
                                  hoverColor: Colors.transparent,
                                  focusColor: Colors.transparent,
                                  isDense: true,
                                  isCollapsed: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            )
                          : Align(
                              key: const ValueKey('hitokoto_text'),
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _hitokoto ?? context.l10n.defaultHitokoto,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.2,
                                  color: isDark ? Colors.white54 : Colors.grey[500],
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 右侧区域：AI 模式下占位（发送按钮已下移到底部），非 AI 模式显示头像
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeOutCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: child,
                        );
                      },
                      child: _isAiMode
                          ? const SizedBox(
                              key: ValueKey('ai_empty_space'),
                              width: 40,
                              height: 40,
                            )
                          : _buildAvatar(context, authState, hasTimetable, isDark,
                              key: const ValueKey('profile_avatar')),
                    ),
                  ),
                ],
                      ), // Row
                    ), // 顶部 60px 行：返回按钮 + 输入框保持原位
                    // 已选图片预览缩略图
                    if (_isAiMode && _selectedImagePath != null)
                      Positioned(
                        top: 10 + (barHeight - 60),
                        left: 42,
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.only(left: 3, right: 8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.08)
                                : Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFF09C489).withOpacity(0.4),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.file(
                                  File(_selectedImagePath!),
                                  width: 34,
                                  height: 34,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedImagePath = null;
                                  });
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // 图片按钮与发送按钮：随展开从顶部下移到底部右下角
                    if (_isAiMode)
                      Positioned(
                        top: 10 + (barHeight - 60),
                        right: 0,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 发送键左侧的图片上传按钮（直接展示图标，不包在圆内）
                            GestureDetector(
                              onTap: _pickImage,
                              behavior: HitTestBehavior.opaque,
                              child: SizedBox(
                                width: 40,
                                height: 40,
                                child: Center(
                                  child: Icon(
                                    _selectedImagePath != null
                                        ? Icons.image_rounded
                                        : Icons.image_outlined,
                                    color: _selectedImagePath != null
                                        ? const Color(0xFF09C489)
                                        : (isDark ? Colors.white70 : Colors.grey[600]),
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            // 发送按钮
                            GestureDetector(
                              onTap: (_aiInputController.text.trim().isNotEmpty || _selectedImagePath != null)
                                  ? () => _submitAiQuery(_aiInputController.text)
                                  : null,
                              behavior: HitTestBehavior.opaque,
                              child: SizedBox(
                                width: 40,
                                height: 40,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: (_aiInputController.text.trim().isNotEmpty || _selectedImagePath != null)
                                          ? const Color(0xFF09C489)
                                          : (isDark
                                              ? Colors.white.withOpacity(0.1)
                                              : Colors.grey[300]),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.arrow_upward_rounded,
                                      color: (_aiInputController.text.trim().isNotEmpty || _selectedImagePath != null)
                                          ? Colors.white
                                          : (isDark ? Colors.white38 : Colors.grey[500]),
                                      size: 16,
                                    ),
                                  ),
                                ),
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
        ),
      ),
    );
  }

  /// 头像（含登录状态圆环、提醒气泡）， plain 顶栏与卡片顶栏共用
  Widget _buildAvatar(
      BuildContext context, AuthState authState, bool hasTimetable, bool isDark,
      {Key? key}) {
    return Stack(
      key: key,
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
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (authState.status == AuthStatus.authenticating)
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.orange),
                    ),
                  )
                else
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _getAuthStatusColor(authState.status),
                        width: 2,
                      ),
                    ),
                  ),
                CircleAvatar(
                  radius: 16,
                  backgroundColor:
                      isDark ? Colors.white10 : const Color(0xFFEEEEEE),
                  backgroundImage: _getAvatarImage(authState),
                  child: _getAvatarImage(authState) == null
                      ? const Icon(Icons.person, size: 20, color: Colors.grey)
                      : null,
                ),
                // 登录失败/身份过期显示感叹号
                if (authState.status == AuthStatus.unauthenticated &&
                    authState.hasAccount)
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
        if (hasTimetable &&
            !_hasSeenReminder &&
            authState.status == AuthStatus.authenticated)
          Positioned(
            top: 42,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomPaint(
                  size: const Size(10, 6),
                  painter: TrianglePainter(
                    color: isDark
                        ? Colors.grey.withOpacity(0.4)
                        : Colors.black54,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.grey.withOpacity(0.4)
                        : Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    context.l10n.enableClassReminderHere,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// AI 模式漂浮顶栏：高度随 _aiAnimController 从 60 展开到 120（2 倍）
  Widget _buildExpandedTopBar(
      BuildContext context, AuthState authState, bool hasTimetable) {
    return AnimatedBuilder(
      animation: _aiAnimController,
      builder: (context, _) {
        final t = CurvedAnimation(
          parent: _aiAnimController,
          curve: Curves.easeOutCubic,
        ).value;
        final barHeight = 60.0 + 60.0 * t; // 60 -> 120
        return _buildGlobalTopBar(context, authState, hasTimetable, barHeight);
      },
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
        SnackBar(
          content: Text(context.l10n.loggingInPleaseWait),
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
