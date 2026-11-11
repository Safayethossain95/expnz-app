import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Payload constants so tap routing is unambiguous.
const String kWeatherPayload = 'weather_update';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool _tzInitialized = false;

  /// Called when the user taps the commute review notification.
  Function(String batchId)? onCommuteTapped;

  /// Called when the user taps the weather forecast notification.
  VoidCallback? onWeatherTapped;

  // ─── Initialisation ────────────────────────────────────────────────────────

  Future<void> init({
    Function(String batchId)? onCommuteTap,
    VoidCallback? onWeatherTap,
  }) async {
    // Always refresh the callbacks (app may re-register after resume).
    if (onCommuteTap != null) onCommuteTapped = onCommuteTap;
    if (onWeatherTap != null) onWeatherTapped = onWeatherTap;

    if (_isInitialized) return;

    await _initTimezone();

    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const linuxSettings = LinuxInitializationSettings(
        defaultActionName: 'Open notification',
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
        linux: linuxSettings,
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onTap,
        // Also handle taps when app was terminated and restarted by notification.
        onDidReceiveBackgroundNotificationResponse: _onBackgroundTap,
      );

      // Create Android notification channels.
      final androidPlatform = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        await androidPlatform.createNotificationChannel(
          const AndroidNotificationChannel(
            'commute_channel',
            'Daily Commute Notifications',
            description:
                'Notifications for daily commute expense entries and review alerts',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
        await androidPlatform.createNotificationChannel(
          const AndroidNotificationChannel(
            'weather_channel',
            'Daily Weather Updates',
            description:
                'Notifications for daily morning weather forecasts and rain alerts',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
        await androidPlatform.requestNotificationsPermission();
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  // ─── Timezone helper ───────────────────────────────────────────────────────

  Future<void> _initTimezone() async {
    if (_tzInitialized) return;
    try {
      tz.initializeTimeZones();
      final String timeZoneName = DateTime.now().timeZoneName;
      if (tz.timeZoneDatabase.locations.containsKey(timeZoneName)) {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } else {
        final Duration offset = DateTime.now().timeZoneOffset;
        final match = tz.timeZoneDatabase.locations.values.firstWhere(
          (loc) => loc.currentTimeZone.offset == offset,
          orElse: () => tz.getLocation('UTC'),
        );
        tz.setLocalLocation(match);
      }
      _tzInitialized = true;
    } catch (e) {
      debugPrint('Timezone init error: $e');
    }
  }

  // ─── Tap routing ──────────────────────────────────────────────────────────

  void _onTap(NotificationResponse response) {
    _routePayload(response.payload);
  }

  /// Stores the last unhandled payload so the app can process it after mounting.
  static String? _pendingPayload;
  static String? get pendingPayload => _pendingPayload;
  static void clearPendingPayload() => _pendingPayload = null;

  static void _routePayloadStatic(String? payload) {
    if (payload == null || payload.isEmpty) return;
    _pendingPayload = payload;
  }

  void _routePayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    if (payload == kWeatherPayload) {
      onWeatherTapped?.call();
    } else {
      onCommuteTapped?.call(payload);
    }
  }

  /// Called when app was killed and user tapped a notification to relaunch.
  /// Stores payload; the screen will pick it up via [pendingPayload].
  Future<void> handleLaunchPayload() async {
    if (!_isInitialized) return;
    final details =
        await _localNotifications.getNotificationAppLaunchDetails();
    if (details != null &&
        details.didNotificationLaunchApp &&
        details.notificationResponse?.payload != null) {
      _pendingPayload = details.notificationResponse!.payload;
    }
  }

  // ─── Show notifications (immediate) ───────────────────────────────────────

  Future<void> showCommuteNotification({
    required String batchId,
    String title = 'Daily Commute Entry Added',
    String body =
        'Data entry successful: CNG (৳80) & Metro (৳36) recorded for today. Tap to keep or discard.',
  }) async {
    try {
      if (!_isInitialized) await init();

      const androidDetails = AndroidNotificationDetails(
        'commute_channel',
        'Daily Commute Notifications',
        channelDescription:
            'Notifications for daily commute entries and review prompts',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      await _localNotifications.show(
        id: 1001,
        title: title,
        body: body,
        notificationDetails: details,
        payload: batchId,
      );
    } catch (e) {
      debugPrint('showCommuteNotification error: $e');
    }
  }

  Future<void> showWeatherNotification({
    required String title,
    required String body,
  }) async {
    try {
      if (!_isInitialized) await init();

      const androidDetails = AndroidNotificationDetails(
        'weather_channel',
        'Daily Weather Updates',
        channelDescription:
            'Daily weather forecast alerts highlighting rain times and temperatures',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      await _localNotifications.show(
        id: 2001,
        title: title,
        body: body,
        notificationDetails: details,
        payload: kWeatherPayload,
      );
    } catch (e) {
      debugPrint('showWeatherNotification error: $e');
    }
  }

  // ─── Schedule notifications (fires even when app is closed) ───────────────

  /// Schedules the commute review notification for [hour]:[minute] today
  /// (or tomorrow if that time has already passed).
  /// Uses [zonedSchedule] so Android fires it via AlarmManager even when
  /// the app is not running.
  Future<void> scheduleCommuteNotification({
    required String batchId,
    int hour = 9,
    int minute = 0,
    String title = 'Daily Commute Entry Added',
    String body =
        'Data entry successful: CNG (৳80) & Metro (৳36) recorded for today. Tap to keep or discard.',
  }) async {
    try {
      if (!_isInitialized) await init();
      await _initTimezone();

      final scheduledDate =
          _nextInstanceOfTime(hour, minute);

      const androidDetails = AndroidNotificationDetails(
        'commute_channel',
        'Daily Commute Notifications',
        channelDescription:
            'Notifications for daily commute entries and review prompts',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      await _localNotifications.zonedSchedule(
        id: 1001,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: batchId,
      );

      debugPrint('Commute notification scheduled for $scheduledDate');
    } catch (e) {
      debugPrint('scheduleCommuteNotification error: $e');
    }
  }

  /// Schedules the weather notification for [hour]:[minute] today
  /// (or tomorrow if that time has already passed).
  Future<void> scheduleWeatherNotification({
    int hour = 9,
    int minute = 0,
    String title = "⛅ Today's Weather",
    String body = 'Morning weather forecast is ready. Tap to view.',
  }) async {
    try {
      if (!_isInitialized) await init();
      await _initTimezone();

      final scheduledDate = _nextInstanceOfTime(hour, minute);

      const androidDetails = AndroidNotificationDetails(
        'weather_channel',
        'Daily Weather Updates',
        channelDescription:
            'Daily weather forecast alerts highlighting rain times and temperatures',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      await _localNotifications.zonedSchedule(
        id: 2001,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: kWeatherPayload,
      );

      debugPrint('Weather notification scheduled for $scheduledDate');
    } catch (e) {
      debugPrint('scheduleWeatherNotification error: $e');
    }
  }

  /// Cancels a previously scheduled notification by id.
  Future<void> cancelNotification(int id) async {
    try {
      await _localNotifications.cancel(id: id);
    } catch (e) {
      debugPrint('cancelNotification error: $e');
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// Returns the next occurrence of [hour]:[minute] in local timezone.
  /// If that time is in the past today, returns tomorrow's occurrence.
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

/// Top-level background tap handler (required by flutter_local_notifications
/// to be a top-level or static function — NOT a class method).
@pragma('vm:entry-point')
void _onBackgroundTap(NotificationResponse response) {
  NotificationService._routePayloadStatic(response.payload);
}
