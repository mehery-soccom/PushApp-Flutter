part of mehery_sender;

mixin PushappCoreMixin on PushappBase {
  static const _prefCustomerProfilePayloadHashKey =
      'mesend_customer_profile_payload_hash';
  static const _prefCustomerProfileSyncedAtMsKey =
      'mesend_customer_profile_synced_at_ms';
  static const Duration _customerProfileMinSyncInterval =
      Duration(hours: 6);
  static const Duration _appOpenDebounceDuration = Duration(seconds: 2);
  static const int _networkRetryMaxAttempts = 5;
  static const Duration _networkRetryBaseDelay = Duration(seconds: 2);

  bool _isCustomerProfileSyncInFlight = false;
  Timer? _pendingAppOpenTimer;
  bool _appOpenSentInSession = false;
  Map<String, dynamic>? _pendingEventReferrer;

Future<void> track(Map<String, dynamic> event) async {
    if (!_ensureDeviceRegistered('track')) {
      return;
    }
    final url = Uri.parse('$serverUrl/pushapp/api/v1/notification/push/track');

    final tokenRaw = event['t'] ?? event['token'];
    final token = tokenRaw?.toString().trim();
    final eventName = event['event']?.toString().trim();
    final ctaId = event['ctaId'];

    if (token == null || token.isEmpty || eventName == null || eventName.isEmpty) {
      sdkPrint('PushApp: skipped push track — missing token or event');
      return;
    }

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
          await _runWithRetry(
            () => sendTokenToServer('android', token),
            label: 'device_register',
          );
          await prefs.setString('device_token', token);
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
          await _runWithRetry(
            () => sendTokenToServer('ios', apns, fcmToken: fcm),
            label: 'device_register',
          );
          await prefs.setString('device_token', apns);
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
        _scheduleAppOpen();
        await _retryPendingLoginIfNeeded();
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
        handleNotificationPayload(call.arguments);
        return null;
      default:
        sdkPrint('PushApp: ignored unknown MethodChannel call: ${call.method}');
        return null;
    }
  }


  Future<void> trackNotificationEvent(String token, String event, {String? ctaId}) async {
    final normalizedToken = token.trim();
    final normalizedEvent = event.trim();
    if (normalizedToken.isEmpty || normalizedEvent.isEmpty) {
      sdkPrint('PushApp: skipped trackNotificationEvent — empty token or event');
      return;
    }
    if (!_ensureDeviceRegistered('trackNotificationEvent')) {
      return;
    }
    final url = Uri.parse('$serverUrl/pushapp/api/v1/notification/push/track');

    final body = {
      't': normalizedToken,
      'event': normalizedEvent,
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
        final rawBody = response.body.trim();
        if (rawBody.isNotEmpty) {
          try {
            final responseData = jsonDecode(rawBody);
            sdkPrint(rawBody);
            await _absorbGuestIdFromRegisterResponse(responseData);
          } catch (e) {
            // Registration succeeded; tolerate non-JSON/empty response formats.
            sdkPrint('Register response parse skipped: $e');
          }
        } else {
          sdkPrint('Register response body empty');
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
    bool restoreGuestRegistration = false,
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
      final sessionId = await getPushSessionId();
      final url = '$serverUrl/pushapp/device/delink';
      final requestBody = <String, dynamic>{
        'user_id': userId,
        'device_id': deviceId,
      };
      if (sessionId != null && sessionId.isNotEmpty) {
        requestBody['session_id'] = sessionId;
      }
      final response = await _meSendHttpPost(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          ...deviceHeaders,
        },
        body: jsonEncode(requestBody),
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

    if (restoreGuestRegistration) {
      await _attemptGuestReRegistration();
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
      await _persistPendingLoginUserId(userId);
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

    try {
      await _runWithRetry(
        () => _postDeviceLink(
          userId: userId,
          setupSocket: !refreshSameUser,
        ),
        label: 'device_link',
      );
      await _clearPendingLoginUserId();
    } catch (e) {
      sdkPrint(
        'device/link failed after retries — staying guest; will retry on next app open: $e',
      );
      await _clearLocalUserSession(userId);
      await _persistPendingLoginUserId(userId);
      rethrow;
    }
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
      completion(false);
      return;
    }

    if (_isCustomerProfileSyncInFlight) {
      sdkPrint('Customer profile sync skipped — request already in flight');
      completion(false);
      return;
    }

    final normalizedCode = code.trim();
    if (normalizedCode.isEmpty) {
      completion(false);
      return;
    }

    final body = <String, dynamic>{
      'additionalInfo': additionalInfo,
      'cohorts': cohorts,
      'code': normalizedCode,
    };
    final fingerprintPayload = <String, dynamic>{
      'additionalInfo': _normalizeJsonValue(additionalInfo),
      'cohorts': _normalizeJsonValue(cohorts),
      'code': normalizedCode,
    };
    final payloadHash = _fingerprintFromJson(fingerprintPayload);
    final prefs = await SharedPreferences.getInstance();
    final lastHash = prefs.getString(_prefCustomerProfilePayloadHashKey) ?? '';
    final lastSyncedAtMs = prefs.getInt(_prefCustomerProfileSyncedAtMsKey) ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final isWithinCooldown = lastSyncedAtMs > 0 &&
        (nowMs - lastSyncedAtMs) < _customerProfileMinSyncInterval.inMilliseconds;

    if (lastHash == payloadHash && isWithinCooldown) {
      sdkPrint('Customer profile sync skipped — unchanged payload within cooldown');
      completion(true);
      return;
    }

    final url = Uri.parse(
      '$serverUrl/pushapp/api/v1/customer/profile?${Uri(queryParameters: {'code': normalizedCode}).query}',
    );
    sdkPrint('createOrUpdateCustomerProfile (PUT) → $url');

    _isCustomerProfileSyncInFlight = true;
    try {
      final deviceHeaders = await getDeviceHeaders();

      final requestHeaders = {
        'Content-Type': 'application/json',
        ...deviceHeaders,
      };

      final jsonBody = jsonEncode(body);
      sdkPrint('Payload for customer profile (PUT):\n$jsonBody');

      final response = await _meSendHttpPut(
        url,
        headers: requestHeaders,
        body: jsonBody,
        label: 'customer_profile',
      );

      sdkPrint('Customer profile (PUT) → Status: ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await prefs.setString(_prefCustomerProfilePayloadHashKey, payloadHash);
        await prefs.setInt(_prefCustomerProfileSyncedAtMsKey, nowMs);
        completion(true);
      } else {
        sdkPrint('Failed response: ${response.body}');
        completion(false);
      }
    } catch (e) {
      sdkPrint('Customer profile PUT request failed: $e');
      completion(false);
    } finally {
      _isCustomerProfileSyncInFlight = false;
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

  @override
  Future<bool> _sendEventNow(
    String name,
    Map<String, dynamic> data,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    var resolvedUserId = prefs.getString('user_id') ?? '';

    if (resolvedUserId.isEmpty) {
      await _hydrateGuestIdFromStorage();
      resolvedUserId = guestId;
    }

    if (resolvedUserId.isEmpty) {
      await _attemptGuestReRegistration();
      await _hydrateGuestIdFromStorage();
      resolvedUserId = guestId;
    }

    if (resolvedUserId.isEmpty) {
      sdkPrint('PushApp: skipped event $name — no user_id or guest_id');
      return false;
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
        'user_id': resolvedUserId,
        'channel_id': channelId,
        'event_name': name,
        'event_data': data,
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
        return true;
      } else {
        sdkPrint("Failed to send event: ${response.body}");
        return false;
      }

    } on DeviceRegistrationPendingException {
      rethrow;
    } catch (e) {
      sdkPrint("Error sending event: $e");
      return false;
    }
  }



  /// Logs out the user and clears local session state for this device.
  Future<void> logout(String userId) async {
    await _clearPendingLoginUserId();
    if (!_ensureDeviceRegistered('logout')) {
      return;
    }
    await _delinkUserFromDevice(
      userId,
      restoreGuestRegistration: true,
    );
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
      'X-SDK-Version': kPushappSdkVersion,
      'sdk_framework': kPushappSdkFramework,
      'sdk_version': kPushappSdkVersion,
      'X-Screen-Resolution': '${mediaData.width.toInt()}x${mediaData.height.toInt()}',
      'X-Device-Orientation': orientation,
      'X-Bundle-ID': packageInfo.packageName,
      'X-Timezone': DateTime.now().timeZoneName,
      'X-Locale': Platform.localeName,
    };

    final normalizedAppId = appId.trim();
    if (normalizedAppId.isNotEmpty) {
      headers['X-App-Id'] = normalizedAppId;
    }
    final normalizedAppSecret = appSecret.trim();
    if (normalizedAppSecret.isNotEmpty) {
      headers['X-App-Key'] = normalizedAppSecret;
    }

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

  /// Pass opened notification/deeplink payloads for one-time app_open attribution.
  void handleNotificationPayload(
    dynamic payload, {
    String sourceType = 'notification',
  }) {
    final map = meSendCoerceMap(payload);
    if (map == null) {
      return;
    }
    final referrer = _extractEventReferrer(map, sourceType: sourceType);
    if (referrer == null) {
      return;
    }
    _scheduleAppOpen(eventReferrer: referrer, immediate: true);
  }

  void _scheduleAppOpen({
    Map<String, dynamic>? eventReferrer,
    bool immediate = false,
  }) {
    if (eventReferrer != null) {
      _pendingEventReferrer = eventReferrer;
    }

    if (immediate) {
      _pendingAppOpenTimer?.cancel();
      _pendingAppOpenTimer = null;
      unawaited(_emitAppOpenEvent());
      return;
    }

    if (_appOpenSentInSession) {
      return;
    }

    _pendingAppOpenTimer?.cancel();
    _pendingAppOpenTimer = Timer(_appOpenDebounceDuration, () {
      unawaited(_emitAppOpenEvent());
    });
  }

  Future<void> _emitAppOpenEvent() async {
    _pendingAppOpenTimer?.cancel();
    _pendingAppOpenTimer = null;

    if (_appOpenSentInSession && _pendingEventReferrer == null) {
      return;
    }

    final eventData = <String, dynamic>{};
    if (_pendingEventReferrer != null) {
      eventData['event_referrer'] = _pendingEventReferrer;
      _pendingEventReferrer = null;
    }

    _appOpenSentInSession = true;
    await sendEvent('app_open', eventData);
  }

  Map<String, dynamic>? _extractEventReferrer(
    Map<String, dynamic> map, {
    String sourceType = 'notification',
  }) {
    final messageId = meSendParseString(
      map['messageId'] ?? map['message_id'] ?? map['id'],
    );
    final campaignId = meSendParseString(
      map['campaignId'] ?? map['campaign_id'] ?? map['campaign'],
    );
    final clickToken = meSendParseString(
      map['click_token'] ?? map['token'] ?? map['t'],
    );

    if (messageId.isEmpty && campaignId.isEmpty && clickToken.isEmpty) {
      return null;
    }

    final referrer = <String, dynamic>{
      'referrer_type': sourceType,
    };
    if (messageId.isNotEmpty) {
      referrer['message_id'] = messageId;
    }
    if (campaignId.isNotEmpty) {
      referrer['campaign_id'] = campaignId;
    }
    if (clickToken.isNotEmpty) {
      referrer['click_token'] = clickToken;
    }
    return referrer;
  }

  Future<void> _runWithRetry(
    Future<void> Function() operation, {
    required String label,
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= _networkRetryMaxAttempts; attempt++) {
      try {
        await operation();
        return;
      } catch (error) {
        lastError = error;
        final canRetry = attempt < _networkRetryMaxAttempts &&
            _shouldRetryOperationError(error);
        sdkPrint(
          '$label attempt $attempt failed${canRetry ? ' — retrying' : ''}: $error',
        );
        if (!canRetry) {
          rethrow;
        }
        await Future<void>.delayed(
          _networkRetryBaseDelay * attempt,
        );
      }
    }
    throw lastError ?? Exception('$label failed');
  }

  bool _shouldRetryOperationError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('socket') ||
        message.contains('timeout') ||
        message.contains('connection') ||
        message.contains('failed host lookup') ||
        message.contains('503') ||
        message.contains('502') ||
        message.contains('504');
  }

  Future<void> _absorbGuestIdFromRegisterResponse(dynamic responseData) async {
    if (responseData is! Map) {
      return;
    }
    final device = meSendCoerceMap(responseData['device']);
    final guestUserId = meSendParseString(device?['user_id']);
    if (guestUserId.isNotEmpty) {
      await _persistGuestId(guestUserId);
    }
  }

  Future<void> _attemptGuestReRegistration() async {
    if (!_deviceRegistered) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('device_token')?.trim();
    if (token == null || token.isEmpty) {
      sdkPrint('Guest re-registration skipped — no stored device token');
      return;
    }

    sdkPrint('Attempting guest re-registration after delink/logout');
    try {
      if (Platform.isAndroid) {
        await _refreshGuestRegistration('android', token);
      } else if (Platform.isIOS) {
        await _refreshGuestRegistration('ios', token);
      }
    } catch (e) {
      sdkPrint('Guest re-registration failed: $e');
    }
  }

  Future<void> _refreshGuestRegistration(String tokenType, String token) async {
    final url = '$serverUrl/pushapp/api/device/register';
    final deviceId = await getDeviceId();
    final deviceHeaders = await getDeviceHeaders();
    final requestBody = <String, dynamic>{
      'platform': tokenType,
      'token': token,
      'device_id': deviceId,
      'channel_id': channelId,
    };

    final response = await _meSendHttpPost(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        ...deviceHeaders,
      },
      body: jsonEncode(requestBody),
      label: 'guest_re_register',
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final responseData = jsonDecode(response.body);
      await _absorbGuestIdFromRegisterResponse(responseData);
      sdkPrint('Guest re-registration succeeded: guest_id=$guestId');
    } else {
      throw Exception(
        'Guest re-registration failed: ${response.statusCode} ${response.body}',
      );
    }
  }

  Object? _normalizeJsonValue(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is String || value is num || value is bool) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, nested) => MapEntry(key.toString(), _normalizeJsonValue(nested)),
      );
    }
    if (value is List) {
      return value.map(_normalizeJsonValue).toList();
    }
    return value.toString();
  }

  String _fingerprintFromJson(Object? value) {
    return jsonEncode(_normalizeJsonValue(value));
  }
}
