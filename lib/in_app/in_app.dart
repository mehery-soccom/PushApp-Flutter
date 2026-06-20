part of mehery_sender;

mixin PushappInAppMixin on PushappCoreMixin {
Future<void> _pollForNotificationData(String userId) async {
      if (!isDeviceRegistered) {
      sdkPrint(PushappBase.deviceRegistrationPendingMessage);
      return;
    }
    sdkPrint("poll calling");
    try {
      var deviceId = await Pushapp.getDeviceId();
      final deviceHeaders = await getDeviceHeaders();
      final contactId = "${userId}_$deviceId";
      sdkPrint(contactId);

      final url = '$serverUrl/pushapp/api/v1/notification/in-app/poll';
      final requestHeaders = {
        'Content-Type': 'application/json',
        ...deviceHeaders,
      };
      final requestBody = {
        'contact_id': contactId,
      };

      // Make HTTP request to poll endpoint
      final response = await _meSendHttpPost(
        Uri.parse(url),
        headers: requestHeaders,
        body: jsonEncode(requestBody),
        label: 'in_app_poll',
      );
      sdkPrint("Poll response body: ${response.body}");

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        sdkPrint("Poll response data: $responseData");

        if (responseData['success'] == true) {
          sdkPrint("Result Poll");
          final results = responseData['results'];

          if (results is List && results.isNotEmpty) {
            final inlineItems = <Map<String, dynamic>>[];
            final tooltipItems = <Map<String, dynamic>>[];
            final overlayItems = <Map<String, dynamic>>[];

            for (final raw in results) {
              final item = meSendCoerceMap(raw);
              if (item == null) {
                continue;
              }
              final style = meSendCoerceMap(item['template']?['style']);
              final code = meSendParseString(style?['code']);
              if (meSendIsTooltipInAppTemplateCode(code) &&
                  item['event']?['event_data']?['compare'] != null) {
                tooltipItems.add(item);
              } else if (meSendIsInlineInAppTemplateCode(code)) {
                inlineItems.add(item);
              } else {
                overlayItems.add(item);
              }
            }

            // Inline slots render in-place and must not wait for tooltips/overlays.
            for (final item in inlineItems) {
              try {
                await _dispatchInlineInAppMessage(item);
              } catch (e) {
                sdkPrint('Error dispatching inline in-app: $e');
              }
            }

            for (final item in tooltipItems) {
              try {
                await _showTooltipFromPollResult(item, contactId);
              } catch (e) {
                sdkPrint('Error showing tooltip in-app: $e');
              }
            }

            for (final item in overlayItems) {
              _notificationQueue.add(item);
            }

            _processNextFromQueue();
          } else {
            sdkPrint("No new notifications from poll — keeping existing queue.");
          }
        } else {
          sdkPrint("Poll failed: ${responseData['message']}");
        }
      } else {
        sdkPrint("Poll request failed with status: ${response.statusCode}");
        sdkPrint("Response body: ${response.body}");
      }
    } catch (e) {
      sdkPrint("Error polling for notification data: $e");
    }
  }


  Future<void> _dispatchInlineInAppMessage(Map<String, dynamic> data) async {
    final templateStyle =
        meSendCoerceMap(data['template']?['style']) ?? <String, dynamic>{};
    final htmlContent = meSendParseHtmlContent(templateStyle['html']);
    final placeholderId = meSendParseString(
      data['event']?['event_data']?['compare'],
    );
    final messageId = meSendParseString(data['messageId']);
    final filterId = meSendParseString(data['filterId']);

    final deviceId = await Pushapp.getDeviceId();
    final contactId = '${userId}_$deviceId';
    if (messageId.isNotEmpty && contactId.isNotEmpty) {
      await ackNotification(contactId, messageId);
    }

    if (placeholderId.isEmpty || htmlContent.isEmpty) {
      sdkPrint('Inline in-app skipped — missing placeholder or html');
      return;
    }

    sdkPrint('Dispatching inline in-app to placeholder: $placeholderId');
    _notifyPlaceholder(placeholderId, [htmlContent], messageId, filterId);
  }

  Future<void> _showTooltipFromPollResult(
    Map<String, dynamic> item,
    String contactId,
  ) async {
    final compareId = meSendParseString(
      item['event']?['event_data']?['compare'],
    );
    if (compareId.isEmpty) {
      return;
    }

    final sdk = TooltipSdk();
    sdk.processApiResponse({'results': [item]});
    await sdk.showTooltipFor(compareId);

    final messageId = meSendParseString(item['messageId']);
    if (messageId.isNotEmpty && contactId.isNotEmpty) {
      await ackNotification(contactId, messageId);
    }
  }

  void _onNotificationClosed() {
    _isProcessingQueue = false;
    _processNextFromQueue();
  }

  void _processNextFromQueue() {
    sdkPrint("Queue");
    sdkPrint(' queue data ${_notificationQueue.length}');

    while (_notificationQueue.isNotEmpty) {
      final peek = meSendCoerceMap(_notificationQueue.first);
      if (peek == null) {
        _notificationQueue.removeAt(0);
        continue;
      }
      final code = meSendParseString(
        meSendCoerceMap(peek['template']?['style'])?['code'],
      );
      if (meSendIsInlineInAppTemplateCode(code)) {
        _notificationQueue.removeAt(0);
        unawaited(_dispatchInlineInAppMessage(peek));
        continue;
      }
      break;
    }

    if (_isProcessingQueue || _notificationQueue.isEmpty) {
      return;
    }

    _isProcessingQueue = true;

    final nextItem = _notificationQueue.removeAt(0);
    sdkPrint("Showing queued notification: $nextItem");

    _processNotificationData(nextItem);
  }

  String getAlignment(Map<String, dynamic> style) {
    sdkPrint(style.toString());
    final vertical =
        meSendParseString(style['vertical_align'], fallback: 'flex-end');
    final horizontal =
        meSendParseString(style['horizontal_align'], fallback: 'flex-end');

    String verticalPart;
    switch (vertical) {
      case 'flex-start':
        verticalPart = 'top';
        break;
      case 'center':
        verticalPart = 'center';
        break;
      case 'flex-end':
      default:
        verticalPart = 'bottom';
    }

    String horizontalPart;
    switch (horizontal) {
      case 'flex-start':
        horizontalPart = 'left';
        break;
      case 'center':
        horizontalPart = 'center';
        break;
      case 'flex-end':
      default:
        horizontalPart = 'right';
    }

    return '$verticalPart-$horizontalPart';
  }


