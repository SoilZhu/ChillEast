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
    const FunctionItem(id: 'settings', label: '设置', icon: Icons.settings_outlined, color: Colors.grey),
  ];

  AppearanceNotifier()
      : super(
          AppearanceState(
            homeItems: _getDefaultHomeItems(),
            functionItems: _getDefaultFunctionItems(),
          ),
        ) {
    _loadSettings();
  }

  static List<FunctionItem> _getDefaultHomeItems() {
    final homeIds = ['payment_code', 'library', 'empty_classroom', 'xgxt', 'repairs', 'bus', 'score'];
    final items = _masterPool.map((item) {
      return item.copyWith(isVisible: homeIds.contains(item.id));
    }).toList();

    items.sort((a, b) {
      if (a.isVisible && !b.isVisible) return -1;
      if (!a.isVisible && b.isVisible) return 1;
      if (a.isVisible && b.isVisible) {
        return homeIds.indexOf(a.id).compareTo(homeIds.indexOf(b.id));
      }
      return 0;
    });

    return items;
  }

  static List<FunctionItem> _getDefaultFunctionItems() {
    final functionIds = [
      'payment_code',
      'recharge',
      'ele_recharge',
      'library',
      'empty_classroom',
      'repairs',
      'gym',
      'xgxt',
      'teaching_eval',
      'score',
      'vpn',
      'campus_card',
      'bus',
      'cs_bus',
      'settings',
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
        final defaultHomeIds = _getDefaultHomeItems().where((e) => e.isVisible).map((e) => e.id).toList();
        homeItems = _mergeWithMaster(decoded, defaultHomeIds);
      } catch (e) {
        debugPrint('Error loading home items: $e');
      }
    }

    if (funcJson != null) {
      try {
        final decoded = json.decode(funcJson) as List;
        final defaultFuncIds = _getDefaultFunctionItems().where((e) => e.isVisible).map((e) => e.id).toList();
        funcItems = _mergeWithMaster(decoded, defaultFuncIds);
      } catch (e) {
        debugPrint('Error loading function items: $e');
      }
    }

    state = state.copyWith(homeItems: homeItems, functionItems: funcItems);
  }

  List<FunctionItem> _mergeWithMaster(List decoded, List<String> defaultIds) {
    final items = <FunctionItem>[];

    for (final data in decoded) {
      final id = data['id'];
      final template = _masterPool.firstWhere(
        (item) => item.id == id,
        orElse: () => const FunctionItem(
          id: 'unknown',
          label: '未知',
          icon: Icons.help_outline,
          color: Colors.grey,
        ),
      );
      if (template.id != 'unknown') {
        items.add(FunctionItem.fromJson(data, template));
      }
    }

    for (final masterItem in _masterPool) {
      if (!items.any((item) => item.id == masterItem.id)) {
        items.add(masterItem.copyWith(isVisible: defaultIds.contains(masterItem.id)));
      }
    }

    return items;
  }

  Future<void> updateHomeItems(List<FunctionItem> items) async {
    state = state.copyWith(homeItems: items);
    await _saveSettings();
  }

  Future<void> updateFunctionItems(List<FunctionItem> items) async {
    state = state.copyWith(functionItems: items);
    await _saveSettings();
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

    int realOldIndex = oldIndex;
    if (oldIndex > visibleCount) {
      realOldIndex = oldIndex - 1;
    } else if (oldIndex == visibleCount) {
      return;
    }

    int realNewIndex = newIndex;
    if (newIndex > visibleCount) {
      realNewIndex = newIndex - 1;
    }

    if (realNewIndex > realOldIndex) realNewIndex -= 1;

    final movedItem = items.removeAt(realOldIndex);

    bool newVisibility = movedItem.isVisible;
    if (newIndex <= visibleCount) {
      newVisibility = true;
    } else {
      newVisibility = false;
    }

    final updatedItem = movedItem.copyWith(isVisible: newVisibility);
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
