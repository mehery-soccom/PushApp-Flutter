## 0.0.1

* TODO: Describe initial release.


## [0.0.3] - 2025-07-18

- Initial release with basic features.

## 0.0.8
- Fixed null assertion warnings
- Minor improvements


## 0.0.9
- Fixed null assertion warnings
- Minor improvements

## 0.0.10
- Fixed null assertion warnings
- Minor improvements

## 0.0.11
- Fixed null assertion warnings
- Minor improvements

## 0.0.12
- README added

## 0.1.7

- Load device registration state before sending events.
- README updates and documentation improvements.

## 0.1.0

- Declare **`firebase_core`** as a direct dependency (required for imports and pub.dev validation).
- **Breaking:** Public SDK class renamed from `MeSend` to `Pushapp`.
- **Breaking:** `identifier` now uses the full app id (e.g. `demo_1751694691225`); tenant is the prefix before the first `_`, and the full string is the channel id. Legacy `tenant$channel` is still supported.
- **Breaking:** `postSessionGeo` now requires a `PushSessionGeoData` argument (app-supplied `geoIP`); random geo generation was removed. `postSessionGeoWithRandomSample` was removed.
- Documentation: PushApp-style README, session geo and `PushSessionGeoData` field reference.