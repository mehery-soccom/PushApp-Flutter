import 'package:flutter/material.dart';

enum NotificationType {
  standard,
  delivery,
  score
}

class NotificationConfig {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final Color? backgroundColor;
  final String? backgroundImageUrl;
  final double? titleFontSize;
  final double? subtitleFontSize;
  final Color? titleColor;
  final Color? subtitleColor;
  final List<NotificationButton>? buttons;

  NotificationConfig({
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.backgroundColor,
    this.backgroundImageUrl,
    this.titleFontSize,
    this.subtitleFontSize,
    this.titleColor,
    this.subtitleColor,
    this.buttons,
  });

  factory NotificationConfig.fromJson(Map<String, dynamic> json) {
    return NotificationConfig(
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      imageUrl: json['image_url'],
      backgroundColor: json['background_color'] != null
          ? Color(int.parse(json['background_color'], radix: 16))
          : null,
      backgroundImageUrl: json['background_image_url'],
      titleFontSize: json['title_font_size']?.toDouble(),
      subtitleFontSize: json['subtitle_font_size']?.toDouble(),
      titleColor: json['title_color'] != null
          ? Color(int.parse(json['title_color'], radix: 16))
          : null,
      subtitleColor: json['subtitle_color'] != null
          ? Color(int.parse(json['subtitle_color'], radix: 16))
          : null,
      buttons: (json['buttons'] as List?)?.map((b) =>
          NotificationButton.fromJson(b)).toList(),
    );
  }
}

class NotificationButton {
  final String text;
  final String action;
  final Color? backgroundColor;
  final Color? textColor;

  NotificationButton({
    required this.text,
    required this.action,
    this.backgroundColor,
    this.textColor,
  });

  factory NotificationButton.fromJson(Map<String, dynamic> json) {
    return NotificationButton(
      text: json['text'] ?? '',
      action: json['action'] ?? '',
      backgroundColor: json['background_color'] != null
          ? Color(int.parse(json['background_color'], radix: 16))
          : null,
      textColor: json['text_color'] != null
          ? Color(int.parse(json['text_color'], radix: 16))
          : null,
    );
  }
} 