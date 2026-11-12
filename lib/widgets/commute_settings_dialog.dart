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
  late int _notifyHour;
  late int _notifyMinute;

  @override
  void initState() {
    super.initState();
    _enabled = _commuteService.config.enabled;
    _items = List.from(_commuteService.config.items);
    _notifyHour = _commuteService.config.notifyHour;
    _notifyMinute = _commuteService.config.notifyMinute;
  }

  String _formatTime12(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$hour12:$minuteStr $period';
  }

  Future<void> _save() async {
    final updated = _commuteService.config.copyWith(
      enabled: _enabled,
      items: _items,
      notifyHour: _notifyHour,
      notifyMinute: _notifyMinute,
    );
    await _commuteService.saveConfig(updated);
    if (_enabled) {
      await _commuteService.updateNotifyTime(_notifyHour, _notifyMinute);
    } else {
      await NotificationService().cancelNotification(1001);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _showAddEditItemDialog({
    CommuteItemTemplate? initialItem,
    int? editIndex,
  }) async {
    ExpenseCategory selectedCategory = initialItem?.category ?? ExpenseCategory.travel;
    final descController = TextEditingController(text: initialItem?.description ?? '');
    final amountController = TextEditingController(
      text: initialItem != null
          ? (initialItem.amount.toInt() == initialItem.amount
              ? initialItem.amount.toInt().toString()
              : initialItem.amount.toString())
          : '',
    );
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.mintBadgeBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.commute_rounded, color: AppColors.forestGreen, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    initialItem == null ? 'Add Commute Entry' : 'Edit Commute Entry',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CATEGORY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: ExpenseCategory.values.map((cat) {
                          final isSelected = cat == selectedCategory;
                          return ChoiceChip(
                            label: Text(
                              cat.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? Colors.white : AppColors.textDark,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: AppColors.forestGreen,
                            backgroundColor: const Color(0xFFF1F5F9),
                            onSelected: (val) {
                              if (val) {
                                setDialogState(() => selectedCategory = cat);
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'DESCRIPTION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: descController,
                        decoration: InputDecoration(
                          hintText: 'e.g. CNG vara, Metro, Bus fare',
                          hintStyle: const TextStyle(fontSize: 13, color: AppColors.placeholderText),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.tableBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.tableBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.forestGreen, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'AMOUNT (BDT)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          prefixText: '৳ ',
                          prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                          hintText: '0.00',
                          hintStyle: const TextStyle(fontSize: 13, color: AppColors.placeholderText),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.tableBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.tableBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.forestGreen, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter amount';
                          }
                          final parsed = double.tryParse(val.trim());
                          if (parsed == null || parsed <= 0) {
                            return 'Enter a valid positive amount';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? false) {
                      final desc = descController.text.trim();
                      final amount = double.parse(amountController.text.trim());
                      final newTemplate = CommuteItemTemplate(
                        category: selectedCategory,
                        description: desc,
                        amount: amount,
                      );

                      setState(() {
                        if (editIndex != null && editIndex >= 0 && editIndex < _items.length) {
                          _items[editIndex] = newTemplate;
                        } else {
                          _items.add(newTemplate);
                        }
                      });
                      Navigator.pop(dialogCtx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forestGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(initialItem == null ? 'Add Entry' : 'Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
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

    final summaryStr = _items.isEmpty
        ? 'No items'
        : _items
            .map((i) => '${i.description} (৳${i.amount.toInt() == i.amount ? i.amount.toInt() : i.amount})')
            .join(' & ');

    // Trigger real system push notification
    await NotificationService().showCommuteNotification(
      batchId: testBatchId,
      title: 'Daily Commute Entry Added',
      body: 'Data entry successful: $summaryStr recorded for today. Tap to keep or discard.',
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

            // Schedule info & notification time picker pill
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(hour: _notifyHour, minute: _notifyMinute),
                );
                if (picked != null) {
                  setState(() {
                    _notifyHour = picked.hour;
                    _notifyMinute = picked.minute;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_rounded, size: 16, color: AppColors.forestGreen),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime12(_notifyHour, _notifyMinute),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.forestGreen),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.edit_rounded, size: 12, color: AppColors.forestGreen),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Review prompt time',
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Scheduled Entries:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.mintBadgeBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_items.length}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.forestGreen),
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => _showAddEditItemDialog(),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 15, color: AppColors.forestGreen),
                  label: const Text(
                    'Add Entry',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.forestGreen),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Entries List
            if (_items.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Center(
                  child: Text(
                    'No morning commute entries configured.\nTap "+ Add Entry" to add.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ),
              )
            else
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: _items[i].category.bgColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _items[i].category.label,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: _items[i].category.textColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _items[i].description,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                            Text(
                              formatCurrency(_items[i].amount),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.textMuted),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                              onPressed: () => _showAddEditItemDialog(
                                initialItem: _items[i],
                                editIndex: i,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                              onPressed: () {
                                setState(() {
                                  _items.removeAt(i);
                                });
                              },
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
              label: Text('Simulate ${_formatTime12(_notifyHour, _notifyMinute)} Notification & Modal'),
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
