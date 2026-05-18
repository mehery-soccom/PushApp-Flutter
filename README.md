# PushApp-Flutter SDK

A lightweight Flutter package for push notifications, custom in-app messages (popup, banner, PiP, inline, tooltip), event tracking, and session handling for your Flutter apps.

---

## What Your App Must Add (Quick Checklist)

Your Flutter app should include all of the following:

- Firebase config files:
  - Android: `android/app/google-services.json`
  - iOS: `ios/Runner/GoogleService-Info.plist`
- Push capability on iOS and foreground notification handling in `AppDelegate.swift` (see platform guides)
- SDK initialization at startup: create a `Pushapp` instance and call `initializeAndSendToken()`
- Firebase background handler registered in `main()` (`meSendFirebaseMessagingBackgroundHandler`) so background receipts behave consistently
- User identity and tracking calls where they match your user journey:
  - `Pushapp.login`
  - `Pushapp.initPage` (page context for in-app surfaces)
  - `Pushapp.sendEvent`
  - `Pushapp.createOrUpdateCustomerProfile` (after login, recommended)
- Optional **session geo** reporting (`Pushapp.postSessionGeo`) after **`login`** (SDK persists **`session_id`** when **`device/link`** returns it); you must pass real location fields via **`PushSessionGeoData`**
- `BuildContext` for in-app UI via `setInAppNotification` before expecting overlays
- Optional: `navigatorObservers` with `meSendRouteObserver` for route-based page events
- Inline/tooltip widgets (`MeSendWidget`, `registerWidget`, `MeSendTooltipWrapper`) only if you use those surfaces

---

## 📦 Installation

Add the dependency to your app’s `pubspec.yaml`:

```yaml
dependencies:
  mehery_sender: ^0.1.0
```

Then install packages:

```bash
flutter pub get
```

For iOS, install CocoaPods dependencies:

```bash
cd ios && pod install && cd ..
```

---

## Step-by-Step Setup (Flutter)

### 1) Add Firebase files

- Android: place `google-services.json` in `android/app/`
- iOS: add `GoogleService-Info.plist` to your Runner target

### 2) iOS push setup

Enable **Push Notifications** in Xcode and add foreground handling:

```swift
import UserNotifications

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return true
}

func userNotificationCenter(_ center: UNUserNotificationCenter,
                            willPresent notification: UNNotification,
                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    if #available(iOS 14.0, *) {
        completionHandler([.banner, .sound, .badge])
    } else {
        completionHandler([.alert, .sound, .badge])
    }
}
```

See [IOSREADME.md](./IOSREADME.md) for Live Activities and extended iOS integration.

### 3) Register background messaging (recommended)

In `main()`, before `runApp`:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mehery_sender/mehery_sender.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(meSendFirebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}
```

### 4) Initialize SDK at app startup

Create one shared `Pushapp` instance. Pass your **full app / channel id** (same format as the Ionic SDK `appId`), for example `demo_1751694691225`:

- **Tenant** (subdomain for `https://<tenant>.pushapp...`) = substring **before the first `_`** → `demo`
- **Channel id** sent to APIs = the **entire string** → `demo_1751694691225`

Legacy identifiers using a **`$`** separator (`tenant$channel`) are still accepted.

```dart
import 'package:mehery_sender/mehery_sender.dart';

final pushapp = Pushapp(
  identifier: 'demo_1751694691225',
  sandbox: false,
);

await pushapp.initializeAndSendToken();
```

`initializeAndSendToken()` registers the device token with the backend (FCM on Android; platform-appropriate flow on iOS).

**API hosts** (`https://<tenant>.pushapp.<tld>`):

| `sandbox` | Host TLD |
|-----------|----------|
| `false` | **`.net`** (production) |
| `true` | **`.ai`** (client sandbox) |

For internal Mehery development against **`.co.in`**, pass `developmentHost: true` (not for production app builds).

### 5) Provide context for in-app notifications

Before showing popup/banner/PiP style surfaces:

```dart
pushapp.setInAppNotification(context);
```

### 6) Link user/session + events

```dart
await pushapp.login('user_123');

pushapp.initPage('home');

await pushapp.sendEvent('button_clicked', {
  'source': 'welcome_screen',
  'method': 'google',
});
```

