import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../core/localization/locale.dart';
import '../core/localization/localization.dart';
import '../core/localization/localization_scope.dart';
import '../core/theme/appearance.dart';
import '../core/theme/appearance_scope.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
import 'di/injector.dart';
import 'router/app_router.dart';
import 'router/routes.dart';
import 'theme/app_theme.dart';

/// Stateful so the `GoRouter` is built once: rebuilding it on a theme or language change would drop every branch's navigation stack.
final class GPApp extends StatefulWidget {
  const GPApp({super.key, this.appearance, this.localization, this.initialLocation});

  /// For tests. Null resolves it from `getIt`.
  final GPAppearance? appearance;

  /// For tests. Null resolves it from `getIt`.
  final GPLocalization? localization;

  /// For tests: start on this path, as a deep link would.
  final String? initialLocation;

  @override
  State<GPApp> createState() => _GPAppState();
}

final class _GPAppState extends State<GPApp> {
  late final GoRouter _router = createRouter(widget.initialLocation ?? Routes.initial);
  late final GPLocalization _localization = widget.localization ?? getIt.get<GPLocalization>();
  late final GPAppearance _appearance = widget.appearance ?? getIt.get<GPAppearance>();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  /// Not lazy: the sign-in routes' redirect reads its state (ADR-0041).
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => AuthBloc(),
    lazy: false,
    child: _buildApp(),
  );

  Widget _buildApp() => ListenableBuilder(
    listenable: Listenable.merge([_localization, _appearance]),
    builder: (_, _) => GPLocalizationScope(
      localization: _localization,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: _localization.current.root.appName,
        theme: GPAppTheme.light(),
        darkTheme: GPAppTheme.dark(),
        themeMode: _appearance.themeMode,
        locale: _localization.locale.toPlatformLocale(),
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        supportedLocales: GPLocale.values.map((locale) => locale.toPlatformLocale()),
        routerConfig: _router,
        builder: (_, child) => GPAppearanceScope(appearance: _appearance, child: child ?? const SizedBox.shrink()),
      ),
    ),
  );
}
