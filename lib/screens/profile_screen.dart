import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/commute_rule.dart';
import '../models/expense_model.dart';
import '../providers/expense_provider.dart';
import '../services/auth_service.dart';
import '../services/commute_automation_service.dart';
import '../services/month_start_service.dart';
import '../services/notification_service.dart';
import '../services/pin_lock_service.dart';
import '../services/weather_service.dart';
import '../theme/app_theme.dart';
import '../widgets/commute_review_dialog.dart';
import '../widgets/set_pin_dialog.dart';
import '../widgets/weather_forecast_dialog.dart';

class ProfileScreen extends StatefulWidget {
  final ExpenseProvider provider;

  const ProfileScreen({super.key, required this.provider});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final PinLockService _pinService = PinLockService();
  final WeatherService _weatherService = WeatherService();
  final CommuteAutomationService _commuteService = CommuteAutomationService();

  bool _isPinSet = false;
  bool _isWeatherEnabled = false;
  bool _isLoading = true;
  bool _isSyncing = false;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _authSubscription = _authService.authStateChanges.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final user = _authService.currentUser;
    final results = await Future.wait([
      _pinService.isPinEnabled(userId: user?.uid),
      _weatherService.loadNotificationEnabled(syncWithCloud: true),
      MonthStartService().load(),
      _commuteService.loadConfig(),
    ]);

