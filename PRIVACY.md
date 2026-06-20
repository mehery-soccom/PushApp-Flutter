# Privacy & data handling

This document describes what the **mehery_sender** Flutter SDK collects, stores locally, and transmits to the **PushApp / Mehery backend**. Use it to answer security questionnaires, DPIAs, and GDPR/CCPA vendor reviews.

**Scope:** SDK behavior only. Your app, Firebase/Google, Apple/Google push infrastructure, and the Mehery server have separate policies and retention rules.

---

## Roles

| Party | Responsibility |
|-------|----------------|
| **Host app (you)** | Privacy policy, lawful basis/consent, user identity (`login`), optional geo (`postSessionGeo`), Firebase configuration, responding to user rights requests |
| **mehery_sender SDK** | Device registration, push token upload, event/analytics payloads, in-app message handling, optional session geo relay |
| **Mehery / PushApp backend** | Storage, processing, and retention of data received via API (contract/DPA with you) |
| **Firebase / APNs** | Push delivery; tokens managed per [Google](https://firebase.google.com/support/privacy) / [Apple](https://www.apple.com/legal/privacy/) policies |

The SDK is **not** a consent management platform. You must disclose SDK-driven collection in your app privacy notice and honor regional requirements before calling SDK APIs that send personal or device data.

---

## Summary table (auditor quick reference)

| Data category | Collected by SDK? | Sent to Mehery API? | Stored on device? | Notes |
|---------------|-------------------|---------------------|-------------------|--------|
| FCM / APNs push token | Host passes in; SDK uploads | Yes (`device/register`, `update/token`) | Yes (`device_token` pref) | Required for push |
| Pseudo device ID | Yes (`AppSetId` + timestamp) | Yes (body + `X-Device-ID` header) | Yes (`persistent_device_id`) | Not hardware serial; see below |
| App bundle / package name | Yes | Yes (`X-Bundle-ID`) | No | |
| App version / build | Yes | Yes (`X-App-Version`, `X-SDK-Version`) | No | |
| OS name, version, model, manufacturer | Yes | Yes (device headers) | No | |
| Screen resolution, orientation | Yes | Yes (headers) | No | |
| Locale, timezone name | Yes | Yes (`X-Locale`, `X-Timezone`) | No | |
| iOS device name (`UIDevice.name`) | Yes | Yes (`X-Device-Name`) | No | May contain user-assigned name |
| Android boot loader string | Yes | Yes (`X-Boot-Time`) | No | |
| User ID (host-supplied) | Host via `login()` | Yes (`device/link`, events, delink) | Yes (`user_id`) | Treat as personal data if identifiable |
| Guest / anonymous device user id | From register response | Yes (events fallback) | In memory | |
| Session ID | From API responses | Yes (`postSessionGeo`) | Yes (`session_id`) | |
| Geo / IP (precise location) | **No automatic GPS** | Only if host calls `postSessionGeo` | No | Host supplies `PushSessionGeoData` |
| Custom event properties | Host via `sendEvent` / navigation | Yes (`event_data`) | Queued in memory until registered | You control payload |
| In-app HTML / WebView content | From Mehery campaigns | Downloaded/displayed | Cache/temp as Flutter/WebView | May load third-party URLs |
| Notification interaction (CTA) | User taps | Yes (`push/track`, in-app track) | No | |

---

## Device identifier

The SDK builds a **persistent pseudo-ID**:

1. Reads **[App Set ID](https://pub.dev/packages/app_set_id)** (platform-scoped advertising/analytics identifier API).
2. Appends `_<timestamp>` on first generation.
3. Persists under SharedPreferences key `persistent_device_id`.

This ID is sent as:

- JSON field `device_id` on register/link/update/delink APIs
- HTTP header `X-Device-ID` on requests using `getDeviceHeaders()`
- WebSocket auth payload as `{userId}_{deviceId}`

It is **not** IMEI/serial. It is intended for device-scoped correlation across SDK sessions until app data is cleared or the app is uninstalled.

---

## HTTP device headers

Most API calls attach `getDeviceHeaders()` (merged into request headers):

| Header | Source |
|--------|--------|
| `X-App-Version` | `package_info` version |
| `X-SDK-Version` | `package_info` build number |
| `X-Screen-Resolution` | Physical screen size (px) |
| `X-Device-Orientation` | Portrait / Landscape |
| `X-Bundle-ID` | App package / bundle identifier |
| `X-Timezone` | `DateTime.timeZoneName` |
| `X-Locale` | `Platform.localeName` |
| `X-Device-Model` | `device_info_plus` |
| `X-OS-Name` | `ANDROID` or `IOS` |
| `X-OS-Version` | OS release string |
| `X-Manufacturer` | Android only |
| `X-API-Level` | Android SDK level |
| `X-Boot-Time` | Android `bootloader` field |
| `X-CPU-ABI` | Android ABIs |
| `X-System-Name` | iOS only |
| `X-Device-Name` | iOS `iosInfo.name` (user-visible device name) |
| `X-Device-ID` | Persistent pseudo device ID |

**Debug builds:** When `meherySenderApiLoggingEnabled` is true (default in debug), headers and bodies may appear in console logs — including tokens. Release builds default to no API body logging.

---

## Backend API payloads (what leaves the device)

Base URL: `https://{tenant}.pushapp.{tld}` (or your `serverUrlOverride`).

| Endpoint | When | Main payload fields |
|----------|------|---------------------|
| `POST /pushapp/api/device/register` | First token registration | `platform`, `token`, `device_id`, `channel_id`, optional `fcm_token` + device headers |
| `POST /pushapp/api/update/token` | Token refresh | `contact_id` (`{userId}_{deviceId}`), `token`, `channel_id`, optional `fcm_token` |
| `POST /pushapp/api/device/link` | `login(userId)` | `user_id`, `device_id`, `channel_id` + headers |
| `POST /pushapp/device/delink` | `logout()` / account switch | `user_id`, `device_id` |
| `POST /pushapp/api/v1/event` | `sendEvent`, route observer, `app_open`, etc. | `user_id`, `channel_id`, `event_name`, `event_data` + headers |
| `POST /pushapp/api/v1/notification/push/track` | Notification CTA / native bridge | `t` (token), `event`, optional `ctaId` |
| `POST /pushapp/api/v1/notification/in-app/track` | In-app interactions | message/filter/CTA ids, event name |
| `POST /pushapp/api/v1/notification/in-app/ack` | In-app ack | `contact_id`, `messageId` |
| `POST /pushapp/api/ping` | Background/data ping | contact + headers |
| `POST /pushapp/api/session/geo` | **Optional** — host calls `postSessionGeo` | `session_id`, `geoIP` (host-built object) |
| In-app poll / placeholder APIs | Campaign delivery | `contact_id`, template ids (see network tab / logs in debug) |

**WebSocket:** `wss://{tenant}.pushapp.{tld}/pushapp` — auth message `{ type: auth, userId: "{userId}_{deviceId}" }`.

---

## Location / geo data

The SDK **does not** read GPS, cell tower, or platform location APIs.

Location-related data is sent **only** when the host app calls:

```dart
await pushApp.postSessionGeo(PushSessionGeoData(
  ip: '…',
  lat: …,
  lng: …,
  countryIsoCode: '…',
  // …
));
```

You are responsible for:

- Obtaining consent where required (e.g. precise location, IP geolocation)
- Accuracy and lawful collection of `PushSessionGeoData` fields
- Not sending geo for users who have opted out

---

## Local storage (on-device)

| Key / area | Content | Cleared when |
|------------|---------|--------------|
| `persistent_device_id` | Pseudo device ID | App uninstall / clear app storage |
| `mesend_device_registration_complete` | Registration flag | Failed register; not cleared on logout alone |
| `device_token` | Last push token | Overwritten on refresh |
| `user_id` | Last logged-in user | Account switch / delink flow |
| `session_id` | Push session for geo API | Logout / delink / empty session |
| In-memory queues | Pending events, login before register | Processed after registration |

Uninstalling the app removes SharedPreferences unless your OS backup restores them (platform-dependent).

---

## Third-party SDKs (transitive)

Declared in [pubspec.yaml](pubspec.yaml); relevant to privacy reviews:

| Package | Purpose | Data touchpoints |
|---------|---------|------------------|
| `firebase_core`, `firebase_messaging` | Push | Instance IDs, tokens — [Firebase Privacy](https://firebase.google.com/support/privacy) |
| `app_set_id` | Device pseudo-ID seed | Platform app-set identifier |
| `device_info_plus` | Device headers | Model, OS, iOS device name |
| `package_info_plus` | App metadata | Version, package name |
| `shared_preferences` | Local persistence | Keys above |
| `webview_flutter` | In-app HTML | Loads remote HTML/URLs from campaigns; JS enabled per widget config |

Review your **`pubspec.lock`** for the full transitive tree before audits.

---

## Retention

| Layer | Retention |
|-------|-----------|
| **SDK on device** | Until app uninstall, storage clear, or explicit logout/switch clearing session/user prefs (see table above) |
| **Mehery backend** | Defined by your **Mehery contract / DPA**, not this SDK. Document server retention separately. |
| **Firebase / APNs** | Provider policies; token rotation handled via `onTokenRefresh` in host app |

The SDK provides **no server-side delete-user API**. For erasure requests (GDPR Art. 17 / CCPA delete), coordinate with Mehery backend operations and remove local app data (logout, uninstall).

---

## Host responsibilities (GDPR / CCPA checklist)

Use this in your compliance program:

1. **Transparency** — List PushApp/Mehery, push notifications, device/app diagnostics, and analytics events in your privacy policy.
2. **Legal basis / consent** — Push permission (OS), marketing consent where required, and optional geo/session features.
3. **User IDs** — Only pass `login(userId)` values you are permitted to share; avoid unnecessary PII in `userId` and `sendEvent` payloads.
4. **Geo** — Call `postSessionGeo` only with appropriate consent and documented purpose.
5. **Vendor management** — Execute DPA with Mehery; include Firebase/Google and Apple/Google as sub-processors for push.
6. **User rights** — Process access/delete/opt-out via your support process + Mehery backend; uninstall/logout for on-device data.
7. **Children** — Do not use the SDK in apps directed at children without appropriate compliance (COPPA etc.).
8. **International transfers** — Confirm Mehery server region and transfer mechanisms in your DPA.
9. **Debug logging** — Disable verbose logging in production (`meherySenderApiLoggingEnabled` defaults to `kDebugMode` only).
10. **In-app HTML** — Campaign HTML may embed trackers or external links; review Mehery content policies.

---

## Data minimization recommendations

- Use opaque user IDs in `login()` (e.g. internal UUID), not email/phone, unless required.
- Keep `sendEvent` `event_data` minimal and avoid sensitive categories (health, financial, etc.) unless legally justified.
- Avoid calling `postSessionGeo` unless product requires it.
- Pin production builds to release logging defaults.
- Document iOS `X-Device-Name` in your policy if auditors flag device names as personal data.

---

## Changes to this document

Material changes to SDK collection behavior are noted in [CHANGELOG.md](CHANGELOG.md) and may affect [VERSIONING.md](VERSIONING.md) semver.

For integration questions: see [README.md](README.md).  
For optional iOS extensions (NSE / Live Activity): [IOSREADME.md](IOSREADME.md).

---

## Document version

Applies to **mehery_sender 0.1.8+**. Re-verify headers and endpoints when upgrading; compare [CHANGELOG.md](CHANGELOG.md).
