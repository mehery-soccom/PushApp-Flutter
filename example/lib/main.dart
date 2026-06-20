import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:mehery_sender/mehery_sender.dart';

import 'firebase_background_handler.dart';
import 'firebase_options.dart';
import 'push_service.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureMeSendFirebaseBackgroundInit(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await MeSendPushNotificationDisplay.ensureInitialized();

  runApp(const MyApp());
  unawaited(_setupPush());
}

Future<void> _setupPush() async {
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);

  String? fcmToken;
  String? apnsToken;

  if (Platform.isAndroid) {
    fcmToken = await messaging.getToken();
  } else if (Platform.isIOS) {
    fcmToken = await messaging.getToken();
    apnsToken = await messaging.getAPNSToken();
    if (apnsToken == null || apnsToken.isEmpty) {
      for (var attempt = 0; attempt < 5; attempt++) {
        await Future.delayed(const Duration(seconds: 1));
        apnsToken = await messaging.getAPNSToken();
        if (apnsToken != null && apnsToken.isNotEmpty) break;
      }
    }
  }

  await initializePushApp(fcmToken: fcmToken, apnsToken: apnsToken);

  FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
    String? apns;
    if (Platform.isIOS) {
      apns = await FirebaseMessaging.instance.getAPNSToken();
    }
    final ok = await pushApp.initializeAndSendToken(
      fcmToken: token,
      apnsToken: apns,
    );
    if (!ok) {
      debugPrint('PushApp: token refresh registration deferred');
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PushApp Example',
      navigatorKey: pushAppNavigatorKey,
      navigatorObservers: pushApp.navigatorObservers,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
