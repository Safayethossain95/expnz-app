import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expnz/screens/calculator_screen.dart';
import 'package:expnz/screens/home_screen.dart';
import 'package:expnz/providers/expense_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CalculatorScreen Tests', () {
    testWidgets('Basic addition test: 25 + 75 = 100', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: CalculatorScreen()),
      );

      // Tap 2, 5
      await tester.tap(find.text('2'));
      await tester.pump();
      await tester.tap(find.text('5'));
      await tester.pump();

      // Tap +
      await tester.tap(find.text('+'));
      await tester.pump();

      // Tap 7, 5
      await tester.tap(find.text('7'));
      await tester.pump();
      await tester.tap(find.text('5'));
      await tester.pump();

      // Tap =
      await tester.tap(find.text('='));
      await tester.pump();

      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('Subtraction test: 50 - 15 = 35', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: CalculatorScreen()),
      );

      await tester.tap(find.text('5'));
      await tester.pump();
      await tester.tap(find.text('0'));
      await tester.pump();

      await tester.tap(find.text('−'));
      await tester.pump();

      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('5'));
      await tester.pump();

      await tester.tap(find.text('='));
      await tester.pump();

      expect(find.text('35'), findsOneWidget);
    });

    testWidgets('Multiplication test: 8 * 7 = 56', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: CalculatorScreen()),
      );

      await tester.tap(find.text('8'));
      await tester.pump();

      await tester.tap(find.text('×'));
      await tester.pump();

      await tester.tap(find.text('7'));
      await tester.pump();

      await tester.tap(find.text('='));
      await tester.pump();

      expect(find.text('56'), findsOneWidget);
    });

    testWidgets('Percentage calculation test: 1000 + 10% = 1100', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: CalculatorScreen()),
      );

      // 1 0 0 0
      for (final d in ['1', '0', '0', '0']) {
        await tester.tap(find.text(d));
        await tester.pump();
      }

      // +
      await tester.tap(find.text('+'));
      await tester.pump();

      // 1 0
      for (final d in ['1', '0']) {
        await tester.tap(find.text(d));
        await tester.pump();
      }

      // %
      await tester.tap(find.text('%'));
      await tester.pump();

      // =
      await tester.tap(find.text('='));
      await tester.pump();

      expect(find.text('1,100'), findsOneWidget);
    });

    testWidgets('Standalone percentage test: 50% = 0.5', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: CalculatorScreen()),
      );

      await tester.tap(find.text('5'));
      await tester.pump();
      await tester.tap(find.text('0'));
      await tester.pump();

      await tester.tap(find.text('%'));
      await tester.pump();

      expect(find.text('0.5'), findsOneWidget);
    });

    testWidgets('Division by zero displays error safely', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: CalculatorScreen()),
      );

      await tester.tap(find.text('9'));
      await tester.pump();

      await tester.tap(find.text('÷'));
      await tester.pump();

      await tester.tap(find.text('0'));
      await tester.pump();

      await tester.tap(find.text('='));
      await tester.pump();

      expect(find.text('Error'), findsOneWidget);
    });

    testWidgets('Clear button resets calculation state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: CalculatorScreen()),
      );

      await tester.tap(find.text('8'));
      await tester.pump();
      await tester.tap(find.text('9'));
      await tester.pump();

      expect(find.text('89'), findsOneWidget);

      await tester.tap(find.text('C'));
      await tester.pump();

      expect(find.text('0'), findsNWidgets(2));
    });
  });

  group('HomeScreen Tools Tab & Calculator Integration Tests', () {
    testWidgets('Tools tab renders and opens CalculatorScreen on tap', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final provider = ExpenseProvider();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(provider: provider),
        ),
      );
      await tester.pumpAndSettle();

      // Find 'Tools' in bottom navigation
      expect(find.text('Tools'), findsWidgets);

      // Tap Tools tab
      await tester.tap(find.text('Tools').last);
      await tester.pumpAndSettle();

      // Verify Calculator tool card is present
      expect(find.text('Full calculator with % calculation'), findsOneWidget);

      // Tap Calculator tool card to open calculator page
      await tester.tap(find.text('Full calculator with % calculation'));
      await tester.pumpAndSettle();

      // Should now be on CalculatorScreen
      expect(find.byType(CalculatorScreen), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Calculator'), findsOneWidget);

      // Back navigation returns to HomeScreen
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
