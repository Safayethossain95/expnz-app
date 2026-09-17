import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';
import '../theme/app_theme.dart';

class HeroSummaryCard extends StatelessWidget {
  final ExpenseProvider provider;
  final VoidCallback onBudgetTap;

  const HeroSummaryCard({
    super.key,
    required this.provider,
    required this.onBudgetTap,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '৳', decimalDigits: 2);
    final totalSpentStr = currencyFormat.format(provider.totalSpent);
    final budgetDeltaStr = currencyFormat.format(provider.budgetDelta.abs());
    final isUnderBudget = provider.isUnderBudget;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.forestGreen,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.forestGreen.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Month/Date label + Entry count badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${provider.filterLabel} total',
                style: const TextStyle(
                  color: Color(0xFFB2D4C3),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.1,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${provider.totalEntriesCount} entries',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Hero Total Amount in Taka
          Text(
            totalSpentStr,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              height: 1.1,
            ),
          ),

          const SizedBox(height: 14),

          // Budget delta indicator row
          InkWell(
            onTap: onBudgetTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isUnderBudget
                          ? Colors.white.withValues(alpha: 0.18)
                          : AppColors.warningRed.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isUnderBudget
                          ? Icons.north_east_rounded
                          : Icons.trending_up_rounded,
                      color: isUnderBudget ? const Color(0xFFCBEAD9) : Colors.white,
                      size: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isUnderBudget
                          ? 'Keeping $budgetDeltaStr below monthly budget'
                          : 'Over your monthly budget by $budgetDeltaStr',
                      style: TextStyle(
                        color: isUnderBudget
                            ? const Color(0xFFCBEAD9)
                            : const Color(0xFFFFD2D2),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
