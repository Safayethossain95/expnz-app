import 'package:flutter/material.dart';
import '../models/expense_model.dart';
import '../providers/expense_provider.dart';
import '../services/commute_automation_service.dart';
import '../theme/app_theme.dart';

class CommuteReviewDialog extends StatelessWidget {
  final String batchId;
  final ExpenseProvider provider;

  const CommuteReviewDialog({
    super.key,
    required this.batchId,
    required this.provider,
  });

  static Future<void> show(
    BuildContext context, {
    required String batchId,
    required ExpenseProvider provider,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CommuteReviewDialog(
        batchId: batchId,
        provider: provider,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final commuteService = CommuteAutomationService();
    final items = provider.allExpenses.where((e) => e.batchId == batchId).toList();

    // Fallback if not found by batchId
    final displayItems = items.isNotEmpty
        ? items
        : commuteService.config.items.map((t) {
            return ExpenseItem(
              id: 'temp',
              category: t.category,
              description: t.description,
              amount: t.amount,
              createdAt: DateTime.now(),
            );
          }).toList();

    final total = displayItems.fold<double>(0.0, (sum, item) => sum + item.amount);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Icon & Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.mintBadgeBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: AppColors.forestGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily Commute Entry',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Auto-inserted at 7:00 AM • ৳${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.forestGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'The following 2 expenses were recorded for your daily commute. Would you like to keep them or discard them?',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),

          // Items Table Preview matching the screenshot
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  for (int i = 0; i < displayItems.length; i++) ...[
                    _buildItemRow(i + 1, displayItems[i]),
                    if (i < displayItems.length - 1)
                      const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Actions: Keep or Discard
          Row(
            children: [
              // Discard Button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await commuteService.discardBatch(batchId, provider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Commute entries discarded'),
                          backgroundColor: Color(0xFF374151),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text(
                    'Discard',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    backgroundColor: const Color(0xFFFEF2F2),
                    side: const BorderSide(color: Color(0xFFFECACA)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Keep Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await commuteService.keepBatch(batchId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Daily commute kept (৳${total.toStringAsFixed(2)})',
                          ),
                          backgroundColor: AppColors.forestGreen,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text(
                    'Keep',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: AppColors.forestGreen,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(int index, ExpenseItem item) {
    final cat = item.category ?? ExpenseCategory.travel;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Index number
          SizedBox(
            width: 20,
            child: Text(
              '$index',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Category Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: cat.bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              cat.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cat.textColor,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Description
          Expanded(
            child: Text(
              item.description.isNotEmpty ? item.description : 'Commute',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Amount
          Text(
            '৳${item.amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