// ✅ NEW: Method to process notification data (extracted from existing logic)
  void _processNotificationData(Map<String, dynamic> data) async{
    final templateStyle =
        meSendCoerceMap(data['template']?['style']) ?? <String, dynamic>{};
    final type = meSendParseString(templateStyle['code']);
    final htmlContent = meSendParseHtmlContent(templateStyle['html']);
    final contentList = htmlContent.isNotEmpty ? [htmlContent] : [];
    final style = templateStyle;

    sdkPrint("Processing notification data - Type: $type");

    // ✅ Get contact_id and messageId for ACK
    final messageId = meSendParseString(data['messageId']);
    final filterId = meSendParseString(data['filterId']);
    var deviceId = await Pushapp.getDeviceId();
    final contactId = "${userId}_$deviceId";

    // 🔔 Immediately send ACK for the notification
    if (messageId.isNotEmpty && contactId.isNotEmpty) {
      await ackNotification(contactId, messageId);
    }

    final overlayContext = _resolveInAppContext();
    if (overlayContext == null &&
        type.isNotEmpty &&
        !type.toLowerCase().contains('inline')) {
      sdkPrint('In-app overlay skipped — no mounted navigator context');
      _onNotificationClosed();
      return;
    }

    if (type.toLowerCase().contains('popup') ||
        type.toLowerCase().contains('roadblock') ||
        type.toLowerCase().contains('roadblock-image')) {
      sdkPrint("POPUP or ROADBLOCK");
      if (contentList.isNotEmpty && overlayContext != null) {
        _showPopupRoadblock(
          contentList,
          messageId,
          filterId,
          overlayContext,
        );
      }
    }
    if (type.toLowerCase().contains('bottomsheet')) {
      sdkPrint("BottomSheet");
      if (contentList.isNotEmpty && overlayContext != null) {
        _showBottomSheetBanner(
          contentList,
          messageId,
          filterId,
          overlayContext,
        );
      }
    }

    if (type.toLowerCase().contains('banner')) {
      sdkPrint("BANNER");
      if (contentList.isNotEmpty && overlayContext != null) {
        sdkPrint("Going in Show Banner");
        _showBanner(
          contentList,
          messageId,
          filterId,
          overlayContext,
          align: "top",
        );
      }
    }
    if (type.toLowerCase().contains('pip') ||
        type.toLowerCase().contains('picture-in-picture')) {
      sdkPrint("PIP STARTED");
      sdkPrint(style.toString());
      final align = getAlignment(style);
      sdkPrint(align);
      if (contentList.isNotEmpty && overlayContext != null) {
        _showPip(contentList, messageId, filterId, overlayContext, align: align);
      }
    }
    if (type.toLowerCase().contains('floater')) {
      final align = getAlignment(style);
      final draggable = meSendParseBool(templateStyle['draggable']);
      sdkPrint("Going in Show Floater");
      if (contentList.isNotEmpty && overlayContext != null) {
        sdkPrint("Calling Show Floater");
        _showFloater(
          contentList,
          overlayContext,
          align: align,
          draggable: draggable,
        );
      }
    }

    if (type.toLowerCase().contains('inline')) {
      final placeholderId = meSendParseString(
        data['event']?['event_data']?['compare'],
      );
      sdkPrint("PlaceholderId $placeholderId");
      sdkPrint("contentList $contentList");
      if (placeholderId.isNotEmpty && contentList.isNotEmpty) {
        sdkPrint("Dispatching content to placeholder: $placeholderId");
        _notifyPlaceholder(placeholderId, contentList, messageId, filterId);
      } else {
        sdkPrint("Placeholder data invalid or content missing.");
      }
      _onNotificationClosed();
      return;
    }
  }



  void _notifyPlaceholder(String placeholderId, List<dynamic> contentList, String? messageId, String? filterId) {
    final listener = _placeholderListeners[placeholderId];
    if (listener != null) {
      listener(contentList,messageId!,filterId!);
    } else {
      sdkPrint("No listener registered for placeholder: $placeholderId");
    }
  }




  void _showPip(
      List<dynamic> contentList,
      String messageId,
      String filterId,
      BuildContext context, {
        String align = "bottom-right", // supports 9 alignments
      }) {
    if (contentList.isEmpty || contentList.first is! String) return;

    final htmlContent = contentList.first as String;

    // --- START WebViewController INITIALIZATION (FIXED FOR iOS VIDEO) ---
    PlatformWebViewControllerCreationParams params;
    if (Platform.isIOS) {
      // 1. Define the WebKit parameters
      params = WebKitWebViewControllerCreationParams(
        // CRITICAL FIX 1: Set allowsInlineMediaPlayback to true
        allowsInlineMediaPlayback: true,
        // CRITICAL FIX 2: Allows autoplay for ALL media types
        mediaTypesRequiringUserAction: {},
      );
    } else {
      // 2. Use the default configuration for other platforms
      params = const PlatformWebViewControllerCreationParams();
    }

    // 3. Create the controller using the platform parameters
    final controller = WebViewController.fromPlatformCreationParams(params);
    // --- END WebViewController INITIALIZATION ---


    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'InAppChannel',
        onMessageReceived: (JavaScriptMessage message) {
          _handleJsMessage(message.message, messageId, filterId);
          if (Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }
          _onNotificationClosed();
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            await controller.runJavaScript('''
          window.handleClick = function(eventType, lab, val) {
            var message = JSON.stringify({
              event: eventType,
              timestamp: Date.now(),
              data: { url: "", label: lab, value: val }
            });
            InAppChannel.postMessage(message);
          };
        ''');

            // ✅ Enhanced JS to aggressively disable controls/fullscreen
            await controller.runJavaScript('''
          document.querySelectorAll('video').forEach(function(v) {
            v.controls = false;
            v.removeAttribute('controls'); // Aggressive control removal
            v.style.pointerEvents = 'none'; // Prevents tap-to-fullscreen
            v.muted = true;
            v.playsInline = true;
            v.autoplay = true;

            var playPromise = v.play();
            if (playPromise !== undefined) {
              playPromise.catch(function(error) {
                console.log('Autoplay blocked', error);
              });
            }
          });
        ''');
          },
          onNavigationRequest: (request) {
            final url = request.url;
            if (url.startsWith('http')) {
              _handleCta(url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadHtmlString(htmlContent);

    // Map align string to Alignment
    final alignment = {
      'top-left': Alignment.topLeft,
      'top-center': Alignment.topCenter,
      'top-right': Alignment.topRight,
      'center-left': Alignment.centerLeft,
      'center-center': Alignment.center,
      'center-right': Alignment.centerRight,
      'bottom-left': Alignment.bottomLeft,
      'bottom-center': Alignment.bottomCenter,
      'bottom-right': Alignment.bottomRight,
    }[align] ?? Alignment.bottomRight;

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (ctx) => Material(
        type: MaterialType.transparency, // Removes white dialog background
        child: Stack(
          children: [
            Align(
              alignment: alignment,
              child: Container(
                height: 200,
                width: 120,
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(blurRadius: 8, color: Colors.black26),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      /// WebView Content
                      Container(
                        color: Colors.transparent,
                        child: WebViewWidget(controller: controller),
                      ),

                      /// Overlay Click Handler (transparent touch layer)
                      Positioned.fill(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _showPopupRoadblock(
                                  [htmlContent], messageId, filterId, context);
                            },
                          ),
                        ),
                      ),

                      /// Share Icon on Top-Right
                      Positioned(
                        top: 8,
                        right: 8,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _showPopupRoadblock(
                                [htmlContent], messageId, filterId, context);
                          },
                          child: Container(
                            height: 32,
                            width: 32,
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.share,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFloater(
      List<dynamic> contentList,
      BuildContext context, {
        String align = "bottom-right", // supports 9 alignments
        bool draggable = false,
      }) {
    if (contentList.isEmpty || contentList.first is! String) return;
    final String finalAlign = align;
    final htmlContent = contentList.first as String;

    // --- START WebViewController INITIALIZATION (FIXED FOR iOS VIDEO) ---
    PlatformWebViewControllerCreationParams params;
    if (Platform.isIOS) {
      // 1. Define the WebKit parameters
      params = WebKitWebViewControllerCreationParams(
        // CRITICAL FIX 1: Set allowsInlineMediaPlayback to true
        allowsInlineMediaPlayback: true,
        // CRITICAL FIX 2: Allows autoplay for ALL media types
        mediaTypesRequiringUserAction: {},
      );
    } else {
      // 2. Use the default configuration for other platforms
      params = const PlatformWebViewControllerCreationParams();
    }

    // 3. Create the controller using the platform parameters
    final controller = WebViewController.fromPlatformCreationParams(params);
    // --- END WebViewController INITIALIZATION ---

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'InAppChannel',
        onMessageReceived: (JavaScriptMessage message) {
          if (Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }
          _onNotificationClosed();
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            await controller.runJavaScript('''
          window.handleClick = function(eventType, lab, val) {
            var message = JSON.stringify({
              event: eventType,
              timestamp: Date.now(),
              data: { url: "", label: lab, value: val }
            });
            InAppChannel.postMessage(message);
          };
        ''');

            await controller.runJavaScript('''
          document.querySelectorAll('video').forEach(function(v) {
            v.controls = false;
            v.removeAttribute('controls'); 
            v.style.pointerEvents = 'none'; 
            v.muted = true;
            v.playsInline = true;
            v.autoplay = true;

            var playPromise = v.play();
            if (playPromise !== undefined) {
              playPromise.catch(function(error) {
                console.log('Autoplay blocked', error);
              });
            }
          });
        ''');
          },
          onNavigationRequest: (request) {
            final url = request.url;
            if (url.startsWith('http')) {
              _handleCta(url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadHtmlString(htmlContent);

    // Map align string to Alignment
    final alignment = {
      'top-left': Alignment.topLeft,
      'top-center': Alignment.topCenter,
      'top-right': Alignment.topRight,
      'center-left': Alignment.centerLeft,
      'center-center': Alignment.center,
      'center-right': Alignment.centerRight,
      'bottom-left': Alignment.bottomLeft,
      'bottom-center': Alignment.bottomCenter,
      'bottom-right': Alignment.bottomRight,
    }[align] ?? Alignment.bottomRight;

    // --- START OF INLINE DRAG IMPLEMENTATION ---

    // 1. Define fixed dimensions based on your code (200x200 + 12 margin)
    const floaterHeight = 200.0;
    const floaterWidth = 200.0;
    const floaterMargin = 12.0;

    // 2. Variable to hold and persist the current position (must be mutable outside StatefulBuilder)
    Offset? _currentOffset;

    // Helper function to calculate initial Positioned Offset from Alignment
    Offset _getInitialOffset(Alignment align, Size screenSize) {
      // Total occupied space (floater size + 2 * margin)
      final totalWidth = floaterWidth + 2 * floaterMargin;
      final totalHeight = floaterHeight + 2 * floaterMargin;

      // Calculate top-left X position
      double x = (screenSize.width - totalWidth) * ((align.x + 1) / 2);
      // Calculate top-left Y position
      double y = (screenSize.height - totalHeight) * ((align.y + 1) / 2);

      // Positioned's left/top is relative to the Stack.
      // The margin is applied to the Container's content, effectively pushing the entire block.
      // We add the margin back to align the Container's left/top corner correctly relative to the stack.
      x += floaterMargin;
      y += floaterMargin;

      var addedOffsetX = 0.0;
      var addedOffsetY = 0.0;

      if (finalAlign.contains('bottom')) {
        addedOffsetY = 100.0;
      }
      if (finalAlign.contains('right')) {
        addedOffsetX = 20.0;
      }

      return Offset(x-addedOffsetX, y-addedOffsetY);
    }

    // Display the floater using a transparent dialog
    showDialog(
      context: context,
      barrierDismissible: true,
      // Using a near-transparent color to prevent system blur/grey barrier
      barrierColor: const Color(0x01000000),
      builder: (ctx) => StatefulBuilder(
        builder: (stfContext, setState) {

          // 3. Calculate initial offset once (using context for screen size)
          if (_currentOffset == null) {
            final screenSize = MediaQuery.of(stfContext).size;
            _currentOffset = _getInitialOffset(alignment, screenSize);
          }

          // The core floater content widget
          final floaterContent = Container(
            height: floaterHeight,
            width: floaterWidth,
            margin: const EdgeInsets.all(floaterMargin),
            decoration: const BoxDecoration(
              color: Color(0x00000000),
              // REMOVED: No borderRadius here
            ),
            child:
            // REMOVED: ClipRRect wrapper
            Stack(
              children: [
                /// WebView Content
                Container(
                  color: Colors.transparent,
                  child: WebViewWidget(controller: controller),
                ),
              ],
            ),
          );

          Widget positionedWidget;

          if (draggable) {
            final screenSize = MediaQuery.of(stfContext).size;

            positionedWidget = Positioned(
              left: _currentOffset!.dx,
              top: _currentOffset!.dy,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    // Update the offset, keeping it within screen bounds
                    _currentOffset = Offset(
                      (_currentOffset!.dx + details.delta.dx).clamp(
                          floaterMargin, // Left bound
                          screenSize.width - floaterWidth - floaterMargin // Right bound
                      ),
                      (_currentOffset!.dy + details.delta.dy).clamp(
                          floaterMargin, // Top bound
                          screenSize.height - floaterHeight - floaterMargin // Bottom bound
                      ),
                    );
                  });
                },
                child: floaterContent,
              ),
            );
          } else {
            // Original non-draggable alignment
            positionedWidget = Align(
              alignment: alignment,
              child: floaterContent,
            );
          }

          return Material(
            type: MaterialType.transparency, // Removes white dialog background
            child: Stack(
              children: [
                positionedWidget, // Either Positioned/GestureDetector or Align
              ],
            ),
          );
        },
      ),
    );
  }



//   // GLOBAL VARIABLE
//   OverlayEntry? _floaterEntry;
//
// // NOTE: You must have a way to manage AppLifecycle.isAppInForeground
// // See the Prerequisite section above.
//
//   void _showFloater(
//       List<dynamic> contentList,
//       BuildContext context, {
//         String align = "bottom-right",
//         bool draggable = false,
//       }) {
//
//     // --- 🛑 CORE RESOLUTION FIX: GUARD CLAUSE 🛑 ---
//     // If the floater is triggered while the app is paused (or coming from background),
//     // this prevents it from being inserted until the app explicitly calls this method
//     // AFTER the AppLifecycleState.resumed state is fully processed.
//     if (!AppLifecycle.isAppInForeground) {
//       debugPrint("❌ Floater prevented: App is not in the foreground.");
//       return;
//     }
//     // ----------------------------------------------
//
//     if (contentList.isEmpty || contentList.first is! String) return;
//
//     // Wrap the entire show logic in a post-frame callback for timing stability.
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//
//       // --- STABILITY FIX 1: Check and remove existing entry ---
//       if (_floaterEntry != null) {
//         _floaterEntry!.remove();
//         _floaterEntry = null;
//         debugPrint("✅ Removed old floater entry before creating a new one.");
//       }
//       // --------------------------------------------------------
//
//       final htmlContent = contentList.first as String;
//
//       // --- WebViewController INITIALIZATION (FIXED FOR 4.4.2) ---
//       PlatformWebViewControllerCreationParams params;
//       if (Platform.isIOS) {
//         params = WebKitWebViewControllerCreationParams(
//           allowsInlineMediaPlayback: true,
//           mediaTypesRequiringUserAction: {},
//         );
//       } else {
//         params = const PlatformWebViewControllerCreationParams();
//       }
//
//       final controller = WebViewController.fromPlatformCreationParams(params);
//       // --- END WebViewController Initialization ---
//
//       controller..setJavaScriptMode(JavaScriptMode.unrestricted)
//         ..setBackgroundColor(const Color(0x00000000))
//         ..setNavigationDelegate(
//           NavigationDelegate(
//             onPageFinished: (url) async {
//               // 1. JS Channel setup (simplified)
//               await controller.runJavaScript('''
//               window.handleClick = function(eventType, lab, val) {
//                 var message = JSON.stringify({
//                   event: eventType,
//                   timestamp: Date.now(),
//                   data: { url: "", label: lab, value: val }
//                 });
//                 // InAppChannel.postMessage(message);
//               };
//             ''');
//
//               // 2. Autoplay and Controls Fix
//               await controller.runJavaScript('''
//               document.querySelectorAll('video').forEach(function(v) {
//                 v.controls = false;
//                 v.removeAttribute('controls');
//                 v.style.pointerEvents = 'none';
//                 v.muted = true;
//                 v.playsInline = true;
//                 v.autoplay = true;
//
//                 var playPromise = v.play();
//                 if (playPromise !== undefined) {
//                   playPromise.catch(function(error) {
//                     console.log('Autoplay blocked', error);
//                   });
//                 }
//               });
//             ''');
//             },
//           ),
//         )
//         ..loadHtmlString(htmlContent);
//
//       final overlay = Navigator.of(context).overlay;
//       if (overlay == null) {
//         debugPrint("❌ No Overlay found in this context!");
//         return;
//       }
//
//       final size = MediaQuery.of(context).size;
//       const double floaterSize = 200.0;
//       const double padding = 16.0;
//
//       // Alignment-based starting position
//       Offset initialOffset;
//       switch (align) {
//         case "top-left":
//           initialOffset = const Offset(padding, padding);
//           break;
//         case "top-right":
//           initialOffset = Offset(size.width - floaterSize - padding, padding);
//           break;
//         case "bottom-left":
//           initialOffset = Offset(padding, size.height - floaterSize - padding);
//           break;
//         case "bottom-right":
//         default:
//           initialOffset = Offset(
//             size.width - floaterSize - padding,
//             size.height - floaterSize - padding,
//           );
//       }
//
//       final positionNotifier = ValueNotifier<Offset>(initialOffset);
//       final showWebView = ValueNotifier(false);
//
//       final entry = OverlayEntry(
//         builder: (ctx) => ValueListenableBuilder<Offset>(
//           valueListenable: positionNotifier,
//           builder: (context, offset, _) {
//             return Positioned(
//               left: offset.dx,
//               top: offset.dy,
//               child: GestureDetector(
//                 onPanUpdate: draggable
//                     ? (details) {
//                   final newOffset = Offset(
//                     offset.dx + details.delta.dx,
//                     offset.dy + details.delta.dy,
//                   );
//                   positionNotifier.value = Offset(
//                     newOffset.dx.clamp(0, size.width - floaterSize),
//                     newOffset.dy.clamp(0, size.height - floaterSize),
//                   );
//                 }
//                     : null,
//                 child: AnimatedOpacity(
//                   opacity: 1,
//                   duration: const Duration(milliseconds: 200),
//                   child: RepaintBoundary(
//                     child: Container(
//                       height: floaterSize,
//                       width: floaterSize,
//                       decoration: BoxDecoration(
//                         color: Colors.transparent,
//                         borderRadius: BorderRadius.circular(16),
//                       ),
//                       child: ClipRRect(
//                         borderRadius: BorderRadius.circular(16),
//                         child: ValueListenableBuilder<bool>(
//                           valueListenable: showWebView,
//                           builder: (context, visible, _) {
//                             if (!visible) return const SizedBox.shrink();
//                             return WebViewWidget(controller: controller);
//                           },
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             );
//           },
//         ),
//       );
//
//       // Insert the entry into the overlay
//       overlay.insert(entry);
//       entry.markNeedsBuild();
//
//       // Use a short delay before showing the WebView contents for surface stability
//       Future.delayed(const Duration(milliseconds: 200), () {
//         showWebView.value = true;
//       });
//
//       _floaterEntry = entry;
//     }); // End of addPostFrameCallback
//   }
//
// // --- HIDE FLOATER FUNCTION ---
//   void _hideFloater() {
//     _floaterEntry?.remove();
//     _floaterEntry = null;
//   }



  void _showBanner(
      List<dynamic> contentList,
      String messageId,
      String filterId,
      BuildContext context, {
        String align = "top",
      }) {
    if (contentList.isEmpty || contentList.first is! String) {
      sdkPrint("No banner HTML found.");
      return;
    }

    sdkPrint("Show Banner Called");

    final htmlContent = (contentList.first as String)
        .replaceAll('[[ALIGN]]', align == 'bottom' ? 'banner-bottom' : 'banner-top');

    final controller = WebViewController();

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'InAppChannel',
        onMessageReceived: (JavaScriptMessage message) {
          _handleJsMessage(message.message, messageId, filterId);
          if (Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }
          _onNotificationClosed();
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            // Inject JS bridge for CTA clicks
            await controller.runJavaScript('''
            window.handleClick = function(eventType, lab, val) {
              var message = JSON.stringify({
                event: eventType,
                timestamp: Date.now(),
                data: { url: "", label: lab, value: val }
              });
              InAppChannel.postMessage(message);
            };
          ''');
          },
          onNavigationRequest: (request) {
            final url = request.url;
            if (url.startsWith('http')) {
              _handleCta(url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadHtmlString(htmlContent);

    sdkPrint("show banner");

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (context) => Align(
        alignment: align == 'bottom' ? Alignment.bottomCenter : Alignment.topCenter,
        child: Container(
          height: 100,
          width: MediaQuery.of(context).size.width,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                SizedBox.expand(
                  child: WebViewWidget(controller: controller),
                ),
                // Close button
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        trackInAppEvent(
                          messageId: messageId,
                          event: "dismissed",
                          completion: (success) {},
                        );
                        Navigator.of(context).pop();
                        _onNotificationClosed();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

  }


  void _showPopupRoadblock(List<dynamic> contentList,String messageId,String filterId, BuildContext context) {
    String htmlContent = '';
    String imageUrl = '';

    // Determine if the content is HTML or an image
    for (var item in contentList) {
      if (item is String) {
        if (item.contains('<html')) {
          htmlContent = item;
          break;
        } else if (item.startsWith('http') &&
            (item.endsWith('.png') ||
                item.endsWith('.jpg') ||
                item.endsWith('.jpeg') ||
                item.endsWith('.gif') ||
                item.endsWith('.webp'))) {
          imageUrl = item;
          break;
        }
      }
    }

    if (htmlContent.isEmpty && imageUrl.isEmpty) {
      debugPrint("❌ No valid content (HTML or image) found.");
      return;
    }

    Widget contentWidget;

    if (htmlContent.isNotEmpty) {

      // 1️⃣ Create platform-specific params
      late final PlatformWebViewControllerCreationParams params;

      if (Platform.isIOS) {
        // iOS: WebKit-specific params
        params = WebKitWebViewControllerCreationParams(
          allowsInlineMediaPlayback: true, // ✅ allow inline
        );
      } else {
        // Android / default
        params = const PlatformWebViewControllerCreationParams();
      }

// 2️⃣ Create controller
      final controller = WebViewController.fromPlatformCreationParams(params);

      controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..addJavaScriptChannel(
          'InAppChannel',
          onMessageReceived: (JavaScriptMessage message) {
            _handleJsMessage(message.message, messageId, filterId);
            Navigator.of(context).pop();
            _onNotificationClosed();
          },
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (url) async {
              // CTA bridge
              await controller.runJavaScript('''
          window.handleClick = function(eventType, lab, val) {
            var message = JSON.stringify({
              event: eventType,
              timestamp: Date.now(),
              data: { url: "", label: lab, value: val }
            });
            InAppChannel.postMessage(message);
          };
        ''');

              // Autoplay video fix
              await controller.runJavaScript('''
  document.querySelectorAll('video').forEach(function(v) {
    // Remove poster and controls
    v.removeAttribute('poster');
    v.controls = false;
    v.muted = true;
    v.playsInline = true;
    v.autoplay = true;

    // Force reload to clear poster frame (important on Android WebView)
    try {
      v.load();
      v.currentTime = 0;
    } catch (e) {
      console.log('Video reload error', e);
    }

    // Start playing (catch autoplay block)
    var playPromise = v.play();
    if (playPromise !== undefined) {
      playPromise.catch(function(error) {
        console.log('Autoplay blocked', error);
      });
    }

    // Optional: keep removing poster if re-added by scripts
    const observer = new MutationObserver(function(mutations) {
      mutations.forEach(function(m) {
        if (m.attributeName === 'poster') {
          v.removeAttribute('poster');
        }
      });
    });
    observer.observe(v, { attributes: true });
  });
''');

              // Viewport fix for iOS
              if (Platform.isIOS) {
                await controller.runJavaScript('''
            if (!document.querySelector('meta[name=viewport]')) {
              var meta = document.createElement('meta');
              meta.name = 'viewport';
              meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
              document.head.appendChild(meta);
            }
          ''');
              }
            },
            onNavigationRequest: (request) {
              final url = request.url;
              if (url.startsWith('http')) {
                _handleCta(url);
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadHtmlString(htmlContent);



      contentWidget = WebViewWidget(controller: controller);
    } else {
      contentWidget = Image.network(
        imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
        const Center(child: Text("Failed to load image")),
      );
    }

    // Show dialog with the WebView or image
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Scaffold(
          backgroundColor: Colors.black, // full screen dark background
          body: Stack(
            children: [
              // Fullscreen WebView
              Positioned.fill(
                child: contentWidget, // WebView or Image
              ),

              // Close button overlay
          Positioned(
            top: 40,
            right: 20,
            child: Container(
              width: 24, // make circle smaller
              height: 24,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                padding: EdgeInsets.zero, // removes extra space inside button
                constraints: const BoxConstraints(), // removes default min size (48x48)
                icon: const Icon(Icons.close, color: Colors.white, size: 12),
                onPressed: () {
                  trackInAppEvent(
                    messageId: messageId,
                    event: "dismissed",
                    completion: (success) {},
                  );
                  Navigator.of(context).pop();
                  _onNotificationClosed();
                },
              ),
            ),
          )
          ],
          ),
        );
      },
    );
  }


  void _showBottomSheetBanner(
      List<dynamic> contentList,
      String messageId,
      String filterId,
      BuildContext context,
      ) async {
    String htmlContent = '';
    String imageUrl = '';

    // Determine if the content is HTML or an image
    for (var item in contentList) {
      if (item is String) {
        if (item.contains('<html')) {
          htmlContent = item;
          break;
        } else if (item.startsWith('http') &&
            (item.endsWith('.png') ||
                item.endsWith('.jpg') ||
                item.endsWith('.jpeg') ||
                item.endsWith('.gif') ||
                item.endsWith('.webp'))) {
          imageUrl = item;
          break;
        }
      }
    }

    if (htmlContent.isEmpty && imageUrl.isEmpty) {
      debugPrint("❌ No valid content (HTML or image) found.");
      return;
    }

    Widget contentWidget;

    // --- START WebViewController INITIALIZATION (FIXED FOR 4.4.2) ---
    PlatformWebViewControllerCreationParams params;
    if (Platform.isIOS) {
      // 1. Define the parameters directly on the WebKitWebViewControllerCreationParams
      // This structure is compatible with webview_flutter 4.4.2 and fixes the errors.
      params = WebKitWebViewControllerCreationParams(
        // CRITICAL FIX: Set allowsInlineMediaPlayback to true at creation
        // This prevents the video from going fullscreen on iOS.
        allowsInlineMediaPlayback: true,
        // Allows autoplay for ALL media types (resolves the 'none' error)
        mediaTypesRequiringUserAction: {},
      );
    } else {
      // 2. Use the default configuration for other platforms
      params = const PlatformWebViewControllerCreationParams();
    }

    // 3. Create the controller using the platform parameters
    final controller = WebViewController.fromPlatformCreationParams(params);
    // --- END WebViewController INITIALIZATION ---

    if (htmlContent.isNotEmpty) {

      controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..addJavaScriptChannel(
          'InAppChannel',
          onMessageReceived: (JavaScriptMessage message) {
            _handleJsMessage(message.message, messageId, filterId);
            Navigator.of(context).pop();
            _onNotificationClosed();
          },
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (url) async {
              // Re-define JS helper function
              await controller.runJavaScript('''
              window.handleClick = function(eventType, lab, val) {
                var message = JSON.stringify({
                  event: eventType,
                  timestamp: Date.now(),
                  data: { url: "", label: lab, value: val }
                });
                InAppChannel.postMessage(message);
              };
            ''');

              // Autoplay, Controls, and Fullscreen Fix (JS injection)
              await controller.runJavaScript('''
              document.querySelectorAll('video').forEach(function(v) {
                // Remove or override poster
                v.removeAttribute('poster'); 
                
                // Set all required attributes and properties
                v.muted = true;
                v.playsInline = true;
                v.autoplay = true;

                // **Aggressive control removal**
                v.controls = false; 
                v.removeAttribute('controls');
                
                // **Prevents the video from being a tap target for native controls/fullscreen**
                v.style.pointerEvents = 'none';

                var playPromise = v.play();
                if (playPromise !== undefined) {
                  playPromise.catch(function(error) {
                    console.log('Autoplay blocked', error);
                  });
                }
              });
            ''');

              // Viewport fix for iOS
              if (Platform.isIOS) {
                await controller.runJavaScript('''
                if (!document.querySelector('meta[name=viewport]')) {
                  var meta = document.createElement('meta');
                  meta.name = 'viewport';
                  meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
                  document.head.appendChild(meta);
                }
              ''');
              }
            },
            onNavigationRequest: (request) {
              final url = request.url;
              if (url.startsWith('http')) {
                _handleCta(url);
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadHtmlString(htmlContent);

      contentWidget = WebViewWidget(controller: controller);
    } else {
      // ... (Image handling remains the same)
      contentWidget = Image.network(
        imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
        const Center(child: Text("Failed to load image")),
      );
    }

    // Show the bottom sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.3,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox.expand(
                      child: contentWidget,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                        onPressed: () {
                          trackInAppEvent(
                            messageId: messageId,
                            event: "dismissed",
                            completion: (success) {},
                          );
                          Navigator.of(context).pop();
                          _onNotificationClosed();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }




  void _handleJsMessage(String body,String messageId,String filterId) async {
    debugPrint("📩 JS → Flutter message: $body");

    try {
      final decoded = jsonDecode(body);
      final event = "cta";
      final ctaId = decoded["data"]?["value"] ?? "";

      if (ctaId.isEmpty) return;

      // Handle CTA
      _handleCta(ctaId);

      // Track event (equivalent to PushApp.shared.trackInAppEvent)
      trackInAppEvent(messageId: messageId, event: event, filterId: filterId, ctaId: ctaId,completion: (success) {
        if (success) {
          sdkPrint("Tracked in-app event successfully");
        } else {
          sdkPrint("Failed to track in-app event");
        }
      }
      );
    } catch (e) {
      debugPrint("❌ Failed to parse JS message: $e");
    }
  }

  Future<void> _handleCta(String ctaId) async {
    try {
      final uri = Uri.tryParse(ctaId);
      if (uri != null && (uri.isScheme("http") || uri.isScheme("https"))) {
        if (!meSendIsCtaUrlAllowed(uri)) {
          sdkPrint('PushApp: blocked CTA URL (not allowed): $uri');
          return;
        }
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else {
        debugPrint("📍 CTA String ID: $ctaId (non-URL)");
        // TODO: handle internal CTA actions here (e.g., navigate to screen)
      }
    } catch (e) {
      debugPrint("❌ Failed to handle CTA: $e");
    }
  }

  Future<void> trackInAppEvent({
    required String messageId,
    required String event,
    String? filterId,
    String? ctaId,
    required void Function(bool success) completion,
  }) async {
    if (!_ensureDeviceRegistered('trackInAppEvent')) {
      return;
    }
    final url = Uri.parse('$serverUrl/pushapp/api/v1/notification/in-app/track');
    sdkPrint("trackInAppEvent → $url");

    try {
      // Get device headers
      final deviceHeaders = await getDeviceHeaders();

      final requestHeaders = {
        'Content-Type': 'application/json',
        ...deviceHeaders,
      };

      // Build request body
      final body = <String, dynamic>{
        'messageId': messageId,
        'event': event,
      };

      if (filterId != null) body['filterId'] = filterId;
      if (ctaId != null) body['data'] = {'ctaId': ctaId};

      final jsonBody = jsonEncode(body);
      sdkPrint("Payload for in-app track:\n$jsonBody");

      // Send API request
      final response = await _meSendHttpPost(
        url,
        headers: requestHeaders,
        body: jsonBody,
        label: 'in_app_track',
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        completion(true);
      } else {
        sdkPrint("Failed response: ${response.body}");
        completion(false);
      }
    } on DeviceRegistrationPendingException {
      rethrow;
    } catch (e) {
      sdkPrint("In-app track request failed: $e");


      completion(false);
    }
  }
}
