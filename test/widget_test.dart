import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expnz/providers/expense_provider.dart';
import 'package:expnz/screens/home_screen.dart';
import 'package:expnz/services/commute_automation_service.dart';
import 'package:expnz/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CommuteAutomationService().saveConfig(
      CommuteAutomationService().config.copyWith(
        lastDecisionDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      ),
    );
  });

  testWidgets('HomeScreen renders SL, CATEGORY, DESCRIPTION, AMOUNT in Taka with 0 launch state',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = ExpenseProvider();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: AnimatedBuilder(
          animation: provider,
          builder: (context, _) => HomeScreen(provider: provider),
        ),
      ),
    );

    await tester.pumpAndSettle();

 

    // 2. Verify Hero Card in Taka and table rows with 0 entries
    expect(find.text('৳0'), findsNWidgets(3)); // 1 in hero card + 2 in table rows
    expect(find.text('0 entries'), findsOneWidget);

    // 3. Verify Table Column Headers: SL, CATEGORY, DESCRIPTION, AMOUNT
    expect(find.text('SL'), findsOneWidget);
    expect(find.text('CATEGORY'), findsOneWidget);
    expect(find.text('DESCRIPTION'), findsOneWidget);
    expect(find.text('AMOUNT'), findsOneWidget);

    // 4. Verify 2 rows initially visible with SL 1..2
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    // 5. Tap '+' button to add new row
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    // 6. Switch to Tools tab
    await tester.tap(find.text('Tools').last);
    await tester.pumpAndSettle();

    expect(find.text('Monthly Budget Status'), findsOneWidget);
    expect(find.text('Category Breakdown'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
  });
}
