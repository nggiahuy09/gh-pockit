import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:get_it/get_it.dart';
import '../../core/database/database.dart';
import '../../core/database/owner_id.dart';
import '../../core/localization/drift_locale_store.dart';
import '../../core/localization/locale_store.dart';
import '../../core/localization/localization.dart';
import '../../core/logging/app_logger.dart';
import '../../core/logging/developer_logger.dart';
import '../../core/utils/clock.dart';
import '../../core/utils/uuid_generator.dart';
import '../../features/accounts/data/daos/account_dao.dart';
import '../../features/accounts/data/repositories/account_repository_impl.dart';
import '../../features/accounts/domain/repositories/account_repository.dart';
import '../../features/categories/data/daos/category_dao.dart';
import '../../features/categories/data/repositories/category_repository_impl.dart';
import '../../features/categories/data/seed/category_seeder.dart';
import '../../features/categories/domain/repositories/category_repository.dart';
import '../../features/transactions/data/daos/transaction_dao.dart';
import '../../features/transactions/data/repositories/transaction_repository_impl.dart';
import '../../features/transactions/domain/repositories/transaction_repository.dart';

/// Use cases are never registered here: blocs build them from repositories resolved through this (ADR-0013).
final GetIt getIt = GetIt.instance;

/// [container] lets a test register into a fresh `GetIt()` instead of the global one.
void configureCoreDependencies([GetIt? container]) {
  final c = container ?? getIt;

  c
    // `dispose` is for tests: resetting the locator without closing leaks the sqlite connection, and with `shareAcrossIsolates` its isolate too.
    ..registerLazySingleton<GPAppDatabase>(GPAppDatabase.new, dispose: (db) => db.close())
    ..registerLazySingleton<GPClock>(GPSystemClock.new)
    // Must stay a singleton: `v7()` keeps a counter that orders IDs minted in the same millisecond, which only holds with one generator.
    ..registerLazySingleton<GPUuidGenerator>(() => GPUuidGeneratorImpl(clock: c.get<GPClock>()))
    ..registerLazySingleton<GPAppLogger>(
      () => GPDeveloperLogger(c.get<GPClock>(), minLevel: kReleaseMode ? GPLogLevel.info : GPLogLevel.debug),
    )
    ..registerLazySingleton<GPLocaleStore>(() => GPDriftLocaleStore(clock: c.get<GPClock>(), database: c.get<GPAppDatabase>(), logger: c.get<GPAppLogger>()))
    // Must stay a singleton: it holds the active language, and a second instance would leave part of the tree in the old one.
    ..registerLazySingleton<GPLocalization>(() => GPLocalization(c.get<GPLocaleStore>()));
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
        // The sentinel owner until auth. Passed, never defaulted, so every site is greppable.
        ownerId: localOwnerId,
      ),
    );
}

void configureCategoriesDependencies([GetIt? container]) {
  final c = container ?? getIt;

  c
    ..registerLazySingleton<CategoryDao>(() => CategoryDao(c.get<GPAppDatabase>()))
    ..registerLazySingleton<CategorySeeder>(
      () => CategorySeeder(clock: c.get<GPClock>(), dao: c.get<CategoryDao>(), uuidGenerator: c.get<GPUuidGenerator>(), ownerId: localOwnerId),
    )
    ..registerLazySingleton<CategoryRepository>(
      () => CategoryRepositoryImpl(
        clock: c.get<GPClock>(),
        dao: c.get<CategoryDao>(),
        logger: c.get<GPAppLogger>(),
        uuidGenerator: c.get<GPUuidGenerator>(),
        ownerId: localOwnerId,
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
        ownerId: localOwnerId,
      ),
    );
}
