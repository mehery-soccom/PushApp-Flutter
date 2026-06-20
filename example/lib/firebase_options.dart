// Generated-style Firebase options for the example app (project: mehery-75d3b).
// Re-run `flutterfire configure` in example/ to refresh from your Firebase project.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web is not configured for this example.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAHz076gHJHvmfMJD1K4G9qm0Sp-Oeqp-M',
    appId: '1:22930153229:android:example0000000000000000',
    messagingSenderId: '22930153229',
    projectId: 'mehery-75d3b',
    storageBucket: 'mehery-75d3b.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAHz076gHJHvmfMJD1K4G9qm0Sp-Oeqp-M',
    appId: '1:22930153229:ios:f96a52011c577818e4da44',
    messagingSenderId: '22930153229',
    projectId: 'mehery-75d3b',
    storageBucket: 'mehery-75d3b.firebasestorage.app',
    iosBundleId: 'com.example.example.mehios',
  );
}
