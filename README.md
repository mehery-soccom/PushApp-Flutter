# PushApp Flutter SDK

Flutter SDK for push notifications, event tracking, and in-app messages (popup, banner, PiP, roadblock).

**Documentation site:** [https://docs.mehery.com/guide/pushapp/flutter-sdk/](https://docs.mehery.com/guide/pushapp/flutter-sdk/) — hosted on [MeherY docs](https://docs.mehery.com/guide/pushapp/); HTML source in this repo under [`docs/`](docs/) (see [docs/README.md](docs/README.md)).

---
## What Your App Must Add (Quick Checklist)

Your Flutter app should include all of the following:

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

Add to your app `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  mehery_sender: ^0.1.14
  firebase_core: ^4.10.0
  firebase_messaging: ^16.3.0
```

`flutter_local_notifications` is pulled in **transitively** by `mehery_sender` for foreground tray display — you do **not** need to declare it in the host app.

```bash
flutter pub get
```

### Compatibility matrix (`mehery_sender` 0.1.14)

Host apps within this matrix do **not** need `dependency_overrides`.

#### Minimum requirements

| Component | Minimum | Source |
|-----------|---------|--------|
| Flutter | 3.38.1 | `pubspec.yaml` `environment.flutter` |
| Dart | 3.10.0 | `pubspec.yaml` `environment.sdk` |
| Android (API level) | 21 | Plugin `android/` (`minSdk 21`) |
| iOS deployment target | 15.0 | Recommended `Podfile` (§1.5) |
| `firebase_core` | 4.10.0 | Host `pubspec.yaml` (`^4.10.0`) |
| `firebase_messaging` | 16.3.0 | Host `pubspec.yaml` (`^16.3.0`) |
| `flutter_local_notifications` | 22.0.0 | Transitive via `mehery_sender` |

#### Tested combination (example app / release QA)

Verified with `flutter analyze`, `flutter test`, and example builds on **Flutter 3.44.1 / Dart 3.12.1**:

| Component | Tested version |
|-----------|----------------|
| Flutter | 3.44.1 |
| Dart | 3.12.1 |
| Android | minSdk 21, compileSdk 34 |
| iOS | 15.0+ (`platform :ios, '15.0'`) |
| `firebase_core` | 4.10.0 – 4.11.0 |
| `firebase_messaging` | 16.3.0 – 16.4.0 |
| `flutter_local_notifications` | 22.0.0 |
| `mehery_sender` | 0.1.14 |

New releases document an updated matrix in [CHANGELOG.md](CHANGELOG.md).

**When overrides are needed (rare):** Only if another plugin forces `firebase_core` &lt; 4.10, `firebase_messaging` &lt; 16.3, or an incompatible `flutter_local_notifications`. Prefer upgrading the conflicting plugin; use `dependency_overrides` only as a temporary workaround and align with the matrix above.

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
    defaultConfig {
        // mehery_sender plugin requires minSdk 21+
        minSdk = maxOf(flutter.minSdkVersion, 21)
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

**FCM delivery (push-only):** The plugin does **not** register a second `MESSAGING_EVENT` handler. Firebase Cloud Messaging is delivered through **`FlutterFirebaseMessagingService`** (from `firebase_messaging`) into Dart — foreground via `MeSendPushNotificationDisplay`, background via `meSendFirebaseMessagingBackgroundHandler`. Do not add `LiveActivityMessagingService` to your manifest unless you opt into native rich-notification templates (see [AndroidREADME.md](AndroidREADME.md)).

---

## 1.5 iOS platform config

This section is the **minimum** for push + in-app SDK features. **Notification Service Extension**, **Notification Content Extension**, and **Live Activity** targets are **optional** — see [IOSREADME.md](IOSREADME.md) for when to add them and step-by-step Xcode setup.

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

### Optional: Live Activity & notification extensions

Not required for push registration, foreground notifications, or in-app messages.

| Feature | Guide |
|---------|--------|
| Rich mutable push (images, modified content) | [IOSREADME.md — NSE](IOSREADME.md#step-by-step-notification-service-extension) |
| Custom expanded notification UI | [IOSREADME.md — Content extension](IOSREADME.md#step-by-step-notification-content-extension) |
| Live Activity / Dynamic Island (iOS 16.1+) | [IOSREADME.md — Live Activity](IOSREADME.md#step-by-step-live-activity-widget-extension) |

The [`example/ios/`](example/ios/) project includes all optional targets as reference; your app can integrate with **Runner only** per the steps above.

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
✓ (Optional) NSE / Live Activity — see IOSREADME.md
```

---

# Part 2 — Implementation

Dart code to wire the SDK into your app. Complete **Part 1** first.

---

## 2.1 Import

```dart
import 'package:mehery_sender/mehery_sender.dart';
```

### Debug logging (optional)

All SDK diagnostics use the prefix **`[MeherySender]`** so you can filter them apart from your app’s own logs (logcat filter `MeherySender`, Xcode console search `MeherySender`).

By default logging follows `kDebugMode` (on in debug, off in release). To trace registration, API, push, or in-app issues in **release/profile** builds, enable logging **before** creating your `Pushapp` instance:

```dart
import 'package:mehery_sender/mehery_sender.dart';

void main() {
  meherySenderApiLoggingEnabled = true; // opt-in for release/profile
  // ...
}
```

Subsystem tags appear as `[MeherySender][API]`, `[MeherySender][Push|foreground]`, `[MeherySender][InApp]`, etc.

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
  pushApp.attachNavigatorKey(pushAppNavigatorKey);
  final context = pushAppNavigatorKey.currentContext;
  if (context != null && context.mounted) {
    pushApp.setInAppNotification(context);
  }
}

Future<void> initializePushApp({
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
}
```

### Registration state

Observe device registration without polling [Pushapp.isDeviceRegistered]:

```dart
// Current snapshot (before or between stream events)
final snapshot = pushApp.registrationSnapshot;

pushApp.registrationState.listen((state) {
  switch (state.status) {
    case MeSendDeviceRegistrationStatus.pending:
      // Waiting for tokens / first register call
      break;
    case MeSendDeviceRegistrationStatus.registered:
      // Device linked; state.restoredFromCache == true after app restart
      break;
    case MeSendDeviceRegistrationStatus.failed:
      // state.message — retry initializeAndSendToken when tokens are ready
      break;
    case MeSendDeviceRegistrationStatus.tokenRefreshed:
      // Push token updated on server (FCM/APNs refresh)
      break;
  }
});
```

[Pushapp.deviceRegistrationState] still emits `true`/`false` for simple listeners.

**Retry on failure** — `initializeAndSendToken` returns `Future<bool>` and does not throw unless [meherySenderStrictRegistrationMode] is enabled:

```dart
Future<void> registerPushWhenReady() async {
  final messaging = FirebaseMessaging.instance;
  final fcm = await messaging.getToken();
  final apns = Platform.isIOS ? await messaging.getAPNSToken() : null;

  final ok = await pushApp.initializeAndSendToken(
    fcmToken: fcm,
    apnsToken: apns,
  );
  if (!ok) {
    debugPrint('Registration pending: ${pushApp.registrationSnapshot.message}');
  }
}

// Also retry when FCM refreshes the token:
FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
  await pushApp.initializeAndSendToken(
    fcmToken: token,
    apnsToken: Platform.isIOS ? await FirebaseMessaging.instance.getAPNSToken() : null,
  );
});
```

---

## 2.3 App entry — `lib/main.dart`

**Background handler file** — create `lib/firebase_background_handler.dart`:

```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mehery_sender/mehery_sender.dart';

import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await meSendHandleBackgroundRemoteMessage(
    message,
    options: DefaultFirebaseOptions.currentPlatform,
  );
}
```

**Main:**

```dart
import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:mehery_sender/mehery_sender.dart';

import 'firebase_background_handler.dart';
import 'firebase_options.dart';
import 'push_service.dart';

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
```

> **Foreground push:** [MeSendPushNotificationDisplay.ensureInitialized] attaches
> FCM listeners automatically after [Firebase.initializeApp]. Do **not** call
> [MeSendPushNotificationDisplay.attachFirebaseListeners] from host code.

> **Background handler (required pattern):** FCM runs `firebaseMessagingBackgroundHandler` in a **separate Dart isolate**. Module-level statics set in [main] (including [configureMeSendFirebaseBackgroundInit]) are **not** visible there. You **must** use a host top-level handler that calls [meSendHandleBackgroundRemoteMessage] with `DefaultFirebaseOptions.currentPlatform` evaluated **inside** that handler (see `firebase_background_handler.dart` above). Do **not** register [meSendFirebaseMessagingBackgroundHandler] directly unless you wrap it the same way.

> **Data-only background pushes (Android):** When the FCM payload has no `notification` block, the SDK builds the tray notification from `data` fields (`title`/`body` or `message1`/`message2`). The SDK skips `requestNotificationsPermission` in the background isolate (no Activity context); request permission in [main] / `_setupPush` instead.

### Troubleshooting — background push

| Log line | Cause | Fix |
|----------|--------|-----|
| `[MeherySender][Push\|background] Firebase init skipped — pass options to meSendHandleBackgroundRemoteMessage` | Background isolate has no [FirebaseOptions] | Add host top-level handler per §2.3 |
| `NullPointerException` … `requestNotificationsPermission` in background handler | Old SDK called permission APIs without Activity | Upgrade to **0.1.11+**; ensure tray init uses background path |
| `data-only parsed … showTray=true` but no notification | Crash during local notification show | Upgrade to **0.1.11+**; verify POST_NOTIFICATIONS granted in foreground |

```dart
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

Pass the navigator key from `push_service.dart` and register SDK route observers for automatic page tracking:

```dart
MaterialApp(
  navigatorKey: pushAppNavigatorKey,
  navigatorObservers: pushApp.navigatorObservers,
  home: const HomeScreen(),
);
```

Name your routes when possible so analytics receive stable page ids:

```dart
Navigator.push(
  context,
  MaterialPageRoute<void>(
    settings: const RouteSettings(name: 'dashboard'),
    builder: (_) => const DashboardScreen(),
  ),
);
```

---

## 2.5 Login / logout

**On sign-in** (after your auth succeeds):

```dart
await pushApp.login(userId);
```

**Account switch (same device):** When a different user signs in, call `login(newUserId)` directly. The SDK delinks the previous user (`device/delink`), clears local session state, and links the new user. You do **not** need to call `logout()` first.

**On sign-out** (no replacement user):

```dart
await pushApp.logout(userId);
```

Both APIs queue or no-op when device registration is still pending — they do not throw during normal startup timing.

---

## 2.6 Screen tracking

**Automatic (recommended):** With [navigatorObservers] wired in §2.4, the SDK sends `page_open` and `page_closed` events when the user navigates.

**Manual (optional):** Call [Pushapp.initPage] on a screen to record a page view and trigger an in-app message poll:

```dart
@override
void initState() {
  super.initState();
  pushApp.initPage('dashboard');
}
```

Use `initPage` when you need in-app polling on that screen; route observers handle analytics-only tracking.

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

> **Security:** Campaign HTML runs in WebView with **unrestricted JavaScript**. Configure [CTA URL allowlists](WEBVIEW_SECURITY.md#cta-url-allowlist-recommended-for-production) for production. See [WEBVIEW_SECURITY.md](WEBVIEW_SECURITY.md).

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

## CI

Every push and pull request runs [GitHub Actions](.github/workflows/ci.yml):

| Job | Runner | Checks |
|-----|--------|--------|
| **Analyze & test** | `ubuntu-latest` | `flutter analyze` (SDK + example), `flutter test` |
| **Build example (Android)** | `ubuntu-latest` | `flutter build apk --debug` |
| **Build example (iOS)** | `macos-latest` | `flutter build ios --simulator --debug` |

Requires Flutter **≥ 3.38.1** (stable channel in CI). Fix analyzer errors and failing tests before merging PRs.

---

## Version

`^0.1.14` — see [VERSIONING.md](VERSIONING.md) for semver rules and [CHANGELOG.md](CHANGELOG.md) for release notes and migration steps.

**Privacy & data handling:** [PRIVACY.md](PRIVACY.md) (device data, APIs, retention, GDPR/CCPA host checklist).

**WebView / in-app HTML security:** [WEBVIEW_SECURITY.md](WEBVIEW_SECURITY.md) (unrestricted JS, CTA allowlist).

**Publishing to pub.dev:** [PUBLISHING.md](PUBLISHING.md) (metadata, false_secrets, dry-run checklist).

---

## License

MIT
