# Semantic versioning policy

`mehery_sender` follows [Semantic Versioning 2.0.0](https://semver.org/) so hosts can predict upgrade impact from the version number in `pubspec.yaml`.

Current package version: see [`pubspec.yaml`](pubspec.yaml) and [CHANGELOG.md](CHANGELOG.md).

---

## Version format

`MAJOR.MINOR.PATCH` (e.g. `0.1.8`)

| Bump | When we use it | Host impact |
|------|----------------|-------------|
| **MAJOR** | Breaking public API or integration contract | Requires code or config changes; read CHANGELOG migration notes |
| **MINOR** | New backward-compatible features, new optional APIs, raised minimums when documented | Safe to upgrade within the same major; review new APIs and compatibility matrix |
| **PATCH** | Bug fixes, docs, internal refactors, dependency patch bumps with no API change | Drop-in upgrade |

---

## Pre-1.0 (`0.x.y`)

While the package is **0.x**, we still document every release in [CHANGELOG.md](CHANGELOG.md).

- **0.1.x** — Integration-focused releases for production hosts. We avoid breaking changes in patch releases. Breaking changes ship only in a new **minor** (e.g. `0.1.0` → `0.2.0`) with a **Breaking** section in the changelog.
- **0.0.x** — Early history; breaking changes were not always semver-aligned. Treat `0.1.0+` as the baseline for upgrade planning.

**1.0.0** will mark the first semver-stable API: breaking changes only in major releases.

---

## What counts as public API

Treat these as semver-governed:

| Surface | Examples |
|---------|----------|
| **Dart exports** | `Pushapp`, `MeSendPushNotificationDisplay`, `parsePushappIdentifier`, `MeSendDeviceRegistrationState` |
| **Method / property signatures** | `initializeAndSendToken`, `login`, `registrationState`, `navigatorObservers` |
| **Constants & channels** | `meherySenderMethodChannel`, `meherySenderEventChannel`, `sessionIdPrefsKey` |
| **Platform contracts** | Android plugin package `com.mehery.sender`, documented method-channel method names |
| **Environment constraints** | Minimum Flutter/Dart in `pubspec.yaml` `environment` |
| **Documented host setup** | Required `pubspec` deps, Firebase versions in README compatibility matrix |

**Not** governed by semver (may change in any release):

- Private members (`_` prefix, unexported `part` files)
- Example app code under `example/`
- Debug log prefixes (`[MeSend Push]`, `[MeSend API]`)
- Undocumented internal behavior

---

## Breaking vs non-breaking changes

### Breaking (major, or 0.x minor with changelog)

- Removing or renaming public classes, methods, getters, or exports
- Changing required parameters or return types
- Renaming the primary SDK type (`MeSend` → `Pushapp` in **0.1.0**)
- Changing identifier parsing rules for existing dashboard ids
- Raising minimum Flutter/Dart/Firebase beyond what `^` constraints allow without host action
- Changing native method-channel names or required host wiring

### Non-breaking (minor or patch)

- Adding new optional parameters or new public methods
- Adding streams, getters, or types (e.g. `registrationState` in 0.1.8)
- Deprecating APIs while keeping them functional
- Bug fixes that restore documented behavior
- New docs, CI, or example updates
- Internal module splits (`part`/`library` refactors) with the same public exports

---

## Naming and deprecations

### `Pushapp` vs `MeSend`

| Name | Status |
|------|--------|
| **`Pushapp`** | Canonical public SDK class |
| **`MeSend`** | Deprecated `typedef` alias for `Pushapp`; kept for legacy code |
| **`MeSendWidget`**, **`MeSendRouteObserver`**, etc. | Stable widget/helper names; not the same as the old `MeSend` class rename |

We will **not** remove deprecated aliases without a **major** (or documented 0.x minor) release and a **Breaking** changelog entry.

New integrations should use **`Pushapp`** only.

### Deprecation process

1. Mark API `@Deprecated` in Dart docs with the replacement.
2. Document in [CHANGELOG.md](CHANGELOG.md) under the release that introduced the deprecation.
3. Keep deprecated API working for at least one **minor** release when possible.
4. Remove only in a **major** (or explicit breaking 0.x minor) with migration steps.

---

## Upgrading

1. Read [CHANGELOG.md](CHANGELOG.md) for your target version.
2. Check the **Compatibility matrix** in README / CHANGELOG for Flutter, Dart, and Firebase.
3. Prefer caret constraints aligned with the matrix, e.g. `mehery_sender: ^0.1.8`.
4. Run `flutter pub get`, `flutter analyze`, and your integration tests.

### Example impact by constraint

| Your constraint | Resolves to | Expected impact |
|-----------------|-------------|-----------------|
| `^0.1.8` | `>=0.1.8 <0.2.0` | Patches only (`0.1.9`, …) — lowest risk |
| `^0.1.0` | `>=0.1.0 <0.2.0` | May include new 0.1.x features; check changelog for each bump |
| `0.1.8` | Exact pin | No automatic updates; you choose when to read changelog |

---

## Release checklist (maintainers)

Each release must:

- [ ] Bump `version` in `pubspec.yaml`
- [ ] Add a dated section to [CHANGELOG.md](CHANGELOG.md) with **Breaking**, **Added**, **Fixed** as needed
- [ ] Update README compatibility matrix when Flutter/Firebase mins change
- [ ] Tag the git release to match the pub version

---

## Historical note (0.1.0)

Release **0.1.0** documented these breaking changes (should have been the first semver-aligned integration baseline):

- `MeSend` → `Pushapp` (alias `typedef MeSend = Pushapp` retained)
- Full app id for `identifier` (legacy `tenant$channel` still supported)
- `postSessionGeo` requires `PushSessionGeoData`; random geo helper removed

See [CHANGELOG.md § 0.1.0](CHANGELOG.md#010) for details.
