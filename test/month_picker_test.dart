import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expnz/models/expense_model.dart';
import 'package:expnz/providers/expense_provider.dart';
import 'package:expnz/services/month_start_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MonthPeriod and MonthStartService Tests', () {
    test('Period formatting with 15th start day produces 15 Oct – 15 Nov style', () {
      final period = MonthPeriod(
        start: DateTime(2026, 10, 15),
        end: DateTime(2026, 11, 15),
      );

      expect(period.label, '15 Oct – 15 Nov 2026');
      expect(period.contains(DateTime(2026, 10, 15)), isTrue);
      expect(period.contains(DateTime(2026, 11, 14)), isTrue);
      // 15 Nov is the start of the next period (15 Nov – 15 Dec), so it must be false
      expect(period.contains(DateTime(2026, 11, 15)), isFalse);
      expect(period.contains(DateTime(2026, 10, 14)), isFalse);
      expect(period.contains(DateTime(2026, 11, 16)), isFalse);
    });

    test('15 Oct – 15 Nov and 15 Nov – 15 Dec periods strictly separate their expenses', () {
      final octNov = MonthPeriod(
        start: DateTime(2026, 10, 15),
        end: DateTime(2026, 11, 15),
      );
      final novDec = MonthPeriod(
        start: DateTime(2026, 11, 15),
        end: DateTime(2026, 12, 15),
      );

      // Date in Oct-Nov
      final octItemDate = DateTime(2026, 10, 20);
      expect(octNov.contains(octItemDate), isTrue);
      expect(novDec.contains(octItemDate), isFalse);

      // Boundary date 15 Nov belongs strictly to Nov-Dec, NEVER to Oct-Nov
      final novItemDate = DateTime(2026, 11, 15);
      expect(octNov.contains(novItemDate), isFalse);
      expect(novDec.contains(novItemDate), isTrue);

      // Date inside Nov-Dec
      final novDecItemDate = DateTime(2026, 12, 1);
      expect(octNov.contains(novDecItemDate), isFalse);
      expect(novDec.contains(novDecItemDate), isTrue);
    });

    test('generatePeriods produces current and previous periods', () {
      final service = MonthStartService();
      final periods = service.generatePeriods(count: 12);

      expect(periods.length, 13); // current + 12 previous
      expect(periods.first.isCurrent, isTrue);
      expect(periods.skip(1).every((p) => !p.isCurrent), isTrue);

      // Consecutive periods should connect seamlessly
      for (int i = 0; i < periods.length - 1; i++) {
        expect(periods[i].start, equals(periods[i + 1].end));
      }
    });

    test('Selecting different month period filters monthly distribution expenses', () async {
      final provider = ExpenseProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      provider.setFilterMode(DateFilterMode.monthlyDistribution);

      final periods = provider.availableMonthPeriods;
      final currentPeriod = periods.firstWhere((p) => p.isCurrent);
      final previousPeriod = periods.firstWhere((p) => !p.isCurrent && p.start.isBefore(currentPeriod.start));

      // Add expense in current period
      await provider.addNewRow(
        date: currentPeriod.start.add(const Duration(days: 1)),
        description: 'Current Month Grocery',
        amount: 3000.0,
        category: ExpenseCategory.food,
      );

      expect(provider.totalSpent, 3000.0);

      // Switch to previous period
      provider.setSelectedMonthlyDistributionPeriod(previousPeriod);
      expect(provider.totalSpent, 0.0);

      // Add expense in previous period
      await provider.addNewRow(
        date: previousPeriod.start,
        description: 'Previous Month Rent',
        amount: 8000.0,
        category: ExpenseCategory.bills,
      );

      expect(provider.totalSpent, 8000.0);

      // Switch back to current period
      provider.setSelectedMonthlyDistributionPeriod(currentPeriod);
      expect(provider.totalSpent, 3000.0);
    });

    test('Copy to next month inserts after existing values or from beginning', () async {
      final provider = ExpenseProvider();
      await Future.delayed(const Duration(milliseconds: 100));

      provider.setFilterMode(DateFilterMode.monthlyDistribution);
      final currentPeriod = provider.selectedMonthlyDistributionPeriod;
      final nextPeriod = provider.nextMonthlyDistributionPeriod;

      // 1. Add 2 entries in current month
      await provider.addNewRow(
        date: currentPeriod.start,
        description: 'Internet bill',
        amount: 1000.0,
        category: ExpenseCategory.bills,
      );
      await provider.addNewRow(
        date: currentPeriod.start,
        description: 'House Rent',
        amount: 15000.0,
        category: ExpenseCategory.home,
      );

      expect(provider.activeExpenses.length, 2);

      // 2. Select first row with checkbox
      final firstRowId = provider.activeExpenses.first.id;
      provider.toggleRowSelection(firstRowId);
      expect(provider.selectedMonthlyDistributionIds.contains(firstRowId), isTrue);

      // 3. Copy to next month (which initially has NO values) -> should insert from beginning
      final copiedCount = await provider.copySelectedToNextMonth();
      expect(copiedCount, 1);
      expect(provider.selectedMonthlyDistributionIds.isEmpty, isTrue);

      // Switch to next month and verify
      provider.setSelectedMonthlyDistributionPeriod(nextPeriod);
      expect(provider.activeExpenses.length, 1);
      expect(provider.activeExpenses.first.description, 'Internet bill');
      expect(provider.activeExpenses.first.amount, 1000.0);

      // 4. Switch back to current month and copy the second row ('House Rent')
      provider.setSelectedMonthlyDistributionPeriod(currentPeriod);
      final secondRowId = provider.activeExpenses[1].id;
      provider.toggleRowSelection(secondRowId);

      // Next month ALREADY has 'Internet bill', so copying should insert AFTER existing values
      final copiedSecondCount = await provider.copySelectedToNextMonth();
      expect(copiedSecondCount, 1);

      // Switch to next month and verify order: Internet bill FIRST, then House Rent
      provider.setSelectedMonthlyDistributionPeriod(nextPeriod);
      expect(provider.activeExpenses.length, 2);
      expect(provider.activeExpenses[0].description, 'Internet bill');
      expect(provider.activeExpenses[1].description, 'House Rent');
    });
  });
}

