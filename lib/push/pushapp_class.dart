part of mehery_sender;

abstract class PushappBase {
  static PushappBase? _activeInstance;

  static PushappBase? get activeInstance => _activeInstance;

  static const String deviceRegistrationPendingMessage =
      kDeviceRegistrationPendingMessage;

  static const _prefDeviceRegistrationCompleteKey =
      'mesend_device_registration_complete';
  static const _prefAppInstallSentKey = 'mesend_app_install_sent';

  static const _prefGuestUserIdKey = 'mesend_guest_user_id';
  static const _prefPendingLoginUserIdKey = 'mesend_pending_login_user_id';

  late final String serverUrl;
  String? _wsUrlOverride;
  bool _deviceRegistered = false;

  bool get isDeviceRegistered => _deviceRegistered;

  MeSendDeviceRegistrationState _registrationSnapshot =
      MeSendDeviceRegistrationState.pending;

  /// Latest registration snapshot; use before subscribing to [registrationState].
  MeSendDeviceRegistrationState get registrationSnapshot => _registrationSnapshot;

  final StreamController<MeSendDeviceRegistrationState>
      _registrationStateController =
      StreamController<MeSendDeviceRegistrationState>.broadcast();

  /// Emits registration lifecycle updates: pending, registered, failed, token refresh.
  Stream<MeSendDeviceRegistrationState> get registrationState =>
      _registrationStateController.stream;

  /// Emits `true` when the device registers, `false` when registration is cleared.
  ///
  /// Prefer [registrationState] for failure reasons and token refresh events.
  Stream<bool> get deviceRegistrationState =>
      registrationState.map((state) => state.isRegistered);

  final List<({String name, Map<String, dynamic> data})> _pendingEvents = [];
  String? _pendingLoginUserId;

  List<Map<String, dynamic>> _notificationQueue = [];
  bool _isProcessingQueue = false;

  /// Identifies the overlay that currently owns the in-app queue slot.
  ///
  /// An overlay can report closure from several places — an in-content CTA, the
  /// close button, and the dialog route completing — so each release carries the
  /// id it was displayed with and stale ones are ignored. Without it a late
  /// callback could release a slot a newer overlay already took, showing two
  /// messages at once and skipping one.
  int _queueLatchId = 0;

  var mockJson = r'''
''';

  final String tenant;
  final String channelId;
  final String appId;
  final String appSecret;
  bool sandbox = false;

  /// When `true`, API/WebSocket hosts use **`.co.in`** (internal development only).
  bool developmentHost = false;

  late final String _hostTld;
  String userId = "";
  String guestId = "";
  BuildContext? buildContext;
  GlobalKey<NavigatorState>? _navigatorKey;

  /// Prefer this over [setInAppNotification] alone so overlays survive route
  /// changes. Pass the same key used for `MaterialApp.navigatorKey`.
  ///
  /// For automatic `page_open` / `page_closed` events, also pass
  /// [navigatorObservers] to `MaterialApp.navigatorObservers`.
  void attachNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  /// Navigator observers to register on `MaterialApp.navigatorObservers`.
  ///
  /// Includes [meSendRouteObserver] for automatic page tracking when routes use
  /// named [RouteSettings] (or fall back to the route debug label).
  List<NavigatorObserver> get navigatorObservers => [meSendRouteObserver];

  /// Returns a mounted context for in-app overlays, or `null` if unavailable.
  BuildContext? _resolveInAppContext() {
    final keyContext = _navigatorKey?.currentContext;
    if (keyContext != null && keyContext.mounted) {
      return keyContext;
    }

    final ctx = buildContext;
    if (ctx == null) {
      return null;
    }
    if (!ctx.mounted) {
      _clearInAppContext();
      sdkPrint('PushApp: in-app context unmounted — overlay skipped');
      return null;
    }
    return ctx;
  }

  void _clearInAppContext() {
    buildContext = null;
  }

  final MeSendRouteObserver meSendRouteObserver = MeSendRouteObserver();

  final SocketService _socketService = SocketService();

  static final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  static const _channel = MethodChannel(meherySenderMethodChannel);

  final Map<String, void Function(List<dynamic>, String, String)>
      _placeholderListeners = {};

  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get events => _controller.stream;

