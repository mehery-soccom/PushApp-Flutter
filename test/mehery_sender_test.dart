import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mehery_sender/mehery_sender.dart';
import 'package:mehery_sender/mesend_parsing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('identifier parsing', () {
    test('parses full app id tenant_channel suffix', () {
      final parsed = parsePushappIdentifier('MeheryTestFlutter_1734160381705');
      expect(parsed.tenant, 'MeheryTestFlutter');
      expect(parsed.channelId, 'MeheryTestFlutter_1734160381705');
    });

    test('parses legacy tenant\$channel format', () {
      final parsed = parsePushappIdentifier('acme\$prod-channel-1');
      expect(parsed.tenant, 'acme');
      expect(parsed.channelId, 'prod-channel-1');
    });

    test('rejects empty identifier', () {
      expect(() => parsePushappIdentifier(''), throwsArgumentError);
      expect(() => parsePushappIdentifier('   '), throwsArgumentError);
    });

    test('rejects malformed legacy identifier', () {
      expect(() => parsePushappIdentifier('tenant\$'), throwsArgumentError);
      expect(() => parsePushappIdentifier(r'$channel'), throwsArgumentError);
    });

    test('Pushapp factory applies parsed tenant and channelId', () {
      final pushApp = Pushapp(identifier: 'demo_1751694691225');
      expect(pushApp.tenant, 'demo');
      expect(pushApp.channelId, 'demo_1751694691225');
      expect(pushApp.serverUrl, 'https://demo.pushapp.ai');
    });

    test('parsePushappServerBase normalizes trailing slashes and /pushapp', () {
      final parsed = parsePushappServerBase('https://ngrok.example/pushapp/');
      expect(parsed.serverUrl, 'https://ngrok.example');
      expect(parsed.wsUrl, 'wss://ngrok.example/pushapp');
    });

    test('pushappHostTld selects sandbox and development hosts', () {
      expect(pushappHostTld(sandbox: true), 'net');
      expect(pushappHostTld(sandbox: false), 'ai');
      expect(
        pushappHostTld(sandbox: false, developmentHost: true),
        'co.in',
      );
    });
  });

  group('payload parsing', () {
    test('meSendCoerceMap accepts Map and Map<String,dynamic>', () {
      expect(meSendCoerceMap({'a': 1}), {'a': 1});
      expect(meSendCoerceMap(<String, dynamic>{'b': 2}), {'b': 2});
      expect(meSendCoerceMap(null), isNull);
      expect(meSendCoerceMap('not-a-map'), isNull);
    });

    test('meSendParseString coerces non-string values', () {
      expect(meSendParseString(null), '');
      expect(meSendParseString(42), '42');
      expect(meSendParseString('hello'), 'hello');
      expect(meSendParseString(null, fallback: 'x'), 'x');
    });

    test('meSendParseHtmlContent requires a string', () {
      expect(meSendParseHtmlContent('<p>hi</p>'), '<p>hi</p>');
      expect(meSendParseHtmlContent(123), '');
      expect(meSendParseHtmlContent(null), '');
    });

    test('meSendParseBool handles bool, num, and string forms', () {
      expect(meSendParseBool(true), isTrue);
      expect(meSendParseBool(0), isFalse);
      expect(meSendParseBool('yes'), isTrue);
      expect(meSendParseBool('false'), isFalse);
      expect(meSendParseBool('maybe', fallback: true), isTrue);
    });

    test('meSendParseDouble handles int, double, and numeric strings', () {
      expect(meSendParseDouble(14), 14.0);
      expect(meSendParseDouble('12.5'), 12.5);
      expect(meSendParseDouble('bad', fallback: 3), 3.0);
    });

    test('meSendParseStringList maps list entries to strings', () {
      expect(meSendParseStringList(['bold', 1]), ['bold', '1']);
      expect(meSendParseStringList(null), isEmpty);
    });

    test('TooltipStyle.fromJson tolerates missing and wrong-type fields', () {
      final style = TooltipStyle.fromJson({
        'line_1': 123,
        'line1_font_size': '18',
        'line2_font_size': null,
        'line1_text_styles': ['bold'],
        'line1_icon': '&#128512;',
      });

      expect(style.line1, '123');
      expect(style.line1Size, 18.0);
      expect(style.line2Size, 12.0);
      expect(style.line1TextStyles, ['bold']);
      expect(style.line1Icon, isNotEmpty);
      expect(style.bgColor, '#000000');
    });
  });

  group('session id extraction', () {
    test('finds session_id at top level', () {
      expect(
        meSendExtractSessionIdFromDynamic({'session_id': ' abc '}),
        'abc',
      );
    });

    test('finds sessionId in nested device map', () {
      expect(
        meSendExtractSessionIdFromDynamic({
          'device': {'sessionId': 'sess-99'},
        }),
        'sess-99',
      );
    });

    test('finds session id inside results list', () {
      expect(
        meSendExtractSessionIdFromDynamic({
          'results': [
            {'messageId': 'm1'},
            {'session_id': 'from-list'},
          ],
        }),
        'from-list',
      );
    });

    test('returns null for invalid JSON body', () {
      expect(meSendExtractSessionIdFromBody('not-json'), isNull);
    });

    test('absorbSessionFromApiJson persists session for geo API', () async {
      SharedPreferences.setMockInitialValues({});
      final pushApp = Pushapp(identifier: 'demo_123');

      await pushApp.absorbSessionFromApiJson({
        'data': {'session_id': 'persist-me'},
      });

      expect(await pushApp.getPushSessionId(), 'persist-me');
    });
  });

  group('push type classification', () {
    RemoteMessage message({
      Map<String, String> data = const {},
      RemoteNotification? notification,
    }) {
      return RemoteMessage(data: data, notification: notification);
    }

    test('shows tray for standard notification with title and body', () {
      final payload = MeSendDataPushPayload.fromRemoteMessage(
        message(
          data: const {'type': 'notification', 'title': 'Hi', 'body': 'There'},
        ),
      );

      expect(payload.shouldShowTrayNotification, isTrue);
      expect(payload.displayTitle, 'Hi');
      expect(payload.displayBody, 'There');
    });

    test('skips tray for in-app-only types', () {
      for (final type in ['banner', 'roadblock', 'pip', 'tooltip', 'in_app']) {
        final payload = MeSendDataPushPayload.fromRemoteMessage(
          message(
            data: {'type': type, 'title': 'Title', 'body': 'Body'},
          ),
        );
        expect(
          payload.shouldShowTrayNotification,
          isFalse,
          reason: 'type $type should not show tray',
        );
      }
    });

    test('skips tray when there is no displayable content', () {
      final payload = MeSendDataPushPayload.fromRemoteMessage(
        message(data: const {'type': 'notification'}),
      );
      expect(payload.hasDisplayableContent, isFalse);
      expect(payload.shouldShowTrayNotification, isFalse);
    });

    test('uses notification block fields when data map is sparse', () {
      final payload = MeSendDataPushPayload.fromRemoteMessage(
        message(
          notification: const RemoteNotification(
            title: 'System title',
            body: 'System body',
          ),
        ),
      );

      expect(payload.displayTitle, 'System title');
      expect(payload.shouldShowTrayNotification, isTrue);
    });

    test('androidChannelId defaults and uses category', () {
      expect(
        MeSendDataPushPayload(
          category: 'Promo',
          title: 'x',
          body: 'y',
        ).androidChannelId,
        'mesend_promo',
      );
      expect(
        MeSendDataPushPayload(title: 'x', body: 'y').androidChannelId,
        'mesend_default',
      );
    });
  });

  group('registration gating', () {
    late bool previousStrictMode;

    setUp(() {
      previousStrictMode = meherySenderStrictRegistrationMode;
      meherySenderStrictRegistrationMode = false;
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() {
      meherySenderStrictRegistrationMode = previousStrictMode;
    });

    test('sendEvent queues without throwing when device is not registered', () async {
      final pushApp = Pushapp(identifier: 'demo_123');
      expect(pushApp.isDeviceRegistered, isFalse);

      await expectLater(
        pushApp.sendEvent('page_open', {'page': 'home'}),
        completes,
      );
      expect(pushApp.isDeviceRegistered, isFalse);
    });

    test('login queues without throwing when device is not registered', () async {
      final pushApp = Pushapp(identifier: 'demo_123');

      await expectLater(pushApp.login('user-1'), completes);
      expect(pushApp.isDeviceRegistered, isFalse);
    });

    test('initPage does not throw before registration completes', () {
      final pushApp = Pushapp(identifier: 'demo_123');
      expect(() => pushApp.initPage('dashboard'), returnsNormally);
    });

    test('track throws only in strict registration mode', () async {
      final pushApp = Pushapp(identifier: 'demo_123');

      await pushApp.track({'event': 'open', 't': 'token-1'});
      expect(pushApp.isDeviceRegistered, isFalse);

      meherySenderStrictRegistrationMode = true;
      await expectLater(
        pushApp.track({'event': 'open', 't': 'token-1'}),
        throwsA(isA<DeviceRegistrationPendingException>()),
      );
    });

    test('deviceRegistrationState emits when registration flag is restored', () async {
      SharedPreferences.setMockInitialValues({
        'mesend_device_registration_complete': true,
      });
      final pushApp = Pushapp(identifier: 'demo_123');

      final states = <bool>[];
      final sub = pushApp.deviceRegistrationState.listen(states.add);

      await pushApp.sendEvent('ping', {});
      await Future<void>.delayed(Duration.zero);

      expect(states, contains(true));
      expect(pushApp.isDeviceRegistered, isTrue);

      await sub.cancel();
    });
  });

  group('registration state API', () {
    setUp(() {
      meherySenderStrictRegistrationMode = false;
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(resetMeSendFirebaseListenersForTest);

    test('registrationSnapshot starts pending before load', () {
      final pushApp = Pushapp(identifier: 'demo_123');
      expect(
        pushApp.registrationSnapshot.status,
        MeSendDeviceRegistrationStatus.pending,
      );
      expect(pushApp.isDeviceRegistered, isFalse);
    });

    test('registrationState emits registered when flag is restored', () async {
      SharedPreferences.setMockInitialValues({
        'mesend_device_registration_complete': true,
      });
      final pushApp = Pushapp(identifier: 'demo_123');
      final states = <MeSendDeviceRegistrationState>[];
      final sub = pushApp.registrationState.listen(states.add);

      await pushApp.sendEvent('ping', {});
      await Future<void>.delayed(Duration.zero);

      expect(
        states,
        contains(
          isA<MeSendDeviceRegistrationState>().having(
            (s) => s.status,
            'status',
            MeSendDeviceRegistrationStatus.registered,
          ).having(
            (s) => s.restoredFromCache,
            'restoredFromCache',
            isTrue,
          ),
        ),
      );
      expect(pushApp.registrationSnapshot.isRegistered, isTrue);

      await sub.cancel();
    });

    test('registrationState emits failed when device register fails', () async {
      final pushApp = Pushapp(identifier: 'demo_123');
      final states = <MeSendDeviceRegistrationState>[];
      final sub = pushApp.registrationState.listen(states.add);

      try {
        await pushApp.sendTokenToServer('android', 'test-token');
      } catch (_) {
        // Network/plugins unavailable in unit tests.
      }
      await Future<void>.delayed(Duration.zero);

      expect(
        pushApp.registrationSnapshot.status,
        MeSendDeviceRegistrationStatus.failed,
      );
      expect(
        states,
        contains(
          isA<MeSendDeviceRegistrationState>().having(
            (s) => s.status,
            'status',
            MeSendDeviceRegistrationStatus.failed,
          ),
        ),
      );
      expect(pushApp.registrationSnapshot.isRegistered, isFalse);

      await sub.cancel();
    });

    test('deviceRegistrationState maps registered bool from registrationState', () async {
      SharedPreferences.setMockInitialValues({
        'mesend_device_registration_complete': true,
      });
      final pushApp = Pushapp(identifier: 'demo_123');
      final boolStates = <bool>[];
      final sub = pushApp.deviceRegistrationState.listen(boolStates.add);

      await pushApp.sendEvent('page_open', {'page': 'home'});
      await Future<void>.delayed(Duration.zero);

      expect(boolStates, contains(true));

      await sub.cancel();
    });
  });

  group('login account switch', () {
    setUp(() {
      meherySenderStrictRegistrationMode = false;
      SharedPreferences.setMockInitialValues({});
    });

    test('login switches to new userId when prefs hold a different user', () async {
      SharedPreferences.setMockInitialValues({
        'user_id': 'user-a',
        'persistent_device_id': 'test-device',
      });
      final pushApp = Pushapp(identifier: 'demo_123');

      await pushApp.login('user-b');

      expect(pushApp.userId, 'user-b');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_id'), isNot('user-a'));
    });

    test('login clears stored user before linking when device is registered', () async {
      SharedPreferences.setMockInitialValues({
        'user_id': 'user-a',
        'mesend_device_registration_complete': true,
        'persistent_device_id': 'test-device',
        'session_id': 'session-a',
      });
      final pushApp = Pushapp(identifier: 'demo_123');

      try {
        await pushApp.login('user-b');
      } catch (_) {
        // Network unavailable in unit tests; local switch should still run.
      }

      expect(pushApp.userId, 'user-b');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_id'), isNot('user-a'));
      expect(prefs.getString('session_id'), isNull);
    });

    test('login keeps same user for repeat sign-in', () async {
      SharedPreferences.setMockInitialValues({
        'user_id': 'user-a',
        'persistent_device_id': 'test-device',
      });
      final pushApp = Pushapp(identifier: 'demo_123');

      await pushApp.login('user-a');

      expect(pushApp.userId, 'user-a');
    });
  });

  group('background FCM Firebase init', () {
    tearDown(resetMeSendFirebaseBackgroundInitForTest);

    test('configureMeSendFirebaseBackgroundInit stores FlutterFire options', () {
      const options = FirebaseOptions(
        apiKey: 'test-key',
        appId: '1:123:android:abc',
        messagingSenderId: '123',
        projectId: 'test-project',
      );

      configureMeSendFirebaseBackgroundInit(options: options);

      expect(meSendConfiguredFirebaseBackgroundOptions, options);
    });

    test('ensureFirebaseInitializedForBackground returns false without options', () async {
      final ready =
          await MeSendPushNotificationDisplay.ensureFirebaseInitializedForBackground();
      expect(ready, isFalse);
    });

    test('ensureFirebaseInitializedForBackground attempts init when options provided', () async {
      const options = FirebaseOptions(
        apiKey: 'test-key',
        appId: '1:123:android:abc',
        messagingSenderId: '123',
        projectId: 'test-project',
      );

      await expectLater(
        MeSendPushNotificationDisplay.ensureFirebaseInitializedForBackground(
          options: options,
        ),
        throwsA(isA<PlatformException>()),
      );
    });

    test('MeSendDataPushPayload parses data-only title and body', () {
      final payload = MeSendDataPushPayload.fromRemoteMessage(
        RemoteMessage(
          data: const {
            'type': 'notification',
            'category': 'CONTENT_CATEGORY',
            'title': 'Test title',
            'body': 'Test body',
          },
        ),
      );

      expect(payload.title, 'Test title');
      expect(payload.body, 'Test body');
      expect(payload.shouldShowTrayNotification, isTrue);
    });

    test('MeSendDataPushPayload parses message1 and message2 data fields', () {
      final payload = MeSendDataPushPayload.fromRemoteMessage(
        RemoteMessage(
          data: const {
            'type': 'notification',
            'message1': 'Title from message1',
            'message2': 'Body from message2',
          },
        ),
      );

      expect(payload.title, 'Title from message1');
      expect(payload.body, 'Body from message2');
      expect(payload.shouldShowTrayNotification, isTrue);
    });
  });

  group('in-app template routing', () {
    test('meSendIsInlineInAppTemplateCode matches inline variants', () {
      expect(meSendIsInlineInAppTemplateCode('inline'), isTrue);
      expect(meSendIsInlineInAppTemplateCode('INLINE_BANNER'), isTrue);
      expect(meSendIsInlineInAppTemplateCode('banner'), isFalse);
    });

    test('meSendIsTooltipInAppTemplateCode matches tooltip only', () {
      expect(meSendIsTooltipInAppTemplateCode('tooltip'), isTrue);
      expect(meSendIsTooltipInAppTemplateCode('Tooltip'), isTrue);
      expect(meSendIsTooltipInAppTemplateCode('inline'), isFalse);
    });
  });

  group('FCM listener attachment', () {
    tearDown(resetMeSendFirebaseListenersForTest);

    test('listener attachment flag tracks single registration', () {
      expect(meSendFirebaseListenersAttachedForTest, isFalse);

      MeSendPushNotificationDisplay.markListenersAttachedForTest();
      expect(meSendFirebaseListenersAttachedForTest, isTrue);

      resetMeSendFirebaseListenersForTest();
      expect(meSendFirebaseListenersAttachedForTest, isFalse);
    });
  });

  group('trackNotification argument parsing', () {
    test('parses token and event from map', () {
      final args = meSendParseTrackNotificationArgs({
        'token': 'click-token',
        'event': 'cta',
        'ctaId': 'action1',
      });

      expect(args?.token, 'click-token');
      expect(args?.event, 'cta');
      expect(args?.ctaId, 'action1');
    });

    test('accepts legacy t alias for token', () {
      final args = meSendParseTrackNotificationArgs({
        't': 'legacy-token',
        'event': 'open',
      });

      expect(args?.token, 'legacy-token');
      expect(args?.event, 'open');
      expect(args?.ctaId, isNull);
    });

    test('returns null for non-map arguments', () {
      expect(meSendParseTrackNotificationArgs('bad'), isNull);
      expect(meSendParseTrackNotificationArgs(null), isNull);
    });

    test('returns null when token or event is missing', () {
      expect(meSendParseTrackNotificationArgs({'token': 'x'}), isNull);
      expect(meSendParseTrackNotificationArgs({'event': 'open'}), isNull);
      expect(meSendParseTrackNotificationArgs({}), isNull);
    });
  });

  group('Android native method channel', () {
    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel(meherySenderMethodChannel),
        null,
      );
    });

    test('routes ping from native to Pushapp handler', () async {
      SharedPreferences.setMockInitialValues({
        'mesend_device_registration_complete': true,
      });
      final pushApp = Pushapp(identifier: 'demo_123');
      pushApp.setupMethodChannelHandler();

      Object? channelError;
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        meherySenderMethodChannel,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('ping'),
        ),
        (data) {
          if (data != null) {
            channelError = const StandardMethodCodec().decodeEnvelope(data);
          }
        },
      );

      expect(channelError, isNull);
    });

    test('routes trackNotification from native to Pushapp handler', () async {
      SharedPreferences.setMockInitialValues({
        'mesend_device_registration_complete': true,
      });
      final pushApp = Pushapp(identifier: 'demo_123');
      pushApp.setupMethodChannelHandler();

      Object? channelError;
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        meherySenderMethodChannel,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('trackNotification', {
            'token': 'click-token',
            'event': 'cta',
            'ctaId': 'action1',
          }),
        ),
        (data) {
          if (data != null) {
            channelError = const StandardMethodCodec().decodeEnvelope(data);
          }
        },
      );

      expect(channelError, isNull);
    });

    test('ignores malformed trackNotification payloads without channel error', () async {
      final pushApp = Pushapp(identifier: 'demo_123');
      pushApp.setupMethodChannelHandler();

      Object? channelError;
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        meherySenderMethodChannel,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('trackNotification', 'not-a-map'),
        ),
        (data) {
          if (data != null) {
            channelError = const StandardMethodCodec().decodeEnvelope(data);
          }
        },
      );

      expect(channelError, isNull);
    });

    test('ignores trackNotification map missing required fields', () async {
      final pushApp = Pushapp(identifier: 'demo_123');
      pushApp.setupMethodChannelHandler();

      Object? channelError;
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        meherySenderMethodChannel,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('trackNotification', {'token': 'only-token'}),
        ),
        (data) {
          if (data != null) {
            channelError = const StandardMethodCodec().decodeEnvelope(data);
          }
        },
      );

      expect(channelError, isNull);
    });

    test('ignores unknown method channel calls', () async {
      final pushApp = Pushapp(identifier: 'demo_123');
      pushApp.setupMethodChannelHandler();

      Object? channelError;
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        meherySenderMethodChannel,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('unknownMethod'),
        ),
        (data) {
          if (data != null) {
            channelError = const StandardMethodCodec().decodeEnvelope(data);
          }
        },
      );

      expect(channelError, isNull);
    });
  });

  group('Android EventChannel CTA payload', () {
    test('native bridge payload matches track() field names', () {
      const nativePayload = {
        'token': 'click-token-1',
        'event': 'cta',
        'ctaId': 'action1',
      };

      final token = nativePayload['t'] ?? nativePayload['token'];
      final eventName = nativePayload['event'];
      final ctaId = nativePayload['ctaId'];

      expect(token, 'click-token-1');
      expect(eventName, 'cta');
      expect(ctaId, 'action1');
    });
  });

  group('API logging', () {
    tearDown(() {
      meherySenderApiLoggingEnabled = kDebugMode;
    });

    test('meherySenderApiLoggingEnabled defaults to kDebugMode', () {
      expect(meherySenderApiLoggingEnabled, kDebugMode);
    });

    test('sdkPrint is silent when API logging is disabled', () {
      meherySenderApiLoggingEnabled = false;
      final pushApp = Pushapp(identifier: 'demo_123');

      expect(() => pushApp.sdkPrint('secret-token-log'), returnsNormally);
    });
  });

  group('initializeAndSendToken', () {
    setUp(() {
      meherySenderStrictRegistrationMode = false;
      SharedPreferences.setMockInitialValues({});
      resetMeSendFirebaseListenersForTest();
    });

    tearDown(resetMeSendFirebaseListenersForTest);

    test('returns false without throwing on unsupported test platform', () async {
      final pushApp = Pushapp(identifier: 'demo_123');

      final ok = await pushApp.initializeAndSendToken(
        fcmToken: 'test-fcm',
        apnsToken: 'test-apns',
      );

      expect(ok, isFalse);
      expect(
        pushApp.registrationSnapshot.status,
        MeSendDeviceRegistrationStatus.failed,
      );
    });

    test('returns false for null tokens without strict mode', () async {
      final pushApp = Pushapp(identifier: 'demo_123');

      final ok = await pushApp.initializeAndSendToken(
        fcmToken: null,
        apnsToken: null,
      );

      expect(ok, isFalse);
      expect(
        pushApp.registrationSnapshot.status,
        MeSendDeviceRegistrationStatus.failed,
      );
    });
  });

  group('in-app template parsing', () {
    test('getAlignment tolerates missing and wrong-type align fields', () {
      final pushApp = Pushapp(identifier: 'demo_123');

      expect(pushApp.getAlignment({}), 'bottom-right');
      expect(
        pushApp.getAlignment({
          'vertical_align': 123,
          'horizontal_align': null,
        }),
        'bottom-right',
      );
      expect(
        pushApp.getAlignment({
          'vertical_align': 'flex-start',
          'horizontal_align': 'center',
        }),
        'top-center',
      );
    });

    test('meSendParseBool handles floater draggable variants', () {
      expect(meSendParseBool(null), isFalse);
      expect(meSendParseBool(true), isTrue);
      expect(meSendParseBool('true'), isTrue);
      expect(meSendParseBool('false'), isFalse);
      expect(meSendParseBool(1), isTrue);
      expect(meSendParseBool('not-a-bool'), isFalse);
    });

    test('meSendParseHtmlContent rejects non-string html', () {
      expect(meSendParseHtmlContent('<p>ok</p>'), '<p>ok</p>');
      expect(meSendParseHtmlContent(42), '');
      expect(meSendParseHtmlContent(null), '');
    });
  });

  group('CTA URL allowlist', () {
    tearDown(() {
      meherySenderCtaUrlAllowedHosts = [];
      meherySenderCtaUrlValidator = null;
    });

    test('meSendIsCtaUrlAllowed permits all http(s) when allowlist empty', () {
      expect(
        meSendIsCtaUrlAllowed(Uri.parse('https://any.example.org/path')),
        isTrue,
      );
    });

    test('meSendIsCtaUrlAllowed matches host and subdomains', () {
      meherySenderCtaUrlAllowedHosts = ['example.com'];

      expect(
        meSendIsCtaUrlAllowed(Uri.parse('https://example.com/a')),
        isTrue,
      );
      expect(
        meSendIsCtaUrlAllowed(Uri.parse('https://app.example.com/a')),
        isTrue,
      );
      expect(
        meSendIsCtaUrlAllowed(Uri.parse('https://notexample.com/a')),
        isFalse,
      );
    });

    test('meherySenderCtaUrlValidator overrides allowlist', () {
      meherySenderCtaUrlAllowedHosts = ['example.com'];
      meherySenderCtaUrlValidator = (uri) => uri.scheme == 'https';

      expect(
        meSendIsCtaUrlAllowed(Uri.parse('https://example.com')),
        isTrue,
      );
      expect(
        meSendIsCtaUrlAllowed(Uri.parse('http://example.com')),
        isFalse,
      );
    });
  });

  group('in-app context guards', () {
    testWidgets('attachNavigatorKey resolves mounted overlay context', (
      WidgetTester tester,
    ) async {
      final navKey = GlobalKey<NavigatorState>();
      final pushApp = Pushapp(identifier: 'demo_123');
      pushApp.attachNavigatorKey(navKey);

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: const Scaffold(body: Text('home')),
        ),
      );

      pushApp.setInAppNotification(navKey.currentContext!);
      expect(navKey.currentContext!.mounted, isTrue);
    });
  });

  group('route observer', () {
    test('Pushapp exposes navigatorObservers for MaterialApp', () {
      final pushApp = Pushapp(identifier: 'demo_123');

      expect(pushApp.navigatorObservers, contains(pushApp.meSendRouteObserver));
      expect(pushApp.navigatorObservers, hasLength(1));
    });

    test('MeSendRouteObserver tracks navigation without throwing', () {
      final pushApp = Pushapp(identifier: 'demo_123');
      final observer = pushApp.meSendRouteObserver;

      final loginRoute = MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'login'),
        builder: (_) => const SizedBox(),
      );
      final dashboardRoute = MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'dashboard'),
        builder: (_) => const SizedBox(),
      );

      expect(() => observer.didPush(dashboardRoute, loginRoute), returnsNormally);
      expect(() => observer.didPop(dashboardRoute, loginRoute), returnsNormally);
      expect(
        () => observer.didReplace(newRoute: dashboardRoute, oldRoute: loginRoute),
        returnsNormally,
      );
    });
  });
}