### 7) Optional: route observer for navigation events

Attach the observer included on your `Pushapp` instance:

```dart
MaterialApp(
  navigatorObservers: [pushapp.meSendRouteObserver],
  // ...
);
```

### 8) Update customer profile (recommended after login)

```dart
final headers = await pushapp.getDeviceHeaders();
final deviceId = headers['X-Device-ID'] ?? '';
final code = 'user_123_$deviceId';

await pushapp.createOrUpdateCustomerProfile(
  code: code,
  additionalInfo: {'city': 'Mumbai', 'plan': 'free'},
  cohorts: {'segment': 'trial'},
  completion: (success) {
    // handle result
  },
);
```

### 9) Session geo (optional)

Sends **`POST /pushapp/api/session/geo`** on your tenant host. The SDK adds **`session_id`** automatically after **`login`** when **`device/link`** returns a session (otherwise the call returns **`false`**).

You supply **`geoIP`** by building **`PushSessionGeoData`** from GPS, platform locale, IP lookup, or your backend — the SDK does not invent coordinates.

**`geoIP` JSON shape** (also see **`PushSessionGeoData`** in Dart):

| Field | Type | What you provide |
|--------|------|------------------|
| `geoIP.ip` | `string` | IPv4 for this session/device (from your network stack or server). |
| `geoIP.location.lat` | `number` | Latitude, decimal degrees (WGS‑84). |
| `geoIP.location.lng` | `number` | Longitude, decimal degrees (WGS‑84). |
| `geoIP.country.iso_code` | `string` | Country ISO code (e.g. `IN`, `US`). |
| `geoIP.country.name` | `string` | Country display name. |
| `geoIP.region.iso_code` | `string` | Region/state ISO code (e.g. `MH`, `NY`). |
| `geoIP.region.name` | `string` | Region/state display name. |
| `geoIP.city.name` | `string` | City name. |
| `geoIP.area.name` | `string` | Area or neighborhood / locality name. |

**Example**

```dart
final geo = PushSessionGeoData(
  ip: '203.0.113.10',
  lat: 19.07609,
  lng: 72.87771,
  countryIsoCode: 'IN',
  countryName: 'India',
  regionIsoCode: 'MH',
  regionName: 'Maharashtra',
  cityName: 'Mumbai',
  areaName: 'Parel',
);

final ok = await pushapp.postSessionGeo(geo);
```

### 10) Optional: inline + tooltip in-app placements

#### 🎨 Inline placeholder (`MeSendWidget`)

Embeds HTML/WebView-driven inline content for a given placeholder id:

```dart
MeSendWidget(
  placeholderId: 'my_placeholder_id',
  meSend: pushapp,
  height: 200,
  width: double.infinity,
)
```

#### 💬 Tooltip anchor (`registerWidget`)

Wraps a child widget so tooltips can anchor to it (uses the SDK tooltip pipeline):

```dart
pushapp.registerWidget(
  placeholderId: 'my_tooltip_target',
  child: YourButton(),
);
```

#### 💬 Tooltip wrapper (`MeSendTooltipWrapper`)

Alternative wrapper for tooltip-style surfaces:

```dart
MeSendTooltipWrapper(
  placeholderId: 'my_tooltip_target',
  meSend: pushapp,
  child: YourButton(),
)
```

---

## 📋 API Reference

### Core / lifecycle

#### `Pushapp({required String identifier, bool sandbox, bool developmentHost})`

Creates the SDK client.

**Parameters:**

- `identifier` (string, required): **App id** — e.g. `demo_1751694691225`. The **channel id** for APIs is this full string; the **tenant** subdomain is the substring before the first `_` (`demo`). If you still use the old form **`tenant$channel`**, that is supported for backward compatibility.
- `sandbox` (bool, optional): `false` → **`*.pushapp.net`** (production). `true` → **`*.pushapp.ai`** (client sandbox).
- `developmentHost` (bool, optional, default `false`): when `true`, uses **`*.pushapp.co.in`** for internal development (overrides `sandbox`). Do not ship this to end-user production builds.

#### `Future<void> initializeAndSendToken()`

Requests notification permission where applicable, reads the device token, and registers it with the backend.

#### `void setInAppNotification(BuildContext context)`

Stores `BuildContext` used when rendering in-app notification UI.

