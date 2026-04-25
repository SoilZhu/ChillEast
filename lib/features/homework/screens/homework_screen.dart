import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/homework_provider.dart';
import '../models/homework_model.dart';
import '../../../core/state/auth_state.dart';
import '../../../core/widgets/login_required_placeholder.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import '../../workspace/screens/webview_detail_screen.dart';
import '../../../core/network/cookie_manager.dart';

class HomeworkScreen extends ConsumerStatefulWidget {
  const HomeworkScreen({super.key});

  @override
  ConsumerState<HomeworkScreen> createState() => _HomeworkScreenState();
}

class _HomeworkScreenState extends ConsumerState<HomeworkScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // 0: 存档, 1: 已完成, 2: 未完成. 初始选中 2
    _tabController = TabController(length: 3, vsync: this, initialIndex: 2);
    _tabController.addListener(() {
      setState(() {}); // 移除 indexIsChanging 判断，使动画并行执行
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final homeworkState = ref.watch(homeworkProvider);
    final authState = ref.watch(authStateProvider);
    
    return _buildBody(authState, homeworkState);
  }

  Widget _buildBody(AuthState authState, AsyncValue<List<HomeworkModel>> homeworkState) {
    // 直接返回带有 FAB 的 Scaffold
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 3), // 阴影偏移 3
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _showAddHomeworkSheet(context),
          shape: const CircleBorder(),
          elevation: 0, // 禁用默认阴影以使用自定义阴影
          backgroundColor: Theme.of(context).brightness == Brightness.light 
              ? Colors.white 
              : Theme.of(context).cardTheme.color ?? const Color(0xFF1E1E1E),
          child: Icon(
            Icons.add, 
            color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF00E676) : Colors.white
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSubHeader(),
          Expanded(
            child: homeworkState.when(
              data: (list) {
                // 如果处于正在登录中，或者已经登录，显示全部内容（包含之前的缓存）
                final displayList = (authState.status == AuthStatus.authenticated || 
                                     authState.status == AuthStatus.authenticating) 
                    ? list 
                    : list.where((e) => e.isManual).toList();

                // 如果显示列表为空，且处于未登录状态，显示登录占位
                if (displayList.isEmpty && authState.status == AuthStatus.unauthenticated) {
                   return const LoginRequiredPlaceholder(
                    title: '需要登录以同步作业',
                    message: '登录后即可从超星平台实时同步您的课程作业，您也可以直接点击右下角手动添加',
                    icon: Icons.assignment_late_outlined,
                  );
                }

                // 正常显示作业内容
                final archiveList = displayList.where((e) => e.status == HomeworkStatus.archived).toList();
                final completedList = displayList.where((e) => e.status == HomeworkStatus.completed).toList();
                final pendingList = displayList.where((e) => e.status == HomeworkStatus.pending).toList();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRefreshableList(archiveList, Icons.inventory_2_outlined, '存档里空空如也', authState.username, isPending: false),
                    _buildRefreshableList(completedList, Icons.task_alt, '还没完成过作业哦', authState.username, isPending: false),
                    _buildRefreshableList(pendingList, Icons.assignment_outlined, '暂时没有待办作业', authState.username, isPending: true),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text('作业加载失败: $err', style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.read(homeworkProvider.notifier).refresh(authState.username ?? ''),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubHeader() {
    return Container(
      height: 52,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.symmetric(horizontal: 16),
        labelColor: const Color(0xFF00E676),
        unselectedLabelColor: Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.grey[600],
        labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        indicator: UnderlineTabIndicator(
          borderSide: const BorderSide(
            width: 4,
            color: Color(0xFF00E676),
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
          ),
          insets: const EdgeInsets.symmetric(horizontal: 4),
        ),
        tabs: [
          _buildDynamicTab(index: 0, icon: Icons.inventory_2_outlined, label: '存档'),
          _buildDynamicTab(index: 1, icon: Icons.task_alt, label: '已完成'),
          _buildDynamicTab(index: 2, icon: Icons.assignment_outlined, label: '未完成'),
        ],
      ),
    );
  }

  Tab _buildDynamicTab({required int index, required IconData icon, required String label}) {
    final bool isActive = _tabController.index == index;
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isActive ? 1.0 : 0.0,
              child: isActive 
                ? Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(label, style: const TextStyle(fontSize: 16)),
                  )
                : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String msg) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        Center(
          child: Column(
            children: [
              Icon(icon, size: 64, color: Colors.grey[200]),
              const SizedBox(height: 16),
              Text(msg, style: TextStyle(color: Colors.grey[400])),
            ],
          ),
        ),
      ],
    );
  }

  /// 包装了下拉刷新的列表
  Widget _buildRefreshableList(List<HomeworkModel> items, IconData emptyIcon, String emptyMsg, String? username, {required bool isPending}) {
    return RefreshIndicator(
      onRefresh: () => ref.read(homeworkProvider.notifier).refresh(username ?? ''),
      child: isPending 
          ? _buildPendingList(items, emptyIcon, emptyMsg)
          : _buildSimpleList(items, emptyIcon, emptyMsg),
    );
  }

  /// 待办列表 (按日期聚合并显示)
  Widget _buildPendingList(List<HomeworkModel> items, IconData emptyIcon, String emptyMsg) {
    if (items.isEmpty) return _buildEmptyState(emptyIcon, emptyMsg);

    // 1. 分离有无时间的
    final withTime = items.where((e) => e.endTime != null).toList()
      ..sort((a, b) => a.endTime!.compareTo(b.endTime!));
    final noTime = items.where((e) => e.endTime == null).toList();

    // 2. 按日期对有时间的进行分组
    final Map<String, List<HomeworkModel>> grouped = {};
    for (var item in withTime) {
      final dateKey = DateFormat('M月d日').format(item.endTime!);
      grouped.putIfAbsent(dateKey, () => []).add(item);
    }

    final sortedDateKeys = grouped.keys.toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        for (var dateKey in sortedDateKeys) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              dateKey,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.grey[700],
              ),
            ),
          ),
          ...grouped[dateKey]!.map((item) => _buildHomeworkItem(item, showDate: false)),
        ],
        
        if (noTime.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              '无截止时间作业',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ...noTime.map((item) => _buildHomeworkItem(item, showDate: false)),
        ],
      ],
    );
  }

  /// 已完成/存档列表
  Widget _buildSimpleList(List<HomeworkModel> items, IconData emptyIcon, String emptyMsg) {
    if (items.isEmpty) return _buildEmptyState(emptyIcon, emptyMsg);

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildHomeworkItem(item);
      },
    );
  }

  Widget _buildHomeworkItem(HomeworkModel item, {bool showDate = true}) {
    final bool hasTime = item.endTime != null;
    final String timeDisplay = hasTime 
        ? (showDate ? DateFormat('M月d日 HH:mm').format(item.endTime!) : DateFormat('HH:mm').format(item.endTime!))
        : '';
    
    final bool isCompleted = item.status == HomeworkStatus.completed;

    Widget content = InkWell(
      onTap: () async {
        if (item.isManual) {
          _showHomeworkDetailDialog(item);
        } else if (item.dataUrl.isNotEmpty) {
           // 如果正在登录中，提示并返回，防止未授权打开详情
           final auth = ref.read(authStateProvider);
           if (auth.status == AuthStatus.authenticating) {
             if (context.mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('⏳ 正在登录中，请稍后...'), duration: Duration(seconds: 2)),
               );
             }
             return;
           }

           _logger.i('Opening homework detail: ${item.dataUrl}');
           await AppCookieManager().injectAllChaoxingCookies();
           if (context.mounted) {
             Navigator.push(context, MaterialPageRoute(builder: (context) => WebViewDetailScreen(title: '作业详情', url: item.dataUrl)));
           }
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: SizedBox(
                width: 20, height: 20,
                child: Checkbox(
                  value: isCompleted,
                  onChanged: (val) {
                    if (item.isManual) {
                      ref.read(homeworkProvider.notifier).toggleStatus(item.id);
                    }
                  },
                  activeColor: const Color(0xFF00E676),
                  checkColor: Colors.white,
                  side: BorderSide(color: Colors.grey[400]!, width: 1.5),
                  shape: const CircleBorder(),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF202124),
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (item.courseName.isNotEmpty) ...[
                    Text(item.courseName, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    const SizedBox(height: 4),
                  ],
                  Row(
                    children: [
                      if (hasTime) ...[
                        Icon(Icons.access_time_rounded, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(timeDisplay, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        const SizedBox(width: 12),
                      ],
                      if (!item.isManual && item.dataUrl.contains('chaoxing.com')) ...[
                        Icon(Icons.open_in_new_rounded, size: 12, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text('在学习通里完成', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ] else if (item.isManual) ...[
                        Icon(Icons.edit_note_rounded, size: 14, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text('手动添加', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (item.isManual) {
      return Dismissible(
        key: Key(item.id),
        background: _buildDismissBackground(isDelete: true),
        secondaryBackground: _buildDismissBackground(isDelete: false, isArchive: item.status != HomeworkStatus.archived),
        onDismissed: (direction) {
          if (direction == DismissDirection.endToStart) {
            // 左滑：存档/撤销存档
            final isArchiving = item.status != HomeworkStatus.archived;
            ref.read(homeworkProvider.notifier).setArchived(item.id, isArchiving);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isArchiving ? '已移至存档' : '已移出存档'), duration: const Duration(seconds: 2)));
          } else {
            // 右滑：删除
            final oldList = ref.read(homeworkProvider).value ?? [];
            ref.read(homeworkProvider.notifier).deleteHomework(item.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('已删除作业'),
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: '撤销',
                  onPressed: () => ref.read(homeworkProvider.notifier).restoreList(oldList),
                ),
              ),
            );
          }
        },
        child: content,
      );
    }
    return content;
  }

  Widget _buildDismissBackground({required bool isDelete, bool isArchive = true}) {
    return Container(
      color: isDelete ? Colors.red[400] : Colors.blue[400],
      alignment: isDelete ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Icon(
        isDelete ? Icons.delete_outline : (isArchive ? Icons.archive_outlined : Icons.unarchive_outlined),
        color: Colors.white,
      ),
    );
  }

  void _showAddHomeworkSheet(BuildContext context) {
    String title = '';
    String course = '';
    DateTime? endTime;
    String remarks = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
          ),
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: '准备做什么？', 
                    border: InputBorder.none, 
                    hintStyle: TextStyle(fontSize: 18),
                    fillColor: Colors.white,
                  ),
                  style: const TextStyle(fontSize: 18),
                  onChanged: (v) => title = v,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.history_edu_rounded, 
                        size: 22, 
                        color: course.isNotEmpty ? const Color(0xFF00E676) : Colors.grey
                      ),
                      onPressed: () async {
                        if (course.isNotEmpty) {
                          setSheetState(() => course = '');
                        } else {
                          final val = await _showInputDialog('课程名称', '输入所属课程');
                          if (val != null && val.trim().isNotEmpty) setSheetState(() => course = val);
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.schedule_rounded, 
                        size: 22, 
                        color: endTime != null ? const Color(0xFF00E676) : Colors.grey
                      ),
                      onPressed: () async {
                        if (endTime != null) {
                          setSheetState(() => endTime = null);
                        } else {
                          final date = await showDatePicker(
                            context: context, 
                            initialDate: DateTime.now(), 
                            firstDate: DateTime.now(), 
                            lastDate: DateTime.now().add(const Duration(days: 365))
                          );
                          if (date != null && context.mounted) {
                            final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                            if (time != null) setSheetState(() => endTime = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                          }
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.notes, 
                        size: 22, 
                        color: remarks.isNotEmpty ? const Color(0xFF00E676) : Colors.grey
                      ),
                      onPressed: () async {
                        if (remarks.isNotEmpty) {
                          setSheetState(() => remarks = '');
                        } else {
                          final val = await _showInputDialog('备注', '添加备注信息');
                          if (val != null && val.trim().isNotEmpty) setSheetState(() => remarks = val);
                        }
                      },
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        if (title.trim().isNotEmpty) {
                          ref.read(homeworkProvider.notifier).addManualHomework(title: title, courseName: course, endTime: endTime, remarks: remarks);
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('保存', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00E676))),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _showInputDialog(String title, String hint) async {
    String val = '';
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(autofocus: true, decoration: InputDecoration(hintText: hint), onChanged: (v) => val = v),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, val), child: const Text('确定')),
        ],
      ),
    );
  }

  void _showHomeworkDetailDialog(HomeworkModel item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        title: Text(item.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.courseName.isNotEmpty) ...[
              const Text('所属课程', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text(item.courseName, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
            ],
            if (item.endTime != null) ...[
              const Text('截止时间', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text(DateFormat('yyyy-MM-dd HH:mm').format(item.endTime!), style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
            ],
            if (item.remarks.isNotEmpty) ...[
              const Text('备注', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text(item.remarks, style: const TextStyle(fontSize: 16)),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
        ],
      ),
    );
  }

  final _logger = Logger();
}
