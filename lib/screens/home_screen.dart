import 'dart:async';
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
import 'calculator_screen.dart';
import 'profile_screen.dart';
import '../services/commute_automation_service.dart';
import '../widgets/commute_review_dialog.dart';
import '../widgets/commute_settings_dialog.dart';
import '../widgets/top_save_indicator.dart';
import '../services/weather_service.dart';
import '../services/notification_service.dart';
import '../widgets/weather_forecast_dialog.dart';
import '../widgets/weather_tools_card.dart';
import '../widgets/white_loading_screen.dart';

class HomeScreen extends StatefulWidget {
  final ExpenseProvider provider;

  const HomeScreen({
    super.key,
    required this.provider,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final ScrollController _scrollController;
  bool _isSavingToDb = false;
  bool _isCommuteDialogShowing = false;
  Timer? _commute930Timer;

  ExpenseProvider get provider => widget.provider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController = ScrollController();
    _initCommuteRoutine();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndShowCommuteReview();
    }
  }

  void _initCommuteRoutine() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final commuteService = CommuteAutomationService();
        await commuteService.init(
          onReview: (batchId) {
            _showCommuteDialog(batchId);
          },
          onWeatherTap: () {
            if (mounted) {
              WeatherForecastDialog.show(context);
            }
          },
        );
        await commuteService.checkAndApplyDailyCommute(provider);
        await WeatherService().checkAndApplyLocalMorningWeather();

        // Check if after 9:30 AM and review prompt should popup immediately
        _checkAndShowCommuteReview();

        // If currently before 9:30 AM, schedule in-app timer to popup at 9:30 AM
        _schedule930CommuteTimer();

