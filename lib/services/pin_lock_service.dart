import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinLockService {
  static final PinLockService _instance = PinLockService._internal();
  factory PinLockService() => _instance;
  PinLockService._internal();

  FirebaseAuth? get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  String _resolveUid(String? userId) {
    if (userId != null && userId.isNotEmpty) return userId;
    return _auth?.currentUser?.uid ?? 'guest';
  }

  String _pinCodeKey(String uid) => 'expnz_app_pin_code_$uid';
  String _pinEnabledKey(String uid) => 'expnz_app_pin_enabled_$uid';
  String _pinUserEmailKey(String uid) => 'expnz_app_pin_user_email_$uid';

  /// Resolves stored PIN for the specific Google account (or guest).
  /// 1. Checks account-specific local SharedPreferences key.
  /// 2. If not found, checks for legacy global key and migrates it.
  /// 3. If not in local storage, attempts to fetch from Cloud Firestore for this user.
  Future<String?> _getStoredPin(SharedPreferences prefs, String uid) async {
    final accountKey = _pinCodeKey(uid);
    final pin = prefs.getString(accountKey);
    if (pin != null && pin.length == 4) {
      return pin;
    }

    // Migration from legacy global key
    final legacyPin = prefs.getString('expnz_app_pin_code');
    final legacyEnabled = prefs.getBool('expnz_app_pin_enabled') ?? false;
    final legacyEmail = prefs.getString('expnz_app_pin_user_email');
    final currentEmail = _auth?.currentUser?.email;

    if (legacyPin != null && legacyPin.length == 4 && legacyEnabled) {
      if (legacyEmail == null || legacyEmail == currentEmail || uid != 'guest') {
        await prefs.setString(accountKey, legacyPin);
        await prefs.setBool(_pinEnabledKey(uid), true);
        if (currentEmail != null) {
          await prefs.setString(_pinUserEmailKey(uid), currentEmail);
        }
        return legacyPin;
      }
    }

    // Cloud Firestore backup check for signed-in Google accounts
    final firestore = _firestore;
    if (uid != 'guest' && firestore != null) {
      try {
        final doc = await firestore
            .collection('users')
            .doc(uid)
            .collection('settings')
            .doc('pin_lock')
            .get();

        if (doc.exists && doc.data() != null) {
          final cloudPin = doc.data()!['pin'] as String?;
          final cloudEnabled = doc.data()!['enabled'] as bool? ?? false;
          if (cloudEnabled && cloudPin != null && cloudPin.length == 4) {
            await prefs.setString(accountKey, cloudPin);
            await prefs.setBool(_pinEnabledKey(uid), true);
            if (currentEmail != null) {
              await prefs.setString(_pinUserEmailKey(uid), currentEmail);
            }
            return cloudPin;
          }
        }
      } catch (e) {
        debugPrint('Error syncing PIN from Firestore: $e');
      }
    }

    return null;
  }

  /// Check if PIN lock is currently enabled for this Google account
  Future<bool> isPinEnabled({String? userId}) async {
    final uid = _resolveUid(userId);
    final prefs = await SharedPreferences.getInstance();
    final pin = await _getStoredPin(prefs, uid);
    final enabled = prefs.getBool(_pinEnabledKey(uid)) ?? false;
    return enabled && pin != null && pin.length == 4;
  }

  /// Check if a PIN has been created previously for this Google account
  Future<bool> hasPin({String? userId}) async {
    final uid = _resolveUid(userId);
    final prefs = await SharedPreferences.getInstance();
    final pin = await _getStoredPin(prefs, uid);
    return pin != null && pin.length == 4;
  }

  /// Save or update the 4-digit PIN and turn PIN lock ON for this Google account
  Future<bool> setPin(String pin, {String? userId, String? userEmail}) async {
    if (pin.length != 4 || int.tryParse(pin) == null) {
      return false;
    }
    final uid = _resolveUid(userId);
    final auth = _auth;
    final email = userEmail ?? (auth?.currentUser?.uid == uid ? auth?.currentUser?.email : null);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinCodeKey(uid), pin);
    await prefs.setBool(_pinEnabledKey(uid), true);
    if (email != null) {
      await prefs.setString(_pinUserEmailKey(uid), email);
    }

    // Sync to Cloud Firestore if this is a signed-in Google account
    final firestore = _firestore;
    if (uid != 'guest' && firestore != null) {
      try {
        await firestore
            .collection('users')
            .doc(uid)
            .collection('settings')
            .doc('pin_lock')
            .set({
          'pin': pin,
          'enabled': true,
          'email': email,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error saving PIN lock to Cloud Firestore: $e');
      }
    }

    return true;
  }

  /// Verify user input against the stored PIN for this Google account
  Future<bool> verifyPin(String pin, {String? userId}) async {
    final uid = _resolveUid(userId);
    final prefs = await SharedPreferences.getInstance();
    final storedPin = await _getStoredPin(prefs, uid);
    return storedPin != null && storedPin == pin;
  }

  /// Turn off PIN lock and remove stored PIN for this Google account
  Future<void> removePin({String? userId}) async {
    final uid = _resolveUid(userId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinCodeKey(uid));
    await prefs.setBool(_pinEnabledKey(uid), false);
    await prefs.remove(_pinUserEmailKey(uid));

    final firestore = _firestore;
    if (uid != 'guest' && firestore != null) {
      try {
        await firestore
            .collection('users')
            .doc(uid)
            .collection('settings')
            .doc('pin_lock')
            .set({
          'pin': null,
          'enabled': false,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error removing PIN lock from Cloud Firestore: $e');
      }
    }
  }

  /// Retrieve the email/name of the user who set the PIN for this Google account
  Future<String?> getPinUserEmail({String? userId}) async {
    final uid = _resolveUid(userId);
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pinUserEmailKey(uid));
  }
}
