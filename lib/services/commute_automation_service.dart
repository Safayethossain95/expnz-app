import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/commute_rule.dart';
import '../models/expense_model.dart';
import '../providers/expense_provider.dart';

import 'notification_service.dart';
import 'weather_service.dart';

class CommuteAutomationService {
  static final CommuteAutomationService _instance =
      CommuteAutomationService._internal();
  factory CommuteAutomationService() => _instance;
  CommuteAutomationService._internal();

  static const String _prefKeyConfig = 'expnz_commute_config_v1';
  final _uuid = const Uuid();
  FirebaseFirestore? get _firestore {
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseFirestore.instance;
      }
    } catch (_) {}
    return null;
  }

  FirebaseAuth? get _auth {
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseAuth.instance;
      }
    } catch (_) {}
    return null;
  }

  CommuteConfig _config = CommuteConfig.initial();
  CommuteConfig get config => _config;

  @visibleForTesting
  void resetForTesting() {
    _config = CommuteConfig.initial();
  }

  Function(String batchId)? onReviewRequested;
  VoidCallback? onWeatherTapped;

  Future<void> init({
    Function(String batchId)? onReview,
    VoidCallback? onWeatherTap,
  }) async {
    onReviewRequested = onReview;
    onWeatherTapped = onWeatherTap;
    await loadConfig();
    await NotificationService().init(
      onCommuteTap: (batchId) {
        onReviewRequested?.call(batchId);
      },
      onWeatherTap: () {
        onWeatherTapped?.call();
      },
    );
    await _initFirebaseMessaging();
  }

  Future<void> _initFirebaseMessaging() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Request permission for push notifications
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Fetch and register FCM token
        final token = await messaging.getToken();
        if (token != null) {
          await _saveFcmTokenToCloud(token);
        }

        // Listen for token refreshes
        messaging.onTokenRefresh.listen((newToken) {
          _saveFcmTokenToCloud(newToken);
        });
      }

      // Check if launched from terminated state via notification click
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageTap(initialMessage);
      }

      // When app is in background and opened by notification tap
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleMessageTap(message);
      });

      // When app is in foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Foreground FCM message received: ${message.notification?.title}');
        final data = message.data;
        if (data['type'] == 'weather') {
          // Load it once on morning notification and store it in local storage!
          final weatherService = WeatherService();
          weatherService.getCachedOrFetchForecast().then((hours) {
            final summary = weatherService.cachedSummary ?? weatherService.generateSummary(hours);
            NotificationService().showWeatherNotification(
              title: summary.title.isNotEmpty ? summary.title : (message.notification?.title ?? "⛅ Today's Weather"),
              body: summary.body.isNotEmpty ? summary.body : (message.notification?.body ?? 'Hourly weather update available.'),
            );
          });
          return;
        }

        final batchId = data['batchId']?.toString() ?? _config.pendingReviewBatchId;
        if (batchId != null && batchId.isNotEmpty) {
          NotificationService().showCommuteNotification(
            batchId: batchId,
            title: message.notification?.title ?? 'Daily Commute Review',
            body: message.notification?.body ??
                'Review today\'s commute: CNG (৳80) & Metro (৳36). Tap to keep or discard.',
          );
          onReviewRequested?.call(batchId);
        }
      });
    } catch (e) {
      debugPrint('FirebaseMessaging init error (may not be supported on web without VAPID): $e');
    }
  }

  void _handleMessageTap(RemoteMessage message) {
    final data = message.data;
    final batchId = data['batchId']?.toString() ?? _config.pendingReviewBatchId;
    if (batchId != null && batchId.isNotEmpty) {
      onReviewRequested?.call(batchId);
    }
  }

  Future<void> _saveFcmTokenToCloud(String token) async {
    final user = _auth?.currentUser;
    final firestore = _firestore;
    if (user != null && firestore != null) {
      try {
        await firestore.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'fcmUpdatedAt': FieldValue.serverTimestamp(),
          'devicePlatform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error saving FCM token: $e');
      }
    }
  }

  Future<CommuteConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefKeyConfig);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        _config = CommuteConfig.fromMap(jsonDecode(jsonStr));
      } catch (_) {}
    } else {
      _config = CommuteConfig.initial();
    }

    final user = _auth?.currentUser;
    final firestore = _firestore;
    if (user != null && firestore != null) {
      try {
        final doc = await firestore
            .collection('users')
            .doc(user.uid)
            .collection('settings')
            .doc('commute_automation')
            .get();

        if (doc.exists && doc.data() != null) {
          _config = CommuteConfig.fromMap(doc.data()!);
          await prefs.setString(_prefKeyConfig, jsonEncode(_config.toMap()));
        }
      } catch (e) {
        debugPrint('Error loading cloud commute config: $e');
      }
    }

    return _config;
  }

  Future<void> saveConfig(CommuteConfig newConfig) async {
    _config = newConfig;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyConfig, jsonEncode(_config.toMap()));

    final user = _auth?.currentUser;
    final firestore = _firestore;
    if (user != null && firestore != null) {
      try {
        await firestore
            .collection('users')
            .doc(user.uid)
            .collection('settings')
            .doc('commute_automation')
            .set(_config.toMap(), SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error saving cloud commute config: $e');
      }
    }
  }

  /// Updates the notification and review prompt time (hour, minute) and reschedules notification
  Future<void> updateNotifyTime(int hour, int minute) async {
    final updated = _config.copyWith(notifyHour: hour, notifyMinute: minute);
    await saveConfig(updated);
    if (updated.enabled) {
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final batchId = 'commute_$todayStr';
      final summaryStr = _config.items.isEmpty
          ? 'No items'
          : _config.items
              .map((i) => '${i.description} (৳${i.amount.toInt() == i.amount ? i.amount.toInt() : i.amount})')
              .join(' & ');
      await NotificationService().scheduleCommuteNotification(
        batchId: batchId,
        hour: hour,
        minute: minute,
        title: 'Daily Commute Review',
        body: 'Review today\'s commute: $summaryStr. Tap to keep or discard.',
      );
    }
  }

  /// Updates the default commute items template inserted every morning
  Future<void> updateItems(List<CommuteItemTemplate> items) async {
    final updated = _config.copyWith(items: items);
    await saveConfig(updated);
  }

  /// Enables or disables daily commute automation
  Future<void> setEnabled(bool enabled) async {
    final updated = _config.copyWith(enabled: enabled);
    await saveConfig(updated);
    if (!enabled) {
      await NotificationService().cancelNotification(1001);
    }
  }

  /// Returns true if it is at/after configured notification time and today's commute decision is pending
  /// (i.e. neither Kept nor Discarded yet, and no commute items exist for today).
  bool shouldPromptReview(ExpenseProvider provider) {
    if (!_config.enabled) return false;

    final now = DateTime.now();
    // Only prompt after configured notification time
    final isAfterNotifyTime = now.hour > _config.notifyHour ||
        (now.hour == _config.notifyHour && now.minute >= _config.notifyMinute);
    if (!isAfterNotifyTime) return false;

    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    // If user already made a decision (keep or discard) today, don't prompt again
    if (_config.lastDecisionDate == todayStr) {
      return false;
    }

    final batchId = 'commute_$todayStr';
    final alreadyExists = provider.allExpenses.any((e) => e.batchId == batchId);
    if (alreadyExists) return false;

    return true;
  }

  /// Schedules daily review notification with configured time and items.
  /// Does NOT auto-insert at 7:00 AM. Insertion only happens when "Keep" is clicked.
  Future<bool> checkAndApplyDailyCommute(ExpenseProvider provider) async {
    if (!_config.enabled) return false;

    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final batchId = 'commute_$todayStr';

    final summaryStr = _config.items.isEmpty
        ? 'No items'
        : _config.items
            .map((i) => '${i.description} (৳${i.amount.toInt() == i.amount ? i.amount.toInt() : i.amount})')
            .join(' & ');

    // Schedule review notification at user-configured time
    await NotificationService().scheduleCommuteNotification(
      batchId: batchId,
      hour: _config.notifyHour,
      minute: _config.notifyMinute,
      title: 'Daily Commute Review',
      body: 'Review today\'s commute: $summaryStr. Tap to keep or discard.',
    );

    return shouldPromptReview(provider);
  }

  /// User clicked "Keep": entries are inserted into today's expenses and saved
  Future<void> keepBatch(String batchId, ExpenseProvider provider) async {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    final alreadyExists = provider.allExpenses.any((e) => e.batchId == batchId);
    if (!alreadyExists) {
      final newItems = _config.items.map((template) {
        return ExpenseItem(
          id: _uuid.v4(),
          date: now,
          category: template.category,
          description: template.description,
          amount: template.amount,
          isPlaceholder: false,
          createdAt: DateTime.now(),
          batchId: batchId,
        );
      }).toList();
      await provider.addExpenseItems(newItems);
    }

    final updated = _config.copyWith(
      lastInsertedDate: todayStr,
      lastDecisionDate: todayStr,
      lastDecision: 'keep',
      clearPendingReview: true,
    );
    await saveConfig(updated);
  }

  /// User clicked "Discard": items are NOT inserted (or removed if already existed),
  /// and today is marked as handled so it won't prompt again today.
  Future<void> discardBatch(String batchId, ExpenseProvider provider) async {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    await provider.deleteItemsByBatchId(batchId);
    final updated = _config.copyWith(
      lastDecisionDate: todayStr,
      lastDecision: 'discard',
      clearPendingReview: true,
    );
    await saveConfig(updated);
  }
}
