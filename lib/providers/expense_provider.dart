import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense_model.dart';
import '../services/expense_repository.dart';

enum DateFilterMode {
  allTime('All time'),
  today('Today'),
  thisMonth('This month'),
  customDate('Specific date');

  final String label;
  const DateFilterMode(this.label);
}

class ExpenseProvider extends ChangeNotifier {
  final ExpenseRepository _repository = ExpenseRepository();

  List<ExpenseItem> _expenses = [];
  double _monthlyBudget = ExpenseRepository.defaultMonthlyBudget;
  DateFilterMode _filterMode = DateFilterMode.thisMonth;
  DateTime? _customSelectedDate;
  int _activeTabIndex = 0; // 0 = Tracker, 1 = Insights
  DateTime _lastSavedAt = DateTime.now();
  bool _isLoading = true;

  // Initial visible rows count (5 rows visible initially)
  int _visibleLimit = 5;

  ExpenseProvider() {
    _init();
  }

  bool get isLoading => _isLoading;
  List<ExpenseItem> get allExpenses => _expenses;
  double get monthlyBudget => _monthlyBudget;
  DateFilterMode get filterMode => _filterMode;
  DateTime? get customSelectedDate => _customSelectedDate;
  int get activeTabIndex => _activeTabIndex;
  DateTime get lastSavedAt => _lastSavedAt;
  int get visibleLimit => _visibleLimit;

