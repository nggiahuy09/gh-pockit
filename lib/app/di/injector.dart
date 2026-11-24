import 'dart:math';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:get_it/get_it.dart';
import 'package:supabase/supabase.dart';

import '../../core/database/database.dart';
import '../../core/database/owner_context.dart';
import '../../core/database/settings_owner_context.dart';
import '../../core/localization/drift_locale_store.dart';
import '../../core/localization/locale_store.dart';
import '../../core/localization/localization.dart';
import '../../core/logging/app_logger.dart';
import '../../core/logging/developer_logger.dart';
import '../../core/security/flutter_secure_store.dart';
import '../../core/security/secure_store.dart';
import '../../core/utils/clock.dart';
import '../../core/utils/uuid_generator.dart';
import '../../features/accounts/data/daos/account_dao.dart';
import '../../features/accounts/data/repositories/account_repository_impl.dart';
import '../../features/accounts/domain/repositories/account_repository.dart';
import '../../features/auth/data/daos/device_owner_dao.dart';
import '../../features/auth/data/datasources/supabase_session_keeper.dart';
import '../../features/auth/data/repositories/device_owner_repository_impl.dart';
import '../../features/auth/data/repositories/local_only_auth_repository.dart';
import '../../features/auth/data/repositories/supabase_auth_repository.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/repositories/device_owner_repository.dart';
import '../../features/categories/data/daos/category_dao.dart';
import '../../features/categories/data/repositories/category_repository_impl.dart';
import '../../features/categories/data/seed/category_seeder.dart';
import '../../features/categories/domain/repositories/category_repository.dart';
import '../../features/transactions/data/daos/transaction_dao.dart';
import '../../features/transactions/data/repositories/transaction_repository_impl.dart';
import '../../features/transactions/data/seed/benchmark_dataset_generator.dart';
import '../../features/transactions/data/seed/benchmark_dataset_seeder.dart';
import '../../features/transactions/data/seed/benchmark_dataset_size_enum.dart';
import '../../features/transactions/domain/repositories/transaction_repository.dart';
import '../config/backend_config.dart';

/// Use cases are never registered here: blocs build them from repositories resolved through this (ADR-0013).
final GetIt getIt = GetIt.instance;

/// `--dart-define=DATASET=1k|10k|50k` on a non-release build: the run opens a database file of its own for that size and seeds it (ADR-0025, ADR-0026).
final BenchmarkDatasetSize? benchmarkDatasetSize = kReleaseMode ? null : BenchmarkDatasetSize.fromKey(const String.fromEnvironment('DATASET'));

/// [container] lets a test register into a fresh `GetIt()` instead of the global one.
void configureCoreDependencies([GetIt? container]) {
  final c = container ?? getIt;

  c
    // `dispose` is for tests: resetting the locator without closing leaks the sqlite connection, and with `shareAcrossIsolates` its isolate too.
    ..registerLazySingleton<GPAppDatabase>(
      () => switch (benchmarkDatasetSize) {
        final size? => GPAppDatabase(name: 'pockit_bench_${size.key}_v${BenchmarkDatasetGenerator.version}', logger: c.get<GPAppLogger>()),
        null => GPAppDatabase(logger: c.get<GPAppLogger>()),
      },
      dispose: (db) => db.close(),
    )
    ..registerLazySingleton<GPClock>(GPSystemClock.new)
    // Must stay a singleton: every repository reads its cache (ADR-0040).
    ..registerLazySingleton<GPSettingsOwnerContext>(
      () => GPSettingsOwnerContext(database: c.get<GPAppDatabase>(), logger: c.get<GPAppLogger>()),
      dispose: (context) => context.dispose(),
    )
    ..registerLazySingleton<GPOwnerContext>(() => c.get<GPSettingsOwnerContext>())
    ..registerLazySingleton<GPSecureStore>(GPFlutterSecureStore.new)
    // Must stay a singleton: `v7()` keeps a counter that orders IDs minted in the same millisecond, which only holds with one generator.
    ..registerLazySingleton<GPUuidGenerator>(() => GPUuidGeneratorImpl(clock: c.get<GPClock>()))
    ..registerLazySingleton<GPAppLogger>(
      () => GPDeveloperLogger(c.get<GPClock>(), minLevel: kReleaseMode ? GPLogLevel.info : GPLogLevel.debug),
    )
    ..registerLazySingleton<GPLocaleStore>(() => GPDriftLocaleStore(clock: c.get<GPClock>(), database: c.get<GPAppDatabase>(), logger: c.get<GPAppLogger>()))
    // Must stay a singleton: it holds the active language, and a second instance would leave part of the tree in the old one.
    ..registerLazySingleton<GPLocalization>(() => GPLocalization(c.get<GPLocaleStore>()));
}

