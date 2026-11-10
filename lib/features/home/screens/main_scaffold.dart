import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../cloudisk/screens/cloud_sync_prompt_screen.dart';
import '../../../core/utils/route_utils.dart';
import '../../../core/services/update_service.dart';
import '../../../core/services/app_navigator.dart';
import '../../../core/services/home_widget_service.dart';
import '../../../core/services/hitokoto_service.dart';
import '../../../core/state/auth_state.dart';
import '../../../core/state/widget_action_provider.dart';
import 'home_screen.dart';
import '../../timetable/screens/timetable_screen.dart';
import '../../homework/screens/homework_screen.dart';
import '../../notice/screens/notice_list_screen.dart';
import '../../workspace/screens/functions_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../widgets/ai_response_card.dart';
import '../../../core/ai/ai_provider.dart';
import '../../profile/providers/settings_provider.dart';
import '../../../core/utils/l10n_extension.dart';
import '../widgets/quick_action_router.dart';
import '../../cloudisk/services/cloud_backup_manager.dart';


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
  DateTime _lastReschedule = DateTime.fromMillisecondsSinceEpoch(0);

  // AI 助理交互状态
  bool _isAiMode = false;
  bool _promptPushed = false;
  bool _guideCheckedThisSession = false;
  String? _selectedImagePath;
  final TextEditingController _aiInputController = TextEditingController();
  final FocusNode _aiInputFocusNode = FocusNode();
  String? _hitokoto;

  @override
  void initState() {
    super.initState();
    AppNavigator.onSwitchTab = switchToTab;
    AppNavigator.onCloseAiMode = _exitAiMode;
    WidgetsBinding.instance.addObserver(this);
    _initHitokoto();
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

    // 桌面小组件点进来时，取原生暂存的动作并路由；同时检查开始引导更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumeWidgetAction();
      _checkOnboardingGuide();
    });
    
    // 延迟检查更新，避免干扰启动
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        UpdateService().checkUpdate(context);
      }
    });
  }

  /// 检查是否需要给已登录用户展示本次更新的「开始引导」
  Future<void> _checkOnboardingGuide() async {
    if (_guideCheckedThisSession) return;
    _guideCheckedThisSession = true;

    final authState = ref.read(authStateProvider);
    if (!authState.hasAccount) return;
    if (_promptPushed || ref.read(cloudSyncPromptPendingProvider)) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSeen =
          prefs.getInt(CloudSyncPromptScreen.kLastSeenGuideVersionKey) ?? 0;
      if (lastSeen < CloudSyncPromptScreen.kCurrentOnboardingGuideVersion) {
        if (!mounted) return;
        // 等待界面首帧过渡稳定
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted ||
            _promptPushed ||
            ref.read(cloudSyncPromptPendingProvider)) {
          return;
        }
        _promptPushed = true;
        await Navigator.of(context).push(CloudSyncPromptScreen.route());
        _promptPushed = false;
      }
    } catch (e) {
      debugPrint('⚠️ 检查引导版本失败: $e');
    }
  }

  Future<void> _initHitokoto() async {
    final hitokotoService = HitokotoService();
    final cached = await hitokotoService.getCachedHitokoto();
    if (mounted && cached != null) {
      setState(() {
        _hitokoto = cached;
      });
    }

    try {
      final fresh = await hitokotoService.prefetchNextHitokoto();
      if (mounted && fresh != null) {
        setState(() {
          _hitokoto = fresh;
        });
      }
    } catch (_) {
      // 失败静默使用缓存或缺省
    }
  }

  /// 消费小组件点击动作：agenda/homework 切 tab，功能 id 打开对应页面
  Future<void> _consumeWidgetAction() async {
    try {
      final action = await HomeWidgetService().consumeInitialWidgetAction();
      if (action != null && action.isNotEmpty && mounted) {
        ref.read(widgetActionProvider.notifier).state = action;
      }
    } catch (_) {}
  }

  /// 消费小组件点击动作：agenda/homework 切 tab，功能 id 打开对应页面。
  /// 未登录时功能动作不清零，先弹登录，登录成功后由 auth 监听接力跳转。
  Future<void> _handleWidgetAction(String action) async {
    if (action == 'agenda') {
      if (mounted) switchToTab(1);
      ref.read(widgetActionProvider.notifier).state = null;
    } else if (action == 'homework') {
      if (mounted) switchToTab(2);
      ref.read(widgetActionProvider.notifier).state = null;
    } else if (HomeWidgetService.allFunctionIds.contains(action)) {
      final authed =
          ref.read(authStateProvider).status == AuthStatus.authenticated;
      if (!authed) {
        // 未登录（含游客）：先走登录流程，动作保留，登录成功后继续
        if (mounted) await openFunctionById(context, ref, action);
        return;
      }
      if (mounted) switchToTab(0);
      // 等 tab 切回主页后再打开功能页，避免动画冲突
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      await openFunctionById(context, ref, action);
      ref.read(widgetActionProvider.notifier).state = null;
    } else {
      ref.read(widgetActionProvider.notifier).state = null;
    }
  }

  /// 把同步推荐页推到顶层（全屏弹窗），避免被主页/登录残留路由盖住。
  void _pushCloudSyncPrompt() {
    if (_promptPushed) return;
    _promptPushed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (!ref.read(cloudSyncPromptPendingProvider)) {
        _promptPushed = false;
        return;
      }
      await Navigator.of(context).push(CloudSyncPromptScreen.route());
      _promptPushed = false;
    });
  }

  void _enterAiMode() {
    setState(() {
      _isAiMode = true;
    });
    _aiAnimController.forward();
    // 进入 AI 模式后自动聚焦输入框并调起键盘
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _aiInputFocusNode.requestFocus();
      }
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
    if (ref.read(aiAssistantProvider).isLoading) return;
    _aiInputController.clear();
    setState(() {
      _selectedImagePath = null;
    });
    ref.read(aiAssistantProvider.notifier).sendMessage(query, imagePath: imagePath);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeRescheduleOnResume();
      // 从桌面小组件点进来时（App 活着走 onNewIntent），这里取走暂存动作并路由；
      // 冷启动路径仍由 initState 的 postFrame 消费。
      _consumeWidgetAction();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // 当应用切入后台时，若有未同步的离线修改，立刻触发一次同步
      CloudBackupManager.instance.syncNow();
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
    if (AppNavigator.onSwitchTab == switchToTab) {
      AppNavigator.onSwitchTab = null;
    }
    if (AppNavigator.onCloseAiMode == _exitAiMode) {
      AppNavigator.onCloseAiMode = null;
    }
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
    final aiState = ref.watch(aiAssistantProvider);
    final hasChat = aiState.displayMessages.isNotEmpty ||
        aiState.isLoading ||
        aiState.errorMessage != null;

    // 桌面小组件点击动作（原生侧透出一次，消费后清空）
    ref.listen<String?>(widgetActionProvider, (previous, next) {
      if (next != null && next.isNotEmpty) {
        _handleWidgetAction(next);
      }
    });

    // 登录成功接力：小组件点的是需登录功能且当时未登录时，
    // 动作会保留到这里，登录一完成立刻跳转进去
    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (previous?.status != AuthStatus.authenticated &&
          next.status == AuthStatus.authenticated) {
        final pending = ref.read(widgetActionProvider);
        if (pending != null && pending.isNotEmpty && mounted) {
          _handleWidgetAction(pending);
        }
      }
    });

    // 登录后同步推荐：以顶层弹窗盖在主页之上，同一会话只推一次
    ref.listen<bool>(cloudSyncPromptPendingProvider, (previous, next) {
      if (next == true) {
        _pushCloudSyncPrompt();
      } else {
        _promptPushed = false;
      }
    });
    if (ref.watch(cloudSyncPromptPendingProvider) && !_promptPushed) {
      _pushCloudSyncPrompt();
    }

    return PopScope(
      canPop: !_isAiMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isAiMode) {
          _exitAiMode();
        }
      },
      child: Stack(
        children: [
          Builder(
            builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final size = MediaQuery.sizeOf(context);
              final orientation = MediaQuery.orientationOf(context);
              final isTabletOrLandscape = size.width >= 600 ||
                  (orientation == Orientation.landscape && size.width >= 500);

              return Scaffold(
                appBar: isTabletOrLandscape
                    ? null
                    : _buildGlobalTopBar(context, authState),
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
                body: Row(
                  children: [
                    if (isTabletOrLandscape)
                      _buildLeftRail(context, authState, isDark),
                    Expanded(
                      child: Column(
                        children: [
                          if (isTabletOrLandscape)
                            SizedBox(
                              height: MediaQuery.paddingOf(context).top > 0
                                  ? MediaQuery.paddingOf(context).top
                                  : 4.0,
                            ),
                          Expanded(
                            child: MediaQuery.removePadding(
                              context: context,
                              removeTop: true,
                              child: Container(
                                color: Theme.of(context).scaffoldBackgroundColor,
                                child: AnimatedBuilder(
                                  animation: _tabController,
                                  builder: (context, _) {
                                    return AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 300),
                                      layoutBuilder: (currentChild, previousChildren) {
                                        return Stack(
                                          fit: StackFit.expand,
                                          alignment: Alignment.topCenter,
                                          children: [
                                            ...previousChildren,
                                            if (currentChild != null) currentChild,
                                          ],
                                        );
                                      },
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
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                bottomNavigationBar: isTabletOrLandscape
                    ? null
                    : Material(
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
              );
            },
          ),

          // AI 模式下：全屏统一暗色背景遮罩 + 底部悬浮卡片与输入底栏
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
                    color: Colors.black.withValues(alpha: 0.54),
                  ),
                ),
              ),
            ),
            Builder(
              builder: (context) {
                final size = MediaQuery.sizeOf(context);
                final orientation = MediaQuery.orientationOf(context);
                final isTabletOrLandscape = size.width >= 600 ||
                    (orientation == Orientation.landscape && size.width >= 500);
                final pageWidth = isTabletOrLandscape ? (size.width - 76.0) : size.width;
                final canSplit = pageWidth >= 600;
                final aiLeft = isTabletOrLandscape ? 76.0 : 0.0;
                final aiRight = canSplit ? (pageWidth / 2) : 0.0;

                return Positioned(
                  left: aiLeft,
                  right: aiRight,
                  top: MediaQuery.of(context).padding.top + 8,
                  bottom: (MediaQuery.of(context).viewInsets.bottom > 0
                      ? MediaQuery.of(context).viewInsets.bottom + 8
                      : MediaQuery.of(context).padding.bottom + 8),
                  child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _aiAnimController,
                  curve: Curves.easeOutCubic,
                ),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.05), // 自底栏平滑上移淡入
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _aiAnimController,
                    curve: Curves.easeOutCubic,
                  )),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                          // 点击之后先不展示卡片，而是直接暴露原本的快捷提问按钮（一行一个）；
                          // 出现对话或正在加载时才展示卡片
                          Flexible(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeOutCubic,
                              layoutBuilder: (currentChild, previousChildren) {
                                return Stack(
                                  alignment: Alignment.bottomLeft,
                                  children: [
                                    ...previousChildren,
                                    if (currentChild != null) currentChild,
                                  ],
                                );
                              },
                              child: hasChat
                                  ? KeyedSubtree(
                                      key: const ValueKey('ai_response_card'),
                                      child: AiResponseCard(
                                        onClose: _exitAiMode,
                                        onQuickQuerySelected: (query) {
                                          _aiInputController.clear();
                                          setState(() {
                                            _selectedImagePath = null;
                                          });
                                        },
                                      ),
                                    )
                                  : KeyedSubtree(
                                      key: const ValueKey('ai_exposed_quick_prompts'),
                                      child: AiQuickPromptsList(
                                        onDismiss: _exitAiMode,
                                        onPromptSelected: (prompt) {
                                          _aiInputController.clear();
                                          _aiInputFocusNode.unfocus();
                                          setState(() {
                                            _selectedImagePath = null;
                                          });
                                        },
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // 原顶栏现成为底栏（拦截内部点击，避免误触退出）
                          Material(
                            type: MaterialType.transparency,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {},
                              child: _buildAiBottomBar(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            ],
        ],
      ),
    );
  }

  Widget _buildLeftRail(BuildContext context, AuthState authState,
      bool isDark) {
    final navItems = [
      (
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: context.l10n.tabHome
      ),
      (
        icon: Icons.calendar_month_outlined,
        selectedIcon: Icons.calendar_month,
        label: context.l10n.tabTimetable
      ),
      (
        icon: Icons.assignment_outlined,
        selectedIcon: Icons.assignment,
        label: context.l10n.tabHomework
      ),
      (
        icon: Icons.inbox_outlined,
        selectedIcon: Icons.inbox,
        label: context.l10n.tabNotice
      ),
      (
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        label: context.l10n.tabFunctions
      ),
    ];

    return Container(
      key: const ValueKey('tablet_navigation_rail'),
      width: 76,
      decoration: BoxDecoration(
        color: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
        border: Border(
          right: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : const Color(0x0D000000),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            // 上方放置底栏的5个页面导航项
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    for (int i = 0; i < navItems.length; i++) ...[
                      _buildRailItem(
                        context,
                        index: i,
                        icon: navItems[i].icon,
                        selectedIcon: navItems[i].selectedIcon,
                        label: navItems[i].label,
                        isSelected: _tabController.index == i,
                        isDark: isDark,
                      ),
                      if (i < navItems.length - 1) const SizedBox(height: 4),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // 底部：AI 入口与头像
            GestureDetector(
              key: const ValueKey('ai_entry_button'),
              onTap: _enterAiMode,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 44,
                height: 44,
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
            const SizedBox(height: 8),
            _buildAvatar(context, authState, isDark),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildRailItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required bool isSelected,
    required bool isDark,
  }) {
    const activeColor = Color(0xFF09C489);
    final unselectedColor = isDark ? Colors.white54 : Colors.grey;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => switchToTab(index),
        child: SizedBox(
          width: 76,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSelected ? selectedIcon : icon,
                      color: isSelected ? activeColor : unselectedColor,
                      size: 22,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected ? activeColor : unselectedColor,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      width: 3,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: activeColor,
                        borderRadius: BorderRadius.horizontal(
                          left: Radius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildGlobalTopBar(
      BuildContext context, AuthState authState) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                  transitionBuilder: (child, animation) {
                    final isText =
                        child.key == const ValueKey('hitokoto_text');
                    if (!isText) {
                      return FadeTransition(
                        opacity: animation,
                        child: child,
                      );
                    }
                    final curve =
                        isHomeTab ? Curves.easeOutCubic : Curves.easeInCubic;
                    final curved = CurvedAnimation(
                      parent: animation,
                      curve: curve,
                    );
                    final slide = isHomeTab
                        ? Tween<Offset>(
                            begin: const Offset(0, 0.5), end: Offset.zero)
                            .animate(curved)
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
                key: const ValueKey('ai_entry_button'),
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
                    _buildAvatar(context, authState, isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// AI 模式悬浮底栏（原顶栏）
  Widget _buildAiBottomBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final aiState = ref.watch(aiAssistantProvider);
    final isLimitReached = aiState.isRoundLimitReached;
    final canSend = !isLimitReached &&
        !aiState.isLoading &&
        (_aiInputController.text.trim().isNotEmpty || _selectedImagePath != null);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(8), // MD2 圆角 8
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.5)
                : Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.12)
              : Colors.grey.withOpacity(0.1),
          width: 1.0,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 输入行：输入框
          SizedBox(
            height: 44,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('ai_text_field'),
                    controller: _aiInputController,
                    focusNode: _aiInputFocusNode,
                    autofocus: true,
                    enabled: !isLimitReached,
                    textInputAction: TextInputAction.send,
                    onSubmitted: canSend ? _submitAiQuery : null,
                    cursorColor: const Color(0xFF09C489),
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.2,
                      color: isDark ? Colors.white : const Color(0xFF202124),
                    ),
                    decoration: InputDecoration(
                      hintText: isLimitReached
                          ? '本轮对话已达上限（20次），请开启新对话'
                          : context.l10n.whatsNewHint,
                      hintStyle: TextStyle(
                        fontSize: isLimitReached ? 14 : 16,
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
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // 操作行：图片预览（若有）+ 图片选择 + 发送按钮
          SizedBox(
            height: 40,
            child: Row(
              children: [
                if (_selectedImagePath != null)
                  Container(
                    height: 36,
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
                            width: 30,
                            height: 30,
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
                const Spacer(),
                GestureDetector(
                  onTap: isLimitReached ? null : _pickImage,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: Icon(
                        _selectedImagePath != null
                            ? Icons.image_rounded
                            : Icons.image_outlined,
                        color: isLimitReached
                            ? (isDark ? Colors.white24 : Colors.grey[400])
                            : (_selectedImagePath != null
                                ? const Color(0xFF09C489)
                                : (isDark ? Colors.white70 : Colors.grey[600])),
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: canSend ? () => _submitAiQuery(_aiInputController.text) : null,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: canSend
                              ? const Color(0xFF09C489)
                              : (isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.grey[300]),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          color: canSend
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
    );
  }

  /// 头像（含登录状态圆环）， plain 顶栏与卡片顶栏共用
  Widget _buildAvatar(
      BuildContext context, AuthState authState, bool isDark,
      {Key? key}) {
    return Stack(
      key: key,
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              createSlideHorizontalRoute(const ProfileScreen()),
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
      ],
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
  
  Color _getAuthStatusColor(AuthStatus status) {
    switch (status) {
      case AuthStatus.authenticated:
        return Colors.green;
      case AuthStatus.unauthenticated:
        return Colors.red;
      case AuthStatus.authenticating:
        return Colors.orange;
    }
  }
}
