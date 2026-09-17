import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/hero_summary_card.dart';
import '../widgets/expense_sheet_table.dart';
import '../widgets/sync_status_card.dart';
import '../widgets/insights_view.dart';
import '../widgets/edit_cell_dialogs.dart';

class HomeScreen extends StatefulWidget {
  final ExpenseProvider provider;

  const HomeScreen({
    super.key,
    required this.provider,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ScrollController _scrollController;

  ExpenseProvider get provider => widget.provider;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
                  leading: const Icon(Icons.pie_chart_outline_rounded, color: AppColors.forestGreen),
                  title: const Text('Monthly distribution'),
                  trailing: provider.filterMode == DateFilterMode.monthlyDistribution
                      ? const Icon(Icons.check_rounded, color: AppColors.forestGreen)
                      : null,
                  onTap: () {
                    provider.setFilterMode(DateFilterMode.monthlyDistribution);
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

  void _showAccountDialog(BuildContext context) {
    final authService = AuthService();
    final user = authService.currentUser;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.mintBadgeBg,
                  border: Border.all(color: AppColors.forestGreen, width: 2),
                ),
                child: ClipOval(
                  child: user?.photoURL != null
                      ? Image.network(
                          user!.photoURL!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.person_rounded,
                            color: AppColors.forestGreen,
                            size: 36,
                          ),
                        )
                      : const Icon(
                          Icons.person_rounded,
                          color: AppColors.forestGreen,
                          size: 36,
                        ),
                ),
              ),
              const SizedBox(height: 14),

              Text(
                user?.displayName ?? (user != null ? 'Signed In' : 'Guest Mode'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user?.email ?? 'Using offline local storage only',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 18),

              // Cloud Status Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: user != null ? const Color(0xFFF0FDF4) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: user != null ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      user != null ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                      size: 18,
                      color: user != null ? AppColors.forestGreen : const Color(0xFFD97706),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        user != null
                            ? 'Cloud Firestore Synced: Your data is backed up safely across uninstalls.'
                            : 'Not synced to cloud. Reinstalling will erase local data.',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: user != null ? AppColors.forestGreen : const Color(0xFF92400E),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              if (user != null) ...[
                // Refresh / Sync Now Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await provider.refreshFromCloud();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Data reloaded from Cloud Firestore!'),
                            backgroundColor: AppColors.forestGreen,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.sync_rounded, size: 18, color: AppColors.forestGreen),
                    label: const Text(
                      'Sync Now with Cloud',
                      style: TextStyle(color: AppColors.forestGreen, fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.forestGreen),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Sign Out Button
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await authService.signOut();
                    },
                    icon: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFFDC2626)),
                    label: const Text(
                      'Sign Out',
                      style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ] else ...[
                // Sign in with Google Button
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        await authService.signInWithGoogle();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Sign-in failed: $e'),
                              backgroundColor: const Color(0xFFDC2626),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.login_rounded, size: 18),
                    label: const Text('Sign in with Google'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.forestGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showOptionsMenu(BuildContext context) {
    final user = AuthService().currentUser;
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
                  leading: Icon(
                    user != null ? Icons.cloud_done_rounded : Icons.cloud_outlined,
                    color: AppColors.forestGreen,
                  ),
                  title: Text(user != null ? 'Account & Cloud Sync (${user.email})' : 'Sign in to Back up to Cloud'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showAccountDialog(context);
                  },
                ),
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
    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        final isTrackerTab = provider.activeTabIndex == 0;

        return Scaffold(
          backgroundColor: AppColors.scaffoldBg,
          body: SafeArea(
            child: provider.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.forestGreen),
                  )
                : CustomScrollView(
                    key: const PageStorageKey<String>('home_custom_scroll_view'),
                    controller: _scrollController,
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

                          // User Avatar & Cloud Button
                          Builder(builder: (context) {
                            final currentUser = AuthService().currentUser;
                            return InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () => _showAccountDialog(context),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: currentUser != null
                                            ? AppColors.forestGreen
                                            : Colors.grey.shade300,
                                        width: 1.5,
                                      ),
                                      color: Colors.white,
                                    ),
                                    child: ClipOval(
                                      child: currentUser?.photoURL != null
                                          ? Image.network(
                                              currentUser!.photoURL!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) => const Icon(
                                                Icons.person_rounded,
                                                color: AppColors.forestGreen,
                                                size: 22,
                                              ),
                                            )
                                          : Icon(
                                              currentUser != null
                                                  ? Icons.person_rounded
                                                  : Icons.person_outline_rounded,
                                              color: currentUser != null
                                                  ? AppColors.forestGreen
                                                  : Colors.grey.shade600,
                                              size: 22,
                                            ),
                                    ),
                                  ),
                                  if (currentUser != null)
                                    Positioned(
                                      right: -1,
                                      bottom: -1,
                                      child: Container(
                                        width: 13,
                                        height: 13,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(width: 8),

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

                                // Monthly Distribution Breakdown (shown when 'Monthly distribution' is chosen)
                                if (provider.filterMode == DateFilterMode.monthlyDistribution) ...[
                                  _buildMonthlyDistributionSection(context, provider),
                                  const SizedBox(height: 16),
                                ],

                                // Expense Sheet Table (Columns: SL, CATEGORY, DESCRIPTION, AMOUNT)
                                ExpenseSheetTable(provider: provider),

                                const SizedBox(height: 16),

                                // All changes saved banner
                                SyncStatusCard(
                                  lastSavedAt: provider.lastSavedAt,
                                  isCloudSynced: provider.isCloudSynced,
                                ),

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
      },
    );
  }

  Widget _buildMonthlyDistributionSection(BuildContext context, ExpenseProvider provider) {
    final currencyFormat = NumberFormat.currency(symbol: '৳', decimalDigits: 2);
    final categoryMap = provider.categoryBreakdown;
    final totalSpent = provider.totalSpent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.tableBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.mintBadgeBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.pie_chart_outline_rounded,
                      size: 18,
                      color: AppColors.forestGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Monthly Distribution',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => provider.setActiveTab(1),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        'Insights',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.forestGreen,
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 11,
                        color: AppColors.forestGreen,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (categoryMap.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text(
                  'No expenses recorded for this month yet.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                ),
              ),
            )
          else
            ...categoryMap.entries.map((entry) {
              final cat = entry.key;
              final amt = entry.value;
              final percentage = totalSpent > 0 ? (amt / totalSpent) : 0.0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: cat.bgColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            cat.label,
                            style: TextStyle(
                              color: cat.textColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          currencyFormat.format(amt),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(percentage * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: percentage,
                        minHeight: 5,
                        backgroundColor: Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation<Color>(cat.textColor),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
