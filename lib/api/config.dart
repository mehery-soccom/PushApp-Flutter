part of mehery_sender;

/// When true, SDK APIs throw [DeviceRegistrationPendingException] if the device
/// is not registered. Default `false` — calls are no-ops or queued instead.
bool meherySenderStrictRegistrationMode = false;
const String kDeviceRegistrationPendingMessage = 'Device registration pending';

/// Android native code → Dart [MethodChannel] name (ping, trackNotification).
const String meherySenderMethodChannel = 'mehery_channel';

/// Android native CTA/open events → Dart [EventChannel] name.
const String meherySenderEventChannel = 'mesend_event_channel';

/// Host suffix allowlist for in-app CTA `http`/`https` links opened via
/// [Pushapp._handleCta] and WebView navigation handlers.
///
/// When **empty** (default), all valid http(s) CTA URLs may open externally.
/// When **non-empty**, the URL host must equal an entry or end with `.{entry}`
/// (case-insensitive), e.g. `example.com` allows `https://app.example.com`.
List<String> meherySenderCtaUrlAllowedHosts = [];

/// Optional CTA URL gate. When set, overrides [meherySenderCtaUrlAllowedHosts].
/// Return `true` to allow [url] to open, `false` to block.
bool Function(Uri url)? meherySenderCtaUrlValidator;

/// Returns whether an http(s) CTA [uri] may be opened by the SDK.
bool meSendIsCtaUrlAllowed(Uri uri) {
  if (!uri.hasScheme ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty) {
    return false;
  }
  final validator = meherySenderCtaUrlValidator;
  if (validator != null) {
    return validator(uri);
  }
  if (meherySenderCtaUrlAllowedHosts.isEmpty) {
    return true;
  }
  final host = uri.host.toLowerCase();
  for (final allowed in meherySenderCtaUrlAllowedHosts) {
    final entry = allowed.trim().toLowerCase();
    if (entry.isEmpty) {
      continue;
    }
    if (host == entry || host.endsWith('.$entry')) {
      return true;
    }
  }
  return false;
}
