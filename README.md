# PushApp Flutter SDK

Flutter SDK for push notifications, event tracking, and in-app messages (popup, banner, PiP, roadblock).

---
## What Your App Must Add (Quick Checklist)

Your Ionic/Capacitor app should include all of the following:

- Firebase config files:
  - Android: `android/app/google-services.json`
  - iOS: `ios/App/GoogleService-Info.plist`
- Push capability on iOS and foreground notification handling in `AppDelegate.swift`
- SDK initialization at app startup (`PushApp.initialize`)
- Push token registration from app code (`PushApp.register`)
- User identity and tracking calls where they match your user journey:
  - `PushApp.login`
  - `PushApp.setPageName`
  - `PushApp.sendEvent`
  - `PushApp.saveUserData` (after login)
- Placeholder/tooltip registration only if you use inline/tooltip in-app surfaces
---

# Part 1 — Setup

One-time project configuration before writing SDK integration code.

---

## 1.1 Dependencies

Add to `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  mehery_sender: ^0.1.7
  firebase_core: ^4.10.0
  firebase_messaging: ^16.3.0

dependency_overrides:
  firebase_core: ^4.10.0
  firebase_messaging: ^16.3.0
  flutter_local_notifications: ^18.0.1
```

```bash
flutter pub get
```

---

## 1.2 Firebase Console

