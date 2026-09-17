import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense_model.dart';
import '../providers/expense_provider.dart';
import '../theme/app_theme.dart';

class InsightsView extends StatelessWidget {
  final ExpenseProvider provider;

  const InsightsView({
    super.key,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '৳', decimalDigits: 2);
    final totalSpent = provider.totalSpent;
    final budget = provider.monthlyBudget;
    final budgetPercent = budget > 0 ? (totalSpent / budget).clamp(0.0, 1.0) : 0.0;
    final categoryMap = provider.categoryBreakdown;

    ExpenseCategory? topCategory;
    double topAmount = 0.0;
    categoryMap.forEach((cat, amt) {
      if (amt > topAmount) {
        topAmount = amt;
        topCategory = cat;
      }
    });

    final activeExpenses = provider.activeExpenses;
    final avgDailySpend = activeExpenses.isNotEmpty ? totalSpent / 30.0 : 0.0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Budget Overview Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.forestGreen,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppColors.forestGreen.withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Monthly Budget Status',
                      style: TextStyle(
                        color: Color(0xFFB2D4C3),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${(budgetPercent * 100).toStringAsFixed(0)}% used',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: budgetPercent,
                    minHeight: 10,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      budgetPercent > 0.9 ? const Color(0xFFF87171) : const Color(0xFF6EE7B7),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Spent',
                          style: TextStyle(color: Color(0xFF94B5A5), fontSize: 11),
                        ),
                        Text(
                          currencyFormat.format(totalSpent),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Remaining',
                          style: TextStyle(color: Color(0xFF94B5A5), fontSize: 11),
                        ),
                        Text(
                          currencyFormat.format(provider.budgetDelta.abs()),
                          style: TextStyle(
                            color: provider.isUnderBudget
                                ? const Color(0xFFCBEAD9)
                                : const Color(0xFFFFD2D2),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 2. Metric Grid
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  title: 'Daily Average',
                  value: currencyFormat.format(avgDailySpend),
                  icon: Icons.calendar_view_day_rounded,
                  iconColor: AppColors.forestGreen,
                  bgColor: AppColors.mintBadgeBg,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  title: 'Top Category',
                  value: topCategory != null ? topCategory!.label : 'None',
                  icon: topCategory?.icon ?? Icons.star_rounded,
                  iconColor: topCategory?.textColor ?? AppColors.forestGreen,
                  bgColor: topCategory?.bgColor ?? AppColors.mintBadgeBg,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 3. Category Spending Breakdown
          const Text(
            'Category Breakdown',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Distribution of expenses for this period',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),

          if (categoryMap.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.tableBorder),
              ),
              child: const Center(
                child: Text(
                  'No expenses recorded yet. Tap + to add.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.tableBorder),
              ),
              child: Column(
                children: categoryMap.entries.map((entry) {
                  final cat = entry.key;
                  final amt = entry.value;
                  final percentage = totalSpent > 0 ? (amt / totalSpent) : 0.0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: cat.bgColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(cat.icon, size: 14, color: cat.textColor),
                                  const SizedBox(width: 5),
                                  Text(
                                    cat.label,
                                    style: TextStyle(
                                      color: cat.textColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Text(
                              currencyFormat.format(amt),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(percentage * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percentage,
                            minHeight: 6,
                            backgroundColor: Colors.grey.shade100,
                            valueColor: AlwaysStoppedAnimation<Color>(cat.textColor),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.tableBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