  PushappBase._({
    required this.tenant,
    required this.channelId,
    required this.appId,
    required this.appSecret,
    required this.sandbox,
    required this.developmentHost,
    String? serverUrlOverride,
  }) {
    _hostTld = pushappHostTld(
      sandbox: sandbox,
      developmentHost: developmentHost,
    );
    if (serverUrlOverride != null && serverUrlOverride.trim().isNotEmpty) {
      final parsed = parsePushappServerBase(serverUrlOverride);
      serverUrl = parsed.serverUrl;
      _wsUrlOverride = parsed.wsUrl;
      sdkPrint('PushApp API base override: $serverUrl');
    } else {
      serverUrl = 'https://$tenant.pushapp.$_hostTld';
    }
  }

  Future<bool> _sendEventNow(String name, Map<String, dynamic> data);
  Future<void> _loginNow(String userId);
  Future<void> _pollForNotificationData(String userId);

  void sdkPrint(String? message, {String? tag}) {
    if (message == null) {
      return;
    }
    meherySenderLog(message, tag: tag);
  }

  void _emitRegistrationState(MeSendDeviceRegistrationState state) {
    _registrationSnapshot = state;
    if (!_registrationStateController.isClosed) {
      _registrationStateController.add(state);
    }
  }

  Future<void> _failDeviceRegistration(String message) async {
    _deviceRegistered = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefDeviceRegistrationCompleteKey, false);
    _emitRegistrationState(MeSendDeviceRegistrationState.failed(message));
  }

  /// Returns `true` when registered. When not registered, logs and optionally
  /// throws only if [meherySenderStrictRegistrationMode] is enabled.
  bool _ensureDeviceRegistered(String operation) {
    if (_deviceRegistered) {
      return true;
    }
    sdkPrint('PushApp: $operation skipped — $deviceRegistrationPendingMessage');
    if (meherySenderStrictRegistrationMode) {
      throw DeviceRegistrationPendingException();
    }
    return false;
  }

  Future<void> _flushPendingAfterRegistration() async {
    if (!_deviceRegistered) {
      return;
    }

    await _sendAppInstallIfNeeded();

    final events = List<({String name, Map<String, dynamic> data})>.from(
      _pendingEvents,
    );
    _pendingEvents.clear();
    for (final event in events) {
      await _sendEventNow(event.name, event.data);
    }

    await _retryPendingLoginIfNeeded();
  }

  /// Retries a queued/failed [login] while staying guest if link still fails.
  Future<void> _retryPendingLoginIfNeeded() async {
    if (!_deviceRegistered) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final linkedUserId = prefs.getString('user_id') ?? '';
    if (linkedUserId.isNotEmpty) {
      await _clearPendingLoginUserId();
      return;
    }

    final pending =
        (_pendingLoginUserId ?? prefs.getString(_prefPendingLoginUserIdKey))
            ?.trim();
    _pendingLoginUserId = null;
    if (pending == null || pending.isEmpty) {
      return;
    }

    sdkPrint('Retrying pending login($pending)');
    try {
      await _loginNow(pending);
    } catch (e) {
      sdkPrint('Pending login retry failed — remaining guest: $e');
    }
  }

  Future<void> _persistPendingLoginUserId(String userId) async {
    final trimmed = userId.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _pendingLoginUserId = trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefPendingLoginUserIdKey, trimmed);
  }

  Future<void> _clearPendingLoginUserId() async {
    _pendingLoginUserId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefPendingLoginUserIdKey);
  }

  Future<void> _sendAppInstallIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadySent = prefs.getBool(_prefAppInstallSentKey) ?? false;
    if (alreadySent) {
      return;
    }

    final sent = await _sendEventNow(
      'app_install',
      {
        'source': 'sdk',
      },
    );
    if (sent) {
      await prefs.setBool(_prefAppInstallSentKey, true);
      sdkPrint('app_install sent and marked complete');
    } else {
      sdkPrint('app_install send failed/skipped; will retry later');
    }
  }

  Future<void> _loadDeviceRegistrationState() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceRegistered =
        prefs.getBool(_prefDeviceRegistrationCompleteKey) ?? false;
    await _hydrateGuestIdFromStorage();
    if (_deviceRegistered) {
      sdkPrint('Device registration complete (restored from cache)');
      _emitRegistrationState(
        MeSendDeviceRegistrationState.registered(restoredFromCache: true),
      );
    } else {
      _emitRegistrationState(MeSendDeviceRegistrationState.pending);
    }
  }

  Future<void> _markDeviceRegistered() async {
    _deviceRegistered = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefDeviceRegistrationCompleteKey, true);
    _emitRegistrationState(MeSendDeviceRegistrationState.registered());
    await _flushPendingAfterRegistration();
  }

  void _emitTokenRefreshed() {
    _emitRegistrationState(MeSendDeviceRegistrationState.tokenRefreshed);
  }

  Future<void> _hydrateGuestIdFromStorage() async {
    if (guestId.isNotEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefGuestUserIdKey);
    if (stored != null && stored.trim().isNotEmpty) {
      guestId = stored.trim();
    }
  }

  Future<void> _persistGuestId(String id) async {
    final trimmed = id.trim();
    guestId = trimmed;
    if (trimmed.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefGuestUserIdKey, trimmed);
  }
}

