import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'providers/expense_provider.dart';
import 'screens/auth_gate.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart';
import 'services/weather_service.dart';

import 'firebase_options.dart';

/// Top-level FCM background message handler.
/// Must be a top-level (not a class method) function.
/// Called when an FCM message arrives while the app is in the background or terminated.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase must be initialised even in background isolates.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final data = message.data;
  final notificationService = NotificationService();
  await notificationService.init();

  if (data['type'] == 'weather') {
    // Load it once on morning notification and store it in local storage!
    final weatherService = WeatherService();
    final hours = await weatherService.getCachedOrFetchForecast();
    final summary = weatherService.cachedSummary ?? weatherService.generateSummary(hours);

    await notificationService.showWeatherNotification(
      title: summary.title.isNotEmpty ? summary.title : (message.notification?.title ?? "⛅ Today's Weather"),
      body: summary.body.isNotEmpty ? summary.body : (message.notification?.body ?? 'Morning weather forecast is ready. Tap to view.'),
    );
  } else {
    final batchId = data['batchId']?.toString();
    if (batchId != null && batchId.isNotEmpty) {
      await notificationService.showCommuteNotification(
        batchId: batchId,
        title: message.notification?.title ?? 'Daily Commute Entry Added',
        body: message.notification?.body ??
            'Data entry successful: CNG (৳80) & Metro (৳36) recorded for today. Tap to keep or discard.',
      );
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register FCM background handler as early as possible.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase.initializeApp error: $e');
  }

  // Initialise notification service and check if app was launched via notification tap.
  final notificationService = NotificationService();
  await notificationService.init();
  await notificationService.handleLaunchPayload();

  // Preload weather from local storage so Tools page renders instantly without loading
  await WeatherService().initFromLocalStorage();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const ExpnzApp());
}

class ExpnzApp extends StatefulWidget {
  const ExpnzApp({super.key});

  @override
  State<ExpnzApp> createState() => _ExpnzAppState();
}

class _ExpnzAppState extends State<ExpnzApp> {
  late final ExpenseProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = ExpenseProvider();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: AuthGate(provider: _provider),
    );
  }
}
