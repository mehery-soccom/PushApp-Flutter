import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mehery_sender/mehery_sender.dart';

import 'firebase_options.dart';

/// FCM background handler — must be a top-level function.
///
/// [DefaultFirebaseOptions.currentPlatform] is read **inside** this isolate
/// (statics from [main] are not available here).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await meSendHandleBackgroundRemoteMessage(
    message,
    options: DefaultFirebaseOptions.currentPlatform,
  );
}
