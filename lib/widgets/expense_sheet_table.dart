import 'package:flutter/material.dart';
import '../providers/expense_provider.dart';
import '../theme/app_theme.dart';
import 'edit_cell_dialogs.dart';

class ExpenseSheetTable extends StatelessWidget {
  final ExpenseProvider provider;

  const ExpenseSheetTable({
    super.key,
    required this.provider,
  });

  void _showDbSaveToast(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
    final isCloud = provider.isCloudSynced;
    final syncError = provider.lastSyncError;

    String message;
    Color bg;
    IconData icon;

    if (syncError != null) {
      message = 'Saved locally • Cloud DB error: $syncError';
      bg = const Color(0xFF991B1B);
      icon = Icons.warning_amber_rounded;
    } else if (isCloud) {
      message = 'Saved to Cloud Database (Firestore)';
      bg = AppColors.forestGreen;
      icon = Icons.cloud_done_rounded;
    } else {
      message = 'Saved to Local DB (Sign in to sync with Cloud)';
      bg = const Color(0xFF334155);
      icon = Icons.save_rounded;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = provider.tableRows;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.tableBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const double minTableWidth = 300.0;
          final double availableWidth = constraints.maxWidth;
          final bool isScrollable = availableWidth < minTableWidth;
          final double tableWidth = isScrollable ? minTableWidth : availableWidth;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Scrollable Sheet Content
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: isScrollable
                    ? const BouncingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Row
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                          border: Border(
                            bottom: BorderSide(
                              color: AppColors.tableBorder,
                              width: 1,
                            ),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              child: Text(
                                'SL',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.grey.shade700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 74,
                              child: Text(
                                'CATEGORY',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.grey.shade700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'DESCRIPTION',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.grey.shade700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 72,
                              child: Text(
                                'AMOUNT',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.grey.shade700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Dynamic Table Rows
                      ...rows.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final serialNumber = index + 1;
                        final isLast = index == rows.length - 1;

                        return Container(
                          decoration: BoxDecoration(
                            border: isLast
                                ? null
                                : Border(
                                    bottom: BorderSide(
                                      color: Colors.grey.shade100,
                                      width: 1,
                                    ),
                                  ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onLongPress: () {
                                if (!item.isPlaceholder) {
                                  EditCellDialogs.showRowOptions(
                                    context: context,
                                    item: item,
                                    onUpdate: (updated) async {
                                      await provider.updateCell(
                                        id: updated.id,
                                        date: updated.date,
                                        category: updated.category,
                                        description: updated.description,
                                        amount: updated.amount,
                                      );
                                      if (context.mounted) _showDbSaveToast(context);
                                    },
                                    onDelete: () async {
                                      await provider.deleteRow(item.id);
                                      if (context.mounted) _showDbSaveToast(context);
                                    },
                                  );
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 11,
                                ),
                                child: Row(
                                  children: [
                                    // 1. SL (Serial Number) CELL
                                    SizedBox(
                                      width: 24,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Text(
                                          '$serialNumber',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: item.isPlaceholder
                                                ? AppColors.placeholderText
                                                : AppColors.textDark,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // 2. CATEGORY CELL (Selectable through popup)
                                    SizedBox(
                                      width: 74,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () async {
                                          final selected = await EditCellDialogs.pickCategory(
                                            context,
                                            item.category,
                                          );
                                          if (selected != null) {
                                            await provider.updateCell(id: item.id, category: selected);
                                            if (context.mounted) _showDbSaveToast(context);
                                          }
                                        },
                                        child: item.category != null && !item.isPlaceholder
                                            ? Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: item.category!.bgColor,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  item.category!.label,
                                                  textAlign: TextAlign.center,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: item.category!.textColor,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              )
                                            : const Padding(
                                                padding: EdgeInsets.symmetric(vertical: 4),
                                                child: Text(
                                                  'Category ⌵',
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    color: AppColors.placeholderText,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // 3. DESCRIPTION CELL
                                    Expanded(
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(6),
                                        onTap: () async {
                                          final updatedDesc = await EditCellDialogs.editDescription(
                                            context,
                                            item.description,
                                          );
                                          if (updatedDesc != null) {
                                            await provider.updateCell(id: item.id, description: updatedDesc);
                                            if (context.mounted) _showDbSaveToast(context);
                                          }
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Text(
                                            item.description.isNotEmpty
                                                ? item.description
                                                : 'Add a note...',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w500,
                                              color: item.description.isNotEmpty && !item.isPlaceholder
                                                  ? AppColors.textDark
                                                  : AppColors.placeholderText,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // 4. AMOUNT CELL (In Bangladeshi Taka ৳)
                                    SizedBox(
                                      width: 72,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(6),
                                        onTap: () async {
                                          final updatedAmt = await EditCellDialogs.editAmount(
                                            context,
                                            item.amount,
                                          );
                                          if (updatedAmt != null) {
                                            await provider.updateCell(id: item.id, amount: updatedAmt);
                                            if (context.mounted) _showDbSaveToast(context);
                                          }
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Text(
                                            item.amount > 0 && !item.isPlaceholder
                                                ? '৳${item.amount.toStringAsFixed(2)}'
                                                : '৳0.00',
                                            textAlign: TextAlign.right,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: item.amount > 0 && !item.isPlaceholder
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: item.amount > 0 && !item.isPlaceholder
                                                  ? AppColors.textDark
                                                  : AppColors.placeholderText,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),

                      // Total Spent Footer Row (shown on Monthly Distribution tab)
                      if (provider.filterMode == DateFilterMode.monthlyDistribution)
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F9F6),
                            border: Border(
                              top: BorderSide(
                                color: AppColors.forestGreen.withValues(alpha: 0.25),
                                width: 1.5,
                              ),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 24,
                                child: Icon(
                                  Icons.functions_rounded,
                                  size: 17,
                                  color: AppColors.forestGreen,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'TOTAL SPENT',
                                style: TextStyle(
                                  color: AppColors.forestGreen,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '(${provider.totalEntriesCount} ${provider.totalEntriesCount == 1 ? 'entry' : 'entries'})',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 72,
                                child: Text(
                                  '৳${provider.totalSpent.toStringAsFixed(2)}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.forestGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Bottom Hint / Action Guide
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade100, width: 1),
                  ),
                ),
                child: Center(
                  child: isScrollable
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.swap_horiz_rounded,
                              size: 14,
                              color: AppColors.textSubtle,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Swipe horizontally to see all columns',
                              style: TextStyle(
                                color: AppColors.textSubtle,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'Tap any cell to edit • Long press for options',
                          style: TextStyle(
                            color: AppColors.textSubtle,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

