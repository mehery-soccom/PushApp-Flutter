# iOS optional extensions guide

This document covers **optional** native iOS targets for rich push, custom notification UI, and Live Activities. It is separate from the main [README.md](README.md) setup (Part 1 §1.5), which covers the **minimum** push integration.

---

## Required vs optional

| Capability | Required for basic PushApp SDK? | Minimum iOS | Xcode targets |
|------------|--------------------------------|-------------|---------------|
| FCM/APNs push, foreground tray, in-app messages, events | **Yes** | **15.0** | **Runner** only |
| Mutable push payload (download images, modify content before display) | No | 15.0 | + **Notification Service Extension (NSE)** |
| Custom expanded notification UI (long-look) | No | 15.0 | + **Notification Content Extension** |
| Live Activity / Dynamic Island from push | No | **16.1** | + **Widget Extension (Live Activity)**; NSE recommended to start activities from push |

**Push-only hosts:** Follow [README.md §1.5](README.md#15-ios-platform-config) only. Do **not** add NSE, content extension, or Live Activity targets unless you need those features.

The [`example/ios/`](example/ios/) app ships all optional targets as **reference implementations**. You can delete them from your fork if you only need push + in-app.

---

## Push-only (minimum) recap

1. **Capabilities (Runner):** Push Notifications; Background Modes → Remote notifications (optional but recommended).
2. **`Runner.entitlements`:** `aps-environment` (`development` or `production`).
3. **`AppDelegate.swift`:** Register for remote notifications and set `UNUserNotificationCenter` delegate (see README §1.5).
4. **`Podfile`:** `platform :ios, '15.0'` (or higher).
5. **Dart:** `firebase_core`, `firebase_messaging`, `mehery_sender` — no native extension wiring required.

No App Groups, no ActivityKit, no extension bundle IDs.

---

## When to add each extension

### Notification Service Extension (NSE)

Add an NSE when Mehery (or your backend) sends pushes with **`mutable-content: 1`**. The NSE runs before the notification is shown and can:

- Download images and attach them to the notification
- Rewrite title/subtitle/body
- Start a Live Activity from the push payload (delivery tracking)

**Reference:** [`example/ios/NotificationServiceExtension/`](example/ios/NotificationServiceExtension/)

Key file: `NotificationService.swift` — routes on `template_id` (`delivery`, `score`, or default pass-through).

### Notification Content Extension

Add a content extension when you want a **custom long-look UI** for a notification category (e.g. delivery progress bar, driver/car images).

**Reference:** [`example/ios/NotificationContentExtension/`](example/ios/NotificationContentExtension/)

- `Info.plist` → `UNNotificationExtensionCategory` must match the category set in the NSE (example: `DELIVERY_CATEGORY`).
- Storyboard + `NotificationViewController.swift` render attachments and `userInfo` fields.

**Not required** for standard title/body pushes or SDK in-app messages.

### Live Activity extension

Add a Live Activity **Widget Extension** when you want Lock Screen / Dynamic Island UI updated from delivery (or similar) pushes.

**Reference:** [`example/ios/LiveActivityExtension/`](example/ios/LiveActivityExtension/)

Requirements:

- iOS **16.1+** on device (limited simulator support)
- `NSSupportsLiveActivities` = `true` in **Runner** `Info.plist` (see [`example/ios/Runner/Info.plist`](example/ios/Runner/Info.plist))
- Shared `ActivityAttributes` type used by **both** the NSE (to call `Activity.request`) and the widget (to define UI)
- Example shared model: [`example/ios/Shared/DeliveryAttributes.swift`](example/ios/Shared/DeliveryAttributes.swift)

> **Important:** The widget and NSE must use the **same** `ActivityAttributes` struct (same module name and fields). Add the Swift file to both targets via Xcode **Target Membership**.

---

## Step-by-step: Notification Service Extension

### 1. Create the target

1. Open `ios/Runner.xcworkspace` in Xcode.
2. **File → New → Target → Notification Service Extension**.
3. Product name: `NotificationServiceExtension` (or your choice).
4. Bundle ID pattern: `{your.app.bundle}.NotificationServiceExtension`  
   Example: `com.example.example.mehios.NotificationServiceExtension`
5. Deployment target: **15.0** (push-only rich content) or **16.1+** if the NSE will start Live Activities.

### 2. Implement the extension

Copy or adapt [`NotificationService.swift`](example/ios/NotificationServiceExtension/NotificationService.swift) into the new target.

Ensure `Info.plist` contains:

```xml
<key>NSExtension</key>
<dict>
  <key>NSExtensionPointIdentifier</key>
  <string>com.apple.usernotifications.service</string>
  <key>NSExtensionPrincipalClass</key>
  <string>$(PRODUCT_MODULE_NAME).NotificationService</string>
</dict>
```

### 3. Podfile

Add a dedicated target so Firebase Messaging is available in the extension if needed:

```ruby
target 'NotificationServiceExtension' do
  use_frameworks!
  pod 'Firebase/Messaging'
end
```

Then run:

```bash
cd ios && pod install && cd ..
```

### 4. Signing

- Enable **Push Notifications** for the NSE target (Signing & Capabilities).
- Use the same team as Runner; bundle ID must be registered in Apple Developer portal.

### 5. APNS payload

The server must send `mutable-content: 1` and custom keys your NSE reads (example delivery template):

| Key | Purpose |
|-----|---------|
| `template_id` | `delivery`, `score`, or omit for pass-through |
| `driver_name`, `vehicle_info`, `estimated_time`, `progress` | Delivery / Live Activity |
| `driver_image_url`, `vehicle_image_url` | Downloaded in NSE |

---

## Step-by-step: Notification Content Extension

### 1. Create the target

1. **File → New → Target → Notification Content Extension**.
2. Bundle ID: `{your.app.bundle}.NotificationContentExtension`.
3. Deployment target: match Runner (15.0+).

### 2. Configure category

In `Info.plist`, set `UNNotificationExtensionCategory` to the category your NSE assigns (example: `DELIVERY_CATEGORY`).

Reference: [`example/ios/NotificationContentExtension/Info.plist`](example/ios/NotificationContentExtension/Info.plist)

### 3. UI

Implement `UNNotificationContentExtension` in `NotificationViewController.swift` (storyboard or programmatic UI). Read attachments and `userInfo` set by the NSE.

---

## Step-by-step: Live Activity widget extension

### 1. Raise deployment target

Live Activities require **iOS 16.1+**. When enabling them:

```ruby
# ios/Podfile
platform :ios, '16.0'   # 16.1+ recommended for ActivityKit
```

Set `IPHONEOS_DEPLOYMENT_TARGET` to **16.1** (or 16.2+) for Runner and extension targets in Xcode.

### 2. Runner Info.plist

Add to `ios/Runner/Info.plist`:

```xml
<key>NSSupportsLiveActivities</key>
<true/>
<key>NSSupportsLiveActivitiesFrequentUpdates</key>
<true/>
```

Optional: `UIBackgroundModes` → `remote-notification` (already in the example) for background push handling.

### 3. Create Widget Extension with Live Activity

1. **File → New → Target → Widget Extension**.
2. Enable **Include Live Activity**.
3. Bundle ID: `{your.app.bundle}.LiveActivityExtension`.
4. Implement `ActivityConfiguration` in `LiveActivityExtensionLiveActivity.swift` (see example).

### 4. Share ActivityAttributes

1. Add [`DeliveryAttributes.swift`](example/ios/Shared/DeliveryAttributes.swift) (or your own model) to:
   - Notification Service Extension target
   - Live Activity widget target
   - (Optional) Runner target if the app starts activities in foreground
2. In `NotificationService.swift`, call `Activity.request(attributes:contentState:pushType:)` when processing delivery pushes (iOS 16.1+).
3. Use the **same** attribute type in the widget’s `ActivityConfiguration(for:)`.

### 5. Podfile (widget target)

```ruby
target 'LiveActivityExtensionExtension' do
  use_frameworks!
end
```

Target name may vary (`LiveActivityExtension` vs `LiveActivityExtensionExtension`) — match your Xcode project.

---

## Entitlements summary

| Target | Push-only | + NSE / Content ext | + Live Activity |
|--------|-----------|---------------------|-----------------|
| **Runner** | `aps-environment` | Same | + `NSSupportsLiveActivities` in Info.plist |
| **NSE** | — | Push Notifications (recommended) | Same + ActivityKit usage in code |
| **Content extension** | — | App Groups **not** required | — |
| **Widget extension** | — | — | App Groups **optional** (only if sharing files with Runner) |

The example app uses only `aps-environment` on Runner ([`Runner.entitlements`](example/ios/Runner/Runner.entitlements)). **App Groups are not required** for basic push or Live Activities started from the NSE.

Use `production` for `aps-environment` in TestFlight and App Store builds.

---

## Example app layout

```
example/ios/
  Runner/                    ← Minimum push setup (AppDelegate, entitlements)
  NotificationServiceExtension/
  NotificationContentExtension/
  LiveActivityExtension/
  Shared/DeliveryAttributes.swift   ← Share across NSE + widget targets
```

Compare your project to these folders when debugging signing or missing symbols.

---

## Testing checklist

| Test | Push-only | With NSE | With Live Activity |
|------|-----------|----------|-------------------|
| FCM token → SDK registration | ✓ | ✓ | ✓ |
| Foreground tray notification | ✓ | ✓ | ✓ |
| In-app popup/banner from poll | ✓ | ✓ | ✓ |
| Rich images on notification | — | ✓ (mutable-content) | ✓ |
| Custom long-look UI | — | ✓ (with content ext) | ✓ |
| Lock Screen / Dynamic Island | — | — | ✓ (device, iOS 16.1+) |

- Test push on a **physical iPhone** for Live Activities and reliable APNs.
- Confirm `ActivityAuthorizationInfo().areActivitiesEnabled` is true (Settings → Face ID & Passcode → Live Activities).
- NSE execution time is limited (~30s); keep downloads small.

---

## Troubleshooting

| Symptom | Likely cause |
|---------|----------------|
| NSE never runs | Missing `mutable-content: 1` on APNS payload |
| Live Activity does not appear | iOS &lt; 16.1, Live Activities disabled, or mismatched `ActivityAttributes` between NSE and widget |
| Content extension not shown | `categoryIdentifier` ≠ `UNNotificationExtensionCategory` in Info.plist |
| Pod install fails for extension | Missing `target 'NotificationServiceExtension'` block in Podfile |
| Duplicate symbol / wrong Activity UI | NSE and widget use different attribute types — align shared Swift file |

---

## Related documentation

- [README.md §1.5 — iOS platform config (push-only)](README.md#15-ios-platform-config)
- [README.md Part 2 — Dart integration](README.md#part-2--implementation)
- Apple: [ActivityKit](https://developer.apple.com/documentation/activitykit), [UNNotificationServiceExtension](https://developer.apple.com/documentation/usernotifications/unnotificationserviceextension)
