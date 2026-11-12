import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expnz/models/commute_rule.dart';
import 'package:expnz/models/expense_model.dart';
import 'package:expnz/providers/expense_provider.dart';
import 'package:expnz/services/commute_automation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CommuteAutomationService().resetForTesting();
  });

  group('Expense Tracker Taka & SL Column Tests', () {
    test('At launch data is 0 with 2 blank placeholder rows for SL 1..2', () async {
      final provider = ExpenseProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(provider.totalSpent, 0.0);
      expect(provider.totalEntriesCount, 0);
      expect(provider.tableRows.length, 2);
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
      expect(provider.tableRows.length, greaterThanOrEqualTo(2));
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

    test('Data input on a specific/future date is saved under that specific date and isolated from Today', () async {
      final provider = ExpenseProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      // Select a future date: 2028-11-15
      final futureDate = DateTime(2028, 11, 15);
      provider.setFilterMode(DateFilterMode.customDate, customDate: futureDate);

      // Input data into the first placeholder row by editing cells
      final firstRowId = provider.tableRows.first.id;
      await provider.updateCell(
        id: firstRowId,
        category: ExpenseCategory.bills,
        description: 'Future Advance Rent',
        amount: 15000.0,
      );

      // Verify the future date expense was recorded under the future date
      expect(provider.totalSpent, 15000.0);
      expect(provider.totalEntriesCount, 1);
      expect(provider.activeExpenses.first.date!.year, 2028);
      expect(provider.activeExpenses.first.date!.month, 11);
      expect(provider.activeExpenses.first.date!.day, 15);

      // Add another row via addNewRow on the same future date
      await provider.addNewRow(
        category: ExpenseCategory.shopping,
        description: 'Future Electronics',
        amount: 3200.0,
      );
      expect(provider.totalSpent, 18200.0);
      expect(provider.totalEntriesCount, 2);

      // Switch to Today: Should NOT see the future date's expenses
      provider.setFilterMode(DateFilterMode.today);
      expect(provider.totalSpent, 0.0);
      expect(provider.totalEntriesCount, 0);

      // Record an expense on Today
      final todayRowId = provider.tableRows.first.id;
      await provider.updateCell(
        id: todayRowId,
        category: ExpenseCategory.food,
        description: 'Today Lunch',
        amount: 250.0,
      );
      expect(provider.totalSpent, 250.0);
      expect(provider.totalEntriesCount, 1);

      // Switch back to the future date: Should see only the future date expenses
      provider.setFilterMode(DateFilterMode.customDate, customDate: futureDate);
      expect(provider.totalSpent, 18200.0);
      expect(provider.totalEntriesCount, 2);

      // Switch to another distinct date: 2027-05-20
      final anotherDate = DateTime(2027, 5, 20);
      provider.setFilterMode(DateFilterMode.customDate, customDate: anotherDate);
      expect(provider.totalSpent, 0.0);
      expect(provider.totalEntriesCount, 0);

      await provider.addNewRow(
        category: ExpenseCategory.travel,
        description: 'Trip Flight',
        amount: 8000.0,
      );
      expect(provider.totalSpent, 8000.0);
      expect(provider.totalEntriesCount, 1);

      // All Time shows the sum of all distinct dates: 15000 + 3200 + 250 + 8000 = 26450.0
      provider.setFilterMode(DateFilterMode.allTime);
      expect(provider.totalSpent, 26450.0);
      expect(provider.totalEntriesCount, 4);
    });

    test('Monthly distribution and standard tables display all rows even when > 5 rows', () async {
      final provider = ExpenseProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      // 1. Monthly Distribution: Add 8 rows
      provider.setFilterMode(DateFilterMode.monthlyDistribution);
      for (int i = 1; i <= 8; i++) {
        await provider.addNewRow(
          description: 'Dist item $i',
          amount: 100.0 * i,
          category: ExpenseCategory.bills,
        );
      }

      // Verify all 8 recorded rows are visible in tableRows
      expect(provider.activeExpenses.length, 8);
      expect(provider.tableRows.length, greaterThanOrEqualTo(8));
      final visibleDescriptions = provider.tableRows.map((e) => e.description).toList();
      for (int i = 1; i <= 8; i++) {
        expect(visibleDescriptions.contains('Dist item $i'), isTrue,
            reason: 'Dist item $i should be visible');
      }

      // 2. Standard Table (This Month): Add 8 rows
      provider.setFilterMode(DateFilterMode.thisMonth);
      for (int i = 1; i <= 8; i++) {
        await provider.addNewRow(
          description: 'Standard item $i',
          amount: 50.0 * i,
          category: ExpenseCategory.food,
        );
      }

      expect(provider.activeExpenses.length, 8);
      expect(provider.tableRows.length, greaterThanOrEqualTo(8));
      final visibleStandard = provider.tableRows.map((e) => e.description).toList();
      for (int i = 1; i <= 8; i++) {
        expect(visibleStandard.contains('Standard item $i'), isTrue,
            reason: 'Standard item $i should be visible');
      }
    });

    test('Updating cell with clearCategory sets category to null (blank)', () async {
      final provider = ExpenseProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      final firstRowId = provider.tableRows.first.id;
      // First assign a category
      await provider.updateCell(
        id: firstRowId,
        category: ExpenseCategory.food,
        description: 'Snack',
        amount: 80.0,
      );
      expect(provider.tableRows.first.category, ExpenseCategory.food);

      // Now clear category
      await provider.updateCell(
        id: firstRowId,
        clearCategory: true,
      );
      expect(provider.tableRows.first.category, isNull);
      expect(provider.tableRows.first.amount, 80.0);
      expect(provider.tableRows.first.description, 'Snack');
    });

    test('CSV Generation produces valid format with SL and BDT', () async {
      final provider = ExpenseProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      await provider.addNewRow(description: 'Lunch', amount: 150.0);
      final csv = provider.generateCsv();

      expect(csv.contains('SL,Date,Category,Description,Amount (BDT)'), isTrue);
      expect(csv.contains('1,'), isTrue);
      expect(csv.contains('Lunch'), isTrue);
      expect(csv.contains('150'), isTrue);
    });

    test('Monthly Distribution: Export to next month adds from beginning when next month has no entries, and appends when it does', () async {
      final provider = ExpenseProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      provider.setFilterMode(DateFilterMode.monthlyDistribution);

      // Add 2 entries to current monthly distribution period
      await provider.addNewRow(
        category: ExpenseCategory.bills,
        description: 'Internet Bill',
        amount: 1000.0,
      );
      await provider.addNewRow(
        category: ExpenseCategory.food,
        description: 'Monthly Ration',
        amount: 4500.0,
      );

      expect(provider.activeExpenses.length, 2);

      // Select both rows
      final items = provider.activeExpenses;
      provider.toggleRowSelection(items[0].id);
      provider.toggleRowSelection(items[1].id);
      expect(provider.selectedMonthlyDistributionIds.length, 2);

      final currentPeriod = provider.selectedMonthlyDistributionPeriod;
      final nextPeriod = provider.nextMonthlyDistributionPeriod;

      // 1. Export to next month (which has NO entries initially)
      final exportedCount = await provider.exportSelectedToNextMonth();
      expect(exportedCount, 2);
      expect(provider.selectedMonthlyDistributionIds.isEmpty, isTrue);

      // Switch to next month period and verify entries are added from beginning
      provider.setSelectedMonthlyDistributionPeriod(nextPeriod);
      expect(provider.activeExpenses.length, 2);
      expect(provider.activeExpenses[0].description, 'Internet Bill');
      expect(provider.activeExpenses[0].amount, 1000.0);
      expect(provider.activeExpenses[1].description, 'Monthly Ration');
      expect(provider.activeExpenses[1].amount, 4500.0);

      // 2. Now add a new entry to next month
      await provider.addNewRow(
        category: ExpenseCategory.shopping,
        description: 'Next Month Clothes',
        amount: 2000.0,
      );
      expect(provider.activeExpenses.length, 3);
      expect(provider.activeExpenses[2].description, 'Next Month Clothes');

      // 3. Switch back to first period, select 1 entry, and export again
      provider.setSelectedMonthlyDistributionPeriod(currentPeriod);
      provider.toggleRowSelection(provider.activeExpenses[0].id); // select 'Internet Bill'
      expect(provider.selectedMonthlyDistributionIds.length, 1);

      final secondExportCount = await provider.exportSelectedToNextMonth();
      expect(secondExportCount, 1);

      // Switch to next period again and verify entry is APPENDED after existing 3 entries
      provider.setSelectedMonthlyDistributionPeriod(nextPeriod);
      expect(provider.activeExpenses.length, 4);
      expect(provider.activeExpenses[0].description, 'Internet Bill');
      expect(provider.activeExpenses[1].description, 'Monthly Ration');
      expect(provider.activeExpenses[2].description, 'Next Month Clothes');
      expect(provider.activeExpenses[3].description, 'Internet Bill'); // appended at the end!
    });

    test('Daily Commute Customization: User can set custom notification time and customize morning entries', () async {
      final commuteService = CommuteAutomationService();
      await commuteService.loadConfig();

      // 1. Update notification time to 8:15 AM
      await commuteService.updateNotifyTime(8, 15);
      expect(commuteService.config.notifyHour, 8);
      expect(commuteService.config.notifyMinute, 15);

      // 2. Customize entries that will be inserted every morning
      final customEntries = [
        const CommuteItemTemplate(
          category: ExpenseCategory.travel,
          description: 'Uber Ride',
          amount: 250.0,
        ),
        const CommuteItemTemplate(
          category: ExpenseCategory.food,
          description: 'Morning Coffee',
          amount: 120.0,
        ),
      ];
      await commuteService.updateItems(customEntries);
      expect(commuteService.config.items.length, 2);
      expect(commuteService.config.items[0].description, 'Uber Ride');
      expect(commuteService.config.items[0].amount, 250.0);
      expect(commuteService.config.items[1].description, 'Morning Coffee');
      expect(commuteService.config.items[1].amount, 120.0);

      // 3. Keep batch inserts the customized items into today's expenses
      final provider = ExpenseProvider();
      await Future.delayed(const Duration(milliseconds: 100));
      provider.setFilterMode(DateFilterMode.today);

      const batchId = 'test_custom_commute_batch';
      await commuteService.keepBatch(batchId, provider);

      expect(provider.totalSpent, 370.0); // 250 + 120
      expect(provider.totalEntriesCount, 2);
      expect(provider.activeExpenses.any((e) => e.description == 'Uber Ride' && e.amount == 250.0), isTrue);
      expect(provider.activeExpenses.any((e) => e.description == 'Morning Coffee' && e.amount == 120.0), isTrue);

      CommuteAutomationService().resetForTesting();
    });
  });
}
