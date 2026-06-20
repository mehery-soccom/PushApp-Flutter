part of mehery_sender;

class TooltipStyle {
  /// Plain title from API `line_1`.
  final String line1;
  /// Rich HTML title from API `richline_1` (tooltip templates); shown instead of [line1] when non-empty.
  final String richline1;
  final String line2;
  final String bgColor;
  final String line1Color;
  final String line1Icon;
  final double line1Size;
  final double width;
  final String line2Color;
  final double line2Size;
  final List<String> line1TextStyles; // ✅ added
  final List<String> line2TextStyles; // ✅ added

  TooltipStyle({
    required this.line1,
    required this.richline1,
    required this.line2,
    required this.bgColor,
    required this.line1Color,
    required this.line1Icon,
    required this.line1Size,
    required this.width,
    required this.line2Color,
    required this.line2Size,
    required this.line1TextStyles, // ✅ added
    required this.line2TextStyles, // ✅ added
  });

  /// 👇 Put the decoder inside the class
  static String decodeHtmlEntity(String input) {
    final regex = RegExp(r'&#(\d+);');
    return input.replaceAllMapped(regex, (match) {
      final codePoint = int.tryParse(match.group(1)!);
      if (codePoint != null) {
        return String.fromCharCode(codePoint);
      }
      return match.group(0)!;
    });
  }

  factory TooltipStyle.fromJson(Map<String, dynamic> json) {
    final richRaw = json["richline_1"];
    final richline1 = richRaw is String
        ? richRaw
        : (richRaw != null ? richRaw.toString() : "");
    final line1IconRaw = json["line1_icon"];
    final line1Icon = line1IconRaw != null
        ? TooltipStyle.decodeHtmlEntity(meSendParseString(line1IconRaw))
        : "";
    final bgColorRaw = meSendParseString(json["bg_color"]);
    final line1ColorRaw = meSendParseString(json["line1_font_color"]);
    final line2ColorRaw = meSendParseString(json["line2_font_color"]);

    return TooltipStyle(
      line1: meSendParseString(json["line_1"]),
      richline1: richline1,
      line2: meSendParseString(json["line_2"]),
      line1Icon: line1Icon,
      bgColor: bgColorRaw.isNotEmpty ? bgColorRaw : "#000000",
      line1Color: line1ColorRaw.isNotEmpty ? line1ColorRaw : "#FFFFFF",
      line1Size: meSendParseDouble(json["line1_font_size"], fallback: 14),
      line2Color: line2ColorRaw.isNotEmpty ? line2ColorRaw : "#FFFFFF",
      line2Size: meSendParseDouble(json["line2_font_size"], fallback: 12),
      width: meSendParseDouble(json["width"], fallback: 70),
      line1TextStyles: meSendParseStringList(json["line1_text_styles"]),
      line2TextStyles: meSendParseStringList(json["line2_text_styles"]),
    );
  }

  @override
  String toString() {
    return "TooltipStyle(line1='$line1', richline1='$richline1', line2='$line2', "
        "bgColor=$bgColor, line1Color=$line1Color, line1Size=$line1Size, "
        "line2Color=$line2Color, line2Size=$line2Size, "
        "line1TextStyles=$line1TextStyles, line2TextStyles=$line2TextStyles)";
  }
}



class TooltipSdk extends ChangeNotifier {
  static final TooltipSdk _instance = TooltipSdk._internal();
  factory TooltipSdk() => _instance;
  TooltipSdk._internal();

  final Map<String, TooltipStyle> _tooltipData = {};
  final Map<String, super_tooltip.SuperTooltipController> _controllers = {};
  VoidCallback? onTooltipDismissedCallback;

  void _handleTooltipDismissed(String placeholderId) {
    meherySenderLog('Tooltip dismissed for $placeholderId', tag: 'InApp');
    if (onTooltipDismissedCallback != null) {
      onTooltipDismissedCallback!();
    }
  }


  Color _parseColor(String hex) {
    try {
      var normalized = hex.replaceAll("#", "");
      if (normalized.length == 6) normalized = "FF$normalized";
      return Color(int.parse(normalized, radix: 16));
    } catch (_) {
      return Colors.transparent;
    }
  }

