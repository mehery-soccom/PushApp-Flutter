import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/screens/login_screen.dart';

void main() {
  testWidgets('Login screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen()),
    );

    expect(find.text('PushApp Login'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
