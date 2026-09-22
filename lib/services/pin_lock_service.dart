import 'package:shared_preferences/shared_preferences.dart';

class PinLockService {
  static const String _keyPinCode = 'expnz_app_pin_code';
  static const String _keyPinEnabled = 'expnz_app_pin_enabled';
  static const String _keyPinUserEmail = 'expnz_app_pin_user_email';

  /// Check if PIN lock is currently enabled
  Future<bool> isPinEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_keyPinEnabled) ?? false;
    final pin = prefs.getString(_keyPinCode);
    return enabled && pin != null && pin.length == 4;
  }

  /// Check if a PIN has been created previously
  Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString(_keyPinCode);
    return pin != null && pin.length == 4;
  }

  /// Save or update the 4-digit PIN and turn PIN lock ON
  Future<bool> setPin(String pin, {String? userEmail}) async {
    if (pin.length != 4 || int.tryParse(pin) == null) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPinCode, pin);
    await prefs.setBool(_keyPinEnabled, true);
    if (userEmail != null) {
      await prefs.setString(_keyPinUserEmail, userEmail);
    }
    return true;
  }

  /// Verify user input against the stored PIN
  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedPin = prefs.getString(_keyPinCode);
    return storedPin != null && storedPin == pin;
  }

  /// Turn off PIN lock and remove stored PIN
  Future<void> removePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPinCode);
    await prefs.setBool(_keyPinEnabled, false);
    await prefs.remove(_keyPinUserEmail);
  }

  /// Retrieve the email/name of the user who set the PIN, if available
  Future<String?> getPinUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPinUserEmail);
  }
}
