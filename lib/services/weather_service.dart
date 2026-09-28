import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

class WeatherSummary {
  final String title;
  final String body;
  final int? minTemp;
  final int? maxTemp;
  final int? peakHour;
  final bool hasRain;
  final List<Map<String, dynamic>> rainSlots;

  WeatherSummary({
    required this.title,
    required this.body,
    required this.minTemp,
    required this.maxTemp,
    required this.peakHour,
    required this.hasRain,
    required this.rainSlots,
  });
}

class WeatherService {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();

  static const String _defaultApiKey = 'AIzaSyDL74SeFRnARBeIT_wmqeHMDk8PlI4_oNY';
  static const double defaultLatitude = 23.8103; // Dhaka
  static const double defaultLongitude = 90.4125;

  static const String _prefKeyLastWeatherDate = 'expnz_last_weather_date_v1';
  static const String _prefKeyWeatherEnabled = 'expnz_weather_enabled_v1';

  bool _isNotificationEnabled = true;
  bool get isNotificationEnabled => _isNotificationEnabled;

  /// Loads notification preference from local storage and Cloud Firestore
  Future<bool> loadNotificationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    _isNotificationEnabled = prefs.getBool(_prefKeyWeatherEnabled) ?? true;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('settings')
            .doc('weather_automation')
            .get();
        if (doc.exists && doc.data() != null) {
          final cloudEnabled = doc.data()!['enabled'] as bool?;
          if (cloudEnabled != null) {
            _isNotificationEnabled = cloudEnabled;
            await prefs.setBool(_prefKeyWeatherEnabled, cloudEnabled);
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading cloud weather settings: $e');
    }

    return _isNotificationEnabled;
  }

  /// Sets notification preference locally and syncs to Cloud Firestore
  Future<void> setNotificationEnabled(bool enabled) async {
    _isNotificationEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyWeatherEnabled, enabled);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('settings')
            .doc('weather_automation')
            .set({
          'enabled': enabled,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error saving cloud weather settings: $e');
    }
  }

  String get apiKey =>
      const String.fromEnvironment('GOOGLE_MAPS_WEATHER_API_KEY', defaultValue: _defaultApiKey);

