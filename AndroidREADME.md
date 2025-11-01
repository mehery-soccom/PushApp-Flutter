# 📱 PushApp-Flutter Android Integration

This Android module powers **custom notifications**, **CTA (button) tracking**, and **live activity updates** for the **PushApp-Flutter SDK**.  
It extends Firebase Cloud Messaging (FCM) to show **rich, styled notifications**, **progress updates**, and **track user interactions**.

---

## 🧩 Flutter ↔ Android Bridge

`MainActivity` defines a `MethodChannel`:

```kotlin
const channel = MethodChannel('com.mehery.admin/live_activity');
```

---

### Available Methods

| Method | Description |
|---------|-------------|
| `showLiveActivity(Map args)` | Display a live or custom notification. |
| `endLiveActivity(String activityId)` | Dismiss an active notification. |
| `testImageNotification(String id)` | Display a test notification with an image. |
| `testImageLoading(String url)` | Check image download capability. |

---

## 🚀 Setup

### 1️⃣ Update `AndroidManifest.xml`

Make sure to declare your services and activities:

```kotlin
<service
    android:name=".LiveActivityMessagingService"
    android:exported="false">
    <intent-filter>
        <action android:name="com.google.firebase.MESSAGING_EVENT" />
    </intent-filter>
</service>

<activity android:name=".CTATrackingActivity" />
```

---

### 2️⃣ Ensure Firebase Setup

Your app must be configured with Firebase and include a valid **`google-services.json`** file.

---

### 3️⃣ Notification Icon

Ensure `ic_launcher` (or another valid small icon) exists in all drawable density folders.

---

### 4️⃣ Android Version

Requires **Android 8.0 (API 26)** or above for Notification Channels.

---

## 🧠 Example Flutter Usage

```kotlin
import 'package:flutter/services.dart';

const channel = MethodChannel('com.mehery.admin/live_activity');

Future<void> showLiveActivity() async {
await channel.invokeMethod('showLiveActivity', {
'activity_id': 'order_123',
'title': 'Order Progress',
'message': 'Packing your order',
'tap_text': 'View Details',
'progress': 50.0,
'title_color': '#000000',
'message_color': '#444444',
'tap_text_color': '#888888',
'background_color': '#FFFFFF',
'imageUrl': 'https://example.com/image.png',
'bg_color_gradient': '#00BCD4',
'bg_color_gradient_dir': 'horizontal',
'align': 'left',
});
}
```

---

## 🧩 Android Folder Structure

```kotlin
android/
 └── app/
     └── src/main/kotlin/com/mehery/admin/mehery_admin/
         ├── MainActivity.kt
         ├── LiveActivityMessagingService.kt
         ├── CustomNotificationService.kt
         └── CTATrackingActivity.kt
```

---

## 🧾 Summary

This Android implementation provides:

🔹 Custom, rich notification layouts  
🔹 CTA button tracking  
🔹 Seamless Flutter integration via MethodChannel  
🔹 Live activity updates with progress tracking

Perfect for:

🛒 Order tracking • 🚚 Delivery updates • 🎟 Event countdowns • 📦 Progress notifications

---

📘 **Tip:**  
You can extend this by modifying `CustomNotificationService` to add new UI elements, or enhancing `LiveActivityMessagingService` to support more notification types.
