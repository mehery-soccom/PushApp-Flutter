library mehery_sender;

export 'foreground_push_notifications.dart';
export 'mesend_parsing.dart';
export 'sdk_logging.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:app_set_id/app_set_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'sdk_logging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:super_tooltip/super_tooltip.dart' as super_tooltip;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'foreground_push_notifications.dart';
import 'mesend_parsing.dart';

part 'api/config.dart';
part 'api/exceptions.dart';
part 'api/http_client.dart';
part 'api/registration_state.dart';
part 'api/session_geo.dart';
part 'api/server_config.dart';
part 'push/pushapp_core.dart';
part 'in_app/in_app.dart';
part 'push/pushapp_class.dart';
part 'websocket/socket_service.dart';
part 'widgets/tooltip_wrapper.dart';
part 'widgets/mesend_widget.dart';
part 'widgets/route_observer.dart';
part 'widgets/tooltip_sdk.dart';
part 'widgets/app_lifecycle.dart';
part 'push/background_handler.dart';

/// Compatibility alias for [Pushapp]. Prefer [Pushapp] in new code.
@Deprecated('Use Pushapp instead. MeSend will be removed in a future major release.')
typedef MeSend = Pushapp;
