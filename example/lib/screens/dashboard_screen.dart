import 'package:flutter/material.dart';
import 'package:mehery_sender/mehery_sender.dart';

import '../push_service.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.userId});

  final String userId;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    pushApp.initPage('dashboard');
  }

  Future<void> _signOut() async {
    await pushApp.logout(widget.userId);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _sendSampleEvent() async {
    await pushApp.sendEvent('example_tap', {'source': 'dashboard'});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Event sent')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          pushApp.registerWidget(
            placeholderId: 'dashboard_help_button',
            child: IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: 'Help tooltip slot',
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Signed in as ${widget.userId}'),
          const SizedBox(height: 16),
          MeSendWidget(
            placeholderId: 'home_banner_slot',
            meSend: pushApp,
            height: 160,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _sendSampleEvent,
            child: const Text('Send sample event'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _signOut,
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
