import 'package:flutter/material.dart';
import '../services/weather_service.dart';
import '../theme/app_theme.dart';

class WeatherForecastDialog extends StatefulWidget {
  const WeatherForecastDialog({super.key});

  static Future<void> show(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (ctx) => const WeatherForecastDialog(),
    );
  }

  @override
  State<WeatherForecastDialog> createState() => _WeatherForecastDialogState();
}

class _WeatherForecastDialogState extends State<WeatherForecastDialog> {
  final WeatherService _weatherService = WeatherService();
  bool _isLoading = true;
  WeatherSummary? _summary;
  bool _isSendingTest = false;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    setState(() => _isLoading = true);
    final hours = await _weatherService.fetchHourlyForecast();
    final summary = _weatherService.generateSummary(hours);

    if (mounted) {
      setState(() {
        _summary = summary;
        _isLoading = false;
      });
    }
  }

  Future<void> _testNotification() async {
    setState(() => _isSendingTest = true);
    final summary = await _weatherService.triggerImmediateWeatherNotification();
    if (mounted) {
      setState(() => _isSendingTest = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            summary != null
                ? 'Weather notification sent: ${summary.body}'
                : 'Notification triggered!',
          ),
          backgroundColor: AppColors.forestGreen,
          behavior: SnackBarBehavior.floating,
        ),
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
            // Title & Icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.wb_sunny_rounded,
                    color: Colors.orange,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '9:00 AM Weather Alert',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        'Google Maps Weather API',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Schedule info box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8FA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, color: AppColors.forestGreen, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Automated Push Notification delivers every morning at 9:00 AM (Dhaka time) with today\'s temperature and rain prediction.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade800,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Weather Preview Card
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_summary != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.shade50,
                      Colors.orange.shade50.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _summary!.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _summary!.hasRain ? 'Rain Alert' : 'Clear / Fair',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _summary!.hasRain ? Colors.blue.shade700 : Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _summary!.body,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Quick temperature chips
                    if (_summary!.minTemp != null && _summary!.maxTemp != null)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildPill(
                            icon: Icons.thermostat_rounded,
                            label: 'Low: ${_summary!.minTemp}°C',
                            color: Colors.blue.shade600,
                          ),
                          _buildPill(
                            icon: Icons.whatshot_rounded,
                            label: 'High: ${_summary!.maxTemp}°C',
                            color: Colors.deepOrange,
                          ),
                          if (_summary!.peakHour != null)
                            _buildPill(
                              icon: Icons.access_time_filled_rounded,
                              label: 'Peak at ${WeatherService.formatTime(_summary!.peakHour!)}',
                              color: Colors.purple.shade600,
                            ),
                        ],
                      ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      'Close',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isSendingTest ? null : _testNotification,
                    icon: _isSendingTest
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.notifications_active_rounded, size: 18),
                    label: Text(_isSendingTest ? 'Sending...' : 'Test 9 AM Notification'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.forestGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPill({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
