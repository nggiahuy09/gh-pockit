import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/database/database_too_new_exception.dart';
import '../core/localization/locale.dart';
import '../core/localization/locale_en/locale_en.dart';
import '../core/localization/locale_vi/locale_vi.dart';
import '../core/widgets/empty_state.dart';
import 'theme/app_theme.dart';

/// Run instead of `GPApp` when the database will not open. Nothing here reads the database, `getIt` or a stored language (ADR-0030).
final class GPDatabaseErrorApp extends StatelessWidget {
  const GPDatabaseErrorApp({super.key, required this.error, required this.locale});

  final Object error;

  /// The device's: the chosen language is stored in the database that just failed.
  final GPLocale locale;

  @override
  Widget build(BuildContext context) {
    final strings = switch (locale) {
      GPLocale.en => const GPLocaleEn(),
      GPLocale.vi => const GPLocaleVi(),
    };
    final isTooNew = error is GPDatabaseTooNewException;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: strings.root.appName,
      theme: GPAppTheme.light(),
      darkTheme: GPAppTheme.dark(),
      locale: locale.toPlatformLocale(),
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      supportedLocales: GPLocale.values.map((locale) => locale.toPlatformLocale()),
      home: Scaffold(
        body: SafeArea(
          child: GPEmptyState(
            icon: Icon(isTooNew ? Icons.system_update_outlined : Icons.error_outline),
            title: isTooNew ? strings.error.databaseTooNewTitle : strings.error.databaseOpenFailedTitle,
            message: isTooNew ? strings.error.databaseTooNewBody : strings.error.databaseOpenFailedBody,
          ),
        ),
      ),
    );
  }
}
