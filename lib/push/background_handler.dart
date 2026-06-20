part of mehery_sender;

// Set in [main] before other Firebase usage:
//
// ```dart
// configureMeSendFirebaseBackgroundInit(
//   options: DefaultFirebaseOptions.currentPlatform,
// );
// FirebaseMessaging.onBackgroundMessage(meSendFirebaseMessagingBackgroundHandler);
// ```
@pragma('vm:entry-point')
Future<void> meSendFirebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final ready =
      await MeSendPushNotificationDisplay.ensureFirebaseInitializedForBackground();
  if (!ready) {
    return;
  }
  meherySenderLog('SDK background handler invoked', tag: 'Push|background');
  MeSendPushNotificationDisplay.logPayload(message, 'background');
  await MeSendPushNotificationDisplay.handleRemoteMessage(
    message,
    source: 'background',
  );
}
