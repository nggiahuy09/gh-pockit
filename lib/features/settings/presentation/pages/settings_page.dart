import 'package:flutter/material.dart';

/// Placeholder. Fills up gradually: theme (W1 flex), biometric lock and the logout wipe (W23).
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: const Center(child: Text('Settings')),
  );
}
