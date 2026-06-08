import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Parsed MeSend FCM **data** payload (no notification block required).
class MeSendDataPushPayload {
  const MeSendDataPushPayload({
    this.id,
    this.type,
    this.category,
    this.title,
    this.body,
    this.imageUrl,
    this.clickToken,
    this.rawData = const {},
  });

  final String? id;
  final String? type;
  final String? category;
  final String? title;
  final String? body;
  final String? imageUrl;
  final String? clickToken;
  final Map<String, dynamic> rawData;

  factory MeSendDataPushPayload.fromRemoteMessage(RemoteMessage message) {
    final data = message.data;
    final notification = message.notification;

    return MeSendDataPushPayload(
      id: _stringOrNull(data['id']),
      type: _stringOrNull(data['type']),
      category: _stringOrNull(data['category']),
      title: _firstNonEmpty([
        notification?.title,
        data['title'],
        data['message1'],
      ]),
      body: _firstNonEmpty([
        notification?.body,
        data['body'],
        data['message'],
        data['message2'],
      ]),
      imageUrl: _firstNonEmpty([
        data['imageUrl'],
        data['image'],
        notification?.android?.imageUrl,
        notification?.apple?.imageUrl,
      ]),
      clickToken: _stringOrNull(data['click_token']),
      rawData: Map<String, dynamic>.from(data),
    );
  }

  bool get hasDisplayableContent =>
      (title != null && title!.isNotEmpty) ||
      (body != null && body!.isNotEmpty);

  /// Whether this push should appear in the system tray (vs in-app only).
  bool get shouldShowTrayNotification {
    if (!hasDisplayableContent) {
      return false;
    }

    final normalizedType = (type ?? 'notification').toLowerCase();
    const inAppOnlyTypes = <String>{
      'roadblock',
      'roadblock-image',
      'banner',
      'pip',
      'tooltip',
      'in_app',
      'in-app',
    };

    for (final inAppType in inAppOnlyTypes) {
      if (normalizedType.contains(inAppType)) {
        return false;
      }
    }

    return normalizedType.isEmpty ||
        normalizedType == 'notification' ||
        normalizedType == 'default' ||
        normalizedType == 'push';
  }

  String get displayTitle =>
      (title != null && title!.isNotEmpty) ? title! : 'Notification';

  String get displayBody =>
      (body != null && body!.isNotEmpty) ? body! : displayTitle;

  String get androidChannelId {
    final cat = category?.trim();
    if (cat == null || cat.isEmpty) {
      return 'mesend_default';
    }
    return 'mesend_${cat.toLowerCase()}';
  }

  static String? _stringOrNull(dynamic value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static String? _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = _stringOrNull(value);
      if (text != null) {
        return text;
      }
    }
    return null;
  }
}

/// Displays tray notifications for FCM messages (notification or data-only).
class MeSendPushNotificationDisplay {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static bool _listenersAttached = false;
  static final Set<String> _androidChannelsCreated = <String>{};

  /// Attach FCM listeners immediately after [Firebase.initializeApp].
  /// Safe to call multiple times; does not require device registration.
  static void attachFirebaseListeners() {
    if (_listenersAttached) {
      debugPrint('[MeSend Push] Firebase listeners already attached');
      return;
    }
    _listenersAttached = true;

    debugPrint('[MeSend Push] Attaching Firebase listeners (onMessage)');

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('[MeSend Push][foreground] onMessage received in Dart');
      logPayload(message, 'foreground');
      try {
        await handleRemoteMessage(message, source: 'foreground');
      } catch (error, stackTrace) {
        debugPrint('[MeSend Push][foreground] handle failed: $error');
        debugPrint('$stackTrace');
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[MeSend Push][opened_from_background] onMessageOpenedApp');
      logPayload(message, 'opened_from_background');
    });

    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('[MeSend Push][opened_from_terminated] getInitialMessage');
        logPayload(message, 'opened_from_terminated');
      }
    });
  }

  static void logPayload(RemoteMessage message, String source) {
    try {
      final payload = <String, dynamic>{
        'messageId': message.messageId,
        'from': message.from,
        'sentTime': message.sentTime?.toIso8601String(),
        'ttl': message.ttl,
        'collapseKey': message.collapseKey,
        'data': message.data,
      };
      final notification = message.notification;
      if (notification != null) {
        payload['notification'] = <String, dynamic>{
          'title': notification.title,
          'body': notification.body,
        };
      }
      debugPrint(
        '[MeSend Push][$source] payload:\n'
        '${const JsonEncoder.withIndent('  ').convert(payload)}',
      );
    } catch (error, stackTrace) {
      debugPrint('[MeSend Push][$source] failed to log payload: $error');
      debugPrint('$stackTrace');
    }
  }

  static Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }

    if (Platform.isIOS) {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    _initialized = true;
  }

  /// Handles [RemoteMessage] in foreground, background, or terminated flows.
  static Future<void> handleRemoteMessage(
    RemoteMessage message, {
    required String source,
  }) async {
    final payload = MeSendDataPushPayload.fromRemoteMessage(message);

    debugPrint(
      '[MeSend Push][$source] data-only parsed → '
      'type=${payload.type}, category=${payload.category}, '
      'title=${payload.title}, body=${payload.body}, '
      'showTray=${payload.shouldShowTrayNotification}',
    );

    if (!payload.shouldShowTrayNotification) {
      debugPrint(
        '[MeSend Push][$source] skip tray (in-app type or empty): '
        '${payload.type}',
      );
      return;
    }

    // iOS with a notification block is shown by the system in foreground.
    if (Platform.isIOS &&
        source == 'foreground' &&
        message.notification != null) {
      return;
    }

    await _showTrayNotification(message, payload, source);
  }

  static Future<void> _showTrayNotification(
    RemoteMessage message,
    MeSendDataPushPayload payload,
    String source,
  ) async {
    await ensureInitialized();

    if (Platform.isAndroid) {
      await _ensureAndroidChannel(payload.androidChannelId, payload.category);
    }

    final notificationId = _notificationIdFor(message, payload);
    final androidDetails = AndroidNotificationDetails(
      payload.androidChannelId,
      _channelName(payload.category),
      channelDescription: 'MeSend push notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      notificationId,
      payload.displayTitle,
      payload.displayBody,
      NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: payload.rawData.isEmpty ? null : jsonEncode(payload.rawData),
    );

    debugPrint(
      '[MeSend Push][$source] tray notification shown '
      '(data-only=${message.notification == null}): ${payload.displayTitle}',
    );
  }

  static Future<void> _ensureAndroidChannel(
    String channelId,
    String? category,
  ) async {
    if (!Platform.isAndroid || _androidChannelsCreated.contains(channelId)) {
      return;
    }

    final channel = AndroidNotificationChannel(
      channelId,
      _channelName(category),
      description: 'MeSend push notifications',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    _androidChannelsCreated.add(channelId);
  }

  static String _channelName(String? category) {
    final cat = category?.trim();
    if (cat == null || cat.isEmpty) {
      return 'Push Notifications';
    }
    return 'Push · ${cat[0].toUpperCase()}${cat.substring(1)}';
  }

  static int _notificationIdFor(
    RemoteMessage message,
    MeSendDataPushPayload payload,
  ) {
    final seed = payload.id ?? message.messageId ?? payload.displayTitle;
    return seed.hashCode.abs() % (1 << 31);
  }
}

/// Backward-compatible alias used during SDK init.
typedef MeSendForegroundNotifications = MeSendPushNotificationDisplay;
