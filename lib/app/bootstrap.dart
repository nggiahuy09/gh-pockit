import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../core/database/database.dart';
import '../core/error/result.dart';
import '../core/localization/locale.dart';
import '../core/localization/localization.dart';
import '../core/logging/app_logger.dart';
import '../core/utils/clock.dart';
import '../features/accounts/domain/repositories/account_repository.dart';
import '../features/categories/data/seed/category_seeder.dart';
import '../features/settings/presentation/debug/sample_data.dart';
import '../features/transactions/data/seed/benchmark_dataset_seeder.dart';
import '../features/transactions/domain/repositories/transaction_repository.dart';
import '../features/transactions/domain/usecases/seed_sample_data_use_case.dart';
import 'database_error_app.dart';
import 'di/injector.dart';

/// No `runZonedGuarded` on purpose: `PlatformDispatcher.onError` catches uncaught async errors without forcing every error through one zone.
Future<void> bootstrap(Widget Function() builder) async {
  WidgetsFlutterBinding.ensureInitialized();

  configureCoreDependencies();
  configureAccountsDependencies();
  configureCategoriesDependencies();
  configureTransactionsDependencies();
  final logger = getIt.get<GPAppLogger>();

  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    logger.error('uncaught flutter error', fields: {'library': details.library}, error: details.exception, stackTrace: details.stack);
    previousOnError?.call(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    logger.error('uncaught async error', error: error, stackTrace: stack);
    // `true` = handled; `false` would re-report it to the platform and duplicate every line once Sentry is wired.
    return true;
  };

  // The first statement runs the migration. A database this build cannot open gets a screen of its own, not a blank launch (ADR-0030); `Object`,
  // since a missing step throws an `ArgumentError`.
  try {
    await getIt.get<GPAppDatabase>().open();
  } on Object catch (error, stackTrace) {
    logger.error('database open failed', fields: {'error': error.runtimeType.toString()}, error: error, stackTrace: stackTrace);
    runApp(GPDatabaseErrorApp(error: error, locale: GPLocale.fromPlatform(PlatformDispatcher.instance.locale)));
    return;
  }

  // `DateFormat` throws for `vi` until these are loaded.
  await initializeDateFormatting();

  // Resolved before the first frame so the app never paints English and then flips to Vietnamese.
  await getIt.get<GPLocalization>().init(PlatformDispatcher.instance.locale);

  // Every launch, and idempotent, so one missed run cannot leave the categories empty for good. Not in `onUpgrade`: a migration has no owner or
  // clock, and would resurrect categories the user deleted.
  final seeded = await getIt.get<CategorySeeder>().seedDefaults();
  if (seeded > 0) logger.info('seeded default categories', fields: {'count': seeded});

  // `--dart-define=SAMPLE_DATA=true`: a debug run starts with the sample dataset. Only into an empty database, so a restart does not double it.
  if (kDebugMode && const bool.fromEnvironment('SAMPLE_DATA')) {
    final seedSampleData = SeedSampleDataUseCase(getIt.get<AccountRepository>(), getIt.get<GPClock>(), getIt.get<TransactionRepository>());
    switch (await seedSampleData.execute(const SeedSampleDataInput(accounts: sampleAccounts, transactions: sampleTransactions, onlyIfEmpty: true))) {
      case GPOk(:final value):
        logger.info('seeded sample data', fields: {'count': value});
      case GPErr(:final failure):
        logger.error('sample data seed failed', fields: {'failure': failure.runtimeType.toString()});
    }
  }

  // Seeds the benchmark database once; later launches find it full (ADR-0025). Not `kDebugMode`: benchmarks run in profile.
  final datasetSize = benchmarkDatasetSize;
  if (datasetSize != null) {
    final stopwatch = Stopwatch()..start();
    try {
      final count = await getIt.get<BenchmarkDatasetSeeder>().seed(datasetSize);
      logger.info('seeded benchmark dataset', fields: {'size': datasetSize.key, 'count': count, 'elapsed_ms': stopwatch.elapsedMilliseconds});
    } on Exception catch (error, stackTrace) {
      logger.error('benchmark dataset seed failed', fields: {'size': datasetSize.key}, error: error, stackTrace: stackTrace);
    }
  }

  logger.info('app bootstrapped');
  runApp(builder.call());
}
