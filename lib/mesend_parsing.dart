import 'dart:convert';

/// Tenant subdomain + channel id sent to PushApp APIs.
class ParsedPushappId {
  final String tenant;
  final String channelId;
  const ParsedPushappId({required this.tenant, required this.channelId});
}

/// Preferred: full app id, e.g. `demo_1751694691225` — [ParsedPushappId.channelId]
/// is the entire string; [ParsedPushappId.tenant] is the substring before the first `_`.
///
/// Legacy: `tenant$rest` — split on the first `$` (previous SDK behavior).
ParsedPushappId parsePushappIdentifier(String identifier) {
  final trimmed = identifier.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError('identifier must not be empty');
  }
  const legacySep = r'$';
  if (trimmed.contains(legacySep)) {
    final parts = trimmed.split(legacySep);
    final t = parts[0].trim();
    final c = parts.length > 1 ? parts[1].trim() : '';
    if (t.isEmpty || c.isEmpty) {
      throw ArgumentError(
        'Invalid identifier. Expected full app id (e.g. demo_1751694691225) or legacy tenant\$channel',
      );
    }
    return ParsedPushappId(tenant: t, channelId: c);
  }
  final channelId = trimmed;
  final us = trimmed.indexOf('_');
  final tenant = us >= 0 ? trimmed.substring(0, us) : trimmed;
  return ParsedPushappId(tenant: tenant, channelId: channelId);
}

String? meSendExtractSessionIdFromDynamic(dynamic decoded, [int depth = 0]) {
  if (depth > 12 || decoded == null || decoded is! Map) return null;
  final m = Map<String, dynamic>.from(decoded);
  for (final k in ['session_id', 'sessionId']) {
    final v = m[k];
    if (v != null && v.toString().trim().isNotEmpty) {
      return v.toString().trim();
    }
  }
  for (final nestKey in [
    'session',
    'data',
    'device',
    'payload',
    'meta',
    'result',
    'extra',
    'response',
  ]) {
    final nested = m[nestKey];
    if (nested is Map) {
      final found = meSendExtractSessionIdFromDynamic(nested, depth + 1);
      if (found != null) return found;
    }
  }
  final results = m['results'];
  if (results is List) {
    for (final item in results) {
      if (item is Map) {
        final found = meSendExtractSessionIdFromDynamic(
          Map<String, dynamic>.from(item),
          depth + 1,
        );
        if (found != null) return found;
      }
    }
  }
  return null;
}

String? meSendExtractPIdFromDynamic(dynamic decoded, [int depth = 0]) {
  if (depth > 12 || decoded == null || decoded is! Map) return null;
  final m = Map<String, dynamic>.from(decoded);
  final v = m['p_id'];
  if (v != null && v.toString().trim().isNotEmpty) {
    return v.toString().trim();
  }
  for (final nestKey in [
    'device',
    'data',
    'payload',
    'meta',
    'result',
    'extra',
    'response',
    'session',
  ]) {
    final nested = m[nestKey];
    if (nested is Map) {
      final found = meSendExtractPIdFromDynamic(nested, depth + 1);
      if (found != null) return found;
    }
  }
  final results = m['results'];
  if (results is List) {
    for (final item in results) {
      if (item is Map) {
        final found = meSendExtractPIdFromDynamic(
          Map<String, dynamic>.from(item),
          depth + 1,
        );
        if (found != null) return found;
      }
    }
  }
  return null;
}

String? meSendExtractPIdFromBody(String body) {
  try {
    return meSendExtractPIdFromDynamic(jsonDecode(body));
  } catch (_) {
    return null;
  }
}

String? meSendExtractSessionIdFromBody(String body) {
  try {
    return meSendExtractSessionIdFromDynamic(jsonDecode(body));
  } catch (_) {
    return null;
  }
}

Map<String, dynamic>? meSendCoerceMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

String meSendParseString(dynamic value, {String fallback = ''}) {
  if (value == null) {
    return fallback;
  }
  if (value is String) {
    return value;
  }
  return value.toString();
}

String meSendParseHtmlContent(dynamic value) {
  if (value is String) {
    return value;
  }
  return '';
}

bool meSendParseBool(dynamic value, {bool fallback = false}) {
  if (value == null) {
    return fallback;
  }
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.toLowerCase().trim();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
  }
  return fallback;
}

double meSendParseDouble(dynamic value, {double fallback = 0}) {
  if (value == null) {
    return fallback;
  }
  if (value is double) {
    return value;
  }
  if (value is int) {
    return value.toDouble();
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim()) ?? fallback;
  }
  return fallback;
}

List<String> meSendParseStringList(dynamic value) {
  if (value is List) {
    return value.map((e) => e.toString()).toList();
  }
  return const [];
}

