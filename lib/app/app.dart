import 'package:flutter/material.dart';

/// Root widget.
///
/// A placeholder on purpose: W1 T6 replaces `home` with the `go_router` shell
/// and its five tabs, and the flex slot replaces the seeded `ColorScheme`
/// with real design tokens. Building either of those now would mean writing them twice.
class GPApp extends StatelessWidget {
  const GPApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Pockit',
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D67))),
    home: const Scaffold(body: Center(child: Text('Pockit'))),
  );
}