  String get filterLabel {
    switch (_filterMode) {
      case DateFilterMode.allTime:
        return 'All time';
      case DateFilterMode.today:
        return 'Today';
      case DateFilterMode.thisMonth:
        return DateFormat('MMMM yyyy').format(DateTime.now());
      case DateFilterMode.customDate:
        if (_customSelectedDate != null) {
          return DateFormat('dd MMM yyyy').format(_customSelectedDate!);
        }
        return 'Specific date';
    }
  }

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    _expenses = await _repository.loadExpenses();
    _monthlyBudget = await _repository.loadBudget();
    _isLoading = false;
    notifyListeners();
  }

  void setActiveTab(int index) {
    if (_activeTabIndex != index) {
      _activeTabIndex = index;
      notifyListeners();
    }
  }

  void setFilterMode(DateFilterMode mode, {DateTime? customDate}) {
    _filterMode = mode;
    _customSelectedDate = customDate;
    notifyListeners();
  }

  // Check if an expense matches the current date filter
  bool _matchesDateFilter(ExpenseItem item) {
    if (item.date == null) return true;
    final now = DateTime.now();

    switch (_filterMode) {
      case DateFilterMode.allTime:
        return true;
      case DateFilterMode.today:
        return item.date!.year == now.year &&
            item.date!.month == now.month &&
            item.date!.day == now.day;
      case DateFilterMode.thisMonth:
        return item.date!.year == now.year && item.date!.month == now.month;
      case DateFilterMode.customDate:
        if (_customSelectedDate == null) return true;
        return item.date!.year == _customSelectedDate!.year &&
            item.date!.month == _customSelectedDate!.month &&
            item.date!.day == _customSelectedDate!.day;
    }
  }

  // Active recorded expenses (excluding empty placeholders) matching current filter
  List<ExpenseItem> get activeExpenses {
    return _expenses.where((e) => !e.isPlaceholder && e.amount > 0 && _matchesDateFilter(e)).toList();
  }

  // Rows displayed in the sheet table (initially 5 rows SL 1..5, expandable with +)
  List<ExpenseItem> get tableRows {
    final filtered = _expenses.where((e) {
      if (e.isPlaceholder) return true;
      return _matchesDateFilter(e);
    }).toList();

    // Ensure we show at least _visibleLimit rows
    while (filtered.length < _visibleLimit) {
      final blank = _repository.createNewBlankItem(isPlaceholder: true);
      _expenses.add(blank);
      filtered.add(blank);
    }

    if (filtered.length > _visibleLimit) {
      return filtered.sublist(0, _visibleLimit);
    }
    return filtered;
  }

  double get totalSpent {
    double sum = 0.0;
    for (final item in activeExpenses) {
      sum += item.amount;
    }
    return sum;
  }

  int get totalEntriesCount {
    return activeExpenses.length;
  }

  double get budgetDelta {
    return _monthlyBudget - totalSpent;
  }

  bool get isUnderBudget => budgetDelta >= 0;

  Map<ExpenseCategory, double> get categoryBreakdown {
    final map = <ExpenseCategory, double>{};
    for (final item in activeExpenses) {
      final cat = item.category ?? ExpenseCategory.other;
      map[cat] = (map[cat] ?? 0.0) + item.amount;
    }
    return map;
  }

  // Add a new row when the '+' icon is tapped
  Future<void> addNewRow({
    DateTime? date,
    ExpenseCategory? category,
    String description = '',
    double amount = 0.0,
  }) async {
    // Check if there is an untouched placeholder row in tableRows to activate
    final firstPlaceholderIndex = _expenses.indexWhere((e) => e.isPlaceholder);
    if (firstPlaceholderIndex != -1) {
      _expenses[firstPlaceholderIndex] = ExpenseItem(
        id: _expenses[firstPlaceholderIndex].id,
        date: date ?? DateTime.now(),
        category: category ?? ExpenseCategory.food,
        description: description,
        amount: amount,
        isPlaceholder: false,
        createdAt: DateTime.now(),
      );
      // Append a new blank row at the end so it keeps expanding
      final newBlank = _repository.createNewBlankItem(isPlaceholder: true);
      _expenses.add(newBlank);
      _visibleLimit++;
    } else {
      final newItem = ExpenseItem(
        id: _repository.createNewBlankItem().id,
        date: date ?? DateTime.now(),
        category: category ?? ExpenseCategory.food,
        description: description,
        amount: amount,
        isPlaceholder: false,
        createdAt: DateTime.now(),
      );
      _expenses.add(newItem);
      _visibleLimit++;
    }

    _lastSavedAt = DateTime.now();
    notifyListeners();
    await _repository.saveExpenses(_expenses);
  }

  Future<void> updateCell({
    required String id,
    DateTime? date,
    ExpenseCategory? category,
    String? description,
    double? amount,
  }) async {
    final index = _expenses.indexWhere((e) => e.id == id);
    if (index == -1) return;

    final current = _expenses[index];
    final wasPlaceholder = current.isPlaceholder;

    final updated = current.copyWith(
      date: date ?? current.date ?? DateTime.now(),
      category: category ?? current.category,
      description: description ?? current.description,
      amount: amount ?? current.amount,
      isPlaceholder: false,
    );

    _expenses[index] = updated;

    // If a placeholder was filled, add another placeholder at bottom to keep rows available
    if (wasPlaceholder) {
      final newPlaceholder = _repository.createNewBlankItem(isPlaceholder: true);
      _expenses.add(newPlaceholder);
      _visibleLimit++;
    }

    _lastSavedAt = DateTime.now();
    notifyListeners();
    await _repository.saveExpenses(_expenses);
  }

  Future<void> deleteRow(String id) async {
    _expenses.removeWhere((e) => e.id == id);
    if (_visibleLimit > _expenses.length) {
      _visibleLimit = _expenses.length.clamp(5, 9999);
    }
    _lastSavedAt = DateTime.now();
    notifyListeners();
    await _repository.saveExpenses(_expenses);
  }

  Future<void> updateBudget(double newBudget) async {
    _monthlyBudget = newBudget;
    _lastSavedAt = DateTime.now();
    notifyListeners();
    await _repository.saveBudget(newBudget);
  }

  Future<void> resetToBlank() async {
    _expenses = _repository.getInitialSeedData();
    _monthlyBudget = ExpenseRepository.defaultMonthlyBudget;
    _visibleLimit = 5;
    _filterMode = DateFilterMode.thisMonth;
    _lastSavedAt = DateTime.now();
    notifyListeners();
    await _repository.saveExpenses(_expenses);
    await _repository.saveBudget(_monthlyBudget);
  }

  String generateCsv() {
    final buffer = StringBuffer();
    buffer.writeln('SL,Date,Category,Description,Amount (BDT)');
    int sl = 1;
    for (final item in activeExpenses) {
      final dateStr = item.date != null ? DateFormat('dd/MM/yyyy').format(item.date!) : '';
      final cat = item.category?.label ?? '';
      final desc = '"${item.description.replaceAll('"', '""')}"';
      final amt = item.amount.toStringAsFixed(2);
      buffer.writeln('$sl,$dateStr,$cat,$desc,$amt');
      sl++;
    }
    return buffer.toString();
  }
}
