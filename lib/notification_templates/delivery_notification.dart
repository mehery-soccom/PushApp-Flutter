import 'package:flutter/material.dart';
import '../notification_templates.dart';

class DeliveryNotificationConfig extends NotificationConfig {
  final String driverName;
  final String vehicleInfo;
  final String estimatedTime;
  final String? driverImageUrl;
  final String? vehicleImageUrl;
  final double? progress; // For progress bar if needed

  DeliveryNotificationConfig({
    required super.title,
    required super.subtitle,
    required this.driverName,
    required this.vehicleInfo,
    required this.estimatedTime,
    this.driverImageUrl,
    this.vehicleImageUrl,
    this.progress,
    super.backgroundColor,
    super.buttons,
  });

  factory DeliveryNotificationConfig.fromJson(Map<String, dynamic> json) {
    return DeliveryNotificationConfig(
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      driverName: json['driver_name'] ?? '',
      vehicleInfo: json['vehicle_info'] ?? '',
      estimatedTime: json['estimated_time'] ?? '',
      driverImageUrl: json['driver_image_url'],
      vehicleImageUrl: json['vehicle_image_url'],
      progress: json['progress']?.toDouble(),
      backgroundColor: json['background_color'] != null
          ? Color(int.parse(json['background_color'], radix: 16))
          : null,
      buttons: (json['buttons'] as List?)?.map((b) =>
          NotificationButton.fromJson(b)).toList(),
    );
  }
}

class DeliveryNotification {
  static Map<String, dynamic> build({
    required String driverName,
    required String vehicleInfo,
    required String estimatedTime,
    required double progress,
    required String driverImageUrl,
    required String vehicleImageUrl,
  }) {
    return {
      'aps': {
        'alert': {
          'title': 'Pickup in $estimatedTime',
          'subtitle': vehicleInfo,
        },
        'mutable-content': 1,
        'content-available': 1,
        'category': 'DELIVERY_CATEGORY',
      },
      'template_id': 'delivery',
      'driver_name': driverName,
      'vehicle_info': vehicleInfo,
      'estimated_time': estimatedTime,
      'progress': progress,
      'driver_image_url': driverImageUrl,
      'vehicle_image_url': vehicleImageUrl,
    };
  }
} 