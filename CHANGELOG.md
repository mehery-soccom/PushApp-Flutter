# Changelog

All notable changes to **`mehery_sender`** are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and [Semantic Versioning](https://semver.org/). See [VERSIONING.md](VERSIONING.md) for bump rules and upgrade constraints.

---

## [Unreleased]

---

## [0.1.14] - 2026-06-20

Documentation URL update — no API or behavior changes.

### Changed

- **`documentation` URL** — `pubspec.yaml`, README, and `docs/` now point to the hosted guide at [docs.mehery.com/guide/pushapp/flutter-sdk/](https://docs.mehery.com/guide/pushapp/flutter-sdk/).

### Migration from 0.1.13 → 0.1.14

Bump `mehery_sender: ^0.1.14` only. No code changes.

---

## [0.1.13] - 2026-06-19

Pub.dev metadata release — no API or behavior changes.

### Changed

- **Repository URLs** — `homepage`, `repository`, `issue_tracker`, and `documentation` in `pubspec.yaml` now point to [PushApp-Flutter](https://github.com/mehery-soccom/PushApp-Flutter).

### Migration from 0.1.12 → 0.1.13

Bump `mehery_sender: ^0.1.13` only. No code changes.

---

## [0.1.12] - 2026-06-19

Fixes inline in-app slots waiting for tooltips or overlay dismissals.

### Fixed

- **Inline + tooltip:** Poll results split by template type — inline dispatches immediately to placeholder listeners; tooltips and overlays no longer block inline rendering.
- **Queue lock:** Inline items no longer enter the overlay queue; legacy inline entries in the queue are drained without blocking; inline path releases `_isProcessingQueue` when needed.

### Added

- **`meSendIsInlineInAppTemplateCode` / `meSendIsTooltipInAppTemplateCode`** — template routing helpers in `mesend_parsing.dart`.

### Migration from 0.1.11 → 0.1.12

No host code changes — bump `mehery_sender: ^0.1.12` only.

---

## [0.1.11] - 2026-06-19

Fixes background FCM handling reported by integration teams: Firebase init across isolates and tray display for data-only pushes.

### Added

- **`meSendHandleBackgroundRemoteMessage`** — primary API for FCM background isolates; pass `DefaultFirebaseOptions.currentPlatform` from a host top-level handler.
- **`meSendConfiguredFirebaseBackgroundOptions`** — documents options stored in the current isolate only.
- **README §2.3 troubleshooting** — isolate static issue, `requestNotificationsPermission` NPE, data-only tray table.
- **Example** — `example/lib/firebase_background_handler.dart` with recommended registration pattern.

### Fixed

- **Background Firebase init:** `configureMeSendFirebaseBackgroundInit` in [main] no longer implied background isolate configuration; options must be passed into `meSendHandleBackgroundRemoteMessage`.
- **Background tray (Android):** `ensureTrayDisplayReady(background: true)` skips `requestNotificationsPermission` (no Activity in background isolate — fixes NPE and allows data-only tray notifications).
- **Data-only FCM:** Tray display uses parsed `data` title/body when no `notification` block is present (existing parser; background path no longer crashes before `show`).

### Changed

- **`meSendFirebaseMessagingBackgroundHandler`** — deprecated for direct registration; use host wrapper + `meSendHandleBackgroundRemoteMessage`.
- Example `main.dart` registers `firebaseMessagingBackgroundHandler` instead of SDK handler directly.

### Migration from 0.1.10 → 0.1.11

1. Add `lib/firebase_background_handler.dart` (see README §2.3 or example).
2. Replace `FirebaseMessaging.onBackgroundMessage(meSendFirebaseMessagingBackgroundHandler)` with your top-level handler.
3. No other host changes required if you already used the wrapper pattern from 0.1.10.

---

## [0.1.10] - 2026-06-19

Integration-hardening release (Rocket AP-1–AP-4): non-throwing init, single Android FCM path, safe template parsing, context guards, and unified SDK logging.

### Added

- **`meherySenderLog` / `meherySenderLogPrefix`** — all SDK diagnostics use the `[MeherySender]` prefix (with optional subsystem tags such as `[API]`, `[Push]`, `[InApp]`) so host teams can filter logcat / Xcode console separately from app logs.
- **Device QA checklist** in [example/README.md](example/README.md) for physical Android + iOS verification.

### Changed

- **AP-1:** `initializeAndSendToken` returns `Future<bool>`; emits `registrationState.failed` instead of throwing (unless `meherySenderStrictRegistrationMode`).
- **AP-2:** Removed plugin `LiveActivityMessagingService` from default `MESSAGING_EVENT` — single FCM path via `firebase_messaging` (opt-in native service documented in [AndroidREADME.md](AndroidREADME.md)).
- **AP-3:** Safe parsing for in-app template fields (`draggable`, `html`, alignments).
- **AP-4:** In-app overlays use `_resolveInAppContext()` (navigator key + mounted check).
- **Logging:** Replaced raw `print()` in `lib/` with gated `sdkPrint` / `meherySenderLog`; HTTP and push subsystems use tagged `[MeherySender][…]` output.

### Fixed

- Analyzer warnings in `lib/` and `test/` (dead null-aware code, unused fields).

### Migration from 0.1.8 → 0.1.10

1. **pubspec** — bump `mehery_sender: ^0.1.10`.
2. **AP-1 — init return type:** `initializeAndSendToken` is now `Future<bool>`. Check the return value or listen to `registrationState` instead of relying on try/catch for missing tokens. Throws only when `meherySenderStrictRegistrationMode` is `true`.
3. **AP-2 — Android FCM:** No host change required if you already use `firebase_messaging` + `MeSendPushNotificationDisplay.ensureInitialized()`. Do **not** add a second `MESSAGING_EVENT` handler unless you opt into native rich templates ([AndroidREADME.md](AndroidREADME.md)).
4. **Debug logging:** Set `meherySenderApiLoggingEnabled = true` **before** creating `Pushapp` to trace registration, API, push, and in-app flows in release/profile builds. Filter logs with `[MeherySender]`.

### Compatibility matrix (0.1.10)

| Component | Minimum | Tested |
|-----------|---------|--------|
| Flutter | 3.38.1 | 3.44.1 |
| Dart | 3.10.0 | 3.12.1 |
| Android (API) | 21 | minSdk 21, compileSdk 34 |
| iOS | 15.0 | 15.0+ |
| `firebase_core` | 4.10.0 | 4.10.0 – 4.11.0 |
| `firebase_messaging` | 16.3.0 | 16.3.0 – 16.4.0 |
| `flutter_local_notifications` | 22.0.0 (transitive) | 22.0.0 |
| `mehery_sender` | — | 0.1.10 |

---

## [0.1.8] - 2026-06-19

Integration-hardening release: proper Flutter plugin, documented host setup, CI, privacy/security guides, and production-safe defaults.

### Added

- **Flutter plugin** — Android native code auto-registered via `pubspec.yaml` `plugin:` (`com.mehery.sender`); no manual copy of Kotlin into host apps.
- **`Pushapp.navigatorObservers`** — wire on `MaterialApp` for automatic `page_open` / `page_closed` events.
- **`MeSendDeviceRegistrationState`** and **`Pushapp.registrationState`** — lifecycle stream (`pending`, `registered`, `failed`, `tokenRefreshed`) plus **`registrationSnapshot`**.
- **`meSendParseTrackNotificationArgs()`** — safe parsing for native `trackNotification` method-channel payloads.
- **`configureMeSendFirebaseBackgroundInit()`** — FlutterFire options for background FCM handler.
- **CTA URL controls** — `meherySenderCtaUrlAllowedHosts`, `meherySenderCtaUrlValidator`, `meSendIsCtaUrlAllowed()`.
- **Account switch** — `login(newUserId)` delinks previous user automatically (no manual `logout()` required).
- **Automated tests** — identifier/payload parsing, registration gating, push classification, route observer, method channel, registration state, CTA allowlist (57 tests).
- **GitHub Actions CI** — `flutter analyze`, `flutter test`, example Android APK + iOS simulator build ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)).
- **Documentation**
  - [README.md](README.md) — compatibility matrix, setup checklist, registration state, CI
  - [IOSREADME.md](IOSREADME.md) — optional NSE / Live Activity / push-only paths
  - [VERSIONING.md](VERSIONING.md) — semver & deprecation policy
  - [PRIVACY.md](PRIVACY.md) — data collection & GDPR/CCPA host checklist
  - [WEBVIEW_SECURITY.md](WEBVIEW_SECURITY.md) — unrestricted JS & CTA allowlist
  - [PUBLISHING.md](PUBLISHING.md) — pub.dev publish checklist & false_secrets audit

### Changed

- **Monolith split** — `lib/mehery_sender.dart` is a barrel; implementation in `api/`, `push/`, `in_app/`, `websocket/`, `widgets/` (`part`/`part of`).
- **Firebase** — `firebase_core ^4.10.0`, `firebase_messaging ^16.3.0`; `flutter_local_notifications ^22.0.0` (transitive).
- **Minimum SDK** — Dart `>=3.10.0`, Flutter `>=3.38.1`.
- **API logging** — `meherySenderApiLoggingEnabled` defaults to `kDebugMode` (off in release).
- **Routine APIs** — `sendEvent`, `login`, `initPage`, etc. queue or no-op instead of throwing when device registration is pending (`meherySenderStrictRegistrationMode` opt-in for throws).
- **Route observer** — immediate page events (removed 5s delay).
- **Example app** — aligned with README; `dependency_overrides` removed.
- **Android bridge** — unified `mehery_channel` (`ping`, `trackNotification`); EventChannel `mesend_event_channel` registered in plugin.
- **Deprecated** — `typedef MeSend = Pushapp` marked `@Deprecated`; use **`Pushapp`**.

### Fixed

- **Analyzer / build** — `super_tooltip` API compatibility; PiP missing asset replaced with bundled icon.
- **Payload parsing** — defensive parsing for in-app template fields (no cast crashes on malformed JSON).
- **Background FCM** — documented/init pattern for `Firebase.initializeApp` with host `firebase_options`.
- **Duplicate FCM listeners** — single attachment via `MeSendPushNotificationDisplay.ensureInitialized()`.
- **In-app overlays** — `navigatorKey` / mounted context guards; stale `BuildContext` crashes reduced.
- **Slack / debug webhooks** — removed hardcoded URLs and debug telemetry scaffolding.
- **Unused dependencies** — removed dead `pubspec` entries from earlier revisions.

### Compatibility matrix (0.1.8)

| Component | Minimum | Tested |
|-----------|---------|--------|
| Flutter | 3.38.1 | 3.44.1 |
| Dart | 3.10.0 | 3.12.1 |
| Android (API) | 21 | minSdk 21, compileSdk 34 |
| iOS | 15.0 | 15.0+ |
| `firebase_core` | 4.10.0 | 4.10.0 – 4.11.0 |
| `firebase_messaging` | 16.3.0 | 16.3.0 – 16.4.0 |
| `flutter_local_notifications` | 22.0.0 (transitive) | 22.0.0 |
| `mehery_sender` | — | 0.1.8 |

Hosts within this matrix do **not** need `dependency_overrides` for Firebase packages.

### Migration from 0.1.7

1. **pubspec** — bump `mehery_sender: ^0.1.8`, `firebase_core: ^4.10.0`, `firebase_messaging: ^16.3.0`; remove Firebase `dependency_overrides` if present.
2. **Android** — remove any manually copied `lib/android/` Kotlin; rely on plugin merge. Rebuild after `flutter pub get`.
3. **iOS** — `cd ios && pod install` (example lockfile uses Firebase 12.15.x).
4. **MaterialApp** — add `navigatorObservers: pushApp.navigatorObservers` for automatic page tracking.
5. **Background handler** — call `configureMeSendFirebaseBackgroundInit(options: DefaultFirebaseOptions.currentPlatform)` before `FirebaseMessaging.onBackgroundMessage(...)`.
6. **Foreground push** — use `MeSendPushNotificationDisplay.ensureInitialized()` after `Firebase.initializeApp`; do not attach FCM listeners twice in host code.
7. **Optional** — subscribe to `pushApp.registrationState`; set `meherySenderCtaUrlAllowedHosts` for production in-app HTML ([WEBVIEW_SECURITY.md](WEBVIEW_SECURITY.md)).

---

## [0.1.7]

### Changed

- Load device registration state before sending events (avoids race on cold start).
- README updates and documentation improvements.

### Migration from 0.1.6

- No breaking API changes. Upgrade `mehery_sender` version in `pubspec.yaml` and run `flutter pub get`.

---

## [0.1.0]

First semver-aligned integration baseline for production hosts.

### Added

- **`firebase_core`** as a direct dependency (required for FlutterFire imports and pub.dev validation).
- PushApp-style README and **`PushSessionGeoData`** for session geo API.

### Breaking

- **Class rename:** public SDK entry type **`MeSend` → `Pushapp`**. A compatibility alias `typedef MeSend = Pushapp` was added (now deprecated as of 0.1.8).
- **Identifier format:** `Pushapp(identifier: …)` expects the **full app id** from the Mehery dashboard (e.g. `demo_1751694691225`). Tenant = substring before the first `_`; channel id = full string. Legacy `tenant$channel` still parsed.
- **Session geo:** **`postSessionGeo`** requires app-supplied **`PushSessionGeoData`** (no random geo). **`postSessionGeoWithRandomSample`** removed.

### Migration from 0.0.x

1. Replace `MeSend(...)` with **`Pushapp(...)`** (or keep `MeSend` alias temporarily).
2. Update **`identifier`** to the dashboard full app id (or keep legacy `tenant$channel` if already used).
3. Replace random/sample geo calls with explicit **`PushSessionGeoData`** and **`postSessionGeo(geo)`**.
4. Add **`firebase_core`** to host `pubspec.yaml` if not already present.

---

## [0.0.12]

- README added.

## [0.0.11]

- Fixed null assertion warnings; minor improvements.

## [0.0.10]

- Fixed null assertion warnings; minor improvements.

## [0.0.9]

- Fixed null assertion warnings; minor improvements.

## [0.0.8]

- Fixed null assertion warnings; minor improvements.

## [0.0.3] - 2025-07-18

- Initial published features (push registration, in-app messages, events).

## [0.0.1] - 2025

- Initial package scaffold and Mehery PushApp SDK prototype.

---

[Unreleased]: https://github.com/mehery-soccom/PushApp-Flutter/compare/v0.1.14...HEAD
[0.1.14]: https://github.com/mehery-soccom/PushApp-Flutter/compare/v0.1.13...v0.1.14
[0.1.13]: https://github.com/mehery-soccom/PushApp-Flutter/compare/v0.1.12...v0.1.13
[0.1.12]: https://github.com/mehery-soccom/PushApp-Flutter/compare/v0.1.11...v0.1.12
[0.1.11]: https://github.com/mehery-soccom/PushApp-Flutter/compare/v0.1.10...v0.1.11
[0.1.10]: https://github.com/mehery-soccom/PushApp-Flutter/compare/v0.1.8...v0.1.10
[0.1.8]: https://github.com/mehery-soccom/PushApp-Flutter/compare/v0.1.0...v0.1.8
[0.1.0]: https://github.com/mehery-soccom/PushApp-Flutter/compare/v0.0.12...v0.1.0