/// The one place outside `data/` that names Supabase (ADR-0038).
void configureAuthDependencies(GPBackendConfig config, [GetIt? container]) {
  final c = container ?? getIt;

  c
    ..registerLazySingleton<DeviceOwnerDao>(() => DeviceOwnerDao(c.get<GPAppDatabase>()))
    ..registerLazySingleton<DeviceOwnerRepository>(
      () => DeviceOwnerRepositoryImpl(
        clock: c.get<GPClock>(),
        dao: c.get<DeviceOwnerDao>(),
        logger: c.get<GPAppLogger>(),
        ownerContext: c.get<GPSettingsOwnerContext>(),
        uuidGenerator: c.get<GPUuidGenerator>(),
      ),
    );

  switch (config) {
    case GPRemoteBackendConfig(:final url, :final publishableKey):
      c
        ..registerLazySingleton<SupabaseClient>(
          // Implicit flow: PKCE needs a verifier store, and email/password never redirects.
          () => SupabaseClient(url, publishableKey, authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit)),
          dispose: (client) => client.dispose(),
        )
        ..registerLazySingleton<SupabaseSessionKeeper>(
          () => SupabaseSessionKeeper(
            auth: c.get<SupabaseClient>().auth,
            clock: c.get<GPClock>(),
            database: c.get<GPAppDatabase>(),
            logger: c.get<GPAppLogger>(),
            store: c.get<GPSecureStore>(),
          ),
          dispose: (keeper) => keeper.dispose(),
        )
        ..registerLazySingleton<AuthRepository>(
          () => SupabaseAuthRepository(auth: c.get<SupabaseClient>().auth, keeper: c.get<SupabaseSessionKeeper>(), logger: c.get<GPAppLogger>()),
        );
    case GPLocalOnlyBackendConfig():
      c.registerLazySingleton<AuthRepository>(LocalOnlyAuthRepository.new);
    case GPInvalidBackendConfig(:final problem):
      throw ArgumentError.value(problem, 'config', 'the bootstrap stops on an invalid config before DI');
  }
}

void configureAccountsDependencies([GetIt? container]) {
  final c = container ?? getIt;

  c
    ..registerLazySingleton<AccountDao>(() => AccountDao(c.get<GPAppDatabase>()))
    ..registerLazySingleton<AccountRepository>(
      () => AccountRepositoryImpl(
        clock: c.get<GPClock>(),
        dao: c.get<AccountDao>(),
        logger: c.get<GPAppLogger>(),
        uuidGenerator: c.get<GPUuidGenerator>(),
        ownerContext: c.get<GPOwnerContext>(),
      ),
    );
}

void configureCategoriesDependencies([GetIt? container]) {
  final c = container ?? getIt;

  c
    ..registerLazySingleton<CategoryDao>(() => CategoryDao(c.get<GPAppDatabase>()))
    ..registerLazySingleton<CategorySeeder>(
      () => CategorySeeder(clock: c.get<GPClock>(), dao: c.get<CategoryDao>(), ownerContext: c.get<GPOwnerContext>(), uuidGenerator: c.get<GPUuidGenerator>()),
    )
    ..registerLazySingleton<CategoryRepository>(
      () => CategoryRepositoryImpl(
        clock: c.get<GPClock>(),
        dao: c.get<CategoryDao>(),
        logger: c.get<GPAppLogger>(),
        uuidGenerator: c.get<GPUuidGenerator>(),
        ownerContext: c.get<GPOwnerContext>(),
      ),
    );
}

void configureTransactionsDependencies([GetIt? container]) {
  final c = container ?? getIt;

  c
    ..registerLazySingleton<TransactionDao>(() => TransactionDao(c.get<GPAppDatabase>()))
    ..registerLazySingleton<TransactionRepository>(
      () => TransactionRepositoryImpl(
        clock: c.get<GPClock>(),
        dao: c.get<TransactionDao>(),
        logger: c.get<GPAppLogger>(),
        uuidGenerator: c.get<GPUuidGenerator>(),
        ownerContext: c.get<GPOwnerContext>(),
      ),
    )
    // Built only when a non-release run passes `--dart-define=DATASET`.
    ..registerLazySingleton<BenchmarkDatasetSeeder>(
      () => BenchmarkDatasetSeeder(
        accountDao: c.get<AccountDao>(),
        categoryDao: c.get<CategoryDao>(),
        clock: c.get<GPClock>(),
        // Not the singleton: `Random.secure` costs ~0.1 ms an id, nearly all of a 50k seed. Safe because nothing else mints a v7 while it runs.
        generator: BenchmarkDatasetGenerator(
          uuidGenerator: GPUuidGeneratorImpl(clock: c.get<GPClock>(), random: Random(BenchmarkDatasetGenerator.defaultSeed)),
        ),
        transactionDao: c.get<TransactionDao>(),
        ownerContext: c.get<GPOwnerContext>(),
      ),
    );
}
