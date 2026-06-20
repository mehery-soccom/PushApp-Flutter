# Android integration (mehery_sender plugin)

Android support is delivered as a **Flutter plugin** — no manual Kotlin copy into the host app.

---

## What the plugin provides

| Component | Purpose |
|-----------|---------|
| `MeherySenderPlugin` | Auto-registered; wires method + event channels |
| `mehery_channel` | Native → Dart: `ping`, `trackNotification` |
| `mesend_event_channel` | CTA / open events → Dart `track()` |
| `CTATrackingActivity` | Notification action handling (merged manifest) |
| `CustomNotificationService` | Helper for styled tray layouts (invoked from native code paths) |
| `LiveActivityMessagingService` | **Not** registered for FCM by default (see below) |

Cross-link: main setup in [README.md §1.4](README.md#14-android-platform-config).

---

## FCM delivery (Rocket / push-only default)

**Default (recommended):** Only **`FlutterFirebaseMessagingService`** (`firebase_messaging`) handles `com.google.firebase.MESSAGING_EVENT`.

- Foreground → `MeSendPushNotificationDisplay` (Dart)
- Background → `meSendFirebaseMessagingBackgroundHandler` (Dart)
- Configure in host `main()` per README Part 2

The plugin manifest **does not** register `LiveActivityMessagingService` for `MESSAGING_EVENT`. A second handler causes **non-deterministic** message delivery.

### Native rich-notification templates (opt-in)

If you need **native** styled notifications (live-activity-style payloads with `message1`/`message2`/`message3`) without Dart handling first, you may **opt in** by adding to your host `AndroidManifest.xml`:

```xml
<service
    android:name="com.mehery.sender.LiveActivityMessagingService"
    android:exported="false">
    <intent-filter>
        <action android:name="com.google.firebase.MESSAGING_EVENT" />
    </intent-filter>
</service>
```

**Warning:** Only use this when Dart FCM handlers are disabled or you accept chained/custom routing. Test on a **physical device**.

For most integrators (including Rocket push-only), **do not** add this service.

---

## Host setup checklist

1. `google-services.json` in `android/app/`
2. Google Services + desugaring in Gradle (README §1.4)
3. `POST_NOTIFICATIONS` permission (Android 13+)
4. `mehery_sender` in `pubspec.yaml` — plugin merges manifest automatically
5. Dart: `configureMeSendFirebaseBackgroundInit`, `initializeAndSendToken`, FCM listeners via SDK

**Do not** copy Kotlin from `lib/android/` (removed) or duplicate `LiveActivityMessagingService` unless opting in above.

---

## Channel names (current)

| Channel | Name |
|---------|------|
| MethodChannel | `mehery_channel` |
| EventChannel | `mesend_event_channel` |

Legacy names (`com.mehery.admin/live_activity`, `pushapp/methods`) are **not** used by the current plugin.

---

## Troubleshooting

| Symptom | Check |
|---------|--------|
| Duplicate notifications | Two `MESSAGING_EVENT` services in merged manifest |
| CTA not reaching Dart | `mesend_event_channel` registered; plugin applied |
| No foreground tray | `MeSendPushNotificationDisplay.ensureInitialized()` after Firebase init |
| Native ping not firing | Engine must be running; data message with app in background |

---

© Mehery — Android plugin documentation
