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
      expect(period.contains(DateTime(2026, 11, 15)), isTrue);
      expect(period.contains(DateTime(2026, 10, 14)), isFalse);
      expect(period.contains(DateTime(2026, 11, 16)), isFalse);
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
      final currentPeriod = periods[0];
      final previousPeriod = periods[1];

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
  });
}

