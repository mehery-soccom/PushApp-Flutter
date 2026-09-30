import 'package:flutter/material.dart';
import 'package:mehery_sender/mehery_sender.dart';

/// Shared PushApp instance — replace identifier (and optional credentials) with your Mehery dashboard values.
final pushApp = Pushapp(
  identifier: 'MeheryTestFlutter_1734160381705',
  appId: 'yourAppId',
  appSecret: 'yourAppSecret',
  sandbox: false,
);

final pushAppNavigatorKey = GlobalKey<NavigatorState>();

void registerPushInAppContext() {
  pushApp.attachNavigatorKey(pushAppNavigatorKey);
  final context = pushAppNavigatorKey.currentContext;
  if (context != null && context.mounted) {
    pushApp.setInAppNotification(context);
  }
}

Future<bool> initializePushApp({
  required String? fcmToken,
  required String? apnsToken,
}) async {
  final registered = await pushApp.initializeAndSendToken(
    fcmToken: fcmToken,
    apnsToken: apnsToken,
  );
  registerPushInAppContext();
  if (!registered) {
    debugPrint(
      'PushApp: device registration deferred — tokens may arrive shortly.',
    );
  }
  return registered;
}
