part of mehery_sender;

class MeSendTooltipWrapper extends StatefulWidget {
  final String placeholderId;
  final Widget child;
  final Pushapp meSend;

  const MeSendTooltipWrapper({
    super.key,
    required this.placeholderId,
    required this.child,
    required this.meSend,
  });

  @override
  State<MeSendTooltipWrapper> createState() => _MeSendTooltipWrapperState();
}

class _MeSendTooltipWrapperState extends State<MeSendTooltipWrapper> {
  @override
  void initState() {
    super.initState();
    widget.meSend.sendWidgetOpen(widget.placeholderId);
  }

  @override
  void dispose() {
    widget.meSend.unregisterPlaceholderListener(widget.placeholderId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
