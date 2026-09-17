import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/expense_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/hero_summary_card.dart';
import '../widgets/expense_sheet_table.dart';
import '../widgets/sync_status_card.dart';
import '../widgets/insights_view.dart';
import '../widgets/edit_cell_dialogs.dart';

class HomeScreen extends StatelessWidget {
  final ExpenseProvider provider;

  const HomeScreen({
    super.key,
    required this.provider,
  });

  void _showBudgetDialog(BuildContext context) {
    final controller = TextEditingController(
      text: provider.monthlyBudget.toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Monthly Budget',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Set your monthly spending limit in Taka:',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  prefixText: '৳ ',
                  prefixStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.forestGreen,
                  ),
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
                final newBudget = double.tryParse(controller.text);
                if (newBudget != null && newBudget > 0) {
                  provider.updateBudget(newBudget);
                }
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showDateFilterSheet(BuildContext context) {
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
                  'Filter Expenses by Date',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_rounded, color: AppColors.forestGreen),
                  title: const Text('Today'),
                  trailing: provider.filterMode == DateFilterMode.today
                      ? const Icon(Icons.check_rounded, color: AppColors.forestGreen)
                      : null,
                  onTap: () {
                    provider.setFilterMode(DateFilterMode.today);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.date_range_rounded, color: AppColors.forestGreen),
                  title: const Text('This Month'),
                  trailing: provider.filterMode == DateFilterMode.thisMonth
                      ? const Icon(Icons.check_rounded, color: AppColors.forestGreen)
                      : null,
                  onTap: () {
                    provider.setFilterMode(DateFilterMode.thisMonth);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.all_inclusive_rounded, color: AppColors.forestGreen),
                  title: const Text('All Time'),
                  trailing: provider.filterMode == DateFilterMode.allTime
                      ? const Icon(Icons.check_rounded, color: AppColors.forestGreen)
                      : null,
                  onTap: () {
                    provider.setFilterMode(DateFilterMode.allTime);
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_note_rounded, color: AppColors.forestGreen),
                  title: const Text('Pick Specific Date...'),
                  trailing: provider.filterMode == DateFilterMode.customDate
                      ? const Icon(Icons.check_rounded, color: AppColors.forestGreen)
                      : null,
                  onTap: () async {
                    Navigator.pop(ctx);
                    final picked = await EditCellDialogs.pickDate(context, provider.customSelectedDate);
                    if (picked != null) {
                      provider.setFilterMode(DateFilterMode.customDate, customDate: picked);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showOptionsMenu(BuildContext context) {
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
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.forestGreen),
                  title: const Text('Set Monthly Budget (৳)'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showBudgetDialog(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined, color: AppColors.forestGreen),
                  title: const Text('Export to CSV'),
                  onTap: () {
                    Navigator.pop(ctx);
                    final csv = provider.generateCsv();
                    Clipboard.setData(ClipboardData(text: csv));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('CSV data copied to clipboard!'),
                        backgroundColor: AppColors.forestGreen,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_sweep_rounded, color: AppColors.warningRed),
                  title: const Text(
                    'Clear All / Reset to 0',
                    style: TextStyle(color: AppColors.warningRed, fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    provider.resetToBlank();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('All expense entries cleared.'),
                        backgroundColor: AppColors.forestGreen,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onAddRowPressed(BuildContext context) {
    provider.addNewRow();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Added new row. Tap cells to enter details.'),
        backgroundColor: AppColors.forestGreen,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTrackerTab = provider.activeTabIndex == 0;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: provider.isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.forestGreen),
              )
            : CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // App Bar Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                      child: Row(
                        children: [
                          // App Icon (green rounded square with document symbol)
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.forestGreen,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.receipt_long_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Header Titles
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MY FINANCES',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                const Text(
                                  'Expense tracker',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textDark,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // More Options Button (...)
                          InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () => _showOptionsMenu(context),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey.shade200),
                                color: Colors.white,
                              ),
                              child: const Icon(
                                Icons.more_horiz_rounded,
                                color: AppColors.textDark,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Main Content
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    sliver: SliverToBoxAdapter(
                      child: isTrackerTab
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Forest Green Hero Card in Taka
                                HeroSummaryCard(
                                  provider: provider,
                                  onBudgetTap: () => _showBudgetDialog(context),
                                ),

                                const SizedBox(height: 24),

                                // Section Header: Expense sheet & Date Filter
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: const [
                                          Text(
                                            'Expense sheet',
                                            style: TextStyle(
                                              fontSize: 19,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.textDark,
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                          SizedBox(height: 3),
                                          Text(
                                            'Tap a cell to edit your spending',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: AppColors.textMuted,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Date Filter Dropdown Trigger
                                    InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () => _showDateFilterSheet(context),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 4,
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              provider.filterLabel,
                                              style: const TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.forestGreen,
                                              ),
                                            ),
                                            const SizedBox(width: 3),
                                            const Icon(
                                              Icons.keyboard_arrow_down_rounded,
                                              size: 18,
                                              color: AppColors.forestGreen,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 14),

                                // Expense Sheet Table (Columns: SL, CATEGORY, DESCRIPTION, AMOUNT)
                                ExpenseSheetTable(provider: provider),

                                const SizedBox(height: 16),

                                // All changes saved banner
                                SyncStatusCard(lastSavedAt: provider.lastSavedAt),

                                const SizedBox(height: 100),
                              ],
                            )
                          : Column(
                              children: [
                                InsightsView(provider: provider),
                                const SizedBox(height: 100),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
      ),

      // Floating / Docked Bottom Navigation Bar
      bottomNavigationBar: Container(
        padding: const EdgeInsets.only(left: 36, right: 36, bottom: 20, top: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left Tab: Tracker
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => provider.setActiveTab(0),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cottage_outlined,
                      size: 24,
                      color: isTrackerTab ? AppColors.forestGreen : AppColors.textSubtle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tracker',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isTrackerTab ? AppColors.forestGreen : AppColors.textSubtle,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Center Action Button: Elevated green + button
            GestureDetector(
              onTap: () => _onAddRowPressed(context),
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.forestGreen,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.forestGreen.withValues(alpha: 0.38),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),

            // Right Tab: Insights
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => provider.setActiveTab(1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.show_chart_rounded,
                      size: 24,
                      color: !isTrackerTab ? AppColors.forestGreen : AppColors.textSubtle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Insights',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: !isTrackerTab ? AppColors.forestGreen : AppColors.textSubtle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
