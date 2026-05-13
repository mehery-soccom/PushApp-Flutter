import 'package:flutter/material.dart';
import '../notification_templates.dart';

class ScoreNotificationConfig extends NotificationConfig {
  final String team1;
  final String team2;
  final String score1;
  final String score2;
  final String? team1LogoUrl;
  final String? team2LogoUrl;
  final String? matchStatus; // e.g., "Live", "Final", "Half Time"
  final String? additionalInfo; // e.g., overs in cricket, time in football

  ScoreNotificationConfig({
    required super.title,
    required super.subtitle,
    required this.team1,
    required this.team2,
    required this.score1,
    required this.score2,
    this.team1LogoUrl,
    this.team2LogoUrl,
    this.matchStatus,
    this.additionalInfo,
    super.backgroundColor,
    super.buttons,
  });

  factory ScoreNotificationConfig.fromJson(Map<String, dynamic> json) {
    return ScoreNotificationConfig(
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      team1: json['team1'] ?? '',
      team2: json['team2'] ?? '',
      score1: json['score1'] ?? '',
      score2: json['score2'] ?? '',
      team1LogoUrl: json['team1_logo_url'],
      team2LogoUrl: json['team2_logo_url'],
      matchStatus: json['match_status'],
      additionalInfo: json['additional_info'],
      backgroundColor: json['background_color'] != null
          ? Color(int.parse(json['background_color'], radix: 16))
          : null,
      buttons: (json['buttons'] as List?)?.map((b) =>
          NotificationButton.fromJson(b)).toList(),
    );
  }
} 