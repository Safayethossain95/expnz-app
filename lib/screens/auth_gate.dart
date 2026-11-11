import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../providers/expense_provider.dart';
import '../services/auth_service.dart';
import '../services/pin_lock_service.dart';
import '../widgets/white_loading_screen.dart';
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
  bool _isDataLoading = false;

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

  void _loadUserData(String? uid) async {
    _lastLoadedUid = uid;
    if (mounted) {
      setState(() {
        _isDataLoading = true;
      });
    }
    await widget.provider.onUserChanged(uid);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() {
        _isDataLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingPin || _isDataLoading) {
      return const WhiteLoadingScreen();
    }

    if (_pinEnabled && !_isPinUnlocked) {
      return PinLockScreen(
        onUnlocked: () async {
          setState(() {
            _isPinUnlocked = true;
            _isDataLoading = true;
          });
          final currentUser = _authService.currentUser;
          if (currentUser != null) {
            _lastLoadedUid = currentUser.uid;
            await widget.provider.onUserChanged(currentUser.uid);
          } else if (_guestMode) {
            _lastLoadedUid = null;
            await widget.provider.onUserChanged(null);
          } else {
            final user = await _authService.authStateChanges.first;
            if (user != null) {
              _lastLoadedUid = user.uid;
              await widget.provider.onUserChanged(user.uid);
            }
          }
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            setState(() {
              _isDataLoading = false;
            });
          }
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
        if (snapshot.connectionState == ConnectionState.waiting || _isDataLoading) {
          return const WhiteLoadingScreen();
        }

        final user = snapshot.data;

        // If authenticated
        if (user != null) {
          if (_lastLoadedUid != user.uid) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadUserData(user.uid);
            });
            return const WhiteLoadingScreen();
          }
          return HomeScreen(provider: widget.provider);
        }

        // If user explicitly chose to continue as guest
        if (_guestMode) {
          if (_lastLoadedUid != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadUserData(null);
            });
            return const WhiteLoadingScreen();
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

