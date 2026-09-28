import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  Function(String batchId)? onNotificationTapped;

  Future<void> init({Function(String batchId)? onTapped}) async {
    if (_isInitialized) {
      if (onTapped != null) onNotificationTapped = onTapped;
      return;
    }
    onNotificationTapped = onTapped;

    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
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
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            onNotificationTapped?.call(payload);
          }
        },
      );

      // Create Android Notification Channels
      final androidPlatform = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlatform != null) {
        await androidPlatform.createNotificationChannel(
          const AndroidNotificationChannel(
            'commute_channel',
            'Daily Commute Notifications',
            description: 'Notifications for daily commute expense entries and review alerts',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
        await androidPlatform.createNotificationChannel(
          const AndroidNotificationChannel(
            'weather_channel',
            'Daily Weather Updates',
            description: 'Notifications for daily morning weather forecasts and rain alerts',
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

  Future<void> showCommuteNotification({
    required String batchId,
    String title = 'Daily Commute Entry Added',
    String body = 'Data entry successful: CNG (৳80) & Metro (৳36) recorded for today. Tap to keep or discard.',
  }) async {
    try {
      if (!_isInitialized) {
        await init();
      }

      const androidDetails = AndroidNotificationDetails(
        'commute_channel',
        'Daily Commute Notifications',
        channelDescription: 'Notifications for daily commute entries and review prompts',
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
      if (!_isInitialized) {
        await init();
      }

      const androidDetails = AndroidNotificationDetails(
        'weather_channel',
        'Daily Weather Updates',
        channelDescription: 'Daily weather forecast alerts highlighting rain times and temperatures',
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
        payload: 'weather_update',
      );
    } catch (e) {
      debugPrint('showWeatherNotification error: $e');
    }
  }
}
