import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _expression = '';
  String _currentInput = '0';
  double? _firstOperand;
  String? _operator;
  bool _isNewInput = true;

  final NumberFormat _formatter = NumberFormat('#,##0.########');

  void _onDigitPress(String digit) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_isNewInput) {
        _currentInput = digit;
        _isNewInput = false;
      } else {
        if (_currentInput == '0') {
          _currentInput = digit;
        } else if (_currentInput.length < 14) {
          _currentInput += digit;
        }
      }
    });
  }

  void _onDecimalPress() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_isNewInput) {
        _currentInput = '0.';
        _isNewInput = false;
      } else if (!_currentInput.contains('.')) {
        _currentInput += '.';
      }
    });
  }

  void _onOperatorPress(String op) {
    HapticFeedback.selectionClick();
    final val = double.tryParse(_currentInput.replaceAll(',', ''));
    if (val == null) return;

    setState(() {
      if (_firstOperand == null) {
        _firstOperand = val;
        _operator = op;
        _expression = '${_formatNumber(val)} $op';
        _isNewInput = true;
      } else if (!_isNewInput) {
        // Evaluate chain
        final res = _calculate(_firstOperand!, val, _operator!);
        if (res != null) {
          _firstOperand = res;
          _currentInput = _formatNumber(res);
          _expression = '${_formatNumber(res)} $op';
          _operator = op;
          _isNewInput = true;
        }
      } else {
        // Just switch operator
        _operator = op;
        _expression = '${_formatNumber(_firstOperand!)} $op';
      }
    });
  }

  void _onPercentPress() {
    HapticFeedback.selectionClick();
    final val = double.tryParse(_currentInput.replaceAll(',', ''));
    if (val == null) return;

    setState(() {
      if (_firstOperand != null && _operator != null) {
        // E.g. 1000 + 15% -> 15% of 1000 = 150
        double percentVal;
        if (_operator == '+' || _operator == '−') {
          percentVal = _firstOperand! * (val / 100.0);
        } else {
          percentVal = val / 100.0;
        }
        _currentInput = _formatNumber(percentVal);
        _expression = '${_formatNumber(_firstOperand!)} $_operator ${_formatNumber(val)}%';
      } else {
        // Simple percent
        final res = val / 100.0;
        _currentInput = _formatNumber(res);
        _expression = '${_formatNumber(val)}% =';
        _firstOperand = null;
        _operator = null;
        _isNewInput = true;
      }
    });
  }

  void _onToggleSign() {
    HapticFeedback.selectionClick();
    final val = double.tryParse(_currentInput.replaceAll(',', ''));
    if (val == null || val == 0) return;

    setState(() {
      final toggled = -val;
      _currentInput = _formatNumber(toggled);
    });
  }

  void _onBackspace() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_isNewInput) return;
      if (_currentInput.length > 1) {
        _currentInput = _currentInput.substring(0, _currentInput.length - 1);
        if (_currentInput == '-' || _currentInput.isEmpty) {
          _currentInput = '0';
          _isNewInput = true;
        }
      } else {
        _currentInput = '0';
        _isNewInput = true;
      }
    });
  }

  void _onClear() {
    HapticFeedback.selectionClick();
    setState(() {
      _expression = '';
      _currentInput = '0';
      _firstOperand = null;
      _operator = null;
      _isNewInput = true;
    });
  }

  void _onEquals() {
    HapticFeedback.selectionClick();
    if (_firstOperand == null || _operator == null) return;

    final secondOperand = double.tryParse(_currentInput.replaceAll(',', ''));
    if (secondOperand == null) return;

    final res = _calculate(_firstOperand!, secondOperand, _operator!);
    setState(() {
      if (res != null) {
        _expression = '${_formatNumber(_firstOperand!)} $_operator ${_formatNumber(secondOperand)} =';
        _currentInput = _formatNumber(res);
        _firstOperand = null;
        _operator = null;
        _isNewInput = true;
      } else {
        _currentInput = 'Error';
        _expression = 'Cannot divide by 0';
        _firstOperand = null;
        _operator = null;
        _isNewInput = true;
      }
    });
  }

  double? _calculate(double a, double b, String op) {
    switch (op) {
      case '+':
        return a + b;
      case '−':
        return a - b;
      case '×':
        return a * b;
      case '÷':
        if (b == 0) return null;
        return a / b;
      default:
        return b;
    }
  }

  String _formatNumber(double num) {
    if (num.isNaN || num.isInfinite) return 'Error';
    return _formatter.format(num);
  }

  Widget _buildButton({
    required String label,
    required VoidCallback onTap,
    Color? bgColor,
    Color? textColor,
    Widget? customChild,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Material(
          color: bgColor ?? Colors.white,
          borderRadius: BorderRadius.circular(18),
          elevation: 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Container(
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: bgColor != null ? Colors.transparent : const Color(0xFFE5E7EB),
                  width: 1,
                ),
              ),
              child: customChild ??
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: textColor ?? AppColors.textDark,
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Calculator',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.content_copy_rounded, color: AppColors.forestGreen, size: 20),
            tooltip: 'Copy result',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _currentInput));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied $_currentInput to clipboard'),
                  backgroundColor: AppColors.forestGreen,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Display Area
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                alignment: Alignment.bottomRight,
                child: SingleChildScrollView(
                  reverse: true,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Calculation Expression line
                      if (_expression.isNotEmpty)
                        Text(
                          _expression,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                        ),
                      const SizedBox(height: 8),

                      // Current Result / Input
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          _currentInput,
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                            letterSpacing: -1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const Divider(height: 1, color: Color(0xFFE5E7EB)),

            // Keypad
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              color: const Color(0xFFF3F4F6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Row 1: Clear, Toggle Sign, Percent, Divide
                  Row(
                    children: [
                      _buildButton(
                        label: _currentInput == '0' && _expression.isEmpty ? 'AC' : 'C',
                        onTap: _onClear,
                        bgColor: const Color(0xFFFEE2E2),
                        textColor: const Color(0xFFDC2626),
                      ),
                      _buildButton(
                        label: '±',
                        onTap: _onToggleSign,
                        bgColor: const Color(0xFFE5E7EB),
                        textColor: AppColors.textDark,
                      ),
                      _buildButton(
                        label: '%',
                        onTap: _onPercentPress,
                        bgColor: AppColors.mintBadgeBg,
                        textColor: AppColors.forestGreen,
                      ),
                      _buildButton(
                        label: '÷',
                        onTap: () => _onOperatorPress('÷'),
                        bgColor: AppColors.forestGreen,
                        textColor: Colors.white,
                      ),
                    ],
                  ),

                  // Row 2: 7, 8, 9, Multiply
                  Row(
                    children: [
                      _buildButton(label: '7', onTap: () => _onDigitPress('7')),
                      _buildButton(label: '8', onTap: () => _onDigitPress('8')),
                      _buildButton(label: '9', onTap: () => _onDigitPress('9')),
                      _buildButton(
                        label: '×',
                        onTap: () => _onOperatorPress('×'),
                        bgColor: AppColors.forestGreen,
                        textColor: Colors.white,
                      ),
                    ],
                  ),

                  // Row 3: 4, 5, 6, Subtract
                  Row(
                    children: [
                      _buildButton(label: '4', onTap: () => _onDigitPress('4')),
                      _buildButton(label: '5', onTap: () => _onDigitPress('5')),
                      _buildButton(label: '6', onTap: () => _onDigitPress('6')),
                      _buildButton(
                        label: '−',
                        onTap: () => _onOperatorPress('−'),
                        bgColor: AppColors.forestGreen,
                        textColor: Colors.white,
                      ),
                    ],
                  ),

                  // Row 4: 1, 2, 3, Add
                  Row(
                    children: [
                      _buildButton(label: '1', onTap: () => _onDigitPress('1')),
                      _buildButton(label: '2', onTap: () => _onDigitPress('2')),
                      _buildButton(label: '3', onTap: () => _onDigitPress('3')),
                      _buildButton(
                        label: '+',
                        onTap: () => _onOperatorPress('+'),
                        bgColor: AppColors.forestGreen,
                        textColor: Colors.white,
                      ),
                    ],
                  ),

                  // Row 5: 0, Decimal, Backspace, Equals
                  Row(
                    children: [
                      _buildButton(label: '0', onTap: () => _onDigitPress('0')),
                      _buildButton(label: '.', onTap: _onDecimalPress),
                      _buildButton(
                        label: '⌫',
                        onTap: _onBackspace,
                        bgColor: const Color(0xFFE5E7EB),
                        customChild: const Icon(
                          Icons.backspace_outlined,
                          size: 20,
                          color: AppColors.textDark,
                        ),
                      ),
                      _buildButton(
                        label: '=',
                        onTap: _onEquals,
                        bgColor: const Color(0xFF16A34A),
                        textColor: Colors.white,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
