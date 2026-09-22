import 'package:flutter/material.dart';
import '../services/pin_lock_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pin_keypad.dart';

class PinLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  final VoidCallback? onResetAuth;

  const PinLockScreen({
    super.key,
    required this.onUnlocked,
    this.onResetAuth,
  });

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen>
    with SingleTickerProviderStateMixin {
  final PinLockService _pinService = PinLockService();
  final AuthService _authService = AuthService();

  String _inputPin = '';
  String? _errorMessage;
  bool _hasError = false;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _shakeController.stop();
    _shakeController.dispose();
    super.dispose();
  }

  void _triggerError(String message) {
    setState(() {
      _errorMessage = message;
      _hasError = true;
      _inputPin = '';
    });
    _shakeController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _hasError = false;
        });
      }
    });
  }

  void _onDigitPressed(String digit) {
    if (_inputPin.length >= 4) return;

    setState(() {
      _inputPin += digit;
      _errorMessage = null;
    });

    if (_inputPin.length == 4) {
      _verifyPin(_inputPin);
    }
  }

  void _onBackspacePressed() {
    if (_inputPin.isNotEmpty) {
      setState(() {
        _inputPin = _inputPin.substring(0, _inputPin.length - 1);
        _errorMessage = null;
      });
    }
  }

  void _onClearPressed() {
    setState(() {
      _inputPin = '';
      _errorMessage = null;
    });
  }

  Future<void> _verifyPin(String pin) async {
    final isValid = await _pinService.verifyPin(pin);
    if (isValid) {
      widget.onUnlocked();
    } else {
      _triggerError('Incorrect PIN. Try again.');
    }
  }

  void _showForgotPinDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Forgot PIN?',
          style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark),
        ),
        content: const Text(
          'If you forgot your 4-digit PIN, you can reset it by signing out and re-authenticating with your Google Account.',
          style: TextStyle(fontSize: 13.5, color: AppColors.textMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _pinService.removePin();
              await _authService.signOut();
              if (widget.onResetAuth != null) {
                widget.onResetAuth!();
              }
            },
            child: const Text('Reset & Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // User Avatar or App Icon
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: AppColors.forestGreen, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.forestGreen.withValues(alpha: 0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: currentUser?.photoURL != null
                        ? Image.network(
                            currentUser!.photoURL!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.lock_rounded,
                              size: 36,
                              color: AppColors.forestGreen,
                            ),
                          )
                        : const Icon(
                            Icons.lock_rounded,
                            size: 36,
                            color: AppColors.forestGreen,
                          ),
                  ),
                ),
                const SizedBox(height: 18),

                // Welcome / Greeting
                Text(
                  currentUser?.displayName != null
                      ? 'Welcome back, ${currentUser!.displayName}'
                      : 'Expnz App Lock',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Enter your 4-digit PIN to unlock',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 28),

                // Animated PIN dots
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(_shakeAnimation.value, 0),
                      child: PinDotsIndicator(
                        pinLength: _inputPin.length,
                        hasError: _hasError,
                      ),
                    );
                  },
                ),

                const SizedBox(height: 14),
                SizedBox(
                  height: 20,
                  child: _errorMessage != null
                      ? Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFDC2626),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 24),

                // Numeric Keypad
                PinKeypad(
                  onDigitPressed: _onDigitPressed,
                  onBackspacePressed: _onBackspacePressed,
                  onClearPressed: _onClearPressed,
                ),

                const SizedBox(height: 28),

                // Forgot PIN link
                TextButton(
                  onPressed: _showForgotPinDialog,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                  ),
                  child: const Text(
                    'Forgot PIN?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
