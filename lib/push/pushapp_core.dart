part of mehery_sender;

mixin PushappCoreMixin on PushappBase {
Future<void> track(Map<String, dynamic> event) async {
    if (!_ensureDeviceRegistered('track')) {
      return;
    }
    final url = Uri.parse('$serverUrl/pushapp/api/v1/notification/push/track');

    final token = event["t"] ?? event["token"] ?? userId;
    final eventName = event["event"];
    final ctaId = event["ctaId"];

    if (token == null || eventName == null) return;

    final body = {
      "t": token,
      "event": eventName,
      "data": ctaId != null ? {"ctaId": ctaId} : {}
    };

    const requestHeaders = {"Content-Type": "application/json"};
    await _meSendHttpPost(
      url,
      headers: requestHeaders,
      body: jsonEncode(body),
      label: 'push_track',
    );
  }


  void registerPlaceholderListener(String placeholderId, void Function(List<dynamic>,String,String) callback) {
    _placeholderListeners[placeholderId] = callback;
  }

  void unregisterPlaceholderListener(String placeholderId) {
    _placeholderListeners.remove(placeholderId);
  }

  void sendWidgetOpen(String placeholderId) {
    sendEvent('widget_open', {'placeholder_id': placeholderId});
  }

  void initPage(String page){
    sdkPrint("in sdk init page");
    sendEvent("page_open", {"page": page});
    Future.delayed(const Duration(seconds: 2), () {
      _pollForNotificationData(userId);
    });
  }

  /// Initializes the SDK and registers the device using tokens from the host app.
  ///
  /// Returns `true` when the device is registered (or was already registered).
  /// Returns `false` when tokens are missing, registration fails, or the platform
  /// is unsupported — [registrationState] emits [MeSendDeviceRegistrationStatus.failed]
  /// with a readable [MeSendDeviceRegistrationState.message].
  ///
  /// Does not throw unless [meherySenderStrictRegistrationMode] is enabled.
  ///
  /// - **Android:** provide [fcmToken]
  /// - **iOS:** provide [apnsToken]; [fcmToken] is optional but recommended
  Future<bool> initializeAndSendToken({
    String? fcmToken,
    String? apnsToken,
  }) async {
    sdkPrint('Started Load');

    setupMethodChannelHandler();
    await _loadDeviceRegistrationState();
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getString('user_id') ?? '';
    final lastToken = prefs.getString('device_token');

    try {
      if (Platform.isAndroid) {
        final token = fcmToken?.trim();
        if (token == null || token.isEmpty) {
          await _failDeviceRegistration('fcmToken is required on Android.');
          if (meherySenderStrictRegistrationMode) {
            throw ArgumentError('fcmToken is required on Android.');
          }
          return false;
        }

        if (!_deviceRegistered) {
          await prefs.setString('device_token', token);
          await sendTokenToServer('android', token);
        } else if (userId.isNotEmpty) {
          sdkPrint('User already logged in: $userId');
          _setupSocket(userId);
          if (lastToken != token) {
            await updateDeviceToken(token);
            await prefs.setString('device_token', token);
          }
        }
      } else if (Platform.isIOS) {
        final apns = apnsToken?.trim();
        if (apns == null || apns.isEmpty) {
          await _failDeviceRegistration('apnsToken is required on iOS.');
          if (meherySenderStrictRegistrationMode) {
            throw ArgumentError('apnsToken is required on iOS.');
          }
          return false;
        }

        final fcm = fcmToken?.trim();

        if (!_deviceRegistered) {
          await prefs.setString('device_token', apns);
          await sendTokenToServer('ios', apns, fcmToken: fcm);
        } else if (userId.isNotEmpty) {
          sdkPrint('User already logged in: $userId');
          _setupSocket(userId);
          if (lastToken != apns) {
            await updateDeviceToken(apns, fcmToken: fcm);
            await prefs.setString('device_token', apns);
          }
        }
      } else {
        sdkPrint('Unsupported platform.');
        await _failDeviceRegistration('Unsupported platform.');
        if (meherySenderStrictRegistrationMode) {
          throw UnsupportedError('Unsupported platform.');
        }
        return false;
      }

      if (_deviceRegistered) {
        await sendEvent('app_open', {});
      }
      return _deviceRegistered;
    } catch (e) {
      sdkPrint('Error initializing push tokens: $e');
      await _failDeviceRegistration(e.toString());
      if (meherySenderStrictRegistrationMode) {
        rethrow;
      }
      return false;
    } finally {
      try {
        MeSendPushNotificationDisplay.attachFirebaseListeners();
      } catch (e) {
        sdkPrint('FCM listener attachment skipped: $e');
      }
    }
  }

  /// Logs the full FCM [RemoteMessage] data + notification payload to the console.
  static void logRemoteMessagePayload(RemoteMessage message, String source) {
    try {
      final payload = remoteMessageToDiagnosticsMap(message);
      final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);
      meherySenderLog('payload:\n$jsonStr', tag: 'Push|$source');
    } catch (error, stackTrace) {
      meherySenderLog('failed to log payload: $error', tag: 'Push|$source');
      meherySenderLog('$stackTrace', tag: 'Push|$source');
    }
  }

  static Map<String, dynamic> remoteMessageToDiagnosticsMap(RemoteMessage message) {
    final Map<String, dynamic> out = {
      'messageId': message.messageId,
      'from': message.from,
      'sentTime': message.sentTime?.toIso8601String(),
      'ttl': message.ttl,
      'collapseKey': message.collapseKey,
      'data': message.data,
    };
    final RemoteNotification? n = message.notification;
    if (n != null) {
      out['notification'] = <String, dynamic>{
        'title': n.title,
        'body': n.body,
        if (n.android != null)
          'android': <String, dynamic>{
            'channelId': n.android!.channelId,
            'clickAction': n.android!.clickAction,
            'imageUrl': n.android!.imageUrl,
            'link': n.android!.link,
            'smallIcon': n.android!.smallIcon,
            'sound': n.android!.sound,
            'ticker': n.android!.ticker,
          },
        if (n.apple != null)
          'apple': <String, dynamic>{
            'badge': n.apple!.badge,
            'imageUrl': n.apple!.imageUrl,
            'subtitle': n.apple!.subtitle,
          },
      };
    }
    return out;
  }

  void setupMethodChannelHandler() {
    PushappBase._channel.setMethodCallHandler(_onNativeMethodCall);
  }

  Future<dynamic> _onNativeMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'ping':
        await ping();
        return null;
      case 'trackNotification':
        final args = meSendParseTrackNotificationArgs(call.arguments);
        if (args == null) {
          sdkPrint(
            'PushApp: ignored trackNotification — invalid arguments: '
            '${call.arguments}',
          );
          return null;
        }
        await trackNotificationEvent(
          args.token,
          args.event,
          ctaId: args.ctaId,
        );
        return null;
      default:
        sdkPrint('PushApp: ignored unknown MethodChannel call: ${call.method}');
        return null;
    }
  }


  Future<void> trackNotificationEvent(String token, String event, {String? ctaId}) async {
    if (!_ensureDeviceRegistered('trackNotificationEvent')) {
      return;
    }
    final url = Uri.parse('$serverUrl/pushapp/api/v1/notification/push/track');

    final body = {
      't': token,
      'event': event,
      if (ctaId != null) 'data': {'ctaId': ctaId},
    };

    const requestHeaders = {'Content-Type': 'application/json'};
    try {
      final response = await _meSendHttpPost(
        url,
        headers: requestHeaders,
        body: jsonEncode(body),
        label: 'push_track',
      );

      if (response.statusCode == 200) {
        sdkPrint('✅ Notification event "$event" tracked successfully.');
      } else {
        sdkPrint('❌ Failed to track event ($event): ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      sdkPrint('❌ Error tracking notification event: $e');
    }
  }



  /// Sends the token (APNs or Firebase) to the server.
  Future<void> sendTokenToServer(String tokenType, String token, {String? fcmToken}) async {
    sdkPrint("sendTokenToServer");
    try {
      final url = '$serverUrl/pushapp/api/device/register';
      sdkPrint('Server URL : $url');

      var deviceId = await getDeviceId();
      final deviceHeaders = await getDeviceHeaders();
      sdkPrint("ServerDeviceID: $deviceId");

      final requestHeaders = {
        'Content-Type': 'application/json',
        ...deviceHeaders,
      };

      sdkPrint(requestHeaders.toString());

      final requestBody = {
        'platform': tokenType, // 'firebase' or 'apns'
        'token': token,
        'device_id': deviceId,
        'channel_id': channelId,
      };
      if(fcmToken != null){
        requestBody["fcm_token"] = fcmToken;
      }

      sdkPrint("Request Body: $requestBody");

      final response = await _meSendHttpPost(
        Uri.parse(url),
        headers: requestHeaders,
        body: jsonEncode(requestBody),
        label: 'device_register',
      );
      sdkPrint("Register ${response.statusCode}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        sdkPrint(response.body);
        if (responseData['device']['user_id'] != null) {
          guestId = responseData['device']['user_id'].toString();
        }
        sdkPrint("guest_id: $guestId");
        sdkPrint("Token sent successfully!");
        await _markDeviceRegistered();
      } else {
        sdkPrint("Failed to send token: ${response.body}");
        throw Exception("Failed to send token: ${response.body}");
      }

    } catch (e) {
      await _failDeviceRegistration(e.toString());
      sdkPrint("Error sending token to server: $e");
      rethrow;
    }
  }


  Future<void> updateDeviceToken(String token,{String? fcmToken}) async {
    if (!_ensureDeviceRegistered('updateDeviceToken')) {
      return;
    }
    sdkPrint("🔄 updateDeviceToken() called");
    final url = '$serverUrl/pushapp/api/update/token';

    var deviceId = await getDeviceId();
    final contactId = "${userId}_$deviceId";

    try {
      final requestBody = {
        'contact_id': contactId,
        'token': token,
        'channel_id': channelId,
      };

      if(fcmToken != null){
        requestBody['fcm_token'] = fcmToken;
      }

      final response = await _meSendHttpPost(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
        label: 'update_token',
      );

      if (response.statusCode == 200) {
        sdkPrint("✅ Token updated successfully on server.");
        _emitTokenRefreshed();
      } else {
        sdkPrint("❌ Failed to update token: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      sdkPrint("🔥 Error updating device token: $e");
    }
  }



  /// Acknowledges an in-app notification.
  Future<void> ackNotification(String contactId, String messageId) async {
    if (!_ensureDeviceRegistered('api')) {
      return;
    }
    try {
      final url = '$serverUrl/pushapp/api/v1/notification/in-app/ack';
      final requestHeaders = {
        'Content-Type': 'application/json',
      };
      final requestBody = {
        'contact_id': contactId,
        'messageId': messageId,
      };

      final response = await _meSendHttpPost(
        Uri.parse(url),
        headers: requestHeaders,
        body: jsonEncode(requestBody),
        label: 'in_app_ack',
      );

      if (response.statusCode == 200) {
        sdkPrint("Notification acknowledged successfully!");
      } else {
        sdkPrint("Failed to acknowledge notification: ${response.body}");
        throw Exception("Failed to acknowledge notification: ${response.body}");
      }

    } on DeviceRegistrationPendingException {
      rethrow;
    } catch (e) {
      sdkPrint("Error acknowledging notification: $e");
      rethrow;
    }
  }



  /// Parses nested login / poll JSON for `session_id` / `sessionId` and saves it for [postSessionGeo].
  Future<void> absorbSessionFromApiJson(Map<String, dynamic> json) async {
    final sid = meSendExtractSessionIdFromDynamic(json);
    if (sid != null && sid.isNotEmpty) {
      await setPushSessionId(sid);
      sdkPrint('Push session id absorbed from API JSON');
    }
  }

  Future<void> _postDeviceLink({
    required String userId,
    required bool setupSocket,
  }) async {
    if (!_ensureDeviceRegistered('api')) {
      return;
    }
    try {
      var deviceId = await getDeviceId();
      final deviceHeaders = await getDeviceHeaders();
      sdkPrint('LoginDeviceID: $deviceId');

      final url = '$serverUrl/pushapp/api/device/link';
      final requestHeaders = {
        'Content-Type': 'application/json',
        ...deviceHeaders,
      };
      sdkPrint(requestHeaders.toString());

      final requestBody = {
        'user_id': userId,
        'device_id': deviceId,
        'channel_id': channelId,
      };

      final response = await _meSendHttpPost(
        Uri.parse(url),
        headers: requestHeaders,
        body: jsonEncode(requestBody),
        label: 'device_link',
      );
      sdkPrint('json ${jsonEncode(requestBody)}');
      sdkPrint('Response Status Code : ${response.statusCode}');
      sdkPrint('Response : ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        sdkPrint('User registered successfully!');
        final sid = meSendExtractSessionIdFromBody(response.body);
        if (sid != null && sid.isNotEmpty) {
          await setPushSessionId(sid);
          sdkPrint('Push session id saved for geo API');
        }
        if (setupSocket) {
          _setupSocket(userId);
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', userId);
      } else {
        sdkPrint('Failed to register user: ${response.body}');
        throw Exception('Failed to register user: ${response.body}');
      }

    } on DeviceRegistrationPendingException {
      rethrow;
    } catch (e) {
      sdkPrint('Error registering user: $e');

      rethrow;
    }
  }

  /// Clears locally stored session state for [userId] after delink or account switch.
  Future<void> _clearLocalUserSession(String userId) async {
    if (userId.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('user_id') ?? '';
    if (stored == userId) {
      await prefs.remove('user_id');
      await _clearSessionIdPrefs(prefs);
    }
    if (this.userId == userId) {
      this.userId = '';
    }
  }

  /// Delinks [userId] from this device. Used by [logout] and account switch in [login].
  Future<void> _delinkUserFromDevice(
    String userId, {
    bool throwOnFailure = false,
  }) async {
    if (userId.isEmpty) {
      return;
    }

    _socketService.disconnect();

    if (!_deviceRegistered) {
      await _clearLocalUserSession(userId);
      return;
    }

    try {
      final deviceId = await getDeviceId();
      final deviceHeaders = await getDeviceHeaders();
      final url = '$serverUrl/pushapp/device/delink';
      final response = await _meSendHttpPost(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          ...deviceHeaders,
        },
        body: jsonEncode({
          'user_id': userId,
          'device_id': deviceId,
        }),
        label: 'device_delink',
      );

      if (response.statusCode == 200) {
        sdkPrint('User delinked: $userId');
        await _clearLocalUserSession(userId);
      } else if (throwOnFailure) {
        throw Exception('Failed to log out user: ${response.body}');
      } else {
        sdkPrint(
          'Delink failed (continuing): ${response.statusCode} ${response.body}',
        );
        await _clearLocalUserSession(userId);
      }
    } on DeviceRegistrationPendingException {
      rethrow;
    } catch (e) {
      if (throwOnFailure) {
        sdkPrint('Error logging out user: $e');
        rethrow;
      }
      sdkPrint('Delink error (continuing): $e');
      await _clearLocalUserSession(userId);
    }
  }

  /// Sends the userId to the server to register user.
  ///
  /// If another user is already linked on this device, the SDK delinks them first
  /// (server `device/delink` + local session clear) before linking [userId].
  ///
  /// If this device already has the same [userId] in prefs (repeat sign-in), still POSTs
  /// `device/link` to refresh [session id] for geo — without attaching a second socket.
  Future<void> login(String userId) async {
    await _loadDeviceRegistrationState();
    final prefs = await SharedPreferences.getInstance();
    final oldUserId = prefs.getString('user_id') ?? '';

    if (oldUserId.isNotEmpty && oldUserId != userId) {
      sdkPrint('PushApp: switching user from $oldUserId to $userId');
      await _delinkUserFromDevice(oldUserId);
    }

    this.userId = userId;

    if (!_deviceRegistered) {
      _pendingLoginUserId = userId;
      sdkPrint(
        'PushApp: login($userId) queued until device registration completes',
      );
      return;
    }

    await _loginNow(userId);
  }

  Future<void> _loginNow(String userId) async {
    final refreshSameUser = userId.isNotEmpty &&
        (await SharedPreferences.getInstance()).getString('user_id') == userId;
    if (refreshSameUser) {
      sdkPrint('Same user already linked — refreshing device/link for push session id');
    }

    await _postDeviceLink(
      userId: userId,
      setupSocket: !refreshSameUser,
    );
  }


  void setInAppNotification(BuildContext context) {
    final navigator = Navigator.maybeOf(context);
    final resolvedContext = navigator?.context ?? context;

    if (resolvedContext is Element && !resolvedContext.mounted) {
      sdkPrint('In-app context not mounted yet');
      return;
    }

    if (navigator == null) {
      sdkPrint(
        'In-app context has no Navigator ancestor; '
        'use MaterialApp.navigatorKey.currentContext',
      );
    } else {
      sdkPrint('In-app context set!');
    }

    buildContext = resolvedContext;
  }


  void _setupSocket(String userId) {
    sdkPrint("SocketStarted : $userId");
    _socketService.connect(
      userId,
      tenant,
      _hostTld,
      wsUrlOverride: _wsUrlOverride,
    );

    _socketService.notificationStream.listen((notification) {
      sdkPrint("Received notification: $notification");
      _pollForNotificationData(userId);
    });
  }


Future<void> ping() async {
    if (!_ensureDeviceRegistered('ping')) {
      return;
    }
    var deviceId = await getDeviceId();
    final contactId = "${userId}_$deviceId";

    // 3️⃣ Build URL
    final url = Uri.parse('$serverUrl/pushapp/api/ping');
    sdkPrint("Ping → $url");

    try {
      // 4️⃣ Device headers
      final deviceHeaders = await getDeviceHeaders();

      final requestHeaders = {
        'Content-Type': 'application/json',
        ...deviceHeaders,
      };

      sdkPrint("Attached device headers: $deviceHeaders");

      // 5️⃣ Payload
      final body = {
        "channel_id": channelId,
        "contact_id": contactId,
      };

      final jsonBody = jsonEncode(body);
      sdkPrint("Sending Ping Request: $url");
      sdkPrint("Payload: $jsonBody");

      // 6️⃣ API call
      final response = await _meSendHttpPost(
        url,
        headers: requestHeaders,
        body: jsonBody,
        label: 'ping',
      );

      sdkPrint("Ping Response Status: ${response.statusCode}");
      sdkPrint("Headers: ${response.headers}");

      if (response.body.isNotEmpty) {
        sdkPrint("Raw Ping Response: ${response.body}");
      }

      try {
        final json = jsonDecode(response.body);
        sdkPrint("Parsed Ping JSON: $json");
      } catch (e) {
        sdkPrint("Ping response is not valid JSON");
      }
    } catch (e) {
      sdkPrint("Ping request failed: $e");
    }
  }


  Future<void> createOrUpdateCustomerProfile({
    required Map<String, dynamic> additionalInfo,
    required Map<String, dynamic> cohorts,
    required String code,
    required void Function(bool success) completion,
  }) async {
    if (!_ensureDeviceRegistered('api')) {
      return;
    }
    final url = Uri.parse('$serverUrl/pushapp/api/v1/customer/profile?code='+code);
    sdkPrint("createOrUpdateCustomerProfile (PUT) → $url");

    try {
      // Get device headers
      final deviceHeaders = await getDeviceHeaders();

      final requestHeaders = {
        'Content-Type': 'application/json',
        ...deviceHeaders,
      };

      // Build request body
      final body = <String, dynamic>{
        'additionalInfo': additionalInfo, // free JSON
        'cohorts': cohorts,               // free JSON
        'code': code,
      };

      final jsonBody = jsonEncode(body);
      sdkPrint("Payload for customer profile (PUT):\n$jsonBody");

      // 🔁 PUT API request
      final response = await _meSendHttpPut(
        url,
        headers: requestHeaders,
        body: jsonBody,
        label: 'customer_profile',
      );

      sdkPrint("Customer profile (PUT) → Status: ${response.statusCode}");

      if (response.statusCode >= 200 && response.statusCode < 300) {
        completion(true);
      } else {
        sdkPrint("Failed response: ${response.body}");
        completion(false);
      }
    } catch (e) {
      sdkPrint("Customer profile PUT request failed: $e");


      completion(false);
    }
  }









  Future<void> sendEvent(String eventName, Map<String, dynamic> eventData) async {
    await _loadDeviceRegistrationState();
    if (!_deviceRegistered) {
      _pendingEvents.add((name: eventName, data: eventData));
      sdkPrint(
        'PushApp: sendEvent($eventName) queued until device registration completes',
      );
      return;
    }
    await _sendEventNow(eventName, eventData);
  }

  Future<void> _sendEventNow(
    String eventName,
    Map<String, dynamic> eventData,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    var userId = prefs.getString('user_id') ?? '';

    if (userId == "") {
      userId = guestId;
    }

    try {
      final deviceHeaders = await getDeviceHeaders();
      final url = '$serverUrl/pushapp/api/v1/event';
      final requestHeaders = {
        'Content-Type': 'application/json',
        ...deviceHeaders,
      };
      sdkPrint(requestHeaders.toString());

      final requestBody = {
        'user_id': userId,
        'channel_id': channelId,
        'event_name': eventName,
        'event_data': eventData,
      };

      sdkPrint(jsonEncode(requestBody));

      final response = await _meSendHttpPost(
        Uri.parse(url),
        headers: requestHeaders,
        body: jsonEncode(requestBody),
        label: 'event',
      );

      if (response.statusCode == 200) {
        sdkPrint("Event sent successfully!");
        _pollForNotificationData(this.userId);
      } else {
        sdkPrint("Failed to send event: ${response.body}");
      }

    } on DeviceRegistrationPendingException {
      rethrow;
    } catch (e) {
      sdkPrint("Error sending event: $e");

    }
  }



  /// Logs out the user and clears local session state for this device.
  Future<void> logout(String userId) async {
    if (!_ensureDeviceRegistered('logout')) {
      return;
    }
    await _delinkUserFromDevice(userId);
  }

  /// SharedPreferences key for API session id — matches JSON field `session_id`.
  /// Use this when reading session id outside the SDK (e.g. `prefs.getString(Pushapp.sessionIdPrefsKey)`).
  static const String sessionIdPrefsKey = 'session_id';

  /// Legacy key from earlier SDK builds; migrated on read.
  static const _prefLegacySessionIdKey = 'mesend_pushapp_session_id';

  static Future<void> _clearSessionIdPrefs(SharedPreferences prefs) async {
    await prefs.remove(sessionIdPrefsKey);
    await prefs.remove(_prefLegacySessionIdKey);
  }

  /// Persists `session_id` in SharedPreferences under [sessionIdPrefsKey].
  /// Used by [postSessionGeo]. Call when your app receives `session_id` / `sessionId` from login or session APIs.
  Future<void> setPushSessionId(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final t = sessionId.trim();
    if (t.isEmpty) {
      await _clearSessionIdPrefs(prefs);
    } else {
      await prefs.setString(sessionIdPrefsKey, t);
      await prefs.remove(_prefLegacySessionIdKey);
    }
  }

  /// Session id from SharedPreferences (`session_id` key), if any.
  Future<String?> getPushSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    final primary = prefs.getString(sessionIdPrefsKey);
    if (primary != null && primary.trim().isNotEmpty) {
      return primary.trim();
    }
    final legacy = prefs.getString(_prefLegacySessionIdKey);
    if (legacy != null && legacy.trim().isNotEmpty) {
      await prefs.setString(sessionIdPrefsKey, legacy.trim());
      await prefs.remove(_prefLegacySessionIdKey);
      return legacy.trim();
    }
    return null;
  }

  /// POST `$serverUrl/pushapp/api/session/geo` with the saved session id and [geo] as the `geoIP` body field.
  ///
  /// Returns `true` when the request was sent and the server returned 2xx. Returns `false` if no session id is stored or the request failed.
  Future<bool> postSessionGeo(PushSessionGeoData geo) async {
    if (!_ensureDeviceRegistered('postSessionGeo')) {
      return false;
    }
    final sessionId = await getPushSessionId();
    final url = '$serverUrl/pushapp/api/session/geo';
    if (sessionId == null || sessionId.isEmpty) {
      sdkPrint('postSessionGeo: no push session id; ensure login completed so device/link can persist session_id');
      return false;
    }
    try {
      final deviceHeaders = await getDeviceHeaders();
      final requestHeaders = {
        'Content-Type': 'application/json',
        ...deviceHeaders,
      };
      final requestBody = {
        'session_id': sessionId,
        'geoIP': geo.toGeoIpJson(),
      };
      final response = await _meSendHttpPost(
        Uri.parse(url),
        headers: requestHeaders,
        body: jsonEncode(requestBody),
        label: 'session_geo',
      );
      final ok = response.statusCode >= 200 && response.statusCode < 300;
      return ok;
    } on DeviceRegistrationPendingException {
      rethrow;
    } catch (e) {
      sdkPrint('postSessionGeo error: $e');
      return false;
    }
  }

  static const _key = "persistent_device_id";
  static String? _cachedDeviceId;

  static Future<String> getDeviceId() async {
    // If already loaded in memory
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    final prefs = await SharedPreferences.getInstance();
    final storedId = prefs.getString(_key);

    if (storedId != null) {
      _cachedDeviceId = storedId;
      return _cachedDeviceId!;
    }

    // First time: generate new ID
    final id = await AppSetId().getIdentifier();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    _cachedDeviceId = "${id}_$timestamp";

    // Persist to storage
    await prefs.setString(_key, _cachedDeviceId!);

    return _cachedDeviceId!;
  }


  final TooltipSdk sdk = TooltipSdk();
  Widget registerWidget({
    required String placeholderId,
    required Widget child,
  }) {
    sendEvent("widget_open", {"compare": placeholderId});
    return sdk.registerWidget(placeholderId: placeholderId, child: child);
  }


  Future<Map<String, String>> getDeviceHeaders() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final mediaData = PlatformDispatcher.instance.views.first.physicalSize;
    final orientation = mediaData.width > mediaData.height ? 'Landscape' : 'Portrait';

    final headers = <String, String>{
      'X-App-Version': packageInfo.version,
      'X-SDK-Version': packageInfo.buildNumber,
      'X-Screen-Resolution': '${mediaData.width.toInt()}x${mediaData.height.toInt()}',
      'X-Device-Orientation': orientation,
      'X-Bundle-ID': packageInfo.packageName,
      'X-Timezone': DateTime.now().timeZoneName,
      'X-Locale': Platform.localeName,
    };

    if (Platform.isAndroid) {
      final androidInfo = await PushappBase._deviceInfoPlugin.androidInfo;
      final deviceId = await getDeviceId();
      headers.addAll({
        'X-Device-Model': androidInfo.model,
        'X-OS-Name': 'ANDROID',
        'X-OS-Version': androidInfo.version.release,
        'X-Manufacturer': androidInfo.manufacturer,
        'X-API-Level': androidInfo.version.sdkInt.toString(),
        'X-Boot-Time': androidInfo.bootloader,
        'X-Device-ID': deviceId,
        'X-CPU-ABI': androidInfo.supportedAbis.join(', '),
      });

    } else if (Platform.isIOS) {
      final deviceId = await getDeviceId();
      final iosInfo = await PushappBase._deviceInfoPlugin.iosInfo;
      headers.addAll({
        'X-Device-Model': iosInfo.model,
        'X-OS-Name': 'IOS',
        'X-OS-Version': iosInfo.systemVersion,
        'X-System-Name': iosInfo.systemName,
        'X-Device-ID': deviceId,
        'X-Device-Name': iosInfo.name,
      });
    }
    return headers;
  }
}
