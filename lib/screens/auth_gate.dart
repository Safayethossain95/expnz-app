import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../providers/expense_provider.dart';
import '../services/auth_service.dart';
import '../services/pin_lock_service.dart';
import 'home_screen.dart';
import 'pin_lock_screen.dart';
import 'sign_in_screen.dart';

class AuthGate extends StatefulWidget {
  final ExpenseProvider provider;

  const AuthGate({super.key, required this.provider});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _authService = AuthService();
  final PinLockService _pinService = PinLockService();
  bool _guestMode = false;
  String? _lastLoadedUid;
  bool _isPinUnlocked = false;
  bool _isCheckingPin = true;
  bool _pinEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkPinLock();
  }

  Future<void> _checkPinLock() async {
    final enabled = await _pinService.isPinEnabled();
    if (mounted) {
      setState(() {
        _pinEnabled = enabled;
        _isCheckingPin = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingPin) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAF9),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1B4D3E)),
        ),
      );
    }

    if (_pinEnabled && !_isPinUnlocked) {
      return PinLockScreen(
        onUnlocked: () {
          setState(() {
            _isPinUnlocked = true;
          });
        },
        onResetAuth: () {
          setState(() {
            _pinEnabled = false;
            _isPinUnlocked = true;
            _guestMode = false;
          });
        },
      );
    }

    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        // Checking connection
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF8FAF9),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF1B4D3E)),
            ),
          );
        }

        final user = snapshot.data;

        // If authenticated
        if (user != null) {
          if (_lastLoadedUid != user.uid) {
            _lastLoadedUid = user.uid;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.provider.onUserChanged(user.uid);
            });
          }
          return HomeScreen(provider: widget.provider);
        }

        // If user explicitly chose to continue as guest
        if (_guestMode) {
          if (_lastLoadedUid != null) {
            _lastLoadedUid = null;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.provider.onUserChanged(null);
            });
          }
          return HomeScreen(provider: widget.provider);
        }

        // Otherwise show Sign In screen
        return SignInScreen(
          onContinueAsGuest: () {
            setState(() {
              _guestMode = true;
            });
          },
        );
      },
    );
  }
}

