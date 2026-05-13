import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class IOSNotificationTemplates {
  static DarwinNotificationDetails standardTemplate({
    String? imageUrl,
    Map<String, dynamic>? customData,
  }) {
    return DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      attachments: imageUrl != null
          ? [DarwinNotificationAttachment(imageUrl)]
          : null,
      categoryIdentifier: 'standard',
      threadIdentifier: 'standard_notifications',
      // Custom notification interface for iOS
      interruptionLevel: InterruptionLevel.active,
    );
  }

  static DarwinNotificationDetails deliveryTemplate({
    required String driverName,
    required String vehicleInfo,
    required String estimatedTime,
    String? driverImageUrl,
  }) {
    return DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      subtitle: "Estimated arrival: $estimatedTime",
      attachments: driverImageUrl != null
          ? [DarwinNotificationAttachment(driverImageUrl)]
          : null,
      threadIdentifier: 'delivery_notifications',
      // Add custom actions for delivery notifications
      categoryIdentifier: 'DELIVERY_CATEGORY',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
  }

  static DarwinNotificationDetails scoreTemplate({
    required String team1,
    required String team2,
    required String score1,
    required String score2,
    String? matchStatus,
  }) {
    return DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      subtitle: "$team1 $score1 - $score2 $team2",
      categoryIdentifier: 'score',
      threadIdentifier: 'score_notifications',
      interruptionLevel: InterruptionLevel.active,
    );
  }
} 