  /// Formats an hour integer (0-23) into readable 12-hour format (e.g. 2:00 PM)
  static String formatTime(int hour) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$hour12:00 $period';
  }

  /// Fetches 24-hour hourly weather forecast from Google Maps Weather API
  Future<List<Map<String, dynamic>>> fetchHourlyForecast({
    double lat = defaultLatitude,
    double lng = defaultLongitude,
  }) async {
    try {
      final uri = Uri.parse(
        'https://weather.googleapis.com/v1/forecast/hours:lookup?key=$apiKey&location.latitude=$lat&location.longitude=$lng&hours=24',
      );

      final client = HttpClient();
      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode != 200) {
        final errBody = await response.transform(utf8.decoder).join();
        debugPrint('Google Maps Weather API error (${response.statusCode}): $errBody');
        return [];
      }

      final jsonString = await response.transform(utf8.decoder).join();
      final Map<String, dynamic> data = jsonDecode(jsonString);
      final List<dynamic>? hours = data['forecastHours'] as List<dynamic>?;

      if (hours == null) return [];
      return hours.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('fetchHourlyForecast error: $e');
      return [];
    }
  }

  /// Analyzes forecast hours and crafts an informative push notification title & body
  WeatherSummary generateSummary(List<Map<String, dynamic>> hours) {
    if (hours.isEmpty) {
      return WeatherSummary(
        title: "⛅ Today's Weather Update",
        body: 'Weather forecast currently unavailable.',
        minTemp: null,
        maxTemp: null,
        peakHour: null,
        hasRain: false,
        rainSlots: [],
      );
    }

    int minTemp = 999;
    int maxTemp = -999;
    int? peakHour;
    final List<Map<String, dynamic>> rainSlots = [];

    for (final h in hours) {
      final dt = h['displayDateTime'] as Map<String, dynamic>?;
      final hourNum = (dt?['hours'] as num?)?.toInt() ?? 0;

      final tempMap = h['temperature'] as Map<String, dynamic>?;
      final temp = (tempMap?['degrees'] as num?)?.round() ?? 0;

      final precipMap = h['precipitation'] as Map<String, dynamic>?;
      final probMap = precipMap?['probability'] as Map<String, dynamic>?;
      final rainProb = (probMap?['percent'] as num?)?.toInt() ?? 0;

      final condMap = h['weatherCondition'] as Map<String, dynamic>?;
      final descMap = condMap?['description'] as Map<String, dynamic>?;
      final conditionText = (descMap?['text'] as String?) ?? '';
      final descLower = conditionText.toLowerCase();

      if (temp > maxTemp) {
        maxTemp = temp;
        peakHour = hourNum;
      }
      if (temp < minTemp) {
        minTemp = temp;
      }

      if (rainProb >= 25 ||
          descLower.contains('rain') ||
          descLower.contains('shower') ||
          descLower.contains('thunder') ||
          descLower.contains('drizzle')) {
        rainSlots.add({
          'hour': hourNum,
          'prob': rainProb,
          'condition': conditionText.isNotEmpty ? conditionText : 'Rain',
        });
      }
    }

    String rainSummary = '';
    final bool hasRain = rainSlots.isNotEmpty;
    if (hasRain) {
      rainSlots.sort((a, b) => (b['prob'] as int).compareTo(a['prob'] as int));
      final topRain = rainSlots.first;
      final timeSlots = rainSlots
          .take(3)
          .map((r) => formatTime(r['hour'] as int))
          .join(', ');

      rainSummary =
          '🌧️ Rain expected around $timeSlots (up to ${topRain['prob']}% at ${formatTime(topRain['hour'] as int)}).';
    } else {
      rainSummary = '☀️ No rain expected today.';
    }

    final peakText = peakHour != null
        ? ' (Peak $maxTemp°C at ${formatTime(peakHour)})'
        : '';
    final tempSummary = '🌡️ $minTemp°C - $maxTemp°C$peakText.';

    const title = "⛅ Today's Weather (9 AM Forecast)";
    final body = '$rainSummary $tempSummary';

    return WeatherSummary(
      title: title,
      body: body,
      minTemp: minTemp == 999 ? null : minTemp,
      maxTemp: maxTemp == -999 ? null : maxTemp,
      peakHour: peakHour,
      hasRain: hasRain,
      rainSlots: rainSlots,
    );
  }

  /// Sends test notification immediately to test Google Maps Weather API & notification display
  Future<WeatherSummary?> triggerImmediateWeatherNotification({
    double lat = defaultLatitude,
    double lng = defaultLongitude,
  }) async {
    final hours = await fetchHourlyForecast(lat: lat, lng: lng);
    final summary = generateSummary(hours);

    await NotificationService().showWeatherNotification(
      title: summary.title,
      body: summary.body,
    );

    return summary;
  }

  /// Checks if 9:00 AM notification should be delivered today locally (failsafe if FCM is missed)
  Future<bool> checkAndApplyLocalMorningWeather() async {
    final isEnabled = await loadNotificationEnabled();
    if (!isEnabled) {
      return false; // User toggled weather notifications off
    }

    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final prefs = await SharedPreferences.getInstance();
    final lastSentDate = prefs.getString(_prefKeyLastWeatherDate);

    if (lastSentDate == todayStr) {
      return false; // Already sent today
    }

    // Only fire if current time has passed 9:00 AM
    final nineAm = DateTime(now.year, now.month, now.day, 9, 0);
    if (now.isAfter(nineAm)) {
      await prefs.setString(_prefKeyLastWeatherDate, todayStr);
      await triggerImmediateWeatherNotification();
      return true;
    }

    return false;
  }
}
