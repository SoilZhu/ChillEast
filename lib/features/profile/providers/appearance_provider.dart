import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/appearance_state.dart';

final appearanceProvider = StateNotifierProvider<AppearanceNotifier, AppearanceState>((ref) {
  return AppearanceNotifier();
});

class AppearanceNotifier extends StateNotifier<AppearanceState> {
  static const String _homeItemsKey = 'home_function_items';
  static const String _functionItemsKey = 'function_page_items';
  static const String _feedItemsKey = 'home_feed_items';

  static final List<FunctionItem> _masterPool = [
    const FunctionItem(id: 'sunshine', label: '阳光服务', icon: Icons.wb_sunny_outlined, color: Color(0xFF09C489)),
    const FunctionItem(id: 'questionnaire', label: '学工问卷', icon: Icons.assignment_outlined, color: Color(0xFF3476E6)),
    const FunctionItem(id: 'leave', label: '请假申请', icon: Icons.event_note_outlined, color: Color(0xFF009688)),
    const FunctionItem(id: 'payment_code', label: '付款码', icon: Icons.qr_code_scanner_outlined, color: Color(0xFF00C853)),
    const FunctionItem(id: 'recharge', label: '校园卡充值', icon: Icons.account_balance_wallet_outlined, color: Colors.orange),
    const FunctionItem(id: 'library', label: '图书馆', icon: Icons.library_books_outlined, color: Color(0xFF795548)),
    const FunctionItem(id: 'empty_classroom', label: '空教室', icon: Icons.meeting_room_outlined, color: Color(0xFF9C27B0)),
    const FunctionItem(id: 'xgxt', label: '学工系统', icon: Icons.connect_without_contact_outlined, color: Color(0xFF3476E6)),
    const FunctionItem(id: 'repairs', label: '报修平台', icon: Icons.handyman_outlined, color: Colors.blueGrey),
    const FunctionItem(id: 'gym', label: '场馆预约', icon: Icons.sports_basketball_outlined, color: Colors.pink),
    const FunctionItem(id: 'teaching_eval', label: '教评系统', icon: Icons.rate_review_outlined, color: Colors.cyan),
    const FunctionItem(id: 'score', label: '成绩查询', icon: Icons.article_outlined, color: Color(0xFFE63476)),
    const FunctionItem(id: 'vpn', label: 'VPN转换', icon: Icons.vpn_lock_outlined, color: Color(0xFF607D8B)),
    const FunctionItem(id: 'campus_card', label: '校园卡', icon: Icons.credit_card_outlined, color: Color(0xFF008268)),
    const FunctionItem(id: 'ele_recharge', label: '电费充值', icon: Icons.bolt_outlined, color: Colors.yellow),
    const FunctionItem(id: 'bus', label: '实时校车', icon: Icons.airport_shuttle_outlined, color: Color(0xFF34E676)),
    const FunctionItem(id: 'cs_bus', label: '长沙实时公交', icon: Icons.directions_bus_outlined, color: Color(0xFF2196F3)),
    const FunctionItem(id: 'campus_bus_route', label: '校内公交线路', icon: Icons.alt_route_rounded, color: Color(0xFF00A86B)),
  ];

  AppearanceNotifier() : super(AppearanceState(
    homeItems: _getDefaultHomeItems(),
    functionItems: _getDefaultFunctionItems(),
    feedItems: _getDefaultFeedItems(),
  )) {
    _loadSettings();
  }

  static const List<String> _defaultVisibleHomeIds = ['payment_code', 'library', 'empty_classroom', 'xgxt', 'repairs', 'bus', 'score'];

  /// 首页信息流区块（默认全显示，顺序即展示顺序）
  static final List<FunctionItem> _feedPool = [
    const FunctionItem(id: 'feed_quick', label: '快捷功能', icon: Icons.apps_rounded, color: Color(0xFF09C489)),
    const FunctionItem(id: 'feed_library', label: '图书馆预约', icon: Icons.local_library_outlined, color: Color(0xFF795548)),
    const FunctionItem(id: 'feed_agenda', label: '今日日程', icon: Icons.calendar_today_outlined, color: Color(0xFF09C489)),
    const FunctionItem(id: 'feed_questionnaire', label: '待完成的问卷', icon: Icons.assignment_outlined, color: Color(0xFF2E7D32)),
    const FunctionItem(id: 'feed_leave', label: '请假申请', icon: Icons.event_note_outlined, color: Color(0xFF009688)),
    const FunctionItem(id: 'feed_repair', label: '报修工单', icon: Icons.handyman_outlined, color: Colors.blueGrey),
  ];

