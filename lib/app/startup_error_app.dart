import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/localization/locale.dart';
import '../core/localization/locale_base/locale_base.dart';
import '../core/localization/locale_en/locale_en.dart';
import '../core/localization/locale_vi/locale_vi.dart';
import '../core/widgets/empty_state.dart';
import 'theme/app_theme.dart';

/// Run instead of `GPApp` when the bootstrap stops; reads no database, `getIt` or stored language.
final class GPStartupErrorApp extends StatelessWidget {
  const GPStartupErrorApp({super.key, required this.icon, required this.locale, required this.message, required this.title});

  final IconData icon;

  /// The device's: the chosen one is in the database.
  final GPLocale locale;

  final String Function(GPLocaleBase strings) message;
  final String Function(GPLocaleBase strings) title;

  @override
  Widget build(BuildContext context) {
    final strings = switch (locale) {
      GPLocale.en => const GPLocaleEn(),
      GPLocale.vi => const GPLocaleVi(),
    };

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
          child: GPEmptyState(icon: Icon(icon), title: title(strings), message: message(strings)),
        ),
      ),
    );
  }
}
