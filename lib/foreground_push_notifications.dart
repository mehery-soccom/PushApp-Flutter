import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'sdk_logging.dart';

/// FlutterFire [FirebaseOptions] stored in the **current** isolate via
/// [configureMeSendFirebaseBackgroundInit] (typically [main] only).
///
/// Statics are **not** shared with the FCM background isolate. Pass
/// [FirebaseOptions] into [meSendHandleBackgroundRemoteMessage] from a host
/// top-level handler — see README §2.3.
FirebaseOptions? _meSendFirebaseBackgroundOptions;

/// [FirebaseOptions] stored by [configureMeSendFirebaseBackgroundInit] in this
/// isolate (for tests / main-isolate use only).
FirebaseOptions? get meSendConfiguredFirebaseBackgroundOptions =>
    _meSendFirebaseBackgroundOptions;

/// Stores [FirebaseOptions] in the **current** isolate.
///
/// Calling this in [main] does **not** configure the FCM background isolate.
/// Use [meSendHandleBackgroundRemoteMessage] from a host top-level handler.
void configureMeSendFirebaseBackgroundInit({
  required FirebaseOptions options,
}) {
  _meSendFirebaseBackgroundOptions = options;
}

/// Handles an FCM message in a **background isolate**.
///
/// Call from a host `@pragma('vm:entry-point')` top-level function so
/// [FirebaseOptions] are resolved **inside** the background isolate:
///
/// ```dart
/// @pragma('vm:entry-point')
/// Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
///   await meSendHandleBackgroundRemoteMessage(
///     message,
///     options: DefaultFirebaseOptions.currentPlatform,
///   );
/// }
/// ```
///
/// In [main]:
/// ```dart
/// FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
/// ```
Future<void> meSendHandleBackgroundRemoteMessage(
  RemoteMessage message, {
  required FirebaseOptions options,
}) async {
  final ready =
      await MeSendPushNotificationDisplay.ensureFirebaseInitializedForBackground(
    options: options,
  );
  if (!ready) {
    return;
  }
  meherySenderLog('SDK background handler invoked', tag: 'Push|background');
  MeSendPushNotificationDisplay.logPayload(message, 'background');
  await MeSendPushNotificationDisplay.handleRemoteMessage(
    message,
    source: 'background',
  );
}

/// @nodoc
@visibleForTesting
FirebaseOptions? get meSendFirebaseBackgroundOptionsForTest =>
    _meSendFirebaseBackgroundOptions;

/// @nodoc
@visibleForTesting
bool get meSendFirebaseListenersAttachedForTest =>
    MeSendPushNotificationDisplay.listenersAttachedForTest;

/// @nodoc
@visibleForTesting
void resetMeSendFirebaseListenersForTest() {
  MeSendPushNotificationDisplay.resetListenersForTest();
}