  static List<FunctionItem> _getDefaultFeedItems() {
    return List<FunctionItem>.from(_feedPool);
  }

  static List<FunctionItem> _getDefaultHomeItems() {
    // 首页设置页应包含功能页的全部功能，默认只有首页的 7 个按钮显示，其余隐藏
    return _masterPool
        .map((item) => item.copyWith(isVisible: _defaultVisibleHomeIds.contains(item.id)))
        .toList();
  }

  static List<FunctionItem> _getDefaultFunctionItems() {
    // 默认全选，按照指定顺序
    final functionIds = [
      'payment_code', 'recharge', 'ele_recharge', 'library', 'empty_classroom', 'repairs', 
      'sunshine', 'questionnaire', 'leave', 'gym', 'xgxt', 'teaching_eval', 'score', 'vpn', 'campus_card', 'bus', 'cs_bus', 'campus_bus_route'
    ];
    final items = functionIds.map((id) => _masterPool.firstWhere((item) => item.id == id)).toList();
    // 兜底：只加了 _masterPool 忘记加 functionIds 的新功能，自动追加为可见，避免新装用户丢失
    for (final masterItem in _masterPool) {
      if (!items.any((e) => e.id == masterItem.id)) {
        items.add(masterItem);
      }
    }
    return items;
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    final homeJson = prefs.getString(_homeItemsKey);
    final funcJson = prefs.getString(_functionItemsKey);
    final feedJson = prefs.getString(_feedItemsKey);

    List<FunctionItem> homeItems = state.homeItems;
    List<FunctionItem> funcItems = state.functionItems;
    List<FunctionItem> feedItems = state.feedItems;

    if (homeJson != null) {
      try {
        final decoded = json.decode(homeJson) as List;
        homeItems = _mergeWithMaster(decoded, isHome: true);
      } catch (e) {
        debugPrint('Error loading home items: $e');
      }
    }

    if (funcJson != null) {
      try {
        final decoded = json.decode(funcJson) as List;
        funcItems = _mergeWithMaster(decoded, isHome: false);
      } catch (e) {
        debugPrint('Error loading function items: $e');
      }
    }

    if (feedJson != null) {
      try {
        final decoded = json.decode(feedJson) as List;
        feedItems = _mergeFeedItems(decoded);
      } catch (e) {
        debugPrint('Error loading feed items: $e');
      }
    }

    state = state.copyWith(homeItems: homeItems, functionItems: funcItems, feedItems: feedItems);
  }

  List<FunctionItem> _mergeWithMaster(List decoded, {required bool isHome}) {
    List<FunctionItem> items = [];
    for (var data in decoded) {
      final id = data['id'];
      final template = _masterPool.firstWhere((item) => item.id == id, orElse: () => const FunctionItem(id: 'unknown', label: '未知', icon: Icons.help_outline, color: Colors.grey));
      if (template.id != 'unknown') {
        items.add(FunctionItem.fromJson(data, template));
      }
    }
    
    // 检查是否有 masterPool 中新增的项（不在保存的列表中）
    // 老用户已保存的首页列表只有 7 项，缺的 8 项会在这里补上并默认隐藏，实现迁移
    for (var masterItem in _masterPool) {
      if (!items.any((item) => item.id == masterItem.id)) {
        // 功能页新增项默认显示，首页新增项默认隐藏（除非在首页默认显示名单里）
        final defaultVisible = isHome
            ? _defaultVisibleHomeIds.contains(masterItem.id)
            : true;
        items.add(masterItem.copyWith(isVisible: defaultVisible));
      }
    }

    return items;
  }

