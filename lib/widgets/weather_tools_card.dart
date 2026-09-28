import 'package:flutter/material.dart';
import '../services/weather_service.dart';
import '../theme/app_theme.dart';
import 'weather_forecast_dialog.dart';

class WeatherToolsCard extends StatefulWidget {
  const WeatherToolsCard({super.key});

  @override
  State<WeatherToolsCard> createState() => _WeatherToolsCardState();
}

class _WeatherToolsCardState extends State<WeatherToolsCard> {
  final WeatherService _weatherService = WeatherService();
  bool _isLoading = true;
  WeatherSummary? _summary;
  bool _isNotificationEnabled = true;
  int? _currentTemp;
  String _currentCondition = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadWeatherData();
  }

  Future<void> _loadWeatherData() async {
    setState(() => _isLoading = true);
    try {
      final isEnabled = await _weatherService.loadNotificationEnabled();
      final hours = await _weatherService.fetchHourlyForecast();
      final summary = _weatherService.generateSummary(hours);

      int? currentTemp;
      String currentCond = 'Fair';
      if (hours.isNotEmpty) {
        final firstHour = hours.first;
        final tempMap = firstHour['temperature'] as Map<String, dynamic>?;
        currentTemp = (tempMap?['degrees'] as num?)?.round();
        final condMap = firstHour['weatherCondition'] as Map<String, dynamic>?;
        final descMap = condMap?['description'] as Map<String, dynamic>?;
        currentCond = (descMap?['text'] as String?) ?? 'Fair';
      }

      if (mounted) {
        setState(() {
          _isNotificationEnabled = isEnabled;
          _summary = summary;
          _currentTemp = currentTemp ?? summary.maxTemp;
          _currentCondition = currentCond;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('WeatherToolsCard load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openDetails() async {
    await WeatherForecastDialog.show(context);
    if (mounted) {
      final isEnabled = await _weatherService.loadNotificationEnabled();
      setState(() => _isNotificationEnabled = isEnabled);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
          onTap: _openDetails,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.shade100,
                            Colors.amber.shade50,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _summary?.hasRain == true
                            ? Icons.water_drop_rounded
                            : Icons.wb_sunny_rounded,
                        size: 26,
                        color: _summary?.hasRain == true
                            ? Colors.blue.shade700
                            : Colors.orange.shade800,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Weather Forecast',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textDark,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: _isNotificationEnabled
                                      ? const Color(0xFFDCFCE7)
                                      : const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _isNotificationEnabled ? '9 AM ON' : 'OFF',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: _isNotificationEnabled
                                        ? AppColors.forestGreen
                                        : AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Google Maps Weather • Today',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      color: AppColors.textMuted,
                      tooltip: 'Refresh Weather',
                      onPressed: _loadWeatherData,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    const SizedBox(width: 4),
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

                const SizedBox(height: 14),

                // Main Weather Display Body
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else if (_summary != null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _summary!.hasRain
                              ? Colors.blue.shade50.withValues(alpha: 0.6)
                              : Colors.orange.shade50.withValues(alpha: 0.5),
                          const Color(0xFFF9FAFB),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _summary!.hasRain
                            ? Colors.blue.withValues(alpha: 0.15)
                            : Colors.orange.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            if (_currentTemp != null)
                              Text(
                                '$_currentTemp°C',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textDark,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            const SizedBox(width: 8),
                            Text(
                              _currentCondition,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: _summary!.hasRain
                                    ? Colors.blue.shade800
                                    : Colors.orange.shade900,
                              ),
                            ),
                            const Spacer(),
                            if (_summary!.minTemp != null && _summary!.maxTemp != null)
                              Text(
                                'L: ${_summary!.minTemp}° / H: ${_summary!.maxTemp}°',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _summary!.body,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Text(
                    'Unable to retrieve weather data. Tap to retry.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
