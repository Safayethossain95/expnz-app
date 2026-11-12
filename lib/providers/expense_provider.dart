import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense_model.dart';
import '../services/expense_repository.dart';
import '../services/month_start_service.dart';
import '../theme/app_theme.dart';

enum DateFilterMode {
  allTime('All time'),
  today('Today'),
  thisMonth('This month'),
  monthPeriod('Pick month'),
  monthlyDistribution('Monthly distribution'),
  customDate('Specific date');

  final String label;
  const DateFilterMode(this.label);
}

class ExpenseProvider extends ChangeNotifier {
  final ExpenseRepository _repository = ExpenseRepository();
  final MonthStartService _monthStartService = MonthStartService();

  List<ExpenseItem> _expenses = [];
  List<ExpenseItem> _monthlyDistributionExpenses = [];
  final Set<String> _selectedMonthlyDistributionIds = {};
  double _monthlyBudget = ExpenseRepository.defaultMonthlyBudget;
  DateFilterMode _filterMode = DateFilterMode.thisMonth;
  DateTime? _customSelectedDate;
  MonthPeriod? _selectedMonthlyDistributionPeriod;
  MonthPeriod? _selectedExpenseMonthPeriod;
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
  Set<String> get selectedMonthlyDistributionIds => _selectedMonthlyDistributionIds;
  double get monthlyBudget => _monthlyBudget;
  DateFilterMode get filterMode => _filterMode;
  DateTime? get customSelectedDate => _customSelectedDate;
  int get activeTabIndex => _activeTabIndex;
  DateTime get lastSavedAt => _lastSavedAt;
  int get visibleLimit => tableRows.length;
  bool get isMonthlyDistributionMode => _filterMode == DateFilterMode.monthlyDistribution;
  int get monthStartDay => _monthStartService.startDay;

  MonthPeriod get currentMonthPeriod => _monthStartService.currentMonthPeriod();

  MonthPeriod get selectedMonthlyDistributionPeriod =>
      _selectedMonthlyDistributionPeriod ?? currentMonthPeriod;

  MonthPeriod get nextMonthlyDistributionPeriod =>
      _monthStartService.nextPeriodOf(selectedMonthlyDistributionPeriod);

  MonthPeriod? get selectedExpenseMonthPeriod => _selectedExpenseMonthPeriod;

  List<MonthPeriod> get availableMonthPeriods {
    final periods = _monthStartService.generatePeriods(count: 24, futureCount: 6);
    if (_selectedMonthlyDistributionPeriod != null &&
        !periods.contains(_selectedMonthlyDistributionPeriod)) {
      periods.insert(0, _selectedMonthlyDistributionPeriod!);
    }
    final nextP = nextMonthlyDistributionPeriod;
    if (!periods.contains(nextP)) {
      periods.insert(0, nextP);
    }
    return periods;
  }

  bool isRowSelected(String id) => _selectedMonthlyDistributionIds.contains(id);

  void toggleRowSelection(String id) {
    if (_selectedMonthlyDistributionIds.contains(id)) {
      _selectedMonthlyDistributionIds.remove(id);
    } else {
      _selectedMonthlyDistributionIds.add(id);
    }
    notifyListeners();
  }

  void selectAllMonthlyDistributionRows() {
    final activeIds = activeExpenses.map((e) => e.id).toSet();
    if (_selectedMonthlyDistributionIds.containsAll(activeIds) && activeIds.isNotEmpty) {
      _selectedMonthlyDistributionIds.clear();
    } else {
      _selectedMonthlyDistributionIds.addAll(activeIds);
    }
    notifyListeners();
  }

  void clearMonthlyDistributionSelection() {
    if (_selectedMonthlyDistributionIds.isNotEmpty) {
      _selectedMonthlyDistributionIds.clear();
      notifyListeners();
    }
  }

  void setSelectedMonthlyDistributionPeriod(MonthPeriod period) {
    _selectedMonthlyDistributionPeriod = period;
    _extraEmptyRows = 2;
    _selectedMonthlyDistributionIds.clear();
    notifyListeners();
  }

  void setMonthPeriodFilter(MonthPeriod period) {
    _filterMode = DateFilterMode.monthPeriod;
    _selectedExpenseMonthPeriod = period;
    _extraEmptyRows = 2;
    _selectedMonthlyDistributionIds.clear();
    notifyListeners();
  }