/// @nodoc
@visibleForTesting
void resetMeSendFirebaseBackgroundInitForTest() {
  _meSendFirebaseBackgroundOptions = null;
}

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
  static bool _backgroundTrayReady = false;
  static bool _listenersAttached = false;
  static final Set<String> _androidChannelsCreated = <String>{};

  /// Attaches FCM foreground listeners.
  ///
  /// Called automatically by [ensureInitialized]. Host apps should **not** call
  /// this directly — use [ensureInitialized] after [Firebase.initializeApp]
  /// so foreground push is handled exactly once.
  @Deprecated(
    'FCM listeners attach automatically via '
    'MeSendPushNotificationDisplay.ensureInitialized().',
  )
  static void attachFirebaseListeners() {
    _attachFirebaseListenersOnce();
  }

  static void _attachFirebaseListenersOnce() {
    if (_listenersAttached) {
      meherySenderLog('Firebase listeners already attached', tag: 'Push');
      return;
    }
    _listenersAttached = true;

    meherySenderLog('Attaching Firebase listeners (onMessage)', tag: 'Push');

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      meherySenderLog('onMessage received in Dart', tag: 'Push|foreground');
      logPayload(message, 'foreground');
      try {
        await handleRemoteMessage(message, source: 'foreground');
      } catch (error, stackTrace) {
        meherySenderLog('handle failed: $error', tag: 'Push|foreground');
        meherySenderLog('$stackTrace', tag: 'Push|foreground');
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      meherySenderLog('onMessageOpenedApp', tag: 'Push|opened_from_background');
      logPayload(message, 'opened_from_background');
    });

    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        meherySenderLog('getInitialMessage', tag: 'Push|opened_from_terminated');
        logPayload(message, 'opened_from_terminated');
      }
    });
  }

  /// Initializes Firebase in a background isolate when needed.
  ///
  /// Pass [options] from your generated `firebase_options.dart` (evaluated inside
  /// the background handler). [configureMeSendFirebaseBackgroundInit] in [main]
  /// alone is not sufficient — statics are not shared across isolates.
  static Future<bool> ensureFirebaseInitializedForBackground({
    FirebaseOptions? options,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();
    if (Firebase.apps.isNotEmpty) {
      return true;
    }
    final resolved = options ?? _meSendFirebaseBackgroundOptions;
    if (resolved == null) {
      meherySenderLog(
        'Firebase init skipped — pass options to meSendHandleBackgroundRemoteMessage('
        'message, options: DefaultFirebaseOptions.currentPlatform) from a host '
        '@pragma(\'vm:entry-point\') top-level handler. '
        'configureMeSendFirebaseBackgroundInit in main() does not apply to the '
        'background isolate. See README §2.3.',
        tag: 'Push|background',
      );
      return false;
    }
    await Firebase.initializeApp(options: resolved);
    return true;
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
      meherySenderLog(
        'payload:\n${const JsonEncoder.withIndent('  ').convert(payload)}',
        tag: 'Push|$source',
      );
    } catch (error, stackTrace) {
      meherySenderLog('failed to log payload: $error', tag: 'Push|$source');
      meherySenderLog('$stackTrace', tag: 'Push|$source');
    }
  }

  /// Initializes local notifications and attaches FCM foreground listeners.
  ///
  /// Call once in [main] after [Firebase.initializeApp]. This is the single
  /// SDK entry point for foreground push handling — host apps must not call
  /// [attachFirebaseListeners] separately.
  ///
  /// For the FCM **background** isolate, the SDK uses [ensureTrayDisplayReady]
  /// instead (no permission prompt, no FCM listener attachment).
  static Future<void> ensureInitialized() async {
    await ensureTrayDisplayReady(background: false);
    _attachFirebaseListenersOnce();
    _initialized = true;
  }

  /// Initializes [FlutterLocalNotificationsPlugin] for tray display.
  ///
  /// When [background] is `true` (FCM background isolate), skips Android
  /// [requestNotificationsPermission] — there is no [Activity] context and the
  /// call throws. Permission should be requested in [main] / foreground only.
  @visibleForTesting
  static Future<void> ensureTrayDisplayReady({bool background = false}) async {
    if (background) {
      if (_backgroundTrayReady) {
        return;
      }
    } else if (_initialized) {
      return;
    }

    if (!background && Platform.isIOS) {
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
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    if (Platform.isAndroid && !background) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    if (background) {
      _backgroundTrayReady = true;
    }
  }

  /// Handles [RemoteMessage] in foreground, background, or terminated flows.
  static Future<void> handleRemoteMessage(
    RemoteMessage message, {
    required String source,
  }) async {
    final payload = MeSendDataPushPayload.fromRemoteMessage(message);

    meherySenderLog(
      'data-only parsed → type=${payload.type}, category=${payload.category}, '
      'title=${payload.title}, body=${payload.body}, '
      'showTray=${payload.shouldShowTrayNotification}',
      tag: 'Push|$source',
    );

    if (!payload.shouldShowTrayNotification) {
      meherySenderLog(
        'skip tray (in-app type or empty): ${payload.type}',
        tag: 'Push|$source',
      );
      return;
    }

    // Android already displays notification-block payloads when backgrounded.
    if (Platform.isAndroid &&
        source == 'background' &&
        message.notification != null) {
      meherySenderLog(
        'notification block present — system may display; skipping local tray',
        tag: 'Push|background',
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
    final background = source == 'background';
    await ensureTrayDisplayReady(background: background);
    if (!background) {
      _initialized = true;
    }

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
      id: notificationId,
      title: payload.displayTitle,
      body: payload.displayBody,
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: payload.rawData.isEmpty ? null : jsonEncode(payload.rawData),
    );

    meherySenderLog(
      'tray notification shown (data-only=${message.notification == null}): '
      '${payload.displayTitle}',
      tag: 'Push|$source',
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

  /// @nodoc
  @visibleForTesting
  static bool get listenersAttachedForTest => _listenersAttached;

  /// @nodoc
  @visibleForTesting
  static void resetListenersForTest() {
    _listenersAttached = false;
  }

  /// @nodoc
  @visibleForTesting
  static void resetTrayDisplayForTest() {
    _initialized = false;
    _backgroundTrayReady = false;
  }

  /// @nodoc
  @visibleForTesting
  static void markListenersAttachedForTest() {
    _listenersAttached = true;
  }
}

/// Backward-compatible alias used during SDK init.
typedef MeSendForegroundNotifications = MeSendPushNotificationDisplay;
