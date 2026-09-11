import 'package:flutter/material.dart';
import 'package:ghpockit/app/router/app_router.dart';
import 'package:go_router/go_router.dart';

/// Root widget.
///
/// The seeded `ColorScheme` is still a placeholder: the W1 flex slot replaces it with real design tokens.
///
/// Stateful because the router is built once and kept, instead of being rebuilt inside `build`. A `GoRouter` holds the navigation stack of every
/// branch; rebuilding it on a parent rebuild (a theme change, a locale change) would throw that stack away and drop the user back on `/home`.
class GPApp extends StatefulWidget {
  const GPApp({this.initialLocation, super.key});

  /// Overrides where the app starts. Production passes nothing and gets `Routes.initial`; widget tests pass a path to simulate a deep link.
  final String? initialLocation;

  @override
  State<GPApp> createState() => _GPAppState();
}

class _GPAppState extends State<GPApp> {
  late final GoRouter _router = widget.initialLocation == null ? createRouter() : createRouter(initialLocation: widget.initialLocation!);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Pockit',
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D67))),
    routerConfig: _router,
  );
}
