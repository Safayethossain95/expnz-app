import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expnz/services/pin_lock_service.dart';
import 'package:expnz/widgets/pin_keypad.dart';
import 'package:expnz/widgets/set_pin_dialog.dart';
import 'package:expnz/screens/pin_lock_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PinLockService Tests', () {
    test('Initial state: PIN is not set and lock is disabled', () async {
      final service = PinLockService();
      expect(await service.isPinEnabled(), isFalse);
      expect(await service.hasPin(), isFalse);
    });

    test('Setting valid 4-digit PIN enables lock and saves userEmail', () async {
      final service = PinLockService();
      final success = await service.setPin('4321', userEmail: 'test@example.com');
      expect(success, isTrue);
      expect(await service.isPinEnabled(), isTrue);
      expect(await service.hasPin(), isTrue);
      expect(await service.getPinUserEmail(), 'test@example.com');
    });

    test('Validating correct and incorrect PIN', () async {
      final service = PinLockService();
      await service.setPin('5678');
      expect(await service.verifyPin('5678'), isTrue);
      expect(await service.verifyPin('1234'), isFalse);
    });

    test('Rejecting non-4-digit or non-numeric PIN', () async {
      final service = PinLockService();
      expect(await service.setPin('123'), isFalse);
      expect(await service.setPin('12345'), isFalse);
      expect(await service.setPin('abcd'), isFalse);
    });

    test('Removing PIN clears data and disables lock', () async {
      final service = PinLockService();
      await service.setPin('9999');
      expect(await service.isPinEnabled(), isTrue);

      await service.removePin();
      expect(await service.isPinEnabled(), isFalse);
      expect(await service.hasPin(), isFalse);
    });
  });

  group('PinKeypad & PinDotsIndicator Tests', () {
    testWidgets('PinDotsIndicator renders correct filled and empty dots', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PinDotsIndicator(pinLength: 2, maxLength: 4),
          ),
        ),
      );

      expect(find.byType(AnimatedContainer), findsNWidgets(4));
    });

    testWidgets('PinKeypad fires onDigitPressed and onBackspacePressed callbacks', (tester) async {
      final digitsPressed = <String>[];
      var backspacePressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PinKeypad(
              onDigitPressed: (d) => digitsPressed.add(d),
              onBackspacePressed: () => backspacePressed = true,
            ),
          ),
        ),
      );

      // Tap key '1'
      await tester.tap(find.text('1'));
      await tester.pump();
      expect(digitsPressed, ['1']);

      // Tap key '7'
      await tester.tap(find.text('7'));
      await tester.pump();
      expect(digitsPressed, ['1', '7']);

      // Tap backspace
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump();
      expect(backspacePressed, isTrue);
    });
  });

  group('SetPinDialog Widget Tests', () {
    testWidgets('Setting 4-digit PIN with matching confirmation completes successfully', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await SetPinDialog.show(context, userEmail: 'user@test.com');
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Set 4-Digit PIN'), findsOneWidget);
      expect(find.text('Choose a 4-digit PIN for Expnz app lock'), findsOneWidget);

      // Enter first PIN: 1, 2, 3, 4
      for (final digit in ['1', '2', '3', '4']) {
        await tester.tap(find.text(digit));
        await tester.pumpAndSettle();
      }

      // Step moves to confirm
      expect(find.text('Confirm 4-Digit PIN'), findsOneWidget);

      // Confirm with 1, 2, 3, 4
      for (final digit in ['1', '2', '3', '4']) {
        await tester.tap(find.text(digit));
        await tester.pumpAndSettle();
      }

      // Wait for success animation and dialog close
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(result, isTrue);

      final service = PinLockService();
      expect(await service.isPinEnabled(), isTrue);
      expect(await service.verifyPin('1234'), isTrue);
    });

    testWidgets('PIN mismatch resets to step 1 and shows error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => SetPinDialog.show(context),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Enter first PIN: 1, 2, 3, 4
      for (final digit in ['1', '2', '3', '4']) {
        await tester.tap(find.text(digit));
        await tester.pumpAndSettle();
      }

      expect(find.text('Confirm 4-Digit PIN'), findsOneWidget);

      // Confirm with different PIN: 1, 2, 3, 5
      for (final digit in ['1', '2', '3', '5']) {
        await tester.tap(find.text(digit));
        await tester.pumpAndSettle();
      }

      expect(find.text('PINs do not match. Please enter again.'), findsOneWidget);
      expect(find.text('Set 4-Digit PIN'), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });

  group('PinLockScreen Widget Tests', () {
    testWidgets('Unlocks when correct PIN is entered and rejects wrong PIN', (tester) async {
      final service = PinLockService();
      await service.setPin('2580');

      var unlocked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: PinLockScreen(
            onUnlocked: () => unlocked = true,
          ),
        ),
      );

      expect(find.text('Expnz App Lock'), findsOneWidget);
      expect(find.text('Enter your 4-digit PIN to unlock'), findsOneWidget);

      // Enter wrong PIN: 1, 1, 1, 1
      for (int i = 0; i < 4; i++) {
        await tester.tap(find.text('1'));
        await tester.pumpAndSettle();
      }

      expect(find.text('Incorrect PIN. Try again.'), findsOneWidget);
      expect(unlocked, isFalse);

      // Enter correct PIN: 2, 5, 8, 0
      for (final digit in ['2', '5', '8', '0']) {
        await tester.tap(find.text(digit));
        await tester.pumpAndSettle();
      }

      expect(unlocked, isTrue);
    });
  });
}
