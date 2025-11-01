import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:mehery_sender/mehery_sender.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase first
  try {
    await Firebase.initializeApp();
    print('Firebase Initialized');
  } catch (e) {
    print('Error initializing Firebase: $e');
    return;  // Stop if Firebase initialization fails
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const MethodChannel _channel = MethodChannel('com.yourapp/live_activity');

  final PushApp _tokenSender = PushApp( // Replace with your server URL
    identifier : 'MeheryTestFlutter_1734160381705'
  );

  @override
  void initState() {
    super.initState();
    // Wait until Firebase is initialized and then send the token
    _initializeTokenSender();
  }

  // Ensure initialization happens after Firebase is initialized
  Future<void> _initializeTokenSender() async {
    // Only initialize the token sender after Firebase has been initialized
    await _tokenSender.initializeAndSendToken();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase Token Sender Example')),
      body:  Center(
        child: Column(
          children: [
            const Text(
              'Token has been sent to the server.',
              textAlign: TextAlign.center,
            ),
            ElevatedButton(onPressed: (){
              _tokenSender.login("ABCD");
            }, child: const Text("Login")),
            ElevatedButton(onPressed: (){
              _tokenSender.logout("ABCD");
            }, child: const Text("Logout")),
            ElevatedButton(
              onPressed: () async {
                print("🚀 Starting Live Activity...");
                await startLiveActivity(); // start it and wait until it completes

                await Future.delayed(const Duration(seconds: 3)); // wait for 3 seconds

                print("🟢 Updating Live Activity...");
                await update(); // now update it
              },
              child: const Text("Live Activity"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> startLiveActivity() async {
    try {
      final result = await _channel.invokeMethod('startLiveActivity', {
        'rideId': 'ride001',
        'etaMinutes': 5,
        'driverName': 'Sam',
        'carModel': 'Silver Civic',
        'licensePlate': 'XYZ 1234',
        'progress': 0.1,
      });
      print('Live Activity started: $result');
    } catch (e) {
      print('Error starting Live Activity: $e');
    }
  }

  Future<void> update() async {
    print("📦 update() called");
    try {
      final result = await _channel.invokeMethod('updateLiveActivity', {
        'etaMinutes': 2,
        'progress': 0.6,
      });
      print('Live Activity updated: $result');
    } catch (e) {
      print('Error updating Live Activity: $e');
    }
  }
}
