import 'package:flutter/material.dart';
import '../models/commute_rule.dart';
import '../models/expense_model.dart';
import '../providers/expense_provider.dart';
import '../services/commute_automation_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'commute_review_dialog.dart';

class CommuteSettingsDialog extends StatefulWidget {
  final ExpenseProvider provider;

  const CommuteSettingsDialog({super.key, required this.provider});

  static Future<void> show(BuildContext context, ExpenseProvider provider) async {
    await showDialog(
      context: context,
      builder: (ctx) => CommuteSettingsDialog(provider: provider),
    );
  }

  @override
  State<CommuteSettingsDialog> createState() => _CommuteSettingsDialogState();
}

class _CommuteSettingsDialogState extends State<CommuteSettingsDialog> {
  final CommuteAutomationService _commuteService = CommuteAutomationService();
  late bool _enabled;
  late List<CommuteItemTemplate> _items;

  @override
  void initState() {
    super.initState();
    _enabled = _commuteService.config.enabled;
    _items = List.from(_commuteService.config.items);
  }

  Future<void> _save() async {
    final updated = _commuteService.config.copyWith(
      enabled: _enabled,
      items: _items,
    );
    await _commuteService.saveConfig(updated);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _testInsertAndReview() async {
    final now = DateTime.now();
    final testBatchId = 'test_commute_${now.millisecondsSinceEpoch}';

    final testItems = _items.map((t) {
      return ExpenseItem(
        id: 'test-${DateTime.now().microsecondsSinceEpoch}-${t.description}',
        date: now,
        category: t.category,
        description: t.description,
        amount: t.amount,
        isPlaceholder: false,
        createdAt: DateTime.now(),
        batchId: testBatchId,
      );
    }).toList();

    await widget.provider.addExpenseItems(testItems);

    // Trigger real system push notification
    await NotificationService().showCommuteNotification(
      batchId: testBatchId,
      title: 'Daily Commute Entry Added',
      body: 'Data entry successful: CNG (৳80) & Metro (৳36) recorded for today. Tap to keep or discard.',
    );

    if (mounted) {
      Navigator.pop(context);
      CommuteReviewDialog.show(
        context,
        batchId: testBatchId,
        provider: widget.provider,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title & Switch
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.mintBadgeBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.commute_rounded, color: AppColors.forestGreen, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Commute',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        'Automated daily expense routine',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _enabled,
                  activeThumbColor: AppColors.forestGreen,
                  onChanged: (val) {
                    setState(() => _enabled = val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Schedule info pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 16, color: AppColors.forestGreen),
                      SizedBox(width: 8),
                      Text(
                        '7:00 AM',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textDark),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Auto-insert 2 data entries',
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.notifications_active_rounded, size: 16, color: Color(0xFF3B82F6)),
                      SizedBox(width: 8),
                      Text(
                        '9:30 AM',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textDark),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Keep / Discard prompt',
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            const Text(
              'Scheduled Commute Entries:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 10),

            // Entries List
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < _items.length; i++) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _items[i].category.bgColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _items[i].category.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _items[i].category.textColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _items[i].description,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                            ),
                          ),
                          Text(
                            '৳${_items[i].amount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    if (i < _items.length - 1)
                      const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Test Button
            OutlinedButton.icon(
              onPressed: _testInsertAndReview,
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Simulate 9:30 AM Notification & Modal'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.forestGreen,
                side: const BorderSide(color: AppColors.forestGreen),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            // Save / Close
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(color: AppColors.textMuted)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forestGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save Settings'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
