import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:mobile_app/Notification/local_notification_scheduler.dart';
import 'package:mobile_app/Notification/notification_navigator.dart';
import 'package:mobile_app/core/network/backend_connector.dart';
import 'package:mobile_app/splashScreen.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// normal reminders like meds tasks and mood
const AndroidNotificationChannel ayuDefaultChannel = AndroidNotificationChannel(
  'ayu_default',
  'Ayu Notifications',
  description: 'General reminders for medications, tasks and mood check-in',
  importance: Importance.high,
);

// crisis alerts for companion
const AndroidNotificationChannel ayuCrisisChannel = AndroidNotificationChannel(
  'ayu_crisis',
  'Ayu Crisis Alerts',
  description: 'High priority companion crisis alerts',
  importance: Importance.max,
  enableVibration: true,
  playSound: true,
);

// top level required by firebase so it runs when app is killed
@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> _initTimezone() async {
  tz.initializeTimeZones();
  final String localTimezone = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(localTimezone));
}

Future<void> _initLocalNotifications() async {
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  // permissions are requested manually DeviceService
  const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );

  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: androidSettings, iOS: iosSettings),
    // navigate when user taps a local notification from the shade
    onDidReceiveNotificationResponse: (details) {
      navigateFromRoute(details.payload);
    },
  );

  // create channels so notifications have somewhere to go on android
  final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
      flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

  await androidPlugin?.createNotificationChannel(ayuDefaultChannel);
  await androidPlugin?.createNotificationChannel(ayuCrisisChannel);
}

void _setupFcmTapHandlers() {
  // app was in background and user tapped the notification
  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    final route = message.data['route'] as String?;
    navigateFromRoute(route);
  });

  // app was fully killed and user tapped the notification to open it
  FirebaseMessaging.instance.getInitialMessage().then((message) {
    if (message != null) {
      final route = message.data['route'] as String?;
      // delay so the navigator tree is ready before navigating
      Future.delayed(const Duration(milliseconds: 500), () {
        navigateFromRoute(route);
      });
    }
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  // must be registered before runApp
  FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);

  await _initTimezone();
  await _initLocalNotifications();
  _setupFcmTapHandlers();

  // Reschedule mood check in on auth state change to handle cold start user restoration
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) {
      unawaited(LocalNotificationScheduler.instance.scheduleMoodCheckIn());
    }
  });

  BackendConnector.instance.configure(
    tokenProvider: () async => FirebaseAuth.instance.currentUser?.getIdToken(),
    fallbackToken: null,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ayu',
      navigatorKey: notificationNavigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        fontFamily: 'Urbanist',
      ),
      navigatorObservers: [routeObserver],
      home: SplashScreen(),
    );
  }
}
