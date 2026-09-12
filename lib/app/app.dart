import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/app/router/app_router.dart';
import 'package:ghpockit/app/theme/app_theme.dart';
import 'package:ghpockit/core/localization/locale.dart';
import 'package:ghpockit/core/localization/localization.dart';
import 'package:ghpockit/core/localization/localization_scope.dart';
import 'package:go_router/go_router.dart';

/// Root widget.
///
/// Themes come from `GPAppTheme`, which folds the design tokens in `core/theme/` into one `ThemeData` per brightness. The theme follows the device:
/// `MaterialApp` already defaults `themeMode` to `ThemeMode.system`, so passing it explicitly would only be noise. There is no in-app theme switch
/// yet — adding one before Settings has somewhere to persist it would buy a preference that does not survive a restart, which is the trap the
/// language picker is already in until W2 gives it a `settings` table.
///
/// Stateful because the router is built once and kept, instead of being rebuilt inside `build`. A `GoRouter` holds the navigation stack of every
/// branch; rebuilding it on a parent rebuild (a theme change, a language change) would throw that stack away and drop the user back on `/home`.
class GPApp extends StatefulWidget {
  const GPApp({this.initialLocation, this.localization, super.key});

  /// Overrides where the app starts. Production passes nothing and gets `Routes.initial`; widget tests pass a path to simulate a deep link.
  final String? initialLocation;

  /// Overrides the language source. Production resolves it from `get_it`; tests inject one already set to the locale under test.
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
