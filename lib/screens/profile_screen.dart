import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../providers/expense_provider.dart';
import '../services/auth_service.dart';
import '../services/month_start_service.dart';
import '../services/pin_lock_service.dart';
import '../services/weather_service.dart';
import '../theme/app_theme.dart';
import '../widgets/commute_settings_dialog.dart';
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
      _weatherService.loadNotificationEnabled(),
      MonthStartService().load(),
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

  Widget _buildCommuteCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.commute_rounded, size: 19, color: AppColors.forestGreen),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Daily Commute Routine',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  CommuteSettingsDialog.show(context, widget.provider);
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(64, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Configure',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.forestGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '9:30 AM prompt to review & insert CNG (৳80) & Metro (৳36).',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.3,
            ),
          ),
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
                  '9:00 AM Weather Alert',
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
          Row(
            children: [
              Expanded(
                child: Text(
                  _isWeatherEnabled
                      ? 'Delivering at 9:00 AM with temperature & rain prediction.'
                      : 'Weather push notifications disabled. Turn on to resume.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    height: 1.3,
                  ),
                ),
              ),
              if (_isWeatherEnabled)
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
