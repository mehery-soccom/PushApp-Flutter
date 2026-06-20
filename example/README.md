# mehery_sender example

Reference Flutter app for integrating the [mehery_sender](../README.md) (PushApp) SDK.

## What it demonstrates

- Firebase init + background handler (`configureMeSendFirebaseBackgroundInit`)
- FCM/APNs token registration via `Pushapp.initializeAndSendToken`
- `navigatorObservers` + `navigatorKey` for in-app overlays and page tracking
- Login flow (`pushApp.login`) and dashboard with `initPage` / `MeSendWidget`

## Run locally

1. Complete [Part 1 — Setup](../README.md#part-1--setup) in the main README (Firebase config files, Gradle, iOS caps).
2. Replace the demo identifier in `lib/push_service.dart` with your Mehery dashboard app id.
3. From this directory:

```bash
flutter pub get
flutter run
```

## Firebase config in this repo

The example includes **test** Firebase project files (`google-services.json`, `GoogleService-Info.plist`, `firebase_options.dart`) for CI and local builds. Use your own FlutterFire output for production apps — see README §1.2.

## Optional iOS extensions

The `ios/` project includes optional NSE, content extension, and Live Activity targets. Push-only integration needs **Runner** only — see [IOSREADME.md](../IOSREADME.md).

---

## Device QA checklist (Rocket handoff)

Run on **physical devices** (simulators/emulators are insufficient for push token and tray behavior). Enable SDK logs first — set `meherySenderApiLoggingEnabled = true` in `lib/main.dart` **before** SDK init, then filter console/logcat for **`[MeherySender]`**.

### Prerequisites

- [ ] Mehery dashboard app id configured in `lib/push_service.dart`
- [ ] Firebase config files present and match the registered bundle/application id
- [ ] Notification permission granted when prompted
- [ ] Debug logging enabled for the QA session

### Android (physical device)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Cold start app | `[MeherySender]` init logs; no crash |
| 2 | Observe registration | `[MeherySender][API] device_register` success; `registrationState` → `registered` |
| 3 | Sign in (example login) | `[MeherySender][API]` login/delink as applicable; no throw |
| 4 | Navigate to dashboard | `[MeherySender]` page_open / poll logs if configured |
| 5 | Send **foreground** push from Mehery | Tray notification shown; `[MeherySender][Push|foreground]` in logcat |
| 6 | Send **background** push (app backgrounded) | Notification in tray; `[MeherySender][Push|background]` if data handled |
| 7 | Tap notification | App opens; opened-from-background log if applicable |
| 8 | Trigger in-app campaign (banner/popup) | Overlay or inline slot renders; no stale-context crash |
| 9 | Kill and relaunch | `registrationState` restores from cache (`restoredFromCache == true`) |

**AP-2 verify:** Confirm only one FCM path — no duplicate notifications from a second `MESSAGING_EVENT` handler. Logcat should show Dart `onMessage` handling, not a parallel native-only duplicate.

### iOS (physical device)

| Step | Action | Expected |
|------|--------|----------|
| 1 | Cold start app | APNs registration; `[MeherySender]` init logs |
| 2 | Observe registration | Device register API success; `registrationState` → `registered` |
| 3 | Sign in | Login API succeeds |
| 4 | Navigate to dashboard | Page tracking / in-app poll as configured |
| 5 | Send **foreground** push | System banner or SDK tray per payload type |
| 6 | Send **background** push | Notification appears on lock screen / notification center |
| 7 | Tap notification | App foregrounds correctly |
| 8 | In-app message on dashboard | Overlay or `MeSendWidget` content displays |
| 9 | Kill and relaunch | Registration restored from cache |

### Regression smoke (both platforms)

- [ ] `initializeAndSendToken` returns `true` when tokens present (AP-1)
- [ ] Missing token at startup returns `false` without crash; retries on `onTokenRefresh`
- [ ] Logout then login as different user — account switch without manual delink
- [ ] No raw host `print()` confusion — all SDK lines prefixed `[MeherySender]`

### Sign-off

| Field | Value |
|-------|-------|
| SDK version | 0.1.10 |
| Flutter version | |
| Android device / OS | |
| iOS device / OS | |
| Tester | |
| Date | |
| Pass / Fail | |

Document failures with `[MeherySender]` log excerpts and steps to reproduce.
