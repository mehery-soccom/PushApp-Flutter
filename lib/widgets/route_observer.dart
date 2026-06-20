part of mehery_sender;

/// Tracks Flutter navigation and sends `page_open` / `page_closed` analytics events.
///
/// Wire via [Pushapp.navigatorObservers] on `MaterialApp.navigatorObservers`.
/// The SDK attaches itself in the [Pushapp] constructor; no manual [attachSDK] needed.
class MeSendRouteObserver extends NavigatorObserver {
  static final MeSendRouteObserver _instance = MeSendRouteObserver._internal();
  factory MeSendRouteObserver() => _instance;
  MeSendRouteObserver._internal();

  Pushapp? _meSend;

  void attachSDK(Pushapp sdkInstance) {
    _meSend = sdkInstance;
  }

  String _pageName(Route<dynamic> route) {
    final name = route.settings.name;
    if (name != null && name.trim().isNotEmpty) {
      return name.trim();
    }
    return route.toString();
  }

  void _sendPageOpen(String page) {
    _meSend?.sendEvent('page_open', {'page': page});
  }

  void _sendPageClosed(String page) {
    _meSend?.sendEvent('page_closed', {'page': page});
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final sdk = _meSend;
    if (sdk == null) {
      return;
    }

    if (previousRoute != null) {
      _sendPageClosed(_pageName(previousRoute));
    }
    _sendPageOpen(_pageName(route));
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final sdk = _meSend;
    if (sdk == null) {
      return;
    }

    _sendPageClosed(_pageName(route));
    if (previousRoute != null) {
      _sendPageOpen(_pageName(previousRoute));
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final sdk = _meSend;
    if (sdk == null) {
      return;
    }

    if (oldRoute != null) {
      _sendPageClosed(_pageName(oldRoute));
    }
    if (newRoute != null) {
      _sendPageOpen(_pageName(newRoute));
    }
  }
}
