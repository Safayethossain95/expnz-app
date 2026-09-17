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
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Table Content with horizontal scroll safety
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width - 36,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Table Header Row: SL | CATEGORY | DESCRIPTION | AMOUNT
                  Container(
                    color: AppColors.tableHeaderBg,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 36,
                          child: Text(
                            'SL',
                            style: TextStyle(
                              color: AppColors.headerColumnText,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 88,
                          child: Text(
                            'CATEGORY',
                            style: TextStyle(
                              color: AppColors.headerColumnText,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 124,
                          child: Text(
                            'DESCRIPTION',
                            style: TextStyle(
                              color: AppColors.headerColumnText,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 82,
                          child: Text(
                            'AMOUNT',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: AppColors.headerColumnText,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Dynamic Table Rows (Initially 5 rows visible with SL 1..5, expandable via '+' button)
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
                                onUpdate: (updated) {
                                  provider.updateCell(
                                    id: updated.id,
                                    date: updated.date,
                                    category: updated.category,
                                    description: updated.description,
                                    amount: updated.amount,
                                  );
                                },
                                onDelete: () => provider.deleteRow(item.id),
                              );
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 13,
                            ),
                            child: Row(
                              children: [
                                // 1. SL (Serial Number) CELL
                                SizedBox(
                                  width: 36,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Text(
                                      '$serialNumber',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: item.isPlaceholder
                                            ? AppColors.placeholderText
                                            : AppColors.textDark,
                                      ),
                                    ),
                                  ),
                                ),

                                // 2. CATEGORY CELL (Selectable through popup)
                                SizedBox(
                                  width: 88,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () async {
                                      final selected = await EditCellDialogs.pickCategory(
                                        context,
                                        item.category,
                                      );
                                      if (selected != null) {
                                        provider.updateCell(id: item.id, category: selected);
                                      }
                                    },
                                    child: item.category != null && !item.isPlaceholder
                                        ? Container(
                                            margin: const EdgeInsets.only(right: 10),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: item.category!.bgColor,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              item.category!.label,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: item.category!.textColor,
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          )
                                        : const Padding(
                                            padding: EdgeInsets.symmetric(vertical: 4),
                                            child: Text(
                                              'Category ⌵',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                color: AppColors.placeholderText,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                  ),
                                ),

                                // 3. DESCRIPTION CELL
                                SizedBox(
                                  width: 124,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () async {
                                      final updatedDesc = await EditCellDialogs.editDescription(
                                        context,
                                        item.description,
                                      );
                                      if (updatedDesc != null) {
                                        provider.updateCell(id: item.id, description: updatedDesc);
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Text(
                                        item.description.isNotEmpty
                                            ? item.description
                                            : 'Add a note...',
                                        style: TextStyle(
                                          fontSize: 13,
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

                                // 4. AMOUNT CELL (In Bangladeshi Taka ৳)
                                SizedBox(
                                  width: 82,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () async {
                                      final updatedAmt = await EditCellDialogs.editAmount(
                                        context,
                                        item.amount,
                                      );
                                      if (updatedAmt != null) {
                                        provider.updateCell(id: item.id, amount: updatedAmt);
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Text(
                                        item.amount > 0 && !item.isPlaceholder
                                            ? '৳${item.amount.toStringAsFixed(2)}'
                                            : '৳0.00',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontSize: 13,
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
                ],
              ),
            ),
          ),

          // Bottom Hint
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.shade100, width: 1),
              ),
            ),
            child: const Center(
              child: Text(
                'Swipe left and right to see all columns',
                style: TextStyle(
                  color: AppColors.textSubtle,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
