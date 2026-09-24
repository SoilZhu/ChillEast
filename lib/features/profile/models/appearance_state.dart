import 'package:flutter/material.dart';
import '../../../core/utils/l10n_extension.dart';

class FunctionItem {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final bool isVisible;

  const FunctionItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    this.isVisible = true,
  });

  FunctionItem copyWith({
    String? label,
    IconData? icon,
    Color? color,
    bool? isVisible,
  }) {
    return FunctionItem(
      id: id,
      label: label ?? this.label,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isVisible: isVisible ?? this.isVisible,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'isVisible': isVisible,
    };
  }

  factory FunctionItem.fromJson(Map<String, dynamic> json, FunctionItem template) {
    return template.copyWith(
      isVisible: json['isVisible'] ?? template.isVisible,
    );
  }
}

class AppearanceState {
  final List<FunctionItem> homeItems;
  final List<FunctionItem> functionItems;
  final List<FunctionItem> feedItems;
  final List<String> functionGroupOrder;
  final List<String> hiddenFunctionGroups;

  const AppearanceState({
    required this.homeItems,
    required this.functionItems,
    required this.feedItems,
    required this.functionGroupOrder,
    required this.hiddenFunctionGroups,
  });

  AppearanceState copyWith({
    List<FunctionItem>? homeItems,
    List<FunctionItem>? functionItems,
    List<FunctionItem>? feedItems,
    List<String>? functionGroupOrder,
    List<String>? hiddenFunctionGroups,
  }) {
    return AppearanceState(
      homeItems: homeItems ?? this.homeItems,
      functionItems: functionItems ?? this.functionItems,
      feedItems: feedItems ?? this.feedItems,
      functionGroupOrder: functionGroupOrder ?? this.functionGroupOrder,
      hiddenFunctionGroups: hiddenFunctionGroups ?? this.hiddenFunctionGroups,
    );
  }
}

/// 功能页分组：成员 id 固定归属，组内展示顺序来自 functionItems
class FunctionGroup {
  final String titleKey;
  final List<String> ids;
  const FunctionGroup({required this.titleKey, required this.ids});
}

const List<FunctionGroup> functionGroups = [
  FunctionGroup(
      titleKey: 'groupPayment',
      ids: ['payment_code', 'recharge', 'ele_recharge']),
  FunctionGroup(
      titleKey: 'groupStudy',
      ids: ['library', 'empty_classroom', 'score']),
  FunctionGroup(
      titleKey: 'groupLife',
      ids: ['repairs', 'leave', 'questionnaire', 'sunshine']),
  FunctionGroup(
      titleKey: 'groupTravel',
      ids: ['bus', 'cs_bus', 'campus_bus_route']),
  FunctionGroup(titleKey: 'groupTools', ids: ['vpn']),
  FunctionGroup(
      titleKey: 'groupMiniApps',
      ids: ['xgxt', 'teaching_eval', 'gym', 'campus_card']),
];

String functionGroupTitle(BuildContext context, String titleKey) {
  final l10n = context.l10n;
  switch (titleKey) {
    case 'groupPayment':
      return l10n.groupPayment;
    case 'groupStudy':
      return l10n.groupStudy;
    case 'groupLife':
      return l10n.groupLife;
    case 'groupTravel':
      return l10n.groupTravel;
    case 'groupTools':
      return l10n.groupTools;
    case 'groupMiniApps':
      return l10n.groupMiniApps;
    default:
      return '';
  }
}

extension FunctionItemLocalization on FunctionItem {
  String getLocalizedTitle(BuildContext context) {
    final l10n = context.l10n;
    switch (id) {
      case 'sunshine':
        return l10n.funcSunshine;
      case 'questionnaire':
        return l10n.funcQuestionnaire;
      case 'leave':
        return l10n.funcLeave;
      case 'payment_code':
        return l10n.funcPaymentCode;
      case 'recharge':
        return l10n.funcRecharge;
      case 'library':
        return l10n.funcLibrary;
      case 'empty_classroom':
        return l10n.funcEmptyClassroom;
      case 'xgxt':
        return l10n.funcXgxt;
      case 'repairs':
        return l10n.funcRepairs;
      case 'gym':
        return l10n.funcGym;
      case 'teaching_eval':
        return l10n.funcTeachingEval;
      case 'score':
        return l10n.funcScore;
      case 'vpn':
        return l10n.funcVpn;
      case 'campus_card':
        return l10n.funcCampusCard;
      case 'ele_recharge':
        return l10n.funcEleRecharge;
      case 'bus':
        return l10n.funcBus;
      case 'cs_bus':
        return l10n.funcCsBus;
      case 'campus_bus_route':
        return l10n.funcCampusBusRoute;
      case 'feed_quick':
        return l10n.quickActions;
      case 'feed_library':
        return l10n.libraryReservation;
      case 'feed_agenda':
        return l10n.todayAgenda;
      case 'feed_questionnaire':
        return l10n.pendingQuestionnaires;
      case 'feed_leave':
        return l10n.funcLeave;
      case 'feed_repair':
        return l10n.repairWorkOrders;
      default:
        return label;
    }
  }
}
