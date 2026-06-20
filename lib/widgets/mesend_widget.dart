part of mehery_sender;

class MeSendWidget extends StatefulWidget {
  final String placeholderId;
  final double height;
  final double width;
  final Pushapp meSend;

  const MeSendWidget({
    Key? key,
    required this.placeholderId,
    this.height = 200,
    this.width = double.infinity,
    required this.meSend
  }) : super(key: key);

  @override
  State<MeSendWidget> createState() => _MeSendWidgetState();
}

class _MeSendWidgetState extends State<MeSendWidget> {
  WebViewController? _controller;
  String? _htmlContent;

  @override
  void initState() {
    super.initState();
    widget.meSend.sdkPrint('MeSendWidget init placeholder=${widget.placeholderId}');
    widget.meSend.sendEvent('widget_open', {
      'compare': widget.placeholderId,
    });

    widget.meSend.registerPlaceholderListener(widget.placeholderId, _onContentReceived);

    // Initialize controller immediately with all settings
    _initializeWebViewController();
  }

  void _initializeWebViewController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent) // Ensure background is transparent

    // Configure the Navigation Delegate
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            // FIX 1: Inject CSS to hide scrollbars and ensure content fits
            await _controller!.runJavaScript('''
              document.body.style.overflow = 'hidden';
              document.body.style.margin = '0';
              document.documentElement.style.overflow = 'hidden';
            ''');

            // ⭐ FIX 2: Force scroll to the very top (0, 0)
            await _controller!.runJavaScript('window.scrollTo(0, 0);');
          },
        ),
      );
  }

  void _onContentReceived(List<dynamic> contentList,String messageId, String filterId ) {
    if (contentList.isEmpty || contentList.first is! String) return;

    final rawHtml = contentList.first as String;

    // 1️⃣ Wrap HTML in proper document structure
    final html = '''
  <!DOCTYPE html>
  <html>
  <head>
      <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
      <style>
          body, html { 
              margin: 0; 
              padding: 0; 
              height: 100%; 
              width: 100%;
              overflow: hidden;
              background-color: transparent;
          }
          video {
              max-width: 100%;
              height: auto;
          }
      </style>
  </head>
  <body>
      $rawHtml
  </body>
  </html>
  ''';

    if (!mounted) return;

    setState(() {
      _htmlContent = html;
    });

    // 2️⃣ Setup WebViewController with same logic as popup
    late final PlatformWebViewControllerCreationParams params;

    if (Platform.isIOS) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final controller = WebViewController.fromPlatformCreationParams(params);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'InAppChannel',
        onMessageReceived: (JavaScriptMessage message) {
          // 👇 handle CTA or events received from JS
          widget.meSend._handleJsMessage(message.message, messageId, filterId); // Add IDs if available
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            // CTA bridge: connect JS events to Dart
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

            // Video autoplay + inline fix
            await controller.runJavaScript('''
            document.querySelectorAll('video').forEach(function(v) {
              v.removeAttribute('poster');
              v.controls = false;
              v.muted = true;
              v.playsInline = true;
              v.autoplay = true;
              try { v.load(); v.currentTime = 0; } catch (e) {}
              var playPromise = v.play();
              if (playPromise !== undefined) {
                playPromise.catch(function(error) {
                  console.log('Autoplay blocked', error);
                });
              }
              const observer = new MutationObserver(function(mutations) {
                mutations.forEach(function(m) {
                  if (m.attributeName === 'poster') v.removeAttribute('poster');
                });
              });
              observer.observe(v, { attributes: true });
            });
          ''');

            // Ensure viewport meta for iOS
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
              widget.meSend._handleCta(url); // 🔗 handle CTA link click
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadHtmlString(html);

    _controller = controller;
  }


  @override
  void dispose() {
    widget.meSend.unregisterPlaceholderListener(widget.placeholderId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _htmlContent != null
            ? WebViewWidget(
          // Controller is now guaranteed to be non-null after initState
          controller: _controller!,
        )
            : const Center(child: SizedBox.shrink()),
      ),
    );
  }
}
