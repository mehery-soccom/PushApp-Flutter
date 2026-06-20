part of mehery_sender;

class _ParsedPushappId {
  final String tenant;
  final String channelId;
  const _ParsedPushappId({required this.tenant, required this.channelId});
}

/// Preferred: full app id, e.g. `demo_1751694691225` — [channelId] is the entire string;
/// [tenant] is the substring before the first `_` (`demo`).
///
/// Legacy: `tenant$rest` — split on the first `$` (previous SDK behavior).
_ParsedPushappId _parsePushappIdentifier(String identifier) {
  final parsed = parsePushappIdentifier(identifier);
  return _ParsedPushappId(tenant: parsed.tenant, channelId: parsed.channelId);
}

/// PushApp API host TLD for `https://<tenant>.pushapp.<tld>`.
///
/// - [sandbox] `true` → sandbox **`.net`**
/// - [sandbox] `false` → production **`.ai`**
/// - [developmentHost] `true` → internal development **`.co.in`** (overrides [sandbox])
String pushappHostTld({
  required bool sandbox,
  bool developmentHost = false,
}) {
  if (developmentHost) return 'co.in';
  return sandbox ? 'net' : 'ai';
}

class _PushappServerBase {
  const _PushappServerBase({required this.serverUrl, required this.wsUrl});

  final String serverUrl;
  final String wsUrl;
}

/// Normalizes a custom PushApp base (e.g. ngrok) into HTTP [serverUrl] and WebSocket URL.
///
/// Accepts `https://host`, `https://host/pushapp`, or trailing slashes.
_PushappServerBase parsePushappServerBase(String baseUrl) {
  var normalized = baseUrl.trim();
  while (normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  if (normalized.endsWith('/pushapp')) {
    normalized = normalized.substring(0, normalized.length - '/pushapp'.length);
  }
  final wsScheme = normalized.startsWith('https://')
      ? 'wss://'
      : normalized.startsWith('http://')
          ? 'ws://'
          : 'wss://';
  final host = normalized.replaceFirst(RegExp(r'^https?://'), '');
  return _PushappServerBase(
    serverUrl: normalized,
    wsUrl: '$wsScheme$host/pushapp',
  );
}
