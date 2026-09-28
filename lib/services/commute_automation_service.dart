import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/commute_rule.dart';
import '../models/expense_model.dart';
import '../providers/expense_provider.dart';

import 'notification_service.dart';

class CommuteAutomationService {
  static final CommuteAutomationService _instance =
      CommuteAutomationService._internal();
  factory CommuteAutomationService() => _instance;
  CommuteAutomationService._internal();

  static const String _prefKeyConfig = 'expnz_commute_config_v1';
  final _uuid = const Uuid();
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  CommuteConfig _config = CommuteConfig.initial();
  CommuteConfig get config => _config;

  Function(String batchId)? onReviewRequested;

  Future<void> init({Function(String batchId)? onReview}) async {
    onReviewRequested = onReview;
    await loadConfig();
    await NotificationService().init(onTapped: (batchId) {
      onReviewRequested?.call(batchId);
    });
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
          NotificationService().showWeatherNotification(
            title: message.notification?.title ?? "Today's Weather Forecast",
            body: message.notification?.body ?? 'Hourly weather update available.',
          );
          return;
        }

        final batchId = data['batchId']?.toString() ?? _config.pendingReviewBatchId;
        if (batchId != null && batchId.isNotEmpty) {
          NotificationService().showCommuteNotification(
            batchId: batchId,
            title: message.notification?.title ?? 'Daily Commute Entry Added',
            body: message.notification?.body ??
                'Data entry successful: CNG (৳80) & Metro (৳36) recorded for today. Tap to review.',
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
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).set({
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
    }

    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await _firestore
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

    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore
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

  /// Automatically checks if 7:00 AM today's commute data should be inserted.
  /// Works reliably both standalone and in coordination with Cloud Functions.
  Future<bool> checkAndApplyDailyCommute(ExpenseProvider provider) async {
    if (!_config.enabled) return false;

    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    // If today is already inserted, skip insertion
    if (_config.lastInsertedDate == todayStr) {
      // Check if there is still an unreviewed pending batch
      if (_config.pendingReviewBatchId != null &&
          _config.pendingReviewBatchId!.isNotEmpty) {
        // Trigger review modal if past notification time (e.g. 9:30 AM)
        final notifyTime = DateTime(
          now.year,
          now.month,
          now.day,
          _config.notifyHour,
          _config.notifyMinute,
        );
        if (now.isAfter(notifyTime)) {
          onReviewRequested?.call(_config.pendingReviewBatchId!);
        }
      }
      return false;
    }

    // Check if current time has passed the scheduled insertion time (default 7:00 AM)
    final scheduledInsertTime = DateTime(
      now.year,
      now.month,
      now.day,
      _config.insertHour,
      _config.insertMinute,
    );

    if (now.isBefore(scheduledInsertTime)) {
      // Not yet 7:00 AM
      return false;
    }

    final batchId = 'commute_$todayStr';

    // Check if these items already exist in the provider to prevent duplicates
    final alreadyExists = provider.allExpenses.any(
      (e) => e.batchId == batchId,
    );

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

    // Update config with last inserted date and pending batch ID
    final updated = _config.copyWith(
      lastInsertedDate: todayStr,
      pendingReviewBatchId: batchId,
    );
    await saveConfig(updated);

    // If it's already past notify time (9:30 AM), trigger review popup
    final notifyTime = DateTime(
      now.year,
      now.month,
      now.day,
      _config.notifyHour,
      _config.notifyMinute,
    );

    if (now.isAfter(notifyTime)) {
      await NotificationService().showCommuteNotification(
        batchId: batchId,
        title: 'Daily Commute Entry Added',
        body: 'Data entry successful: CNG (৳80) & Metro (৳36) recorded for today. Tap to keep or discard.',
      );
      onReviewRequested?.call(batchId);
    }

    return true;
  }

  /// User clicked "Keep": entries remain in the list, pending review is cleared
  Future<void> keepBatch(String batchId) async {
    final updated = _config.copyWith(clearPendingReview: true);
    await saveConfig(updated);
  }

  /// User clicked "Discard": delete the batch entries from the provider
  Future<void> discardBatch(String batchId, ExpenseProvider provider) async {
    await provider.deleteItemsByBatchId(batchId);
    final updated = _config.copyWith(clearPendingReview: true);
    await saveConfig(updated);
  }
}
