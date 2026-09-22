import 'package:flutter/material.dart';
import '../services/pin_lock_service.dart';
import '../theme/app_theme.dart';
import 'pin_keypad.dart';

enum _PinStep {
  enterCurrent,
  enterNew,
  confirmNew,
  success,
}

class SetPinDialog extends StatefulWidget {
  final bool isChangingExisting;
  final String? userEmail;

  const SetPinDialog({
    super.key,
    this.isChangingExisting = false,
    this.userEmail,
  });

  static Future<bool?> show(
    BuildContext context, {
    bool isChangingExisting = false,
    String? userEmail,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SetPinDialog(
          isChangingExisting: isChangingExisting,
          userEmail: userEmail,
        ),
      ),
    );
  }

  @override
  State<SetPinDialog> createState() => _SetPinDialogState();
}

class _SetPinDialogState extends State<SetPinDialog>
    with SingleTickerProviderStateMixin {
  final PinLockService _pinService = PinLockService();

  late _PinStep _step;
  String _currentInput = '';
  String _firstEnteredPin = '';
  String? _errorMessage;
  bool _hasError = false;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _step = widget.isChangingExisting
        ? _PinStep.enterCurrent
        : _PinStep.enterNew;

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
      _currentInput = '';
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
    if (_currentInput.length >= 4) return;

    setState(() {
      _currentInput += digit;
      _errorMessage = null;
    });

    if (_currentInput.length == 4) {
      _processCompleteInput(_currentInput);
    }
  }

  void _onBackspacePressed() {
    if (_currentInput.isNotEmpty) {
      setState(() {
        _currentInput = _currentInput.substring(0, _currentInput.length - 1);
        _errorMessage = null;
      });
    }
  }

  void _onClearPressed() {
    setState(() {
      _currentInput = '';
      _errorMessage = null;
    });
  }

  Future<void> _processCompleteInput(String pin) async {
    switch (_step) {
      case _PinStep.enterCurrent:
        final isValid = await _pinService.verifyPin(pin);
        if (!isValid) {
          _triggerError('Incorrect current PIN. Try again.');
        } else {
          setState(() {
            _step = _PinStep.enterNew;
            _currentInput = '';
            _errorMessage = null;
          });
        }
        break;

      case _PinStep.enterNew:
        setState(() {
          _firstEnteredPin = pin;
          _step = _PinStep.confirmNew;
          _currentInput = '';
          _errorMessage = null;
        });
        break;

      case _PinStep.confirmNew:
        if (pin != _firstEnteredPin) {
          _triggerError('PINs do not match. Please enter again.');
          // reset back to first step
          setState(() {
            _step = _PinStep.enterNew;
            _firstEnteredPin = '';
          });
        } else {
          // Success! Save PIN
          await _pinService.setPin(pin, userEmail: widget.userEmail);
          setState(() {
            _step = _PinStep.success;
          });
          await Future.delayed(const Duration(milliseconds: 700));
          if (mounted) {
            Navigator.pop(context, true);
          }
        }
        break;

      case _PinStep.success:
        break;
    }
  }

  String get _title {
    switch (_step) {
      case _PinStep.enterCurrent:
        return 'Verify Current PIN';
      case _PinStep.enterNew:
        return widget.isChangingExisting ? 'Enter New PIN' : 'Set 4-Digit PIN';
      case _PinStep.confirmNew:
        return 'Confirm 4-Digit PIN';
      case _PinStep.success:
        return 'PIN Saved Successfully!';
    }
  }

  String get _subtitle {
    switch (_step) {
      case _PinStep.enterCurrent:
        return 'Enter your current PIN to continue';
      case _PinStep.enterNew:
        return 'Choose a 4-digit PIN for Expnz app lock';
      case _PinStep.confirmNew:
        return 'Re-enter your 4-digit PIN to confirm';
      case _PinStep.success:
        return 'Your app is now protected with PIN lock';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
        children: [
          // Close button and header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.mintBadgeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  color: AppColors.forestGreen,
                  size: 22,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context, false),
                icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_step == _PinStep.success) ...[
            const SizedBox(height: 16),
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFDCFCE7),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppColors.forestGreen,
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 24),
          ] else ...[
            Text(
              _title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 24),

            // Animated PIN Dots
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_shakeAnimation.value, 0),
                  child: PinDotsIndicator(
                    pinLength: _currentInput.length,
                    hasError: _hasError,
                  ),
                );
              },
            ),

            const SizedBox(height: 12),
            SizedBox(
              height: 20,
              child: _errorMessage != null
                  ? Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFDC2626),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            // Keypad
            PinKeypad(
              onDigitPressed: _onDigitPressed,
              onBackspacePressed: _onBackspacePressed,
              onClearPressed: _onClearPressed,
            ),
          ],
        ],
      ),
    ),
  );
}
}
