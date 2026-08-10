import 'package:flutter/foundation.dart';

/// Prefix for all SDK diagnostic output. Filter logcat / Xcode console with
/// `[MeherySender]` to separate Mehery logs from the host app.
const String meherySenderLogPrefix = '[MeherySender]';

/// When `true`, SDK HTTP, push, registration, and in-app diagnostics are
/// logged via [meherySenderLog]. Defaults to [kDebugMode]; set to `true`
/// before SDK init to debug release/profile builds.
bool meherySenderApiLoggingEnabled = kDebugMode;

/// Alias for [meherySenderApiLoggingEnabled] (legacy host-app name).
bool get meherySenderConsoleLoggingEnabled =>
    meherySenderApiLoggingEnabled;

set meherySenderConsoleLoggingEnabled(bool value) {
  meherySenderApiLoggingEnabled = value;
}

/// Logs a single line when [meherySenderApiLoggingEnabled] is `true`.
///
/// Optional [tag] adds a subsystem segment, e.g. `[MeherySender][API]`.
void meherySenderLog(String message, {String? tag}) {
  if (!meherySenderApiLoggingEnabled) {
    return;
  }

  final prefix = tag == null || tag.isEmpty
      ? meherySenderLogPrefix
      : '$meherySenderLogPrefix[$tag]';
  debugPrint('$prefix $message');
}
