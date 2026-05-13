import 'package:flutter/material.dart';
import '../notification_templates.dart';

class StandardNotificationWidget extends StatelessWidget {
  final NotificationConfig config;

  const StandardNotificationWidget({
    Key? key,
    required this.config,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: config.backgroundColor,
        image: config.backgroundImageUrl != null
            ? DecorationImage(
          image: NetworkImage(config.backgroundImageUrl!),
          fit: BoxFit.cover,
        )
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (config.imageUrl != null)
            Image.network(config.imageUrl!),
          Text(
            config.title,
            style: TextStyle(
              fontSize: config.titleFontSize ?? 16,
              color: config.titleColor,
            ),
          ),
          Text(
            config.subtitle,
            style: TextStyle(
              fontSize: config.subtitleFontSize ?? 14,
              color: config.subtitleColor,
            ),
          ),
          if (config.buttons != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: config.buttons!.map((button) =>
                  ElevatedButton(
                    onPressed: () {
                      // Handle button action
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: button.backgroundColor,
                      foregroundColor: button.textColor,
                    ),
                    child: Text(button.text),
                  ),
              ).toList(),
            ),
        ],
      ),
    );
  }
} 