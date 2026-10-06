import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:get_it/get_it.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/owner_id.dart';
import 'package:ghpockit/core/localization/drift_locale_store.dart';
import 'package:ghpockit/core/localization/locale_store.dart';
import 'package:ghpockit/core/localization/localization.dart';
import 'package:ghpockit/core/logging/app_logger.dart';
import 'package:ghpockit/core/logging/developer_logger.dart';
import 'package:ghpockit/core/utils/clock.dart';
import 'package:ghpockit/core/utils/uuid_generator.dart';
import 'package:ghpockit/features/accounts/data/daos/account_dao.dart';
import 'package:ghpockit/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:ghpockit/features/accounts/domain/repositories/account_repository.dart';
import 'package:ghpockit/features/accounts/domain/usecases/delete_account_use_case.dart';
import 'package:ghpockit/features/categories/data/daos/category_dao.dart';
import 'package:ghpockit/features/categories/data/repositories/category_repository_impl.dart';
import 'package:ghpockit/features/categories/data/seed/category_seeder.dart';
import 'package:ghpockit/features/categories/domain/repositories/category_repository.dart';
import 'package:ghpockit/features/transactions/data/daos/transaction_dao.dart';
import 'package:ghpockit/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:ghpockit/features/transactions/domain/usecases/create_transaction_use_case.dart';
import 'package:ghpockit/features/transactions/domain/usecases/update_transaction_use_case.dart';

/// Only `bootstrap()`, the `configure*Dependencies()` functions and widget-tree entry points may touch it; the rest take constructor arguments.
final GetIt getIt = GetIt.instance;

/// [container] lets a test register into a fresh `GetIt()` instead of the global one. Every other module resolves from this one.
void configureCoreDependencies({GetIt? container}) {
  final c = container ?? getIt;

  c
    // `dispose` is for tests: resetting the locator without closing leaks the sqlite connection, and with `shareAcrossIsolates` its isolate too.
    ..registerLazySingleton<GPAppDatabase>(GPAppDatabase.new, dispose: (db) => db.close())
    ..registerLazySingleton<GPClock>(GPSystemClock.new)
    // Must stay a singleton: `v7()` keeps a counter that orders IDs minted in the same millisecond, which only holds with one generator.
    ..registerLazySingleton<GPUuidGenerator>(() => GPUuidGeneratorImpl(clock: c<GPClock>()))
    ..registerLazySingleton<GPAppLogger>(
      () => GPDeveloperLogger(clock: c<GPClock>(), minLevel: kReleaseMode ? GPLogLevel.info : GPLogLevel.debug),
    )
    ..registerLazySingleton<GPLocaleStore>(() => GPDriftLocaleStore(database: c<GPAppDatabase>(), clock: c<GPClock>(), logger: c<GPAppLogger>()))
    // Must stay a singleton: it holds the active language, and a second instance would leave part of the tree in the old one.
    ..registerLazySingleton<GPLocalization>(() => GPLocalization(store: c<GPLocaleStore>()));
}

/// Resolving `DeleteAccountUseCase` also needs [configureTransactionsDependencies] (ADR-0010). Registration is lazy, so module call order is free.
void configureAccountsDependencies({GetIt? container}) {
  final c = container ?? getIt;

  c
    ..registerLazySingleton<AccountDao>(() => AccountDao(c<GPAppDatabase>()))
    ..registerLazySingleton<AccountRepository>(
      () => AccountRepositoryImpl(
        dao: c<AccountDao>(),
        clock: c<GPClock>(),
        uuidGenerator: c<GPUuidGenerator>(),
        logger: c<GPAppLogger>(),
        // The sentinel owner until auth (W10). Passed, never defaulted, so every site is greppable.
        ownerId: localOwnerId,
      ),
    )
    ..registerLazySingleton<DeleteAccountUseCase>(
      () => DeleteAccountUseCase(accountRepository: c<AccountRepository>(), transactionRepository: c<TransactionRepository>()),
    );
}

void configureCategoriesDependencies({GetIt? container}) {
  final c = container ?? getIt;

  c
    ..registerLazySingleton<CategoryDao>(() => CategoryDao(c<GPAppDatabase>()))
    ..registerLazySingleton<CategorySeeder>(
      () => CategorySeeder(dao: c<CategoryDao>(), clock: c<GPClock>(), uuidGenerator: c<GPUuidGenerator>(), ownerId: localOwnerId),
    )
    ..registerLazySingleton<CategoryRepository>(
      () => CategoryRepositoryImpl(
        dao: c<CategoryDao>(),
        clock: c<GPClock>(),
        uuidGenerator: c<GPUuidGenerator>(),
        logger: c<GPAppLogger>(),
        ownerId: localOwnerId,
      ),
    );
}

/// Resolving either use case also needs [configureCategoriesDependencies] (ADR-0010). No `DeleteTransactionUseCase` on purpose: deleting owns no rule.
void configureTransactionsDependencies({GetIt? container}) {
  final c = container ?? getIt;

  c
    ..registerLazySingleton<TransactionDao>(() => TransactionDao(c<GPAppDatabase>()))
    ..registerLazySingleton<TransactionRepository>(
      () => TransactionRepositoryImpl(
        dao: c<TransactionDao>(),
        clock: c<GPClock>(),
        uuidGenerator: c<GPUuidGenerator>(),
        logger: c<GPAppLogger>(),
        ownerId: localOwnerId,
      ),
    )
    ..registerLazySingleton<CreateTransactionUseCase>(
      () => CreateTransactionUseCase(transactionRepository: c<TransactionRepository>(), categoryRepository: c<CategoryRepository>()),
    )
    ..registerLazySingleton<UpdateTransactionUseCase>(
      () => UpdateTransactionUseCase(transactionRepository: c<TransactionRepository>(), categoryRepository: c<CategoryRepository>()),
    );
}
