part of mehery_sender;

const int _meSendApiLogBodyMaxChars = 4000;

String _meSendFormatPayloadForLog(dynamic value) {
  if (value == null) {
    return '';
  }
  if (value is String) {
    return value;
  }
  try {
    return jsonEncode(value);
  } catch (_) {
    return value.toString();
  }
}

String _meSendTruncateForApiLog(String value) {
  if (value.length <= _meSendApiLogBodyMaxChars) {
    return value;
  }
  return '${value.substring(0, _meSendApiLogBodyMaxChars)}...(truncated)';
}

void _meSendLogApi({
  required String phase,
  required String method,
  required String url,
  int? statusCode,
  int? durationMs,
  Map<String, String>? headers,
  String? body,
  String? label,
}) {
  if (!meherySenderApiLoggingEnabled) {
    return;
  }

  final tag = label == null || label.isEmpty ? 'API' : 'API|$label';
  final buffer = StringBuffer('$phase $method $url');
  if (statusCode != null) {
    buffer.write(' status=$statusCode');
  }
  if (durationMs != null) {
    buffer.write(' ${durationMs}ms');
  }
  meherySenderLog(buffer.toString(), tag: tag);

  if (headers != null && headers.isNotEmpty) {
    meherySenderLog(
      'headers: ${_meSendTruncateForApiLog(headers.toString())}',
      tag: tag,
    );
  }
  if (body != null && body.isNotEmpty) {
    meherySenderLog(
      'body: ${_meSendTruncateForApiLog(body)}',
      tag: tag,
    );
  }
}
void _meSendRequireDeviceRegistration(Uri url) {
  final u = url.toString();
  if (!u.contains('/pushapp/')) {
    return;
  }
  if (u.contains('/pushapp/api/device/register')) {
    return;
  }
  final sdk = PushappBase._activeInstance;
  if (sdk == null || !sdk.isDeviceRegistered) {
    if (meherySenderStrictRegistrationMode) {
      throw DeviceRegistrationPendingException();
    }
  }
}

http.Response? _meSendSkippedResponseIfNotRegistered(Uri url, String? label) {
  final u = url.toString();
  if (!u.contains('/pushapp/') || u.contains('/pushapp/api/device/register')) {
    return null;
  }
  final sdk = PushappBase._activeInstance;
  if (sdk == null || sdk.isDeviceRegistered) {
    return null;
  }
  if (meherySenderStrictRegistrationMode) {
    throw DeviceRegistrationPendingException();
  }
  debugPrint(
    'PushApp: skipped HTTP request (registration pending)${label != null ? ' [$label]' : ''}',
  );
  return http.Response('Device registration pending', 503);
}

Future<http.Response> _httpPost(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) {
  return http.post(url, headers: headers, body: body, encoding: encoding);
}

Future<http.Response> _httpPut(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) {
  return http.put(url, headers: headers, body: body, encoding: encoding);
}

Future<http.Response> _meSendHttpPost(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
  String? label,
  bool skipApiLog = false,
}) async {
  _meSendRequireDeviceRegistration(url);
  final skipped = _meSendSkippedResponseIfNotRegistered(url, label);
  if (skipped != null) {
    return skipped;
  }
  final bodyForLog = _meSendFormatPayloadForLog(body);
  if (!skipApiLog) {
    _meSendLogApi(
      phase: '→',
      method: 'POST',
      url: url.toString(),
      headers: headers,
      body: bodyForLog,
      label: label,
    );
  }

  final stopwatch = Stopwatch()..start();
  try {
    final response = await _httpPost(
      url,
      headers: headers,
      body: body,
      encoding: encoding,
    );
    if (!skipApiLog) {
      _meSendLogApi(
        phase: '←',
        method: 'POST',
        url: url.toString(),
        statusCode: response.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
        body: response.body,
        label: label,
      );
    }
    return response;
  } catch (error, stackTrace) {
    if (!skipApiLog && meherySenderApiLoggingEnabled) {
      meherySenderLog(
        '✗ POST ${url.toString()} ${stopwatch.elapsedMilliseconds}ms error=$error',
        tag: 'API',
      );
      meherySenderLog('$stackTrace', tag: 'API');
    }
    rethrow;
  }
}

Future<http.Response> _meSendHttpPut(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
  String? label,
  bool skipApiLog = false,
}) async {
  _meSendRequireDeviceRegistration(url);
  final skipped = _meSendSkippedResponseIfNotRegistered(url, label);
  if (skipped != null) {
    return skipped;
  }
  final bodyForLog = _meSendFormatPayloadForLog(body);
  if (!skipApiLog) {
    _meSendLogApi(
      phase: '→',
      method: 'PUT',
      url: url.toString(),
      headers: headers,
      body: bodyForLog,
      label: label,
    );
  }

  final stopwatch = Stopwatch()..start();
  try {
    final response = await _httpPut(
      url,
      headers: headers,
      body: body,
      encoding: encoding,
    );
    if (!skipApiLog) {
      _meSendLogApi(
        phase: '←',
        method: 'PUT',
        url: url.toString(),
        statusCode: response.statusCode,
        durationMs: stopwatch.elapsedMilliseconds,
        body: response.body,
        label: label,
      );
    }
    return response;
  } catch (error, stackTrace) {
    if (!skipApiLog && meherySenderApiLoggingEnabled) {
      meherySenderLog(
        '✗ PUT ${url.toString()} ${stopwatch.elapsedMilliseconds}ms error=$error',
        tag: 'API',
      );
      meherySenderLog('$stackTrace', tag: 'API');
    }
    rethrow;
  }
}
