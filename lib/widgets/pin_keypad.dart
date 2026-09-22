import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PinDotsIndicator extends StatelessWidget {
  final int pinLength;
  final int maxLength;
  final bool hasError;

  const PinDotsIndicator({
    super.key,
    required this.pinLength,
    this.maxLength = 4,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(maxLength, (index) {
        final isFilled = index < pinLength;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: isFilled ? 18 : 14,
          height: isFilled ? 18 : 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasError
                ? const Color(0xFFDC2626)
                : (isFilled ? AppColors.forestGreen : Colors.transparent),
            border: Border.all(
              color: hasError
                  ? const Color(0xFFDC2626)
                  : (isFilled ? AppColors.forestGreen : const Color(0xFF9CA3AF)),
              width: 2,
            ),
            boxShadow: isFilled && !hasError
                ? [
                    BoxShadow(
                      color: AppColors.forestGreen.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

class PinKeypad extends StatelessWidget {
  final ValueChanged<String> onDigitPressed;
  final VoidCallback onBackspacePressed;
  final VoidCallback? onClearPressed;

  const PinKeypad({
    super.key,
    required this.onDigitPressed,
    required this.onBackspacePressed,
    this.onClearPressed,
  });

  Widget _buildKey(String label, {VoidCallback? onTap, Widget? customChild}) {
    return InkResponse(
      onTap: onTap ?? () => onDigitPressed(label),
      radius: 32,
      splashColor: AppColors.mintBadgeBg,
      highlightColor: Colors.transparent,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: customChild ??
              Text(
                label,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 270),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildKey('1'),
              _buildKey('2'),
              _buildKey('3'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildKey('4'),
              _buildKey('5'),
              _buildKey('6'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildKey('7'),
              _buildKey('8'),
              _buildKey('9'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Clear or Empty placeholder
              if (onClearPressed != null)
                InkResponse(
                  onTap: onClearPressed,
                  radius: 32,
                  child: Container(
                    width: 60,
                    height: 60,
                    alignment: Alignment.center,
                    child: const Text(
                      'Clear',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(width: 60, height: 60),

              _buildKey('0'),

              // Backspace
              _buildKey(
                'backspace',
                onTap: onBackspacePressed,
                customChild: const Icon(
                  Icons.backspace_outlined,
                  size: 20,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
