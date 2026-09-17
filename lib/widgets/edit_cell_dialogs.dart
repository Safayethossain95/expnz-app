import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense_model.dart';
import '../theme/app_theme.dart';

class EditCellDialogs {
  // 1. Pick Date
  static Future<DateTime?> pickDate(BuildContext context, DateTime? initialDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.forestGreen,
              onPrimary: Colors.white,
              onSurface: AppColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );
    return picked;
  }

  // 2. Pick Category Popup
  static Future<ExpenseCategory?> pickCategory(BuildContext context, ExpenseCategory? current) async {
    return showModalBottomSheet<ExpenseCategory>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select Category',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Choose category for this expense entry',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: ExpenseCategory.values.map((cat) {
                    final isSelected = cat == current;
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.pop(ctx, cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: cat.bgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(color: cat.textColor, width: 2)
                              : Border.all(color: Colors.transparent),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(cat.icon, size: 16, color: cat.textColor),
                            const SizedBox(width: 6),
                            Text(
                              cat.label,
                              style: TextStyle(
                                color: cat.textColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  // 3. Edit Description
  static Future<String?> editDescription(BuildContext context, String current) async {
    final controller = TextEditingController(text: current);
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Edit Description',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'e.g. Bazar, Rickshaw, Lunch...',
              hintStyle: const TextStyle(color: AppColors.placeholderText),
              filled: true,
              fillColor: AppColors.scaffoldBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.forestGreen, width: 2),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forestGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // 4. Edit Amount (In Bangladeshi Taka ৳)
  static Future<double?> editAmount(BuildContext context, double current) async {
    final controller = TextEditingController(
      text: current > 0 ? current.toStringAsFixed(2) : '',
    );
    return showDialog<double>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Edit Amount',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  prefixText: '৳ ',
                  prefixStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.forestGreen,
                  ),
                  hintText: '0.00',
                  hintStyle: const TextStyle(color: AppColors.placeholderText),
                  filled: true,
                  fillColor: AppColors.scaffoldBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.forestGreen, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [50.0, 100.0, 200.0, 500.0, 1000.0].map((quickAmt) {
                  return ActionChip(
                    label: Text('+৳${quickAmt.toInt()}', style: const TextStyle(fontSize: 11)),
                    backgroundColor: AppColors.tableHeaderBg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    onPressed: () {
                      final val = double.tryParse(controller.text) ?? 0.0;
                      controller.text = (val + quickAmt).toStringAsFixed(2);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forestGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final amt = double.tryParse(controller.text) ?? 0.0;
                Navigator.pop(ctx, amt);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // 5. Full Row Options or Delete
  static Future<void> showRowOptions({
    required BuildContext context,
    required ExpenseItem item,
    required Function(ExpenseItem updated) onUpdate,
    required VoidCallback onDelete,
  }) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.mintBadgeBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.receipt_rounded, color: AppColors.forestGreen),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.description.isEmpty ? 'Expense Row' : item.description,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          Text(
                            item.date != null
                                ? DateFormat('dd/MM/yyyy').format(item.date!)
                                : 'No date set',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '৳${item.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.forestGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.category_rounded, color: AppColors.forestGreen),
                  title: const Text('Change Category'),
                  trailing: Text(
                    item.category?.label ?? 'Select',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final newCat = await pickCategory(context, item.category);
                    if (newCat != null) {
                      onUpdate(item.copyWith(category: newCat, isPlaceholder: false));
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit_note_rounded, color: AppColors.forestGreen),
                  title: const Text('Change Description'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final newDesc = await editDescription(context, item.description);
                    if (newDesc != null) {
                      onUpdate(item.copyWith(description: newDesc, isPlaceholder: false));
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.currency_lira_rounded, color: AppColors.forestGreen),
                  title: const Text('Change Amount (৳)'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final newAmt = await editAmount(context, item.amount);
                    if (newAmt != null) {
                      onUpdate(item.copyWith(amount: newAmt, isPlaceholder: false));
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_today_rounded, color: AppColors.forestGreen),
                  title: const Text('Change Date'),
                  trailing: Text(
                    item.date != null ? DateFormat('dd/MM/yyyy').format(item.date!) : 'Select',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final newDate = await pickDate(context, item.date);
                    if (newDate != null) {
                      onUpdate(item.copyWith(date: newDate, isPlaceholder: false));
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: AppColors.warningRed),
                  title: const Text(
                    'Delete Row',
                    style: TextStyle(color: AppColors.warningRed, fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    onDelete();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
