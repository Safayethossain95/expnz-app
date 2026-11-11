import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expnz/services/pin_lock_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Account-specific PIN Lock Tests', () {
    test('PIN is strictly isolated per Google Account ID', () async {
      final pinService = PinLockService();

      const userA = 'google_uid_user_a';
      const userB = 'google_uid_user_b';

      // Initially neither has PIN
      expect(await pinService.isPinEnabled(userId: userA), isFalse);
      expect(await pinService.isPinEnabled(userId: userB), isFalse);

      // User A sets PIN 1234
      final setA = await pinService.setPin('1234', userId: userA, userEmail: 'usera@gmail.com');
      expect(setA, isTrue);

      // User A has PIN enabled, User B still does NOT
      expect(await pinService.isPinEnabled(userId: userA), isTrue);
      expect(await pinService.isPinEnabled(userId: userB), isFalse);

      // Verify User A pin
      expect(await pinService.verifyPin('1234', userId: userA), isTrue);
      expect(await pinService.verifyPin('9999', userId: userA), isFalse);

      // User B sets a different PIN 5678
      final setB = await pinService.setPin('5678', userId: userB, userEmail: 'userb@gmail.com');
      expect(setB, isTrue);

      // Both now have PIN enabled, each with their own distinct PIN
      expect(await pinService.isPinEnabled(userId: userA), isTrue);
      expect(await pinService.isPinEnabled(userId: userB), isTrue);

      expect(await pinService.verifyPin('1234', userId: userA), isTrue);
      expect(await pinService.verifyPin('5678', userId: userA), isFalse);

      expect(await pinService.verifyPin('5678', userId: userB), isTrue);
      expect(await pinService.verifyPin('1234', userId: userB), isFalse);

      // Removing User A's PIN does NOT affect User B
      await pinService.removePin(userId: userA);
      expect(await pinService.isPinEnabled(userId: userA), isFalse);
      expect(await pinService.isPinEnabled(userId: userB), isTrue);
      expect(await pinService.verifyPin('5678', userId: userB), isTrue);
    });
  });
}

