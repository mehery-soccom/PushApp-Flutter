part of mehery_sender;

/// Lifecycle phase for device registration with the PushApp backend.
enum MeSendDeviceRegistrationStatus {
  /// No successful registration yet (initial or after reset).
  pending,

  /// Device token registered with the server.
  registered,

  /// Registration or token upload failed.
  failed,

  /// Push token was updated on an already-registered device.
  tokenRefreshed,
}

/// Snapshot emitted on [Pushapp.registrationState].
class MeSendDeviceRegistrationState {
  const MeSendDeviceRegistrationState({
    required this.status,
    required this.isRegistered,
    this.message,
    this.restoredFromCache = false,
  });

  final MeSendDeviceRegistrationStatus status;
  final bool isRegistered;
  final String? message;

  /// `true` when [status] is [MeSendDeviceRegistrationStatus.registered] and
  /// the flag was restored from SharedPreferences (app restart).
  final bool restoredFromCache;

  static const MeSendDeviceRegistrationState pending =
      MeSendDeviceRegistrationState(
    status: MeSendDeviceRegistrationStatus.pending,
    isRegistered: false,
  );

  static MeSendDeviceRegistrationState registered({
    bool restoredFromCache = false,
  }) =>
      MeSendDeviceRegistrationState(
        status: MeSendDeviceRegistrationStatus.registered,
        isRegistered: true,
        restoredFromCache: restoredFromCache,
      );

  static MeSendDeviceRegistrationState failed(String message) =>
      MeSendDeviceRegistrationState(
        status: MeSendDeviceRegistrationStatus.failed,
        isRegistered: false,
        message: message,
      );

  static const MeSendDeviceRegistrationState tokenRefreshed =
      MeSendDeviceRegistrationState(
    status: MeSendDeviceRegistrationStatus.tokenRefreshed,
    isRegistered: true,
  );

  @override
  String toString() =>
      'MeSendDeviceRegistrationState(status: $status, isRegistered: $isRegistered'
      '${message != null ? ', message: $message' : ''}'
      '${restoredFromCache ? ', restoredFromCache: true' : ''})';
}
