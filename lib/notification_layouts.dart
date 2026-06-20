import 'package:flutter/services.dart' show rootBundle;

class NotificationLayouts {
  static const _package = 'mehery_sender';

  static Future<String> getStandardLayout() async {
    return rootBundle.loadString('packages/$_package/assets/layouts/standard_notification.xml');
  }

  static Future<String> getDeliveryLayout() async {
    return rootBundle.loadString('packages/$_package/assets/layouts/delivery_notification.xml');
  }

  static Future<String> getScoreLayout() async {
    return rootBundle.loadString('packages/$_package/assets/layouts/score_notification.xml');
  }
}
