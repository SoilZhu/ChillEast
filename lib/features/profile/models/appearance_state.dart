import 'package:flutter/material.dart';

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
