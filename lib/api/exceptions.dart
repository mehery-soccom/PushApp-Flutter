part of mehery_sender;

/// Thrown when a PushApp API is called before device registration succeeds.
class DeviceRegistrationPendingException implements Exception {
  DeviceRegistrationPendingException([
    this.message = kDeviceRegistrationPendingMessage,
  ]);

  final String message;

  @override
  String toString() => message;
}
