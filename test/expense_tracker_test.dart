import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expnz/models/expense_model.dart';
import 'package:expnz/providers/expense_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Expense Tracker Taka & SL Column Tests', () {
    test('At launch data is 0 with 5 blank placeholder rows for SL 1..5', () async {
      final provider = ExpenseProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(provider.totalSpent, 0.0);
      expect(provider.totalEntriesCount, 0);
      expect(provider.tableRows.length, 5);
      expect(provider.tableRows.every((e) => e.isPlaceholder), isTrue);
    });

    test('Adding row records entry in Taka and expands table', () async {
      final provider = ExpenseProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      await provider.addNewRow(
        description: 'Bazar Grocery',
        amount: 850.00,
        category: ExpenseCategory.food,
      );

      expect(provider.totalSpent, 850.00);
      expect(provider.totalEntriesCount, 1);
      expect(provider.tableRows.length, greaterThanOrEqualTo(5));
    });

    test('Updating cell edits fields and recalculates Taka total', () async {
      final provider = ExpenseProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      final firstRowId = provider.tableRows.first.id;
      await provider.updateCell(
        id: firstRowId,
        category: ExpenseCategory.travel,
        description: 'Rickshaw fare',
        amount: 60.00,
      );

      expect(provider.totalSpent, 60.00);
      expect(provider.totalEntriesCount, 1);
    });

    test('Date filtering filters items accurately', () async {
      final provider = ExpenseProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      await provider.addNewRow(
        date: DateTime.now(),
        description: 'Today item',
        amount: 200.0,
      );

      provider.setFilterMode(DateFilterMode.today);
      expect(provider.totalSpent, 200.0);

      // Monthly distribution table is completely detached: standard expenses do not bleed into it
      provider.setFilterMode(DateFilterMode.monthlyDistribution);
      expect(provider.filterLabel, 'Monthly distribution');
      expect(provider.totalSpent, 0.0);

      // Adding to monthly distribution table does not bleed into Today or other tabs
      await provider.addNewRow(description: 'Monthly rent', amount: 5000.0);
      expect(provider.totalSpent, 5000.0);

      provider.setFilterMode(DateFilterMode.today);
      expect(provider.totalSpent, 200.0); // Remains 200.0, monthly rent not shown here

      provider.setFilterMode(DateFilterMode.customDate, customDate: DateTime(2020, 1, 1));
      expect(provider.totalSpent, 0.0);
    });

    test('CSV Generation produces valid format with SL and BDT', () async {
      final provider = ExpenseProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      await provider.addNewRow(description: 'Lunch', amount: 150.0);
      final csv = provider.generateCsv();

      expect(csv.contains('SL,Date,Category,Description,Amount (BDT)'), isTrue);
      expect(csv.contains('1,'), isTrue);
      expect(csv.contains('Lunch'), isTrue);
      expect(csv.contains('150.00'), isTrue);
    });
  });
}