class Pushapp extends PushappBase with PushappCoreMixin, PushappInAppMixin {
  static Future<String> getDeviceId() => PushappCoreMixin.getDeviceId();

  factory Pushapp({
    required String identifier,
    String appId = '',
    String appSecret = '',
    bool sandbox = false,
    bool developmentHost = false,
    String? serverUrlOverride,
  }) {
    final parts = _parsePushappIdentifier(identifier);
    return Pushapp._(
      tenant: parts.tenant,
      channelId: parts.channelId,
      appId: appId,
      appSecret: appSecret,
      sandbox: sandbox,
      developmentHost: developmentHost,
      serverUrlOverride: serverUrlOverride,
    );
  }

  Pushapp._({
    required String tenant,
    required String channelId,
    required String appId,
    required String appSecret,
    required bool sandbox,
    required bool developmentHost,
    String? serverUrlOverride,
  }) : super._(
          tenant: tenant,
          channelId: channelId,
          appId: appId,
          appSecret: appSecret,
          sandbox: sandbox,
          developmentHost: developmentHost,
          serverUrlOverride: serverUrlOverride,
        ) {
    PushappBase._activeInstance = this;

    setMeSendNotificationOpenHandler((payload) {
      handleNotificationPayload(payload);
    });

    setMeSendNotificationActionHandler(_handlePushNotificationAction);

    if (!Platform.isIOS) {
      const eventChannel = EventChannel(meherySenderEventChannel);

      try {
        eventChannel.receiveBroadcastStream().listen(
          (data) {
            if (data is Map) {
              final event = Map<String, dynamic>.from(data);
              sdkPrint(
                'broadcast received: '
                '${const JsonEncoder.withIndent('  ').convert(event)}',
                tag: 'EventChannel',
              );
              _controller.add(event);
              track(event);
            } else {
              sdkPrint('broadcast received: $data', tag: 'EventChannel');
            }
          },
          onError: (Object error) {
            if (error is MissingPluginException ||
                error.toString().contains("mesend_event_channel")) {
              sdkPrint(
                "mesend_event_channel not available on host app; continuing without stream.",
              );
              return;
            }
            sdkPrint("Event channel error: $error");
          },
        );
      } on MissingPluginException {
        sdkPrint(
          "mesend_event_channel not available on host app; continuing without stream.",
        );
      }
    }
    meSendRouteObserver.attachSDK(this);
  }

  /// Tracks a tray CTA button tap and opens its URL.
  ///
  /// Mirrors the native `CTATrackingActivity` contract — event `cta` with the
  /// slot name (`action1`, …) as `ctaId` — so both display paths report the
  /// same analytics.
  Future<void> _handlePushNotificationAction(
    MeSendPushAction action,
    Map<String, dynamic> data,
  ) async {
    try {
      final clickToken = meSendParseString(data['click_token']).trim();
      if (clickToken.isEmpty) {
        sdkPrint('PushApp: push CTA tap without click_token — not tracked');
      } else {
        await trackNotificationEvent(clickToken, 'cta', ctaId: action.slot);
      }

      final url = action.url?.trim();
      if (url == null || url.isEmpty) {
        return;
      }
      final uri = Uri.tryParse(url);
      if (uri == null) {
        sdkPrint('PushApp: unparsable push CTA URL: $url');
        return;
      }
      if (!meSendIsCtaUrlAllowed(uri)) {
        sdkPrint('PushApp: blocked push CTA URL (not allowed): $uri');
        return;
      }
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        sdkPrint('PushApp: cannot launch push CTA URL: $uri');
      }
    } catch (e) {
      sdkPrint('PushApp: push CTA handling failed: $e');
    }
  }
}
