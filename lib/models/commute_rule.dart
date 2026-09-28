import 'expense_model.dart';

class CommuteItemTemplate {
  final ExpenseCategory category;
  final String description;
  final double amount;

  const CommuteItemTemplate({
    required this.category,
    required this.description,
    required this.amount,
  });

  Map<String, dynamic> toMap() {
    return {
      'category': category.name,
      'description': description,
      'amount': amount,
    };
  }

  factory CommuteItemTemplate.fromMap(Map<String, dynamic> map) {
    return CommuteItemTemplate(
      category: ExpenseCategory.fromString(map['category'] as String?),
      description: (map['description'] as String?) ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  CommuteItemTemplate copyWith({
    ExpenseCategory? category,
    String? description,
    double? amount,
  }) {
    return CommuteItemTemplate(
      category: category ?? this.category,
      description: description ?? this.description,
      amount: amount ?? this.amount,
    );
  }
}

class CommuteConfig {
  final bool enabled;
  final int insertHour;
  final int insertMinute;
  final int notifyHour;
  final int notifyMinute;
  final List<CommuteItemTemplate> items;
  final String? lastInsertedDate;
  final String? pendingReviewBatchId;

  const CommuteConfig({
    this.enabled = true,
    this.insertHour = 7,
    this.insertMinute = 0,
    this.notifyHour = 9,
    this.notifyMinute = 30,
    required this.items,
    this.lastInsertedDate,
    this.pendingReviewBatchId,
  });

  static List<CommuteItemTemplate> get defaultItems => const [
        CommuteItemTemplate(
          category: ExpenseCategory.travel,
          description: 'cng vara',
          amount: 80.0,
        ),
        CommuteItemTemplate(
          category: ExpenseCategory.travel,
          description: 'metro vara',
          amount: 36.0,
        ),
      ];

  factory CommuteConfig.initial() {
    return CommuteConfig(
      enabled: true,
      insertHour: 7,
      insertMinute: 0,
      notifyHour: 9,
      notifyMinute: 30,
      items: defaultItems,
      lastInsertedDate: null,
      pendingReviewBatchId: null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'insertHour': insertHour,
      'insertMinute': insertMinute,
      'notifyHour': notifyHour,
      'notifyMinute': notifyMinute,
      'items': items.map((e) => e.toMap()).toList(),
      'lastInsertedDate': lastInsertedDate,
      'pendingReviewBatchId': pendingReviewBatchId,
    };
  }

  factory CommuteConfig.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'] as List<dynamic>?;
    final parsedItems = rawItems != null
        ? rawItems
            .map((e) => CommuteItemTemplate.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList()
        : defaultItems;

    return CommuteConfig(
      enabled: (map['enabled'] as bool?) ?? true,
      insertHour: (map['insertHour'] as num?)?.toInt() ?? 7,
      insertMinute: (map['insertMinute'] as num?)?.toInt() ?? 0,
      notifyHour: (map['notifyHour'] as num?)?.toInt() ?? 9,
      notifyMinute: (map['notifyMinute'] as num?)?.toInt() ?? 30,
      items: parsedItems.isNotEmpty ? parsedItems : defaultItems,
      lastInsertedDate: map['lastInsertedDate'] as String?,
      pendingReviewBatchId: map['pendingReviewBatchId'] as String?,
    );
  }

  CommuteConfig copyWith({
    bool? enabled,
    int? insertHour,
    int? insertMinute,
    int? notifyHour,
    int? notifyMinute,
    List<CommuteItemTemplate>? items,
    String? lastInsertedDate,
    String? pendingReviewBatchId,
    bool clearPendingReview = false,
  }) {
    return CommuteConfig(
      enabled: enabled ?? this.enabled,
      insertHour: insertHour ?? this.insertHour,
      insertMinute: insertMinute ?? this.insertMinute,
      notifyHour: notifyHour ?? this.notifyHour,
      notifyMinute: notifyMinute ?? this.notifyMinute,
      items: items ?? this.items,
      lastInsertedDate: lastInsertedDate ?? this.lastInsertedDate,
      pendingReviewBatchId: clearPendingReview ? null : (pendingReviewBatchId ?? this.pendingReviewBatchId),
    );
  }
}
