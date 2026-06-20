part of mehery_sender;

class SocketService {
  WebSocketChannel? _channel;
  String? _userId;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  String? _tenant;
  String _hostTld = 'net';

  // Stream controller for notifications
  final _notificationController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get notificationStream => _notificationController.stream;

  // Connect to WebSocket
  String? _wsUrlOverride;

  void connect(
    String userId,
    String tenant,
    String hostTld, {
    String? wsUrlOverride,
  }) {
    sdkPrint("Connect Called");
    _userId = userId;
    _tenant = tenant;
    _hostTld = hostTld;
    _wsUrlOverride = wsUrlOverride;
    _connectToSocket();
  }

  void sdkPrint(String? message) {
    if (message == null) {
      return;
    }
    meherySenderLog(message, tag: 'WebSocket');
  }

  void _connectToSocket() {
    sdkPrint("Connect to socket Called");
    try {
      final wsUrl =
          _wsUrlOverride ?? 'wss://$_tenant.pushapp.$_hostTld/pushapp';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      sdkPrint(wsUrl);

      // Send authentication message
      _sendAuthMessage();

      // Listen for messages
      _channel!.stream.listen(
            (message) {
          _handleMessage(message);
        },
        onError: (error) {
          sdkPrint('Socket error: $error');
          _handleDisconnection();
        },
        onDone: () {
          sdkPrint('Socket connection closed');
          _handleDisconnection();
        },
      );

      _isConnected = true;
    } catch (e) {
      sdkPrint('Error connecting to socket: $e');
      _handleDisconnection();
    }
  }

  void _sendAuthMessage() async{
    if (_channel != null && _userId != null) {
      sdkPrint("Auth Called");
      var deviceId = await Pushapp.getDeviceId();
      // if (Platform.isAndroid) {
      // } else if (Platform.isIOS) {
      //   final iosInfo = await _deviceInfoPlugin.iosInfo;
      //   deviceId = iosInfo.identifierForVendor ?? '';
      // }
      sdkPrint(_userId!+"_"+deviceId);
      final authMessage = {
        'type': 'auth',
        'userId': _userId!+"_"+deviceId,
      };
      _channel!.sink.add(jsonEncode(authMessage));
    }
  }

  void _handleMessage(dynamic message) {
    try {
      sdkPrint(message);
      final data = jsonDecode(message);
      if (data is Map<String, dynamic>) {
        if(data.containsKey("action")){
          if (data["action"] == "POLL"){
            _notificationController.add(data);
          }
        }
        switch (data['type']) {
          case 'auth':
            if (data['status'] == 'success') {
              sdkPrint('Socket authenticated successfully');
            } else {
              sdkPrint('Socket authentication failed: ${data['message']}');
            }
            break;
          case 'in_app':
            _notificationController.add(data);
            break;
          case 'error':
            sdkPrint('Socket error: ${data['message']}');
            break;
        }
      }
    } catch (e) {
      sdkPrint('Error handling message: $e');
    }
  }

  void _handleDisconnection() {
    _isConnected = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isConnected) {
        _connectToSocket();
      }
    });
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _notificationController.close();
  }
}
