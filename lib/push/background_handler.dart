part of mehery_sender;

/// Legacy FCM background entry point.
///
/// **Do not register this directly** unless you wrap it in a host top-level
/// handler that passes [FirebaseOptions] into [meSendHandleBackgroundRemoteMessage].
/// Statics set in [main] via [configureMeSendFirebaseBackgroundInit] are **not**
/// visible in the background isolate.
///
/// Recommended host setup — see README §2.3 and `example/lib/firebase_background_handler.dart`.
@pragma('vm:entry-point')
Future<void> meSendFirebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final options = meSendConfiguredFirebaseBackgroundOptions;
  if (options == null) {
    meherySenderLog(
      'Background isolate has no FirebaseOptions — register a host top-level handler '
      'that calls meSendHandleBackgroundRemoteMessage(message, options: '
      'DefaultFirebaseOptions.currentPlatform). See README §2.3.',
      tag: 'Push|background',
    );
    return;
  }
  await meSendHandleBackgroundRemoteMessage(message, options: options);
}
