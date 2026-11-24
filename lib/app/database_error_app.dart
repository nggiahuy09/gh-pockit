import 'package:flutter/material.dart';

import '../core/database/database_too_new_exception.dart';
import '../core/localization/locale.dart';
import 'startup_error_app.dart';

/// Run instead of `GPApp` when the database will not open (ADR-0030).
final class GPDatabaseErrorApp extends StatelessWidget {
  const GPDatabaseErrorApp({super.key, required this.error, required this.locale});

  final Object error;

  /// The device's: the chosen language is stored in the database that just failed.
  final GPLocale locale;

  @override
  Widget build(BuildContext context) {
    final isTooNew = error is GPDatabaseTooNewException;

    return GPStartupErrorApp(
      icon: isTooNew ? Icons.system_update_outlined : Icons.error_outline,
      locale: locale,
      message: (strings) => isTooNew ? strings.error.databaseTooNewBody : strings.error.databaseOpenFailedBody,
      title: (strings) => isTooNew ? strings.error.databaseTooNewTitle : strings.error.databaseOpenFailedTitle,
    );
  }
}