  DateTime get currentEffectiveDate {
    if (_filterMode == DateFilterMode.customDate && _customSelectedDate != null) {
      return _customSelectedDate!;
    }
    if (_filterMode == DateFilterMode.monthPeriod && _selectedExpenseMonthPeriod != null) {
      return _selectedExpenseMonthPeriod!.start;
    }
    if (_filterMode == DateFilterMode.monthlyDistribution) {
      return selectedMonthlyDistributionPeriod.start;
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
        if (_monthStartService.startDay == 1) {
          return DateFormat('MMMM yyyy').format(DateTime.now());
        }
        return _monthStartService.periodLabel();
      case DateFilterMode.monthPeriod:
        return _selectedExpenseMonthPeriod?.label ?? 'Month period';
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

    await _monthStartService.load();

    final loadedExpenses = await _repository.loadExpenses();
    _expenses = loadedExpenses
        .where((e) => !e.isPlaceholder && (e.amount > 0 || e.description.isNotEmpty || e.category != null))
        .toList();

    final loadedMonthly = await _repository.loadMonthlyDistributionExpenses();
    _monthlyDistributionExpenses = loadedMonthly
        .where((e) => !e.isPlaceholder && (e.amount > 0 || e.description.isNotEmpty || e.category != null))
        .toList();

    // Check and automatically move 15 Sep - 15 Oct items to 15 Oct - 15 Nov if needed
    if (hasSepOctMonthlyDistributionItems) {
      await moveSepOctMonthlyDistributionToOctNov();
    }

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
    _selectedMonthlyDistributionIds.clear();
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
        return _monthStartService.isInCurrentPeriod(item.date!);
      case DateFilterMode.monthPeriod:
        if (_selectedExpenseMonthPeriod == null) return true;
        return _selectedExpenseMonthPeriod!.contains(item.date!);
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
      final period = selectedMonthlyDistributionPeriod;
      return _monthlyDistributionExpenses
          .where((e) =>
              !e.isPlaceholder &&
              (e.amount > 0 || e.description.isNotEmpty || e.category != null) &&
              period.contains(e.date ?? e.createdAt))
          .toList();
    }
    return _expenses
        .where((e) => !e.isPlaceholder && (e.amount > 0 || e.description.isNotEmpty || e.category != null) && _matchesDateFilter(e))
        .toList();
  }

