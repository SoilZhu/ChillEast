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

  const AppearanceState({
    required this.homeItems,
    required this.functionItems,
  });

  AppearanceState copyWith({
    List<FunctionItem>? homeItems,
    List<FunctionItem>? functionItems,
  }) {
    return AppearanceState(
      homeItems: homeItems ?? this.homeItems,
      functionItems: functionItems ?? this.functionItems,
    );
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
      default:
        return label;
    }
  }
}