  /// 信息流合并：保留用户顺序与显隐，新增区块默认追加为可见
  List<FunctionItem> _mergeFeedItems(List decoded) {
    final items = <FunctionItem>[];
    for (var data in decoded) {
      final id = data['id'];
      FunctionItem? template;
      for (final master in _feedPool) {
        if (master.id == id) {
          template = master;
          break;
        }
      }
      if (template != null) {
        items.add(FunctionItem.fromJson(data, template));
      }
    }

    for (var masterItem in _feedPool) {
      if (!items.any((item) => item.id == masterItem.id)) {
        // 快捷功能是后加入的，老用户存档里没有，默认插到最顶部
        if (masterItem.id == 'feed_quick') {
          items.insert(0, masterItem);
        } else {
          items.add(masterItem);
        }
      }
    }

    return items;
  }

  Future<void> updateHomeItems(List<FunctionItem> items) async {
    state = state.copyWith(homeItems: items);
    _saveSettings();
  }

  Future<void> updateFunctionItems(List<FunctionItem> items) async {
    state = state.copyWith(functionItems: items);
    _saveSettings();
  }

  Future<void> updateFeedItems(List<FunctionItem> items) async {
    state = state.copyWith(feedItems: items);
    _saveSettings();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_homeItemsKey, json.encode(state.homeItems.map((e) => e.toJson()).toList()));
    await prefs.setString(_functionItemsKey, json.encode(state.functionItems.map((e) => e.toJson()).toList()));
    await prefs.setString(_feedItemsKey, json.encode(state.feedItems.map((e) => e.toJson()).toList()));
  }

  void toggleItemVisibility(String listType, String itemId) {
    if (listType == 'home') {
      final newItems = state.homeItems.map((item) {
        if (item.id == itemId) {
          return item.copyWith(isVisible: !item.isVisible);
        }
        return item;
      }).toList();
      updateHomeItems(newItems);
    } else if (listType == 'feed') {
      final newItems = state.feedItems.map((item) {
        if (item.id == itemId) {
          return item.copyWith(isVisible: !item.isVisible);
        }
        return item;
      }).toList();
      updateFeedItems(newItems);
    } else {
      final newItems = state.functionItems.map((item) {
        if (item.id == itemId) {
          return item.copyWith(isVisible: !item.isVisible);
        }
        return item;
      }).toList();
      updateFunctionItems(newItems);
    }
  }

  void reorderItems(String listType, int oldIndex, int newIndex) {
    final items = List<FunctionItem>.from(
      listType == 'home'
          ? state.homeItems
          : (listType == 'feed' ? state.feedItems : state.functionItems),
    );
    final visibleCount = items.where((e) => e.isVisible).length;
    
    // 1. 修正 oldIndex (UI -> 数据)
    // UI 列表中，HeaderHidden 占据了 visibleCount 这个位置
    int realOldIndex = oldIndex;
    if (oldIndex > visibleCount) {
      realOldIndex = oldIndex - 1;
    } else if (oldIndex == visibleCount) {
      return; // 拖动的是标题，忽略
    }

    // 2. 修正 newIndex (UI -> 数据)
    int realNewIndex = newIndex;
    if (newIndex > visibleCount) {
      realNewIndex = newIndex - 1;
    }

    // 处理 ReorderableListView 的 newIndex 偏移特性
    if (realNewIndex > realOldIndex) realNewIndex -= 1;
    
    final movedItem = items.removeAt(realOldIndex);
    
    // 3. 判定新可见性
    // 如果 newIndex <= visibleCount，说明被拖到了标题之前（或原位），设为可见
    // 如果 newIndex > visibleCount，说明被拖到了标题之后，设为隐藏
    bool newVisibility = movedItem.isVisible;
    if (newIndex <= visibleCount) {
      newVisibility = true;
    } else {
      newVisibility = false;
    }

    final updatedItem = movedItem.copyWith(isVisible: newVisibility);
    
    // 4. 插入并重新排序，确保内存中的 list 始终保持 [Visible..., Hidden...]
    items.insert(realNewIndex > items.length ? items.length : realNewIndex, updatedItem);
    
    items.sort((a, b) {
      if (a.isVisible && !b.isVisible) return -1;
      if (!a.isVisible && b.isVisible) return 1;
      return 0;
    });

    if (listType == 'home') {
      updateHomeItems(items);
    } else if (listType == 'feed') {
      updateFeedItems(items);
    } else {
      updateFunctionItems(items);
    }
  }
}
