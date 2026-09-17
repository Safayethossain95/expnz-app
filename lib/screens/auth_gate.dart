import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../providers/expense_provider.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'sign_in_screen.dart';

class AuthGate extends StatefulWidget {
  final ExpenseProvider provider;

  const AuthGate({super.key, required this.provider});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _authService = AuthService();
  bool _guestMode = false;
  String? _lastLoadedUid;

  @override
  Widget build(BuildContext context) {
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