#### `Future<void> login(String userId)`

Associates the device/session with a user.

#### `Future<void> logout(String userId)`

Delinks the user from the device on the server.

#### `void initPage(String page)`

Signals the current page name for in-app / analytics flows.

#### `Future<void> sendEvent(String eventName, Map<String, dynamic> eventData)`

Sends a custom event (`POST` to `/pushapp/api/v1/event`).

#### `Future<Map<String, String>> getDeviceHeaders()`

Returns device/app metadata headers (`X-Device-ID`, `X-App-Version`, platform fields, etc.) for authenticated calls.

#### `Future<void> createOrUpdateCustomerProfile({...})`

Creates or updates customer profile data (`PUT` `/pushapp/api/v1/customer/profile`).

**Parameters:**

- `code` (string, required): Unique customer code (recommended: `userId_deviceId`).
- `additionalInfo` (map, required): Profile attributes.
- `cohorts` (map, required): Segmentation attributes.
- `completion` (callback, required): Called with `true`/`false` for success.

### Session / geo

#### `PushSessionGeoData`

Constructor fields (serialized under **`geoIP`**): **`ip`**, **`lat`**, **`lng`**, **`countryIsoCode`**, **`countryName`**, **`regionIsoCode`**, **`regionName`**, **`cityName`**, **`areaName`** — see Step 9 for the JSON mapping.

#### `Future<bool> postSessionGeo(PushSessionGeoData geo)`

Sends **`POST /pushapp/api/session/geo`** with:

- **`session_id`** — persisted by the SDK after **`login`** when **`device/link`** returns a session id.
- **`geoIP`** — from **`geo.toGeoIpJson()`** (your **`PushSessionGeoData`**).

Returns **`true`** on HTTP **2xx**, **`false`** if there is no stored session id or the request fails.

#### `static Future<void> postPushReceiptToSlack(RemoteMessage message, String source)`

Internal/diagnostic helper used by the provided background handler; not required for normal integration.

### Placeholder / widget helpers

#### `void registerPlaceholderListener(...)`

Registers a listener for placeholder content pushed over the socket/API path.

#### `void unregisterPlaceholderListener(String placeholderId)`

Removes the listener for a placeholder id.

#### `Widget registerWidget({required String placeholderId, required Widget child})`

Wraps `child` for tooltip registration via `TooltipSdk`.

### Route observer

#### `MeSendRouteObserver` (via `pushapp.meSendRouteObserver`)

`NavigatorObserver` that emits page-related events when attached to `MaterialApp`. Instantiated by the SDK and wired when you construct `Pushapp`.

---

## 🔧 Platform-Specific Notes

### Android

- **Minimum SDK**: API 26+ recommended for notification channels (see [AndroidREADME.md](./AndroidREADME.md)).
- **Firebase**: Apply `google-services` Gradle plugin and include `google-services.json`.
- **ProGuard** (if enabled): consider keeping SDK classes — for example:
  ```proguard
  -keep class com.mehery.** { *; }
  ```

### iOS

- **Minimum**: Align with your app’s deployment target; push setup follows standard Firebase/APNs configuration.
- **Capabilities**: Push Notifications (and Background Modes if you use background delivery).
- **Foreground notifications**: Use `UNUserNotificationCenterDelegate` as in Step 2.
- **Live Activities**: See [IOSREADME.md](./IOSREADME.md) (iOS 16.1+ for ActivityKit features).

---

## 📄 Example Implementation

See the [`example/`](./example/) directory for a sample app:

- Firebase initialization
- `Pushapp` construction and `initializeAndSendToken`
- Login/logout triggers

Session geo: after **`login`**, call **`postSessionGeo(PushSessionGeoData(...))`** with real location fields (see Step 9).

---

## 🏷️ Version

Current package version: **`0.1.0`** (see `pubspec.yaml`).

---

## 💬 Support

- **Repository**: [mehery_sender_flutter](https://github.com/mehery-soccom/mehery_sender_flutter)
- **Issues**: [GitHub Issues](https://github.com/mehery-soccom/mehery_sender_flutter/issues)
- **Platform guides**: [AndroidREADME.md](./AndroidREADME.md), [IOSREADME.md](./IOSREADME.md)

---

## 📝 License

MIT
