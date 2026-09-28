import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense_model.dart';
import '../services/expense_repository.dart';

enum DateFilterMode {
  allTime('All time'),
  today('Today'),
  thisMonth('This month'),
  monthlyDistribution('Monthly distribution'),
  customDate('Specific date');

  final String label;
  const DateFilterMode(this.label);
}

class ExpenseProvider extends ChangeNotifier {
  final ExpenseRepository _repository = ExpenseRepository();

  List<ExpenseItem> _expenses = [];
  List<ExpenseItem> _monthlyDistributionExpenses = [];
  double _monthlyBudget = ExpenseRepository.defaultMonthlyBudget;
  DateFilterMode _filterMode = DateFilterMode.thisMonth;
  DateTime? _customSelectedDate;
  int _activeTabIndex = 0; // 0 = Tracker, 1 = Insights
  DateTime _lastSavedAt = DateTime.now();
  bool _isLoading = true;
  int _extraEmptyRows = 2;

  ExpenseProvider() {
    _init();
  }

  bool get isLoading => _isLoading;
  List<ExpenseItem> get allExpenses => _expenses;
  List<ExpenseItem> get monthlyDistributionExpenses => _monthlyDistributionExpenses;
  double get monthlyBudget => _monthlyBudget;
  DateFilterMode get filterMode => _filterMode;
  DateTime? get customSelectedDate => _customSelectedDate;
  int get activeTabIndex => _activeTabIndex;
  DateTime get lastSavedAt => _lastSavedAt;
  int get visibleLimit => tableRows.length;
  bool get isMonthlyDistributionMode => _filterMode == DateFilterMode.monthlyDistribution;

  DateTime get currentEffectiveDate {
    if (_filterMode == DateFilterMode.customDate && _customSelectedDate != null) {
      return _customSelectedDate!;
    }
    return DateTime.now();
  }

  String get filterLabel {
    switch (_filterMode) {
      case DateFilterMode.allTime:
        return 'All time';
      case DateFilterMode.today:
        return 'Today';
      case DateFilterMode.thisMonth:
        return DateFormat('MMMM yyyy').format(DateTime.now());
      case DateFilterMode.monthlyDistribution:
        return 'Monthly distribution';
      case DateFilterMode.customDate:
        if (_customSelectedDate != null) {
          return DateFormat('dd MMM yyyy').format(_customSelectedDate!);
        }
        return 'Specific date';
    }
  }

  bool get isCloudSynced => _repository.userId != null && _repository.userId!.isNotEmpty;
  String? get lastSyncError => _repository.lastSyncError;

  Future<void> onUserChanged(String? uid) async {
    _repository.setUserId(uid);
    await _init();
  }

  Future<void> refreshFromCloud() async {
    await _init();
  }

  Future<bool> pushToCloud() async {
    if (_repository.userId == null || _repository.userId!.isEmpty) return false;
    await _repository.saveExpenses(_expenses);
    await _repository.saveMonthlyDistributionExpenses(_monthlyDistributionExpenses);
    await _repository.saveBudget(_monthlyBudget);
    notifyListeners();
    return _repository.lastSyncError == null;
  }

  Future<void> _init() async {
    _isLoading = true;
    notifyListeners();

    final loadedExpenses = await _repository.loadExpenses();
    _expenses = loadedExpenses
        .where((e) => !e.isPlaceholder && (e.amount > 0 || e.description.isNotEmpty || e.category != null))
        .toList();

    final loadedMonthly = await _repository.loadMonthlyDistributionExpenses();
    _monthlyDistributionExpenses = loadedMonthly
        .where((e) => !e.isPlaceholder && (e.amount > 0 || e.description.isNotEmpty || e.category != null))
        .toList();

    _monthlyBudget = await _repository.loadBudget();
    _extraEmptyRows = 2;
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
    _extraEmptyRows = 2; // Always reset to 2 empty rows on page change
    notifyListeners();
  }

