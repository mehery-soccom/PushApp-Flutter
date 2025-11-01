# mehery_sender Flutter SDK
A Flutter package to send device tokens, track events, and receive in-app notifications from the Mehery server.

## Features
Automatic device token registration (Firebase for Android, APNs for iOS)

 - User login/logout token registration

 - Event tracking with custom event data

 - WebSocket connection for real-time in-app notifications

 - Support for popup, banner, and picture-in-picture (PiP) notification styles

 - Route observer for automatic page open/close event tracking

 - Easy integration with your Flutter app

## Getting Started
### 1. Add dependency
Add this to your app’s pubspec.yaml:

```yaml
dependencies:
  mehery_sender: ^0.0.11
```

Or the latest version

Run flutter pub get to install.

### 2. Import package
```dart
import 'package:mehery_sender/mehery_sender.dart';
```

### 3. Initialize SDK
```dart
final meSend = MeSend(identifier: "yourTenant\$yourChannelId");
await meSend.initializeAndSendToken();
```
Replace "yourTenant\$yourChannelId" with your tenant and channel ID, separated by $


The SDK will choose the server URL based on sandbox mode (defaults to production)

### 4. Login user
Call this on user login:
```dart
await meSend.login("userId123");
```

### 5. Logout user
Call this on logout:
```dart
await meSend.logout("userId123");
```

### 6. Track custom event
```dart
await meSend.sendEvent("custom_event_name", {"key": "value"});
```

### 7. In-app notifications
Set the BuildContext for rendering in-app notifications:
```dart
meSend.setInAppNotification(context);
```

### 7. Initialize page for In-app on specific pages
```dart
tokenSender.initPage("page_name");
```

## Platform-specific Setup
To enable CTA tracking and live/custom notifications for Android and iOS, refer to the following guides:

- [Android Setup Guide](./AndroidREADME.md)
- [iOS Setup Guide](./IOSREADME.md)

These guides include additional steps for integrating CTA tracking, handling live notifications, and configuring platform-specific settings.


## Notes
 - Make sure to set BuildContext before expecting in-app notifications to display properly.

 - Supports popup, banner, and PiP notifications rendered via WebView or image.

## Versioning & Changelog
Check CHANGELOG.md for version updates.

## Example
See example/ folder for a full example app setup.

## License
MIT License
