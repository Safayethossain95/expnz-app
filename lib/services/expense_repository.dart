import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/expense_model.dart';

class ExpenseRepository {
  static const String _keyExpenses = 'expnz_expenses_taka_v2';
  static const String _keyMonthlyBudget = 'expnz_monthly_budget_taka_v2';
  static const double defaultMonthlyBudget = 25000.0; // ৳25,000

  final _uuid = const Uuid();

  // At launch the data will be 0, no table entry initially recorded
  List<ExpenseItem> getInitialSeedData() {
    // 5 empty placeholder rows visible initially for SL 1..5
    return List.generate(
      5,
      (index) => ExpenseItem(
        id: 'initial-row-${index + 1}',
        date: DateTime.now(),
        category: null,
        description: '',
        amount: 0.0,
        isPlaceholder: true,
        createdAt: DateTime.now().add(Duration(seconds: index)),
      ),
    );
  }

  Future<List<ExpenseItem>> loadExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyExpenses);
    if (jsonString == null || jsonString.isEmpty) {
      final initial = getInitialSeedData();
      await saveExpenses(initial);
      return initial;
    }
    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((e) => ExpenseItem.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      final initial = getInitialSeedData();
      await saveExpenses(initial);
      return initial;
    }
  }

  Future<void> saveExpenses(List<ExpenseItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(items.map((e) => e.toMap()).toList());
    await prefs.setString(_keyExpenses, jsonString);
  }

  Future<double> loadBudget() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyMonthlyBudget) ?? defaultMonthlyBudget;
  }

  Future<void> saveBudget(double budget) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyMonthlyBudget, budget);
  }

  ExpenseItem createNewBlankItem({bool isPlaceholder = false}) {
    return ExpenseItem(
      id: _uuid.v4(),
      date: DateTime.now(),
      category: null,
      description: '',
      amount: 0.0,
      isPlaceholder: isPlaceholder,
      createdAt: DateTime.now(),
    );
  }
}