  // Check if an expense matches the current date filter (only for standard expenses)
  bool _matchesDateFilter(ExpenseItem item) {
    if (item.date == null) {
      return _filterMode == DateFilterMode.allTime || _filterMode == DateFilterMode.monthlyDistribution;
    }
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
      case DateFilterMode.monthlyDistribution:
        return true;
      case DateFilterMode.customDate:
        if (_customSelectedDate == null) return true;
        return item.date!.year == _customSelectedDate!.year &&
            item.date!.month == _customSelectedDate!.month &&
            item.date!.day == _customSelectedDate!.day;
    }
  }

  // Active recorded expenses matching current filter
  List<ExpenseItem> get activeExpenses {
    if (isMonthlyDistributionMode) {
      return _monthlyDistributionExpenses
          .where((e) => !e.isPlaceholder && (e.amount > 0 || e.description.isNotEmpty || e.category != null))
          .toList();
    }
    return _expenses
        .where((e) => !e.isPlaceholder && (e.amount > 0 || e.description.isNotEmpty || e.category != null) && _matchesDateFilter(e))
        .toList();
  }

  // Rows displayed in the table: all recorded entries + exactly 2 extra empty rows (plus any added via '+')
  List<ExpenseItem> get tableRows {
    final realList = isMonthlyDistributionMode
        ? _monthlyDistributionExpenses
            .where((e) => !e.isPlaceholder && (e.amount > 0 || e.description.isNotEmpty || e.category != null))
            .toList()
        : _expenses
            .where((e) => !e.isPlaceholder && (e.amount > 0 || e.description.isNotEmpty || e.category != null) && _matchesDateFilter(e))
            .toList();

    final placeholders = List.generate(
      _extraEmptyRows,
      (index) => ExpenseItem(
        id: 'placeholder_${_filterMode.name}_$index',
        date: currentEffectiveDate,
        category: null,
        description: '',
        amount: 0.0,
        isPlaceholder: true,
        createdAt: DateTime.now().add(Duration(milliseconds: index)),
      ),
    );

    return [...realList, ...placeholders];
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

  // Add a new row: if called without data (e.g. '+' button), adds one more empty row!
  Future<void> addNewRow({
    DateTime? date,
    ExpenseCategory? category,
    String description = '',
    double amount = 0.0,
  }) async {
    if (category != null || description.isNotEmpty || amount > 0) {
      final newItem = ExpenseItem(
        id: _repository.createNewBlankItem().id,
        date: date ?? currentEffectiveDate,
        category: category,
        description: description,
        amount: amount,
        isPlaceholder: false,
        createdAt: DateTime.now(),
      );
      if (isMonthlyDistributionMode) {
        _monthlyDistributionExpenses.add(newItem);
        await _repository.saveMonthlyDistributionExpenses(_monthlyDistributionExpenses);
      } else {
        _expenses.add(newItem);
        await _repository.saveExpenses(_expenses);
      }
    } else {
      // User tapped "+" button: adds one more empty row to the view
      _extraEmptyRows++;
    }

    _lastSavedAt = DateTime.now();
    notifyListeners();
  }

  Future<void> updateCell({
    required String id,
    DateTime? date,
    ExpenseCategory? category,
    bool clearCategory = false,
    String? description,
    double? amount,
  }) async {
    if (isMonthlyDistributionMode) {
      final index = _monthlyDistributionExpenses.indexWhere((e) => e.id == id);
      if (index == -1) {
        if ((amount ?? 0) > 0 || (description ?? '').isNotEmpty || category != null) {
          final newItem = ExpenseItem(
            id: _repository.createNewBlankItem().id,
            date: date ?? currentEffectiveDate,
            category: category,
            description: description ?? '',
            amount: amount ?? 0.0,
            isPlaceholder: false,
            createdAt: DateTime.now(),
          );
          _monthlyDistributionExpenses.add(newItem);
          if (_extraEmptyRows > 2) _extraEmptyRows--;
          _lastSavedAt = DateTime.now();
          notifyListeners();
          await _repository.saveMonthlyDistributionExpenses(_monthlyDistributionExpenses);
        }
        return;
      }

      final current = _monthlyDistributionExpenses[index];
      final updated = current.copyWith(
        date: date ?? current.date ?? DateTime.now(),
        category: category,
        clearCategory: clearCategory,
        description: description ?? current.description,
        amount: amount ?? current.amount,
        isPlaceholder: false,
      );

      _monthlyDistributionExpenses[index] = updated;
      _lastSavedAt = DateTime.now();
      notifyListeners();
      await _repository.saveMonthlyDistributionExpenses(_monthlyDistributionExpenses);
      return;
    }

    final index = _expenses.indexWhere((e) => e.id == id);
    if (index == -1) {
      if ((amount ?? 0) > 0 || (description ?? '').isNotEmpty || category != null) {
        final newItem = ExpenseItem(
          id: _repository.createNewBlankItem().id,
          date: date ?? currentEffectiveDate,
          category: category,
          description: description ?? '',
          amount: amount ?? 0.0,
          isPlaceholder: false,
          createdAt: DateTime.now(),
        );
        _expenses.add(newItem);
        if (_extraEmptyRows > 2) _extraEmptyRows--;
        _lastSavedAt = DateTime.now();
        notifyListeners();
        await _repository.saveExpenses(_expenses);
      }
      return;
    }

    final current = _expenses[index];
    final updated = current.copyWith(
      date: date ?? current.date ?? currentEffectiveDate,
      category: category,
      clearCategory: clearCategory,
      description: description ?? current.description,
      amount: amount ?? current.amount,
      isPlaceholder: false,
    );

    _expenses[index] = updated;
    _lastSavedAt = DateTime.now();
    notifyListeners();
    await _repository.saveExpenses(_expenses);
  }

  Future<void> addExpenseItem(ExpenseItem item) async {
    _expenses.add(item);
    _lastSavedAt = DateTime.now();
    notifyListeners();
    await _repository.saveExpenses(_expenses);
  }

  Future<void> addExpenseItems(List<ExpenseItem> items) async {
    _expenses.addAll(items);
    _lastSavedAt = DateTime.now();
    notifyListeners();
    await _repository.saveExpenses(_expenses);
  }

  Future<void> deleteItemsByBatchId(String batchId) async {
    _expenses.removeWhere((e) => e.batchId == batchId);
    _lastSavedAt = DateTime.now();
    notifyListeners();
    await _repository.saveExpenses(_expenses);
  }

  Future<void> deleteRow(String id) async {
    if (isMonthlyDistributionMode) {
      _monthlyDistributionExpenses.removeWhere((e) => e.id == id);
      _lastSavedAt = DateTime.now();
      notifyListeners();
      await _repository.saveMonthlyDistributionExpenses(_monthlyDistributionExpenses);
      return;
    }

    _expenses.removeWhere((e) => e.id == id);
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
    _extraEmptyRows = 2;
    if (isMonthlyDistributionMode) {
      _monthlyDistributionExpenses = [];
      _lastSavedAt = DateTime.now();
      notifyListeners();
      await _repository.saveMonthlyDistributionExpenses(_monthlyDistributionExpenses);
      return;
    }

    _expenses = [];
    _monthlyBudget = ExpenseRepository.defaultMonthlyBudget;
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
