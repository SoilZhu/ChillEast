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

  static final List<FunctionItem> _masterPool = [
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
  ];

  AppearanceNotifier() : super(AppearanceState(
    homeItems: _getDefaultHomeItems(),
    functionItems: _getDefaultFunctionItems(),
  )) {
    _loadSettings();
  }

  static List<FunctionItem> _getDefaultHomeItems() {
    final homeIds = ['payment_code', 'library', 'empty_classroom', 'xgxt', 'repairs', 'bus', 'score'];
    return _masterPool.where((item) => homeIds.contains(item.id)).toList();
  }

  static List<FunctionItem> _getDefaultFunctionItems() {
    // 默认全选，按照指定顺序
    final functionIds = [
      'payment_code', 'recharge', 'ele_recharge', 'library', 'empty_classroom', 'repairs', 
      'gym', 'xgxt', 'teaching_eval', 'score', 'vpn', 'campus_card', 'bus', 'cs_bus'
    ];
    return functionIds.map((id) => _masterPool.firstWhere((item) => item.id == id)).toList();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    final homeJson = prefs.getString(_homeItemsKey);
    final funcJson = prefs.getString(_functionItemsKey);

    List<FunctionItem> homeItems = state.homeItems;
    List<FunctionItem> funcItems = state.functionItems;

    if (homeJson != null) {
      try {
        final decoded = json.decode(homeJson) as List;
        homeItems = _mergeWithMaster(decoded);
      } catch (e) {
        debugPrint('Error loading home items: $e');
      }
    }

    if (funcJson != null) {
      try {
        final decoded = json.decode(funcJson) as List;
        funcItems = _mergeWithMaster(decoded);
      } catch (e) {
        debugPrint('Error loading function items: $e');
      }
    }

    state = state.copyWith(homeItems: homeItems, functionItems: funcItems);
  }

  List<FunctionItem> _mergeWithMaster(List decoded) {
    List<FunctionItem> items = [];
    for (var data in decoded) {
      final id = data['id'];
      final template = _masterPool.firstWhere((item) => item.id == id, orElse: () => const FunctionItem(id: 'unknown', label: '未知', icon: Icons.help_outline, color: Colors.grey));
      if (template.id != 'unknown') {
        items.add(FunctionItem.fromJson(data, template));
      }
    }
    
    // 检查是否有 masterPool 中新增的项（不在保存的列表中）
    final defaultIds = _getDefaultFunctionItems().map((e) => e.id).toList();
    for (var masterItem in _masterPool) {
      if (!items.any((item) => item.id == masterItem.id)) {
        // 如果是新项，如果在默认列表中，则默认显示
        items.add(masterItem.copyWith(isVisible: defaultIds.contains(masterItem.id)));
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

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_homeItemsKey, json.encode(state.homeItems.map((e) => e.toJson()).toList()));
    await prefs.setString(_functionItemsKey, json.encode(state.functionItems.map((e) => e.toJson()).toList()));
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
    final isHome = listType == 'home';
    final items = List<FunctionItem>.from(isHome ? state.homeItems : state.functionItems);
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

    if (isHome) {
      updateHomeItems(items);
    } else {
      updateFunctionItems(items);
    }
  }
}
