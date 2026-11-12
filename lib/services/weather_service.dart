import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
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

  static const String _prefKeyWeatherEnabled = 'expnz_weather_enabled_v1';
  static const String _prefKeyWeatherHour = 'expnz_weather_hour_v1';
  static const String _prefKeyWeatherMinute = 'expnz_weather_minute_v1';
  static const String _prefKeyWeatherCacheDate = 'expnz_weather_cache_date_v1';
  static const String _prefKeyWeatherCacheData = 'expnz_weather_cache_data_v1';

  // In-memory cache across widget rebuilds and session
  static List<Map<String, dynamic>>? _sessionCache;
  static WeatherSummary? _sessionSummary;
  static int? _sessionCurrentTemp;
  static String? _sessionCurrentCondition;
  static String? _sessionCacheDate;

  bool get hasWeatherForToday =>
      _sessionCacheDate == _todayStr() && _sessionSummary != null;

  WeatherSummary? get cachedSummary =>
      _sessionCacheDate == _todayStr() ? _sessionSummary : null;
  int? get cachedCurrentTemp =>
      _sessionCacheDate == _todayStr() ? _sessionCurrentTemp : null;
  String? get cachedCurrentCondition =>
      _sessionCacheDate == _todayStr() ? _sessionCurrentCondition : null;

  bool _isNotificationEnabled = true;
  bool get isNotificationEnabled => _isNotificationEnabled;

  int _notificationHour = 9;
  int _notificationMinute = 0;
  int get notificationHour => _notificationHour;
  int get notificationMinute => _notificationMinute;

  /// Loads notification preference and scheduled time from local storage and optionally syncs with Cloud Firestore
  Future<bool> loadNotificationEnabled({bool syncWithCloud = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isNotificationEnabled = prefs.getBool(_prefKeyWeatherEnabled) ?? true;
      _notificationHour = prefs.getInt(_prefKeyWeatherHour) ?? 9;
      _notificationMinute = prefs.getInt(_prefKeyWeatherMinute) ?? 0;
      _notificationHour = prefs.getInt(_prefKeyWeatherHour) ?? 9;
      _notificationMinute = prefs.getInt(_prefKeyWeatherMinute) ?? 0;

      if (syncWithCloud && Firebase.apps.isNotEmpty) {
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
            final cloudHour = doc.data()!['hour'] as int?;
            if (cloudHour != null) {
              _notificationHour = cloudHour;
              await prefs.setInt(_prefKeyWeatherHour, cloudHour);
            }
            final cloudMinute = doc.data()!['minute'] as int?;
            if (cloudMinute != null) {
              _notificationMinute = cloudMinute;
              await prefs.setInt(_prefKeyWeatherMinute, cloudMinute);
            }
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

    if (Firebase.apps.isNotEmpty) {
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

    if (enabled) {
      await checkAndApplyLocalMorningWeather();
    } else {
      await NotificationService().cancelNotification(2001);
    }
  }

  /// Sets notification time locally and syncs to Cloud Firestore
  Future<void> setNotificationTime(int hour, int minute) async {
    _notificationHour = hour;
    _notificationMinute = minute;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyWeatherHour, hour);
    await prefs.setInt(_prefKeyWeatherMinute, minute);

    if (Firebase.apps.isNotEmpty) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('settings')
              .doc('weather_automation')
              .set({
            'hour': hour,
            'minute': minute,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } catch (e) {
        debugPrint('Error saving cloud weather time: $e');
      }
    }

    if (_isNotificationEnabled) {
      await checkAndApplyLocalMorningWeather();
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

  /// Preloads today's weather from local storage (SharedPreferences) into memory.
  /// Called at app launch so the Tools page renders instantly without loading.
  Future<bool> initFromLocalStorage() async {
    final todayStr = _todayStr();

    if (_sessionCacheDate == todayStr && _sessionSummary != null) {
      return true;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      _isNotificationEnabled = prefs.getBool(_prefKeyWeatherEnabled) ?? true;
      _notificationHour = prefs.getInt(_prefKeyWeatherHour) ?? 9;
      _notificationMinute = prefs.getInt(_prefKeyWeatherMinute) ?? 0;

      final cachedDate = prefs.getString(_prefKeyWeatherCacheDate);
      if (cachedDate == todayStr) {
        final cachedJson = prefs.getString(_prefKeyWeatherCacheData);
        if (cachedJson != null && cachedJson.isNotEmpty) {
          final decoded = (jsonDecode(cachedJson) as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          if (decoded.isNotEmpty) {
            _sessionCache = decoded;
            _sessionCacheDate = todayStr;
            _sessionSummary = generateSummary(decoded);
            _extractCurrentMetrics(decoded, _sessionSummary!);
            debugPrint('WeatherService: preloaded weather from local storage for $todayStr');
            return true;
          }
        }
      }
    } catch (e) {
      debugPrint('WeatherService error preloading from local storage: $e');
    }

    return false;
  }

  /// Alias for initFromLocalStorage
  Future<bool> loadFromLocalStorage() => initFromLocalStorage();

  /// Returns the cached forecast from local storage if it was already fetched today;
  /// otherwise fetches once from the API, stores it in local storage, and returns it.
  /// Does NOT hit the network again for the whole day unless [forceRefresh] is true.
  Future<List<Map<String, dynamic>>> getCachedOrFetchForecast({
    double lat = defaultLatitude,
    double lng = defaultLongitude,
    bool forceRefresh = false,
  }) async {
    final todayStr = _todayStr();

    // 1. In-memory session cache hit
    if (!forceRefresh && _sessionCacheDate == todayStr && _sessionCache != null && _sessionCache!.isNotEmpty) {
      debugPrint('WeatherService: returning in-memory session cache for $todayStr');
      return _sessionCache!;
    }

    // 2. SharedPreferences local storage hit (don't load from network for the whole day)
    if (!forceRefresh) {
      final prefs = await SharedPreferences.getInstance();
      final cachedDate = prefs.getString(_prefKeyWeatherCacheDate);
      if (cachedDate == todayStr) {
        final cachedJson = prefs.getString(_prefKeyWeatherCacheData);
        if (cachedJson != null && cachedJson.isNotEmpty) {
          try {
            final decoded = (jsonDecode(cachedJson) as List<dynamic>)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
            if (decoded.isNotEmpty) {
              _sessionCache = decoded;
              _sessionCacheDate = todayStr;
              _sessionSummary = generateSummary(decoded);
              _extractCurrentMetrics(decoded, _sessionSummary!);
              debugPrint('WeatherService: returning SharedPreferences local storage cache for $todayStr (no API call)');
              return decoded;
            }
          } catch (_) {}
        }
      }
    }

    // 3. Fetch from network only if forceRefresh is true or no data stored for today
    final fresh = await fetchHourlyForecast(lat: lat, lng: lng);
    if (fresh.isNotEmpty) {
      _sessionCache = fresh;
      _sessionCacheDate = todayStr;
      _sessionSummary = generateSummary(fresh);
      _extractCurrentMetrics(fresh, _sessionSummary!);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefKeyWeatherCacheDate, todayStr);
        await prefs.setString(_prefKeyWeatherCacheData, jsonEncode(fresh));
        debugPrint('WeatherService: fetched & stored in local storage for $todayStr');
      } catch (e) {
        debugPrint('WeatherService cache write error: $e');
      }
    }
    return fresh;
  }

  void _extractCurrentMetrics(List<Map<String, dynamic>> hours, WeatherSummary summary) {
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
    _sessionCurrentTemp = currentTemp ?? summary.maxTemp;
    _sessionCurrentCondition = currentCond;
  }

  /// Clears in-memory session variables (e.g. for testing or fresh reload from storage).
  void resetSessionMemory() {
    _sessionCache = null;
    _sessionSummary = null;
    _sessionCurrentTemp = null;
    _sessionCurrentCondition = null;
    _sessionCacheDate = null;
  }

  /// Alias for resetSessionMemory
  void clearSessionCache() => resetSessionMemory();

  /// Clears local + session weather cache (e.g. when user force-refreshes).
  Future<void> clearCache() async {
    _sessionCache = null;
    _sessionSummary = null;
    _sessionCurrentTemp = null;
    _sessionCurrentCondition = null;
    _sessionCacheDate = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyWeatherCacheDate);
      await prefs.remove(_prefKeyWeatherCacheData);
    } catch (_) {}
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Fetches 24-hour hourly weather forecast from Google Maps Weather API.
  /// Prefer [getCachedOrFetchForecast] for normal use.
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

    const title = "⛅ Today's Weather";
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

  /// Ensures weather is loaded once for the day, stored in local storage,
  /// and the 9:00 AM weather notification is scheduled.
  Future<bool> checkAndApplyLocalMorningWeather() async {
    final isEnabled = await loadNotificationEnabled();
    if (!isEnabled) {
      // Cancel any existing scheduled notification.
      await NotificationService().cancelNotification(2001);
      return false;
    }

    final todayStr = _todayStr();

    // 1. Check local storage: load it once and store in local storage if not already present
    List<Map<String, dynamic>> hours = [];
    final prefs = await SharedPreferences.getInstance();
    final cachedDate = prefs.getString(_prefKeyWeatherCacheDate);

    if (cachedDate == todayStr) {
      final cachedJson = prefs.getString(_prefKeyWeatherCacheData);
      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          hours = (jsonDecode(cachedJson) as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          if (hours.isNotEmpty) {
            _sessionCache = hours;
            _sessionCacheDate = todayStr;
            _sessionSummary = generateSummary(hours);
            _extractCurrentMetrics(hours, _sessionSummary!);
            debugPrint('WeatherService: morning check found existing local storage for $todayStr');
          }
        } catch (_) {}
      }
    }

    // If not stored in local storage yet today, load once from API and store for the whole day
    if (hours.isEmpty) {
      hours = await fetchHourlyForecast();
      if (hours.isNotEmpty) {
        _sessionCache = hours;
        _sessionCacheDate = todayStr;
        _sessionSummary = generateSummary(hours);
        _extractCurrentMetrics(hours, _sessionSummary!);
        try {
          await prefs.setString(_prefKeyWeatherCacheDate, todayStr);
          await prefs.setString(_prefKeyWeatherCacheData, jsonEncode(hours));
          debugPrint('WeatherService: morning check fetched & saved to local storage for $todayStr');
        } catch (e) {
          debugPrint('WeatherService morning cache error: $e');
        }
      }
    }

    // 2. Schedule the morning weather notification with today's summary at user configured time
    final summary = _sessionSummary ?? generateSummary(hours);
    await NotificationService().scheduleWeatherNotification(
      hour: _notificationHour,
      minute: _notificationMinute,
      title: summary.title,
      body: summary.body.isNotEmpty
          ? summary.body
          : 'Morning weather forecast is ready. Tap to view.',
    );

    return true;
  }
}