/// Parsed payload for native `trackNotification` [MethodChannel] calls.
class MeSendTrackNotificationArgs {
  const MeSendTrackNotificationArgs({
    required this.token,
    required this.event,
    this.ctaId,
  });

  final String token;
  final String event;
  final String? ctaId;
}

/// Validates native `trackNotification` arguments without throwing.
///
/// Returns `null` when [arguments] is not a map or required fields are missing.
MeSendTrackNotificationArgs? meSendParseTrackNotificationArgs(dynamic arguments) {
  final map = meSendCoerceMap(arguments);
  if (map == null) {
    return null;
  }

  final token = meSendParseString(map['token'] ?? map['t']).trim();
  final event = meSendParseString(map['event']).trim();
  if (token.isEmpty || event.isEmpty) {
    return null;
  }

  final ctaRaw = map['ctaId'];
  final ctaId = ctaRaw == null
      ? null
      : meSendParseString(ctaRaw).trim();
  return MeSendTrackNotificationArgs(
    token: token,
    event: event,
    ctaId: ctaId != null && ctaId.isNotEmpty ? ctaId : null,
  );
}

/// Whether an in-app template [code] is an inline slot (non-blocking).
bool meSendIsInlineInAppTemplateCode(String code) {
  return code.toLowerCase().contains('inline');
}

/// Whether an in-app template [code] is a tooltip (non-blocking for inline).
bool meSendIsTooltipInAppTemplateCode(String code) {
  return code.toLowerCase() == 'tooltip';
}

/// What [app_install] should do for this process vs last recorded host version.
enum MeSendAppInstallEmit {
  /// Same version (or no current version) — do not send.
  none,

  /// First install — send `app_install` with `updated: false`.
  firstInstall,

  /// Host app version changed — send `app_install` with `updated: true`.
  update,

  /// Install was already sent before version tracking existed; store current
  /// version without emitting (avoids a false update on SDK upgrade).
  rememberVersion,
}

MeSendAppInstallEmit meSendAppInstallEmit({
  required String? lastRecordedVersion,
  required String currentVersion,
  required bool installAlreadySent,
}) {
  final current = currentVersion.trim();
  final last = lastRecordedVersion?.trim();
  if (current.isEmpty) {
    if (last != null && last.isNotEmpty) {
      return MeSendAppInstallEmit.none;
    }
    return installAlreadySent
        ? MeSendAppInstallEmit.none
        : MeSendAppInstallEmit.firstInstall;
  }
  if (last != null && last.isNotEmpty && last == current) {
    return MeSendAppInstallEmit.none;
  }
  if (last == null || last.isEmpty) {
    return installAlreadySent
        ? MeSendAppInstallEmit.rememberVersion
        : MeSendAppInstallEmit.firstInstall;
  }
  return MeSendAppInstallEmit.update;
}

/// Normalizes journey `sourceType` to `NOTIFICATION`, `IN_APP`, `INBOUND`,
/// `OUTBOUND`, or `null`.
String? meSendNormalizeReferrerSourceType(dynamic value) {
  final raw = meSendParseString(value).trim().toUpperCase().replaceAll('-', '_');
  if (raw.isEmpty) {
    return null;
  }
  if (raw == 'INAPP' || raw == 'IN_APP') {
    return 'IN_APP';
  }
  if (raw == 'NOTIFICATION' || raw == 'INBOUND' || raw == 'OUTBOUND') {
    return raw;
  }
  return null;
}

/// Journey `event_referrer` for `app_open` / `app_enter`.
///
/// Always includes `sourceChannel: APP` and `sourceChannelId` when [channelId]
/// is set. Unknown attribution fields are explicit JSON `null`.
Map<String, dynamic> meSendBuildEventReferrer({
  required String channelId,
  String? sourceType,
  String? campaignId,
  String? messageId,
  String? clickToken,
}) {
  final campaign = (campaignId ?? '').trim();
  final message = (messageId ?? '').trim();
  final type = meSendNormalizeReferrerSourceType(sourceType);
  final channel = channelId.trim();

  String? sourceCategory;
  if (campaign.isNotEmpty) {
    sourceCategory = 'CAMPAIGN';
  } else if (message.isNotEmpty) {
    sourceCategory = 'MESSAGE';
  }

  final referrer = <String, dynamic>{
    'sourceCategory': sourceCategory,
    'sourceType': type,
    'sourceChannel': 'APP',
    'sourceChannelId': channel.isEmpty ? null : channel,
    'campaignId': campaign.isEmpty ? null : campaign,
    'messageId': message.isEmpty ? null : message,
  };
  final token = (clickToken ?? '').trim();
  if (token.isNotEmpty) {
    referrer['click_token'] = token;
  }
  return referrer;
}