1. Open [Firebase Console](https://console.firebase.google.com/)
2. Create a project (or use an existing one)
3. Register an **Android** app — use your `applicationId` (e.g. `com.example.myapp`)
4. Register an **iOS** app — use the same bundle ID as in Xcode

Download and place the config files:

| Platform | File | Location |
|----------|------|----------|
| Android | `google-services.json` | `android/app/google-services.json` |
| iOS | `GoogleService-Info.plist` | `ios/Runner/GoogleService-Info.plist` |

In Xcode, ensure `GoogleService-Info.plist` is added to the **Runner** target.

---

## 1.3 FlutterFire CLI

Generate `lib/firebase_options.dart`:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

---

## 1.4 Android platform config

**`android/settings.gradle.kts`**

```kotlin
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
    id("com.google.gms.google-services") version "4.4.2" apply false
}
```

**`android/app/build.gradle.kts`**

```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

**`android/app/src/main/AndroidManifest.xml`**

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <application ...>
```

---

## 1.5 iOS platform config

**Xcode → Runner → Signing & Capabilities**

- **Push Notifications**
- **Background Modes** → Remote notifications *(optional, for background delivery)*

**`ios/Runner/Runner.entitlements`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>aps-environment</key>
    <string>development</string>
</dict>
</plist>
```

Use `production` for App Store / TestFlight builds.

**`ios/Runner/AppDelegate.swift`**

```swift
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

**`ios/Podfile`**

```ruby
platform :ios, '15.0'
```

```bash
cd ios && pod install && cd ..
```

---

## 1.6 Setup checklist

```
✓ pubspec.yaml dependencies added
✓ android/app/google-services.json
✓ lib/firebase_options.dart (flutterfire configure)
✓ Android Gradle + POST_NOTIFICATIONS permission
✓ ios/Runner/GoogleService-Info.plist
✓ iOS Push capability + entitlements + AppDelegate
✓ pod install
```

---

# Part 2 — Implementation

Dart code to wire the SDK into your app. Complete **Part 1** first.

---

## 2.1 Import

```dart
import 'package:mehery_sender/mehery_sender.dart';
```

---

## 2.2 SDK instance — `lib/push_service.dart`

Create one shared instance and a navigator key for in-app overlays:

```dart
import 'package:flutter/material.dart';
import 'package:mehery_sender/mehery_sender.dart';

final pushApp = Pushapp(
  identifier: 'yourTenant_yourChannelId', // from Mehery dashboard
  sandbox: false,
);

final pushAppNavigatorKey = GlobalKey<NavigatorState>();

void registerPushInAppContext() {
  final context = pushAppNavigatorKey.currentContext;
  if (context != null && context.mounted) {
    pushApp.setInAppNotification(context);
  }
}

Future<void> initializePushApp({
  required String? fcmToken,
  required String? apnsToken,
}) async {
  await pushApp.initializeAndSendToken(
    fcmToken: fcmToken,
    apnsToken: apnsToken,
  );
  registerPushInAppContext();
}
```

---

## 2.3 App entry — `lib/main.dart`

```dart
import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:mehery_sender/mehery_sender.dart';

import 'firebase_options.dart';
import 'push_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await MeSendPushNotificationDisplay.handleRemoteMessage(
    message,
    source: 'background',
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await MeSendPushNotificationDisplay.ensureInitialized();
  MeSendPushNotificationDisplay.attachFirebaseListeners();

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
  }

  await initializePushApp(fcmToken: fcmToken, apnsToken: apnsToken);
}
```

---

## 2.4 `MaterialApp`

Pass the 'pushAppNavigatorKey' key from `push_service.dart`:

```dart
MaterialApp(
  navigatorKey: pushAppNavigatorKey,
  home: const HomeScreen(),
);
```

---

## 2.5 Login / logout

**On sign-in** (after your auth succeeds):

```dart
await pushApp.login(userId);
```

**On sign-out**:

```dart
await pushApp.logout(userId);
```

---

## 2.6 Screen tracking

Call in each screen that should receive in-app messages:

```dart
@override
void initState() {
  super.initState();
  pushApp.initPage('dashboard');
}
```

---

## 2.7 Custom events *(optional)*

```dart
await pushApp.sendEvent('event_name', {'key': 'value'});
```


---

## 2.8 Example Implementation file layout

```
lib/
  main.dart                 ← Firebase init, listeners, token → SDK
  push_service.dart         ← Pushapp instance, navigatorKey
  firebase_options.dart     ← from flutterfire configure
  screens/
    login_screen.dart       ← pushApp.login(userId)
    dashboard_screen.dart   ← pushApp.initPage('dashboard')
```

---

---

## 2.9 Inline placeholder *(optional)*

Use when Mehery delivers **inline HTML content** into a fixed area on your screen (banner/card slot).

The `placeholderId` must match the id configured in the Mehery dashboard for that slot.

```dart
import 'package:mehery_sender/mehery_sender.dart';
import '../push_service.dart';

MeSendWidget(
  placeholderId: 'home_banner_slot',
  meSend: pushApp,
  height: 200,
  width: double.infinity,
)
```

Place it in your widget tree where the inline content should appear:

```dart
Column(
  children: [
    const Text('Welcome'),
    MeSendWidget(
      placeholderId: 'home_banner_slot',
      meSend: pushApp,
      height: 180,
    ),
    const Text('More content'),
  ],
)
```

The widget registers itself on build and renders HTML/WebView content when the SDK receives a matching in-app message.

---

## 2.10 Tooltip *(optional)*

Use when Mehery delivers a **tooltip** anchored to a specific widget on screen.

The `placeholderId` must match the id configured in the Mehery dashboard for that anchor.


Wrap the target widget. The SDK handles tooltip registration and display:

```dart
pushApp.registerWidget(
  placeholderId: 'checkout_help_button',
  child: IconButton(
    icon: const Icon(Icons.help_outline),
    onPressed: () {},
  ),
)
```

### Example in a screen

```dart
class DashboardScreen extends StatefulWidget {
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    pushApp.initPage('dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          pushApp.registerWidget(
            placeholderId: '{placeholder_id}',
            child: IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          MeSendWidget(
            placeholderId: '{placeholder_id}',
            meSend: pushApp,
            height: 160,
          ),
          // ... rest of screen
        ],
      ),
    );
  }
}
```

> **Note:** Call `initPage` on the screen and ensure `registerPushInAppContext()` has run so in-app messages (including tooltips and placeholders) can display.

---

## 2.11 Implementation file layout

```
lib/
  main.dart                 ← Firebase init, listeners, token → SDK
  push_service.dart         ← Pushapp instance, navigatorKey
  firebase_options.dart     ← from flutterfire configure
  screens/
    login_screen.dart       ← pushApp.login(userId)
    dashboard_screen.dart   ← pushApp.initPage('dashboard')
                              MeSendWidget / registerWidget
```

---

## Version

`^0.1.7`

---

## License

MIT
