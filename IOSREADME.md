# 📱 iOS Live Activity Integration Guide (Flutter + ActivityKit)

This guide explains how to integrate **Live Activities** and **Dynamic Island** widgets in your iOS Flutter app using **ActivityKit** and a **Flutter MethodChannel**.

---

## 🧩 Prerequisites

Before proceeding, make sure you have:

- Xcode 15 or later (macOS Sonoma or later recommended)
- iOS 16.1+ deployment target (Live Activities require iOS 16.1 or higher)
- Flutter iOS module configured
- App Group created in your Apple Developer account

---

## ⚙️ Step 1: Enable Capabilities in Xcode

1. Open your iOS Runner project in Xcode.
2. Select your project in the Project Navigator → Target **Runner** → **Signing & Capabilities**.
3. Click **+ Capability** → add **Background Modes**, **Push Notifications**, and **App Groups**.
4. Under **App Groups**, add your group ID — e.g.:
   ```
   group.com.mehery.admin.meheryAdmin
   ```

---

## 🧱 Step 2: Create Live Activity Widget Extension

1. In Xcode, go to **File → New → Target → Widget Extension**.
2. Name it `DeliveryActivity`.
3. When prompted, enable **Include Live Activity**.
4. This will create a folder named **DeliveryActivity** containing `DeliveryActivityLiveActivity.swift`.

---

## 🧠 Step 3: Add App Group ID to Both Targets

1. Open both targets (**Runner** and **DeliveryActivity**) in **Signing & Capabilities**.
2. Under **App Groups**, ensure both share the **same group ID**.

---

## 🧰 Step 4: Add Live Activity Widget Code

Replace the generated file `DeliveryActivityLiveActivity.swift` with the provided Swift code implementing:

- `DeliveryActivityAttributes` (with `ContentState`)
- `ActivityConfiguration` for Lock Screen and Dynamic Island
- `loadImageFromAppGroup()` for image sharing
- `TextStyleModifier` for styling text dynamically

This file handles dynamic updates to Live Activities.

---

## 🧩 Step 5: Update AppDelegate.swift

In your Flutter iOS Runner target, replace your `AppDelegate.swift` with the provided code:

- Initializes a **FlutterMethodChannel** named:
  ```swift
  com.mehery.admin/live_activity
  ```
- Handles **remote notifications** and **Live Activity creation** (`startLiveActivity(userInfo:)`)
- Saves image assets in the **App Group container**
- Maps push notification categories to handle CTA actions (e.g., Accept / Reject)

---

## 🧾 Step 6: Configure Notification Categories

In `AppDelegate.swift`, `registerNotificationCategories()` creates multiple categories such as:

- CONFIRMATION_CATEGORY (Yes/No)
- RESPONSE_CATEGORY (Accept/Reject)
- TRANSACTION_CATEGORY (Buy/Sell)
- etc.

This allows interactive push notifications to trigger actions via button taps.

---

## 🚀 Step 7: Update `Info.plist`

In both **Runner** and **DeliveryActivity**, add the following permissions:

```xml
<key>NSUserTrackingUsageDescription</key>
<string>This identifier will be used to track push notifications.</string>
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.apple.backgroundfetch</string>
</array>
```

---

## 🧪 Step 8: Test Live Activity

1. Run your Flutter app on a **real device** (not simulator).
2. Send a **silent push notification** with `imageUrl` and message parameters.
3. The app will trigger:
   ```swift
   startLiveActivity(userInfo: userInfo)
   ```
4. Check the **Lock Screen** or **Dynamic Island** for the activity update.

---

## 🧹 Step 9: Debug Tips

- Use `print()` statements in both Swift files for debugging.
- Check App Group file access:
  ```swift
  FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.mehery.admin.meheryAdmin")
  ```
- Make sure images are written successfully before updating Live Activity.

---

## 🧩 Step 10: Verify Integration

| Test Item | Expected Result |
|------------|----------------|
| App Group Sharing | Image loads successfully in widget |
| Push Notification | Live Activity triggers automatically |
| CTA Buttons | Invoke Flutter method correctly |
| Dynamic Island | Displays progress + text updates |

---

## ✅ Final Notes

- Live Activities **expire automatically** after a few hours.
- iOS restricts the number of simultaneous Live Activities per app.
- Always test on **physical iPhone** with **iOS 16.1+**.

---

© 2025 Mehery Admin — iOS Integration Documentation