        // Handle payload if app was cold-started by a notification tap.
        _handlePendingNotificationPayload();
      } catch (e) {
        debugPrint('Init commute / weather routine error: $e');
      }
    });
  }

  void _schedule930CommuteTimer() {
    _commute930Timer?.cancel();
    final now = DateTime.now();
    final target = DateTime(now.year, now.month, now.day, 9, 30);
    if (now.isBefore(target)) {
      final diff = target.difference(now);
      _commute930Timer = Timer(diff, () {
        if (mounted) {
          _checkAndShowCommuteReview();
        }
      });
    }
  }

  void _checkAndShowCommuteReview() {
    if (!mounted || _isCommuteDialogShowing) return;

    final commuteService = CommuteAutomationService();
    if (!commuteService.shouldPromptReview(provider)) return;

    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final batchId = 'commute_$todayStr';

    _showCommuteDialog(batchId);
  }

  Future<void> _showCommuteDialog(String batchId) async {
    if (!mounted || _isCommuteDialogShowing) return;
    setState(() => _isCommuteDialogShowing = true);
    try {
      await CommuteReviewDialog.show(
        context,
        batchId: batchId,
        provider: provider,
      );
    } finally {
      if (mounted) {
        setState(() => _isCommuteDialogShowing = false);
      }
    }
  }

  /// If the app was launched by tapping a notification while terminated,
  /// the payload is stored statically. We process it once here.
  void _handlePendingNotificationPayload() {
    final payload = NotificationService.pendingPayload;
    if (payload == null || !mounted) return;
    NotificationService.clearPendingPayload();

    if (payload == kWeatherPayload) {
      WeatherForecastDialog.show(context);
    } else if (payload.isNotEmpty) {
      // It's a commute batchId
      _showCommuteDialog(payload);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _commute930Timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  /// Returns ordinal string for a day number: 1 → "1st", 2 → "2nd", etc.
  String _ordinalDay(int day) {
    if (day >= 11 && day <= 13) return '${day}th';
    switch (day % 10) {
      case 1: return '${day}st';
      case 2: return '${day}nd';
      case 3: return '${day}rd';
      default: return '${day}th';
    }
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
                  leading: const Icon(Icons.calendar_month_rounded, color: AppColors.forestGreen),
                  title: const Text('Pick Month Period...'),
                  trailing: provider.filterMode == DateFilterMode.monthPeriod
                      ? const Icon(Icons.check_rounded, color: AppColors.forestGreen)
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showMonthPickerModal(context, provider, forGeneralExpenses: true);
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

  void _openProfileScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(provider: provider),
      ),
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
                    _openProfileScreen(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.commute_rounded, color: AppColors.forestGreen),
                  title: const Text('Daily Commute Automation'),
                  subtitle: const Text('9:30 AM prompt to review & insert CNG (৳80) & Metro (৳36)', style: TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    CommuteSettingsDialog.show(context, provider);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.wb_sunny_rounded, color: Colors.orange),
                  title: const Text('9 AM Weather Forecast Alert'),
                  subtitle: const Text('Google Maps Weather push notification & rain forecast', style: TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    WeatherForecastDialog.show(context);
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
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: provider,
      builder: (context, _) {
        if (provider.isLoading) {
          return const WhiteLoadingScreen();
        }

        final isTrackerTab = provider.activeTabIndex == 0;

        return Scaffold(
          backgroundColor: AppColors.scaffoldBg,
          body: SafeArea(
            child: Stack(
              children: [
                CustomScrollView(
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
                          const Spacer(),

                          // Calculator Quick Access Button
                          Container(
                            margin: const EdgeInsets.only(right: 10),
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 1.2,
                              ),
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(
                                Icons.calculate_outlined,
                                color: AppColors.forestGreen,
                                size: 20,
                              ),
                              tooltip: 'Calculator',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CalculatorScreen(),
                                  ),
                                );
                              },
                            ),
                          ),

                          // User Avatar & Cloud Button
                          Builder(builder: (context) {
                            final currentUser = AuthService().currentUser;
                            return InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () => _openProfileScreen(context),
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

                                // Pick a month button (above marked table)
                                if (provider.filterMode == DateFilterMode.monthlyDistribution) ...[
                                  _buildPickMonthButton(context, provider),
                                  if (provider.hasSepOctMonthlyDistributionItems) ...[
                                    const SizedBox(height: 10),
                                    _buildMoveSepOctBanner(context, provider),
                                  ],
                                  if (provider.selectedMonthlyDistributionIds.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    _buildCopyToNextMonthBar(context, provider),
                                  ],
                                  const SizedBox(height: 14),
                                ],

                                // Expense Sheet Table (Columns: SL, CATEGORY, DESCRIPTION, AMOUNT)
                                ExpenseSheetTable(provider: provider),

                                const SizedBox(height: 14),

                                // Save to DB Action Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    onPressed: _isSavingToDb
                                        ? null
                                        : () async {
                                            setState(() => _isSavingToDb = true);
                                            final ok = await provider.pushToCloud();
                                            if (context.mounted) {
                                              setState(() => _isSavingToDb = false);
                                              final isCloud = provider.isCloudSynced;
                                              final syncError = provider.lastSyncError;

                                              String msg;
                                              Color bg;
                                              IconData icon;

                                              if (!isCloud) {
                                                msg = 'Saved to Local DB (Sign in with Google to sync with Cloud)';
                                                bg = const Color(0xFF334155);
                                                icon = Icons.save_rounded;
                                              } else if (ok) {
                                                msg = 'Successfully saved to Cloud Database (Firestore)!';
                                                bg = AppColors.forestGreen;
                                                icon = Icons.cloud_done_rounded;
                                              } else {
                                                msg = 'Save failed: ${syncError ?? "Check Firestore permissions/database"}';
                                                bg = const Color(0xFF991B1B);
                                                icon = Icons.error_outline_rounded;
                                              }

                                              ScaffoldMessenger.of(context).clearSnackBars();
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Row(
                                                    children: [
                                                      Icon(icon, color: Colors.white, size: 18),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          msg,
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.w600,
                                                            fontSize: 13,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  backgroundColor: bg,
                                                  duration: Duration(seconds: ok ? 3 : 5),
                                                  behavior: SnackBarBehavior.floating,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                    icon: _isSavingToDb
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.cloud_upload_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                    label: Text(
                                      _isSavingToDb ? 'Saving to Database...' : 'Save to DB',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.forestGreen,
                                      elevation: 1,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 14),

                                // All changes saved banner
                                SyncStatusCard(
                                  lastSavedAt: provider.lastSavedAt,
                                  isCloudSynced: provider.isCloudSynced,
                                ),

                                const SizedBox(height: 100),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Live Weather Info & Forecast Tool Card
                                const WeatherToolsCard(),

                                // Tools Action Card (Calculator)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
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
                                  child: Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => const CalculatorScreen(),
                                          ),
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                          vertical: 16,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 48,
                                              height: 48,
                                              decoration: BoxDecoration(
                                                color: AppColors.mintBadgeBg,
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              child: const Icon(
                                                Icons.calculate_rounded,
                                                size: 26,
                                                color: AppColors.forestGreen,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            const Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Calculator',
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w700,
                                                      color: AppColors.textDark,
                                                    ),
                                                  ),
                                                  SizedBox(height: 2),
                                                  Text(
                                                    'Full calculator with % calculation',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: AppColors.textMuted,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF3F4F6),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: const Icon(
                                                Icons.arrow_forward_ios_rounded,
                                                size: 13,
                                                color: AppColors.textDark,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Insight Page kept inside Tools menu
                                InsightsView(provider: provider),
                                const SizedBox(height: 100),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
                // Animated Top Center Save Icon
                Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: TopSaveIndicator(
                      lastSavedAt: provider.lastSavedAt,
                      isCloud: provider.isCloudSynced,
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

            // Right Tab: Tools (Insights inside)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => provider.setActiveTab(1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.handyman_outlined,
                      size: 24,
                      color: !isTrackerTab ? AppColors.forestGreen : AppColors.textSubtle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tools',
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


  Widget _buildMoveSepOctBanner(BuildContext context, ExpenseProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.sync_alt_rounded, size: 20, color: Color(0xFF1D4ED8)),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Move items from 15 Sep – 15 Oct to 15 Oct – 15 Nov',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E3A8A),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              final count = await provider.moveSepOctMonthlyDistributionToOctNov();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Successfully moved $count items to 15 Oct – 15 Nov!'),
                    backgroundColor: AppColors.forestGreen,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.forestGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Move Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyToNextMonthBar(BuildContext context, ExpenseProvider provider) {
    final count = provider.selectedMonthlyDistributionIds.length;
    final nextPeriod = provider.nextMonthlyDistributionPeriod;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.forestGreen,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.forestGreen.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.content_copy_rounded,
              size: 15,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$count ${count == 1 ? 'item' : 'items'} selected',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Next: ${nextPeriod.label}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final copied = await provider.copySelectedToNextMonth();
              if (context.mounted) {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Successfully copied $copied ${copied == 1 ? 'item' : 'items'} to ${nextPeriod.label}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    backgroundColor: AppColors.forestGreen,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    action: SnackBarAction(
                      label: 'View',
                      textColor: Colors.white,
                      onPressed: () {
                        provider.setSelectedMonthlyDistributionPeriod(nextPeriod);
                      },
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.arrow_forward_rounded, size: 14),
            label: const Text(
              'Copy to next month',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.forestGreen,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => provider.clearMonthlyDistributionSelection(),
            icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white70),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Clear selection',
          ),
        ],
      ),
    );
  }

  Widget _buildPickMonthButton(BuildContext context, ExpenseProvider provider) {
    final selectedPeriod = provider.selectedMonthlyDistributionPeriod;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showMonthPickerModal(context, provider),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.tableBorder,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.mintBadgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  size: 18,
                  color: AppColors.forestGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pick a month',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            selectedPeriod.label,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (selectedPeriod.isCurrent) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.forestGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Current',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.forestGreen,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 22,
                color: AppColors.forestGreen,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMonthPickerModal(
    BuildContext context,
    ExpenseProvider provider, {
    bool forGeneralExpenses = false,
  }) {
    final periods = provider.availableMonthPeriods;
    final selectedPeriod = forGeneralExpenses
        ? (provider.selectedExpenseMonthPeriod ?? provider.currentMonthPeriod)
        : provider.selectedMonthlyDistributionPeriod;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceWhite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.35,
          maxChildSize: 0.85,
          expand: false,
          builder: (sheetCtx, scrollController) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.mintBadgeBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.date_range_rounded,
                          size: 20,
                          color: AppColors.forestGreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Select Month',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                            Text(
                              'Cycle starts on the ${_ordinalDay(provider.monthStartDay)} of each month',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.tableBorder),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    itemCount: periods.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      indent: 48,
                      color: Color(0xFFF1F5F9),
                    ),
                    itemBuilder: (itemCtx, index) {
                      final period = periods[index];
                      final isSelected = period == selectedPeriod;

                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        tileColor: isSelected
                            ? AppColors.forestGreen.withValues(alpha: 0.06)
                            : Colors.transparent,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.forestGreen
                                : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isSelected
                                ? Icons.check_rounded
                                : Icons.calendar_today_outlined,
                            size: 15,
                            color: isSelected ? Colors.white : AppColors.textMuted,
                          ),
                        ),
                        title: Text(
                          period.label,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            color: isSelected ? AppColors.forestGreen : AppColors.textDark,
                          ),
                        ),
                        trailing: period.isCurrent
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.mintBadgeBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.forestGreen.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: const Text(
                                  'Current',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.forestGreen,
                                  ),
                                ),
                              )
                            : null,
                        onTap: () {
                          if (forGeneralExpenses) {
                            provider.setMonthPeriodFilter(period);
                          } else {
                            provider.setSelectedMonthlyDistributionPeriod(period);
                          }
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
