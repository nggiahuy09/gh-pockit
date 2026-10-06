import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/core/localization/localization.dart';
import 'package:ghpockit/core/logging/app_logger.dart';
import 'package:ghpockit/features/categories/data/seed/category_seeder.dart';

/// No `runZonedGuarded` on purpose: `PlatformDispatcher.onError` catches uncaught async errors without forcing every error through one zone.
Future<void> bootstrap(Widget Function() builder) async {
  WidgetsFlutterBinding.ensureInitialized();

  configureCoreDependencies();
  configureAccountsDependencies();
  configureCategoriesDependencies();
  configureTransactionsDependencies();
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
    // `true` = handled; `false` would re-report it to the platform and duplicate every line once Sentry is wired.
    return true;
  };

  // Resolved before the first frame so the app never paints English and then flips to Vietnamese.
  await getIt<GPLocalization>().init(deviceLocale: PlatformDispatcher.instance.locale);

  // Every launch: idempotent (derived ids + `INSERT OR IGNORE`), so one missed run cannot leave the categories empty for good. Awaited so the first
  // frame never shows an empty picker. Not in `onUpgrade`: a migration has no owner or clock, and would resurrect categories the user deleted.
  final seeded = await getIt<CategorySeeder>().seedDefaults();
  if (seeded > 0) {
    // Count only: a renamed category's name is user data (golden rule 9).
    logger.info('seeded default categories', fields: {'count': seeded});
  }

  logger.info('app bootstrapped');
  runApp(builder());
}
