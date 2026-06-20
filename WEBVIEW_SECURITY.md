# WebView & in-app HTML security

Mehery in-app campaigns can render **remote HTML** inside **WebView** widgets (popups, banners, PiP, roadblocks, placeholders, tooltips). This document explains the security model and host controls.

Related: [PRIVACY.md](PRIVACY.md) (data collection), [README.md §2.9–2.10](README.md) (integration).

---

## Summary

| Topic | SDK behavior |
|-------|----------------|
| **JavaScript** | **`JavaScriptMode.unrestricted`** on all campaign WebViews |
| **HTML source** | Loaded via `loadHtmlString()` from Mehery API payloads (your tenant) |
| **Network in WebView** | Subresources (images, video, scripts) may fetch from any URL embedded in HTML |
| **Link clicks / CTAs** | `http`/`https` navigations open in the **external browser** via `url_launcher` |
| **JS → Dart bridge** | `InAppChannel` receives JSON from injected `handleClick` / campaign scripts |
| **Default CTA policy** | All valid http(s) URLs allowed unless you configure an allowlist |
| **flutter_html tooltips** | Separate renderer (not WebView); still parses HTML from campaigns |

**Before enabling rich in-app HTML in production**, review Mehery campaign sources, configure a CTA allowlist if needed, and disclose WebView behavior in your privacy/security materials.

---

## Where WebViews are used

| Component | File | Purpose |
|-----------|------|---------|
| In-app overlays | `lib/in_app/in_app.dart` | Popup, banner, PiP, roadblock templates |
| Inline placeholder | `lib/widgets/mesend_widget.dart` | Fixed slot HTML |
| Tooltip preview | `lib/widgets/tooltip_wrapper.dart` | Tooltip HTML preview |

Each WebView is configured approximately as:

```dart
WebViewController()
  ..setJavaScriptMode(JavaScriptMode.unrestricted)
  ..addJavaScriptChannel('InAppChannel', …)
  ..setNavigationDelegate(NavigationDelegate(
    onNavigationRequest: (request) {
      if (request.url.startsWith('http')) {
        _handleCta(request.url); // external browser
        return NavigationDecision.prevent;
      }
      return NavigationDecision.navigate;
    },
  ))
  ..loadHtmlString(htmlFromCampaign);
```

On iOS, **inline media playback** may be enabled for video creatives (`allowsInlineMediaPlayback`).

---

## Security implications

### Unrestricted JavaScript

Campaign HTML runs with **full JavaScript** in the WebView process:

- Scripts from inline HTML or external `<script src="…">` can execute.
- Injected SDK bridge code adds `window.handleClick` and video autoplay helpers after `onPageFinished`.
- Malicious or compromised campaign content could attempt phishing, fingerprinting, or deeplink abuse **within the WebView sandbox**.

The SDK **does not** sandbox JS beyond the platform WebView defaults. Trust **Mehery dashboard content** and your tenant access controls.

### Remote content

`loadHtmlString` does not restrict subresource URLs. Images, fonts, videos, and scripts load from whatever URLs appear in the HTML.

### CTA / link handling

When a user taps a link or JS fires a CTA with an http(s) URL:

1. WebView navigation is **prevented** inside the app.
2. The SDK CTA handler parses the URL.
3. If allowed (see allowlist below), `launchUrl(..., LaunchMode.externalApplication)` opens the **system browser**.

Non-URL CTA strings are logged only (internal routing is host responsibility).

**Note:** `javascript:`, `file:`, and custom schemes are not opened via `_handleCta` today; http(s) links are the primary external-open path.

### JavaScript channel

Messages on `InAppChannel` are parsed as JSON and may trigger:

- In-app analytics (`trackInAppEvent`)
- CTA handling (`_handleCta`)

Treat campaign HTML as **trusted only to the extent you trust Mehery operators and your account security**.

---

## CTA URL allowlist (recommended for production)

By default, **any** http(s) CTA URL may open externally. To restrict destinations, set before showing in-app content:

### Host suffix list

```dart
import 'package:mehery_sender/mehery_sender.dart';

void main() {
  meherySenderCtaUrlAllowedHosts = [
    'example.com',
    'mehery.com',
  ];
  // Allows https://example.com, https://app.example.com, etc.
  // Blocks https://evil.example.org
  runApp(const MyApp());
}
```

Matching rules (case-insensitive):

- Host **equals** an entry, or
- Host **ends with** `.{entry}`

### Custom validator

```dart
meherySenderCtaUrlValidator = (uri) {
  return uri.host.endsWith('.example.com') && uri.scheme == 'https';
};
```

When `meherySenderCtaUrlValidator` is set, it **overrides** `meherySenderCtaUrlAllowedHosts`.

Blocked URLs are logged via `sdkPrint` when API logging is enabled; no user-facing error is shown.

---

## Host checklist

1. **Trust model** — Limit who can publish in-app HTML in Mehery to trusted marketers; use staging tenants for QA.
2. **CTA allowlist** — Set `meherySenderCtaUrlAllowedHosts` or `meherySenderCtaUrlValidator` in production.
3. **Privacy** — Disclose in-app WebView and external link behavior ([PRIVACY.md](PRIVACY.md)).
4. **App Transport Security / cleartext** — Prefer https campaigns; avoid http CTAs on iOS ATS-restricted apps.
5. **Optional disable** — Do not call in-app context APIs if you do not want HTML surfaces (`setInAppNotification`, placeholders, tooltips).
6. **Review creatives** — Periodically audit active templates for unexpected external domains.
7. **Release logging** — Keep `meherySenderApiLoggingEnabled` false in release to avoid logging CTA URLs in consoles.

---

## flutter_html (tooltips)

Tooltip rendering uses **`flutter_html`** ([`lib/widgets/tooltip_sdk.dart`](lib/widgets/tooltip_sdk.dart)), not `webview_flutter`. It still parses HTML from campaigns but with a different attack surface (no unrestricted JS bridge equivalent to WebView). Apply the same **content trust** assumptions.

---

## API reference

| Symbol | Location | Purpose |
|--------|----------|---------|
| `meherySenderCtaUrlAllowedHosts` | `lib/api/config.dart` | Host suffix allowlist |
| `meherySenderCtaUrlValidator` | `lib/api/config.dart` | Custom allow/deny |
| `meSendIsCtaUrlAllowed(Uri)` | `lib/api/config.dart` | Programmatic check (tests, host wrappers) |

---

## Document version

Applies to **mehery_sender 0.1.8+**. Re-read when upgrading; WebView behavior changes are listed in [CHANGELOG.md](CHANGELOG.md).
