# Publishing to pub.dev

Checklist before `flutter pub publish` for **mehery_sender**.

---

## Pre-flight

| Step | Command / action |
|------|------------------|
| Version bump | Set `version` in `pubspec.yaml`; add `[x.y.z]` section to [CHANGELOG.md](CHANGELOG.md) |
| Tests | `flutter test` (57+ passing) |
| Analyze | `flutter analyze lib/ test/` — **0 errors** required |
| Dry run | `flutter pub publish --dry-run` — **0 validation errors** |
| Git state | Commit or stash changes; publish from a clean tree when possible |
| Auth | `dart pub token add` or `flutter pub login` |

---

## pub.dev metadata (`pubspec.yaml`)

| Field | Requirement |
|-------|-------------|
| `description` | Clear, complete sentence(s) — shown on pub.dev |
| `homepage` | Valid HTTPS URL (repo root, **no** `.git` suffix) |
| `repository` | GitHub/GitLab URL |
| `issue_tracker` | Issues URL |
| `documentation` | README anchor or doc site |
| `topics` | Up to 5 relevant pub.dev topics |
| `LICENSE` | MIT — included in package |

---

## false_secrets audit

Example Firebase config contains **client-restricted** API keys (expected for FlutterFire). Declared in `pubspec.yaml`:

```yaml
false_secrets:
  - example/ios/Runner/GoogleService-Info.plist
  - example/android/app/google-services.json
  - example/lib/firebase_options.dart
```

Re-run dry-run after adding new Firebase files. Do **not** add production server secrets to the repo.

---

## Files excluded from publish (`.pubignore`)

- Legacy `lib/android/` (pre-plugin layout; still in git history in some clones)
- `build/`, `.dart_tool/`

---

## pub.dev scores (pana)

After publish, scores appear on the package page. Improve them by:

| Score area | How this package addresses it |
|------------|-------------------------------|
| **Pub Points** | MIT license, README, changelog, example app, no publish errors |
| **Platform support** | Flutter plugin (Android); iOS Dart-only (documented in README) |
| **Documentation** | README, IOSREADME, VERSIONING, PRIVACY, WEBVIEW_SECURITY |
| **Analysis** | Keep `flutter analyze lib/` at 0 errors; reduce warnings over time |

Optional local check (requires [pana](https://pub.dev/packages/pana)):

```bash
dart pub global activate pana
pana --no-warning --exit-code-threshold 0
```

---

## Version vs pub.dev

Before publishing, confirm your version is **greater than** the latest on [pub.dev/packages/mehery_sender](https://pub.dev/packages/mehery_sender). If dry-run reports *"Your version X is earlier than published Y"*, bump to `Y+1` or next semver patch.

---

## Publish command

```bash
flutter pub publish
```

Review the file list, confirm `false_secrets` entries, then approve upload.

---

## Post-publish

1. Tag release: `git tag v0.1.x && git push origin v0.1.x`
2. Update README compatibility matrix if Flutter/Firebase mins changed
3. Verify example app on pub.dev package page links correctly