    if (mounted) {
      setState(() {
        _isPinSet = results[0] as bool;
        _isWeatherEnabled = results[1] as bool;
        _isLoading = false;
      });
    }
  }

  String _ordinalDay(int day) {
    if (day >= 11 && day <= 13) return '${day}th';
    switch (day % 10) {
      case 1:
        return '${day}st';
      case 2:
        return '${day}nd';
      case 3:
        return '${day}rd';
      default:
        return '${day}th';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile & Settings',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.forestGreen),
            )
          : ListenableBuilder(
              listenable: widget.provider,
              builder: (ctx, _) {
                final currentMonthStartDay = widget.provider.monthStartDay;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      child: Column(
                    children: [
                      // Avatar
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.mintBadgeBg,
                          border: Border.all(color: AppColors.forestGreen, width: 2.5),
                        ),
                        child: ClipOval(
                          child: user?.photoURL != null
                              ? Image.network(
                                  user!.photoURL!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.person_rounded,
                                    color: AppColors.forestGreen,
                                    size: 44,
                                  ),
                                )
                              : const Icon(
                                  Icons.person_rounded,
                                  color: AppColors.forestGreen,
                                  size: 44,
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text(
                        user?.displayName ?? (user != null ? 'Signed In' : 'Guest Mode'),
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? 'Using offline local storage only',
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Cloud Status Box
                      _buildCloudStatusCard(user),
                      const SizedBox(height: 16),

                      // App PIN Lock Section
                      _buildPinLockCard(user),
                      const SizedBox(height: 14),

                      // Daily Commute Section
                      _buildCommuteCard(),
                      const SizedBox(height: 14),

                      // 9 AM Weather Automation Card
                      _buildWeatherCard(),
                      const SizedBox(height: 14),

                      // Month Start Day Picker
                      _buildMonthStartCard(currentMonthStartDay),
                      const SizedBox(height: 24),

                      // Account Action Buttons
                      if (user != null) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: OutlinedButton.icon(
                            onPressed: _isSyncing
                                ? null
                                : () async {
                                    setState(() => _isSyncing = true);
                                    final messenger = ScaffoldMessenger.of(context);
                                    final ok = await widget.provider.pushToCloud();
                                    if (!mounted) return;
                                    setState(() => _isSyncing = false);
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          ok
                                              ? 'Data successfully saved to Cloud Firestore!'
                                              : 'Sync failed: ${widget.provider.lastSyncError ?? "Check Firestore permissions"}',
                                        ),
                                        backgroundColor: ok
                                            ? AppColors.forestGreen
                                            : const Color(0xFF991B1B),
                                        duration: Duration(seconds: ok ? 3 : 5),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    );
                                  },
                            icon: _isSyncing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.forestGreen,
                                    ),
                                  )
                                : const Icon(Icons.sync_rounded, size: 20, color: AppColors.forestGreen),
                            label: Text(
                              _isSyncing ? 'Syncing...' : 'Sync Now with Cloud',
                              style: const TextStyle(
                                color: AppColors.forestGreen,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.forestGreen, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: TextButton.icon(
                            onPressed: () async {
                              final navigator = Navigator.of(context);
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  title: const Text(
                                    'Sign Out?',
                                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                                  ),
                                  content: const Text(
                                    'Your local data will remain intact, but cloud sync will stop until you sign back in.',
                                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFDC2626),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('Sign Out'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await _authService.signOut();
                                if (!mounted) return;
                                navigator.pop();
                              }
                            },
                            icon: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFFDC2626)),
                            label: const Text(
                              'Sign Out',
                              style: TextStyle(
                                color: Color(0xFFDC2626),
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await _authService.signInWithGoogle();
                              } catch (e) {
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('Sign-in failed: $e'),
                                    backgroundColor: const Color(0xFFDC2626),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.login_rounded, size: 20),
                            label: const Text(
                              'Sign in with Google',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.forestGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
    );
  }

  Widget _buildCloudStatusCard(User? user) {
    final syncError = widget.provider.lastSyncError;
    final hasError = user != null && syncError != null;
    final isSynced = user != null && !hasError;

    Color boxBg = isSynced
        ? const Color(0xFFF0FDF4)
        : (hasError ? const Color(0xFFFEF2F2) : const Color(0xFFFEF3C7));
    Color borderColor = isSynced
        ? const Color(0xFFBBF7D0)
        : (hasError ? const Color(0xFFFECACA) : const Color(0xFFFDE68A));
    Color textColor = isSynced
        ? AppColors.forestGreen
        : (hasError ? const Color(0xFF991B1B) : const Color(0xFF92400E));
    IconData statusIcon = isSynced
        ? Icons.cloud_done_rounded
        : (hasError ? Icons.cloud_off_rounded : Icons.cloud_off_rounded);

    String message;
    if (user == null) {
      message = 'Guest mode: Not synced to cloud. Reinstalling will erase local data.';
    } else if (hasError) {
      message = 'Sync issue: $syncError\n(Check if Firestore is created & rules allow writes)';
    } else {
      message = 'Cloud Firestore Synced: Your data is backed up safely across uninstalls.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: boxBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(statusIcon, size: 19, color: textColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinLockCard(User? user) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isPinSet ? const Color(0xFFF0FDF4) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isPinSet ? const Color(0xFFBBF7D0) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isPinSet ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
                size: 19,
                color: _isPinSet ? AppColors.forestGreen : AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'App PIN Lock',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _isPinSet ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _isPinSet ? 'Active' : 'Off',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _isPinSet ? AppColors.forestGreen : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _isPinSet
                ? 'App is protected with a 4-digit PIN lock for ${user?.email ?? "this account"}.'
                : 'Set a 4-digit PIN to lock access to your expnz for ${user?.email ?? "this account"}.',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          if (!_isPinSet)
            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final success = await SetPinDialog.show(
                    context,
                    isChangingExisting: false,
                    userId: user?.uid,
                    userEmail: user?.email,
                  );
                  if (success == true) {
                    final enabled = await _pinService.isPinEnabled(userId: user?.uid);
                    if (mounted) setState(() => _isPinSet = enabled);
                  }
                },
                icon: const Icon(Icons.pin_rounded, size: 16),
                label: const Text('Set 4-Digit PIN', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forestGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: OutlinedButton(
                      onPressed: () async {
                        final success = await SetPinDialog.show(
                          context,
                          isChangingExisting: true,
                          userId: user?.uid,
                          userEmail: user?.email,
                        );
                        if (success == true) {
                          final enabled = await _pinService.isPinEnabled(userId: user?.uid);
                          if (mounted) setState(() => _isPinSet = enabled);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.forestGreen),
                        foregroundColor: AppColors.forestGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Change PIN',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: TextButton(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            title: const Text(
                              'Turn Off PIN Lock?',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            content: Text(
                              'Anyone opening this app under ${user?.email ?? "this account"} will be able to access expenses without entering a PIN.',
                              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDC2626),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('Turn Off'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await _pinService.removePin(userId: user?.uid);
                          if (mounted) setState(() => _isPinSet = false);
                        }
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Turn Off',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
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

  String _formatTime12(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$hour12:$minuteStr $period';
  }

  Future<void> _showAddEditCommuteItemDialog({
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
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      final desc = descController.text.trim();
                      final amount = double.parse(amountController.text.trim());
                      final newTemplate = CommuteItemTemplate(
                        category: selectedCategory,
                        description: desc,
                        amount: amount,
                      );

                      final currentItems = List<CommuteItemTemplate>.from(_commuteService.config.items);
                      if (editIndex != null && editIndex >= 0 && editIndex < currentItems.length) {
                        currentItems[editIndex] = newTemplate;
                      } else {
                        currentItems.add(newTemplate);
                      }

                      await _commuteService.updateItems(currentItems);
                      if (mounted) setState(() {});
                      if (dialogCtx.mounted) Navigator.pop(dialogCtx);
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

  Future<void> _deleteCommuteItem(int index) async {
    final currentItems = List<CommuteItemTemplate>.from(_commuteService.config.items);
    if (index >= 0 && index < currentItems.length) {
      final item = currentItems[index];
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Remove Entry?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Text('Remove "${item.description}" from morning commute entries?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        currentItems.removeAt(index);
        await _commuteService.updateItems(currentItems);
        if (mounted) setState(() {});
      }
    }
  }

  Future<void> _testCommuteSimulation() async {
    final now = DateTime.now();
    final testBatchId = 'test_commute_${now.millisecondsSinceEpoch}';
    final items = _commuteService.config.items;

    final testItems = items.map((t) {
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

    final summaryStr = items.isEmpty
        ? 'No items'
        : items
            .map((i) => '${i.description} (৳${i.amount.toInt() == i.amount ? i.amount.toInt() : i.amount})')
            .join(' & ');

    await NotificationService().showCommuteNotification(
      batchId: testBatchId,
      title: 'Daily Commute Entry Added',
      body: 'Data entry successful: $summaryStr. Tap to keep or discard.',
    );

    if (mounted) {
      CommuteReviewDialog.show(
        context,
        batchId: testBatchId,
        provider: widget.provider,
      );
    }
  }

  Widget _buildCommuteCard() {
    final config = _commuteService.config;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: config.enabled ? const Color(0xFFF0FDF4) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: config.enabled ? const Color(0xFFBBF7D0) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.commute_rounded,
                size: 19,
                color: config.enabled ? AppColors.forestGreen : AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Daily Commute Routine',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: config.enabled ? AppColors.textDark : AppColors.textMuted,
                  ),
                ),
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch.adaptive(
                  value: config.enabled,
                  activeTrackColor: AppColors.forestGreen,
                  onChanged: (val) async {
                    await _commuteService.setEnabled(val);
                    if (mounted) setState(() {});
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            config.enabled
                ? 'Review prompt and auto-insert default entries every morning.'
                : 'Commute automation disabled. Turn on to resume morning reminders.',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.3,
            ),
          ),
          if (config.enabled) ...[
            const SizedBox(height: 12),

            // 1. Commute Notification Time Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.alarm_rounded, size: 17, color: AppColors.forestGreen),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Commute Notification Time',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: config.notifyHour,
                          minute: config.notifyMinute,
                        ),
                      );
                      if (picked != null) {
                        await _commuteService.updateNotifyTime(picked.hour, picked.minute);
                        if (mounted) {
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Commute notification time set to ${_formatTime12(picked.hour, picked.minute)}',
                              ),
                              backgroundColor: AppColors.forestGreen,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.forestGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime12(config.notifyHour, config.notifyMinute),
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.forestGreen,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit_rounded, size: 13, color: AppColors.forestGreen),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. Default Morning Commute Entries Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Default Morning Entries',
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
                        '${config.items.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.forestGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => _showAddEditCommuteItemDialog(),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 15, color: AppColors.forestGreen),
                  label: const Text(
                    'Add Entry',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forestGreen,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 3. Entries List
            if (config.items.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Center(
                  child: Text(
                    'No morning commute entries configured.\nTap "+ Add Entry" to customize what gets inserted.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.3),
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < config.items.length; i++) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: config.items[i].category.bgColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                config.items[i].category.label,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: config.items[i].category.textColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                config.items[i].description,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                            Text(
                              formatCurrency(config.items[i].amount),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.textMuted),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              tooltip: 'Edit entry',
                              onPressed: () => _showAddEditCommuteItemDialog(
                                initialItem: config.items[i],
                                editIndex: i,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              tooltip: 'Delete entry',
                              onPressed: () => _deleteCommuteItem(i),
                            ),
                          ],
                        ),
                      ),
                      if (i < config.items.length - 1)
                        const Divider(height: 1, color: Color(0xFFF3F4F6)),
                    ],
                    // Summary Footer Row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total per Morning:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                          ),
                          Text(
                            formatCurrency(config.items.fold(0.0, (sum, item) => sum + item.amount)),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.forestGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),

            // 4. Test Simulation Button
            SizedBox(
              width: double.infinity,
              height: 36,
              child: OutlinedButton.icon(
                onPressed: _testCommuteSimulation,
                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                label: const Text(
                  'Simulate Notification & Review Modal',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.forestGreen,
                  side: const BorderSide(color: AppColors.forestGreen),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeatherCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isWeatherEnabled
            ? Colors.orange.withValues(alpha: 0.06)
            : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isWeatherEnabled
              ? Colors.orange.withValues(alpha: 0.25)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.wb_sunny_rounded,
                size: 19,
                color: _isWeatherEnabled ? Colors.orange : AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Weather Alert',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _isWeatherEnabled ? AppColors.textDark : AppColors.textMuted,
                  ),
                ),
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch.adaptive(
                  value: _isWeatherEnabled,
                  activeTrackColor: Colors.orange,
                  onChanged: (val) async {
                    setState(() => _isWeatherEnabled = val);
                    await _weatherService.setNotificationEnabled(val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            _isWeatherEnabled
                ? 'Delivers daily morning temperature & rain forecast alerts.'
                : 'Weather push notifications disabled. Turn on to resume.',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.3,
            ),
          ),
          if (_isWeatherEnabled) ...[
            const SizedBox(height: 12),

            // Weather Notification Time Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 17, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Weather Notification Time',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: _weatherService.notificationHour,
                          minute: _weatherService.notificationMinute,
                        ),
                      );
                      if (picked != null) {
                        await _weatherService.setNotificationTime(picked.hour, picked.minute);
                        if (mounted) {
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Weather alert time set to ${_formatTime12(picked.hour, picked.minute)}',
                              ),
                              backgroundColor: Colors.orange.shade800,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime12(_weatherService.notificationHour, _weatherService.notificationMinute),
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit_rounded, size: 13, color: Colors.orange),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: Text(
                    'Delivering at ${_formatTime12(_weatherService.notificationHour, _weatherService.notificationMinute)} with rain prediction.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      height: 1.3,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    WeatherForecastDialog.show(context);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(54, 24),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'View / Test',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMonthStartCard(int currentMonthStartDay) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBAE6FD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                size: 19,
                color: Color(0xFF0369A1),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Month Start Date',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _ordinalDay(currentMonthStartDay),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0369A1),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            currentMonthStartDay == 1
                ? 'Using calendar month (1st to last day).'
                : 'This month filter: ${MonthStartService().periodLabel()}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          // Day picker chips – scrollable row
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 28,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final day = i + 1;
                final isSelected = day == currentMonthStartDay;
                return GestureDetector(
                  onTap: () async {
                    await widget.provider.setMonthStartDay(day);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF0369A1)
                          : const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : const Color(0xFF0369A1),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