  /// Title row: prefers API `richline_1` (HTML) over plain `line_1`, optional `line1_icon` prefix.
  Widget _buildTooltipLine1(
    TooltipStyle style,
    TextStyle Function({
      required double fontSize,
      required String color,
      required List<String> styles,
    }) lineTextStyle,
  ) {
    final rich = style.richline1.trim();
    final useRich = rich.isNotEmpty;
    final titleWidget = useRich
        ? Html(
            data: rich,
            shrinkWrap: true,
            style: {
              "body": Style(
                margin: Margins.zero,
                padding: HtmlPaddings.zero,
                fontSize: FontSize(style.line1Size),
                // Default for any text (e.g. spans) without inline color
                color: Colors.black,
              ),
              "p": Style(
                margin: Margins.zero,
                padding: HtmlPaddings.zero,
                color: Colors.black,
              ),
            },
          )
        : (style.line1.isNotEmpty
            ? Text(
                style.line1,
                style: lineTextStyle(
                  fontSize: style.line1Size,
                  color: style.line1Color,
                  styles: style.line1TextStyles,
                ),
                overflow: TextOverflow.ellipsis,
              )
            : const SizedBox.shrink());

    if (style.line1Icon.isEmpty) return titleWidget;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          style.line1Icon,
          style: lineTextStyle(
            fontSize: style.line1Size,
            color: style.line1Color,
            styles: style.line1TextStyles,
          ),
        ),
        if (useRich || style.line1.isNotEmpty) ...[
          const SizedBox(width: 4),
          Flexible(child: titleWidget),
        ],
      ],
    );
  }

  /// Register a widget with a placeholder ID
  Widget registerWidget({
    required String placeholderId,
    required Widget child,
  }) {
    final controller = super_tooltip.SuperTooltipController();
    _controllers[placeholderId] = controller;
    meherySenderLog('Saved controller hash: ${identityHashCode(controller)}', tag: 'InApp');

    return AnimatedBuilder(
      animation: this, // listens to notifyListeners()
      builder: (context, _) {
        final style = _tooltipData[placeholderId];
        final screenWidth = MediaQuery.of(context).size.width;

        // Helper function to build TextStyle from styles list
        TextStyle _buildTextStyle({
          required double fontSize,
          required String color,
          required List<String> styles,
        }) {
          bool isBold = styles.contains("bold");
          bool isItalic = styles.contains("italic");
          bool isUnderline = styles.contains("underline");

          final parsedColor = _parseColor(color);

          return TextStyle(
            fontSize: fontSize,
            color: parsedColor,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
            decoration:
            isUnderline ? TextDecoration.underline : TextDecoration.none,
            decorationColor: parsedColor, // ✅ underline matches text color
            decorationThickness: 1.5, // ✅ optional: makes underline more visible
          );
        }

        final content = style != null
            ? SizedBox(
          width: screenWidth * (style.width / 100),
          child: Stack(
            children: [
              // 👇 Actual content
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (style.richline1.trim().isNotEmpty ||
                        style.line1.isNotEmpty ||
                        style.line1Icon.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _buildTooltipLine1(style, _buildTextStyle),
                      ),
                    if (style.line2.isNotEmpty)
                      Text(
                        style.line2,
                        style: _buildTextStyle(
                          fontSize: style.line2Size,
                          color: style.line2Color,
                          styles: style.line2TextStyles,
                        ),
                      ),
                  ],
                ),
              ),

              // 👇 Close button at top right
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () {
                    controller.hideTooltip(); // closes tooltip
                    TooltipSdk()._handleTooltipDismissed(placeholderId);
                  },
                  child: const Icon(
                    Icons.close,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        )
            : const SizedBox.shrink();

        return super_tooltip.SuperTooltip(
          controller: controller,
          barrierConfig: const super_tooltip.BarrierConfiguration(show: true),
          style: super_tooltip.TooltipStyle(
            backgroundColor: style != null
                ? _parseColor(style.bgColor)
                : Colors.transparent,
          ),
          content: content,
          child: child,
        );
      },
    );




  }


  /// Process API response and update tooltip styles
  void processApiResponse(Map<String, dynamic> response) {
    final results = response["results"];
    if (results is! List || results.isEmpty) return;

    for (final item in results) {
      try {
        final itemMap = meSendCoerceMap(item);
        if (itemMap == null) {
          debugPrint('PushApp: skipped tooltip result — not a map');
          continue;
        }

        final compareId = itemMap["event"]?["event_data"]?["compare"];
        final styleJson = meSendCoerceMap(itemMap["template"]?["style"]);

        if (compareId != null && styleJson != null) {
          _tooltipData[compareId.toString()] = TooltipStyle.fromJson(styleJson);
          debugPrint("✅ Tooltip data loaded for $compareId");
        }
      } catch (e, st) {
        debugPrint('PushApp: skipped malformed tooltip style: $e');
        debugPrint('$st');
      }
    }

    notifyListeners(); // triggers AnimatedBuilder to rebuild content
  }


  /// Show tooltip for a registered placeholder
  Future<void> showTooltipFor(String placeholderId) async {
    final controller = _controllers[placeholderId];
    meherySenderLog('Retrieved controller hash: ${identityHashCode(controller)}', tag: 'InApp');
    if (controller != null) {
      debugPrint("🚀 Showing tooltip for $placeholderId");
      await controller.showTooltip();
    } else {
      debugPrint("⚠️ No controller found for $placeholderId");
    }
  }
}
