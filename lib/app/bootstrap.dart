import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/core/localization/localization.dart';
import 'package:ghpockit/core/logging/app_logger.dart';
import 'package:ghpockit/features/categories/data/seed/category_seeder.dart';

/// Single startup path for every flavor and entry point.
///
/// The order matters: DI is configured before [builder] runs, so a widget can resolve a dependency in its constructor, and the error handlers are
/// installed before `runApp` so a crash during the first frame is still reported.
///
/// `runZonedGuarded` is intentionally absent. `PlatformDispatcher.onError` covers uncaught async errors on current Flutter and does not require every
/// error to travel through one zone — which matters once background isolates (Drift's, `workmanager`'s) enter the picture in P2/P4.
Future<void> bootstrap(Widget Function() builder) async {
  WidgetsFlutterBinding.ensureInitialized();

  configureCoreDependencies();
  configureAccountsDependencies();
  configureCategoriesDependencies();
  final logger = getIt<GPAppLogger>();

  final previousOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    logger.error(
      'uncaught flutter error',
      fields: {'library': details.library},
      error: details.exception,
      stackTrace: details.stack,
    );
    previousOnError?.call(details);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    logger.error('uncaught async error', error: error, stackTrace: stack);
    // `true` = handled; returning false would re-report it to the platform and duplicate every line once Sentry is wired in P7.
    return true;
  };

  // Resolved before the first frame so the app never paints English and then flips to Vietnamese.
  await getIt<GPLocalization>().init(deviceLocale: PlatformDispatcher.instance.locale);

  // Every launch, not just the first (W3 T5). The seeder is idempotent by construction — derived ids plus `INSERT OR IGNORE` — so the steady-state cost is
  // one batch of eleven ignored inserts, and the benefit is that a category list can never be permanently empty because one install missed its one chance.
  //
  // Awaited, and therefore on the path to the first frame, for the same reason the locale is: a category picker that is empty for the first few hundred
  // milliseconds is a picker the user can tap through. It is a single transaction on a table of eleven rows.
  //
  // Not in `onUpgrade`. Seeding needs an owner and a clock, neither of which a migration has, and a migration that wrote rows would also resurrect the
  // categories a user deleted on the previous version.
  final seeded = await getIt<CategorySeeder>().seedDefaults();
  if (seeded > 0) {
    // Count only — a category name is user data once the user renames one, and golden rule 9 keeps payloads out of logs.
    logger.info('seeded default categories', fields: {'count': seeded});
  }

  logger.info('app bootstrapped');
  runApp(builder());
}