  // Rows displayed in the table: all recorded entries + exactly 2 extra empty rows (plus any added via '+')
  List<ExpenseItem> get tableRows {
    final realList = isMonthlyDistributionMode
        ? activeExpenses
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
            id: id,
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
        date: date ?? current.date ?? currentEffectiveDate,
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
          id: id,
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
    _selectedMonthlyDistributionIds.remove(id);
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

  /// Updates the month start day and re-filters the current view.
  Future<void> setMonthStartDay(int day) async {
    await _monthStartService.save(day);
    _selectedMonthlyDistributionPeriod = null;
    _selectedExpenseMonthPeriod = null;
    notifyListeners(); // re-evaluate filtered list
  }

  /// Returns true if there are monthly distribution items falling in 15 Sep - 15 Oct
  bool get hasSepOctMonthlyDistributionItems {
    final sep15 = DateTime(2026, 9, 15);
    final oct15 = DateTime(2026, 10, 15);
    return _monthlyDistributionExpenses.any((e) {
      if (e.isPlaceholder) return false;
      final itemDate = e.date ?? e.createdAt;
      final d = DateTime(itemDate.year, itemDate.month, itemDate.day);
      return !d.isBefore(sep15) && d.isBefore(oct15);
    });
  }

  /// Moves monthly distribution items from 15 Sep - 15 Oct to 15 Oct - 15 Nov and saves to DB.
  Future<int> moveSepOctMonthlyDistributionToOctNov() async {
    int movedCount = 0;
    final sep15 = DateTime(2026, 9, 15);
    final oct15 = DateTime(2026, 10, 15);

    final updatedList = <ExpenseItem>[];
    for (final item in _monthlyDistributionExpenses) {
      final itemDate = item.date ?? item.createdAt;
      final d = DateTime(itemDate.year, itemDate.month, itemDate.day);
      // If the date falls within 15 Sep - 15 Oct (inclusive start, exclusive end)
      if (!d.isBefore(sep15) && d.isBefore(oct15)) {
        // Advance month by 1 to place it in 15 Oct - 15 Nov
        final newYear = itemDate.month == 12 ? itemDate.year + 1 : itemDate.year;
        final newMonth = itemDate.month == 12 ? 1 : itemDate.month + 1;
        final maxDays = DateTime(newYear, newMonth + 1, 0).day;
        final newDay = itemDate.day.clamp(1, maxDays);

        final movedDate = DateTime(
          newYear,
          newMonth,
          newDay,
          itemDate.hour,
          itemDate.minute,
          itemDate.second,
        );

        updatedList.add(item.copyWith(date: movedDate));
        movedCount++;
      } else {
        updatedList.add(item);
      }
    }

    if (movedCount > 0) {
      _monthlyDistributionExpenses = updatedList;
      _lastSavedAt = DateTime.now();
      notifyListeners();
      await _repository.saveMonthlyDistributionExpenses(_monthlyDistributionExpenses);
      debugPrint('Successfully moved $movedCount monthly distribution items from 15 Sep - 15 Oct to 15 Oct - 15 Nov');
    }

    return movedCount;
  }

  /// Exports selected monthly distribution items into the next month's distribution.
  /// If next month already has entries, appends them after the existing entries of next month.
  /// If next month has no entries, inserts them from the beginning.
  Future<int> exportSelectedToNextMonth() async {
    return copySelectedToNextMonth();
  }

  /// Copies selected monthly distribution items into the next month's distribution.
  /// If next month already has entries, appends them after the existing entries of next month.
  /// If next month has no entries, inserts them from the beginning.
  Future<int> copySelectedToNextMonth() async {
    if (_selectedMonthlyDistributionIds.isEmpty) return 0;

    final currentPeriod = selectedMonthlyDistributionPeriod;
    final nextPeriod = _monthStartService.nextPeriodOf(currentPeriod);

    // Get the selected items in their current display order
    final selectedItems = activeExpenses
        .where((e) => _selectedMonthlyDistributionIds.contains(e.id))
        .toList();

    if (selectedItems.isEmpty) return 0;

    // Check existing next month items
    final existingNextMonthItems = _monthlyDistributionExpenses
        .where((e) =>
            !e.isPlaceholder &&
            (e.amount > 0 || e.description.isNotEmpty || e.category != null) &&
            nextPeriod.contains(e.date ?? e.createdAt))
        .toList();

    // Prepare copies with date set to nextPeriod.start (or matching relative day if valid) and unique IDs
    final now = DateTime.now();
    final copiedItems = <ExpenseItem>[];
    for (int i = 0; i < selectedItems.length; i++) {
      final original = selectedItems[i];
      DateTime itemDate = nextPeriod.start;
      if (original.date != null) {
        final orig = original.date!;
        final newYear = orig.month == 12 ? orig.year + 1 : orig.year;
        final newMonth = orig.month == 12 ? 1 : orig.month + 1;
        final maxDays = DateTime(newYear, newMonth + 1, 0).day;
        final newDay = orig.day.clamp(1, maxDays);
        final candidate = DateTime(newYear, newMonth, newDay, orig.hour, orig.minute, orig.second);
        if (nextPeriod.contains(candidate)) {
          itemDate = candidate;
        }
      }

      copiedItems.add(ExpenseItem(
        id: _repository.createNewBlankItem().id,
        date: itemDate,
        category: original.category,
        description: original.description,
        amount: original.amount,
        isPlaceholder: false,
        createdAt: now.add(Duration(milliseconds: i)),
      ));
    }

    if (existingNextMonthItems.isNotEmpty) {
      // Find the last index of an existing next month item in _monthlyDistributionExpenses
      int lastNextIndex = -1;
      for (int i = 0; i < _monthlyDistributionExpenses.length; i++) {
        final item = _monthlyDistributionExpenses[i];
        if (!item.isPlaceholder && nextPeriod.contains(item.date ?? item.createdAt)) {
          lastNextIndex = i;
        }
      }
      if (lastNextIndex != -1) {
        _monthlyDistributionExpenses.insertAll(lastNextIndex + 1, copiedItems);
      } else {
        _monthlyDistributionExpenses.addAll(copiedItems);
      }
    } else {
      // If no values exist in next month, insert from the beginning of next month
      int insertIndex = -1;
      for (int i = 0; i < _monthlyDistributionExpenses.length; i++) {
        final item = _monthlyDistributionExpenses[i];
        final itemDate = item.date ?? item.createdAt;
        if (itemDate.isAfter(nextPeriod.end) || itemDate.isAtSameMomentAs(nextPeriod.end)) {
          insertIndex = i;
          break;
        }
      }
      if (insertIndex != -1) {
        _monthlyDistributionExpenses.insertAll(insertIndex, copiedItems);
      } else {
        _monthlyDistributionExpenses.addAll(copiedItems);
      }
    }

    final count = copiedItems.length;
    _selectedMonthlyDistributionIds.clear();
    _lastSavedAt = DateTime.now();
    notifyListeners();

    await _repository.saveMonthlyDistributionExpenses(_monthlyDistributionExpenses);
    return count;
  }

  Future<void> resetToBlank() async {
    _extraEmptyRows = 2;
    _selectedMonthlyDistributionIds.clear();
    if (isMonthlyDistributionMode) {
      final period = selectedMonthlyDistributionPeriod;
      _monthlyDistributionExpenses.removeWhere((e) =>
          period.contains(e.date ?? e.createdAt));
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
      final amt = formatAmount(item.amount);
      buffer.writeln('$sl,$dateStr,$cat,$desc,$amt');
      sl++;
    }
    return buffer.toString();
  }
}
