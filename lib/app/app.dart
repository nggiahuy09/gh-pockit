import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/app/router/app_router.dart';
import 'package:ghpockit/app/theme/app_theme.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/localization.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';
import 'package:go_router/go_router.dart';

/// Stateful so the `GoRouter` is built once: rebuilding it on a theme or language change would drop every branch's navigation stack.
class GPApp extends StatefulWidget {
  const GPApp({this.initialLocation, this.localization, super.key});

  /// For tests: start on this path, as a deep link would.
  final String? initialLocation;

  /// For tests. Null resolves it from `getIt`.
  final GPLocalization? localization;

  @override
  State<GPApp> createState() => _GPAppState();
}

class _GPAppState extends State<GPApp> {
  late final GoRouter _router = widget.initialLocation == null ? createRouter() : createRouter(initialLocation: widget.initialLocation!);
  late final GPLocalization _localization = widget.localization ?? getIt<GPLocalization>();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _localization,
    builder: (BuildContext context, Widget? child) => GPLocalizationScope(
      localization: _localization,
      child: MaterialApp.router(
        title: _localization.current.root.appName,
        theme: GPAppTheme.light(),
        darkTheme: GPAppTheme.dark(),
        locale: _localization.locale.toPlatformLocale(),
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: GPLocale.values.map((GPLocale locale) => locale.toPlatformLocale()),
        routerConfig: _router,
      ),
    ),
  );
}
