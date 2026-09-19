import 'package:flutter/material.dart';

enum ExpenseCategory {
  food('Food', Color(0xFFFEF3E2), Color(0xFF9A5B13), Icons.restaurant_rounded),
  travel('Travel', Color(0xFFEBF2FF), Color(0xFF3B62B7), Icons.directions_subway_rounded),
  home('Home', Color(0xFFF3E8FF), Color(0xFF7E3AF2), Icons.home_rounded),
  health('Health', Color(0xFFE1F8EC), Color(0xFF12824C), Icons.medical_services_rounded),
  shopping('Shopping', Color(0xFFFFF0F5), Color(0xFFC026D3), Icons.shopping_bag_rounded),
  entertainment('Entertainment', Color(0xFFFFF7ED), Color(0xFFEA580C), Icons.movie_rounded),
  bills('Bills', Color(0xFFEFF6FF), Color(0xFF1D4ED8), Icons.receipt_rounded),
  other('Other', Color(0xFFF3F4F6), Color(0xFF4B5563), Icons.more_horiz_rounded);

  final String label;
  final Color bgColor;
  final Color textColor;
  final IconData icon;

  const ExpenseCategory(this.label, this.bgColor, this.textColor, this.icon);

  static ExpenseCategory fromString(String? name) {
    if (name == null) return ExpenseCategory.other;
    return ExpenseCategory.values.firstWhere(
      (cat) => cat.name.toLowerCase() == name.toLowerCase() || cat.label.toLowerCase() == name.toLowerCase(),
      orElse: () => ExpenseCategory.other,
    );
  }
}

class ExpenseItem {
  final String id;
  final DateTime? date;
  final ExpenseCategory? category;
  final String description;
  final double amount;
  final bool isPlaceholder;
  final DateTime createdAt;

  const ExpenseItem({
    required this.id,
    this.date,
    this.category,
    this.description = '',
    this.amount = 0.0,
    this.isPlaceholder = false,
    required this.createdAt,
  });

  ExpenseItem copyWith({
    String? id,
    DateTime? date,
    ExpenseCategory? category,
    bool clearCategory = false,
    String? description,
    double? amount,
    bool? isPlaceholder,
    DateTime? createdAt,
  }) {
    return ExpenseItem(
      id: id ?? this.id,
      date: date ?? this.date,
      category: clearCategory ? null : (category ?? this.category),
      description: description ?? this.description,
      amount: amount ?? this.amount,
      isPlaceholder: isPlaceholder ?? this.isPlaceholder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date?.toIso8601String(),
      'category': category?.name,
      'description': description,
      'amount': amount,
      'isPlaceholder': isPlaceholder,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ExpenseItem.fromMap(Map<String, dynamic> map) {
    return ExpenseItem(
      id: map['id'] as String,
      date: map['date'] != null ? DateTime.tryParse(map['date'] as String) : null,
      category: map['category'] != null ? ExpenseCategory.fromString(map['category'] as String) : null,
      description: (map['description'] as String?) ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      isPlaceholder: (map['isPlaceholder'] as bool?) ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
