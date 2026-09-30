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
import 'package:ghpockit/features/categories/data/daos/category_dao.dart';
import 'package:ghpockit/features/categories/data/repositories/category_repository_impl.dart';
import 'package:ghpockit/features/categories/data/seed/category_seeder.dart';
import 'package:ghpockit/features/categories/domain/repositories/category_repository.dart';
import 'package:ghpockit/features/transactions/data/daos/transaction_dao.dart';
import 'package:ghpockit/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';

/// The app-wide service locator.
///
/// Only `app/bootstrap.dart`, the `configure*Dependencies()` functions and widget-tree entry points are allowed to touch it. A BLoC receives its
/// dependencies through its constructor and never calls `getIt<...>()` itself — otherwise the dependency graph stops being visible in the code and every
/// BLoC test needs a configured locator.
final GetIt getIt = GetIt.instance;

/// Registers the dependencies that belong to no single feature.
///
/// Registration is split per module (`configureCoreDependencies`, `configureAuthDependencies`, …) as in the blueprint, so a module can be
/// registered in isolation in a test instead of booting the whole graph.
///
/// Everything here is a `lazySingleton`: created on first resolve, then shared. Eager construction at startup would put database and network setup
/// on the critical path to the first frame for no reason.
///
/// [container] exists for tests: passing a fresh `GetIt()` keeps a test from mutating the global instance and leaking into the next one.
void configureCoreDependencies({GetIt? container}) {
  final c = container ?? getIt;

  c
    // The one persistent store (ADR-0001). `dispose` matters for tests more than for the app: a test that resets the locator without closing the database
    // leaks an open sqlite connection — and with `shareAcrossIsolates` a leaked connection also leaks the isolate holding it.
    ..registerLazySingleton<GPAppDatabase>(GPAppDatabase.new, dispose: (db) => db.close())
    ..registerLazySingleton<GPClock>(GPSystemClock.new)
    // Singleton, not a factory: `v7()` carries a counter that keeps IDs created in the same millisecond in order, and that only holds if the
    // whole app shares one generator.
    ..registerLazySingleton<GPUuidGenerator>(() => GPUuidGeneratorImpl(clock: c<GPClock>()))
    ..registerLazySingleton<GPAppLogger>(
      // Debug lines are useful while developing and are noise (and a leak risk) in a shipped build, so the filter is set once, here.
      () => GPDeveloperLogger(clock: c<GPClock>(), minLevel: kReleaseMode ? GPLogLevel.info : GPLogLevel.debug),
    )
    // Persistent since W2: before this the binding was `GPInMemoryLocaleStore` and a chosen language did not survive a restart (ADR-0004's W1 debt).
    // Swapping this one line was indeed the only change the app needed, which was the claim `GPLocaleStore` existed to make good on.
    //
    // It does move one thing onto the startup path: `bootstrap()` awaits `GPLocalization.init()`, which now opens the database and reads a row before the
    // first frame instead of returning null immediately. That is a primary-key lookup on a table holding one row, and it is the price of not painting
    // English and then flipping to Vietnamese.
    ..registerLazySingleton<GPLocaleStore>(() => GPDriftLocaleStore(database: c<GPAppDatabase>(), clock: c<GPClock>(), logger: c<GPAppLogger>()))
    // Singleton, not a factory: it is the one object holding the active language, and a second instance would leave half the tree in the old one.
    ..registerLazySingleton<GPLocalization>(() => GPLocalization(store: c<GPLocaleStore>()));
}

/// Registers the `accounts` feature (W2 T6).
///
/// Depends on [configureCoreDependencies] having run first: it resolves `GPAppDatabase`, `GPClock`, `GPUuidGenerator` and `GPAppLogger` out of the same
/// container. Separate function rather than more lines in the core one, so a widget test for one feature can register that feature and nothing else.
void configureAccountsDependencies({GetIt? container}) {
  final c = container ?? getIt;

  c
    // **The only `AccountDao` in the process**, which is why the DAO is deliberately absent from `@DriftDatabase(daos: ...)` — that annotation would
    // generate a second instance on `GPAppDatabase`, and two ways to reach one DAO is how a write ends up committing outside the transaction that was
    // supposed to contain it.
    ..registerLazySingleton<AccountDao>(() => AccountDao(c<GPAppDatabase>()))
    // Registered against the interface: presentation depends on `AccountRepository` and never names the impl, so a BLoC test can hand in a fake without
    // a database (§3, dependency inversion).
    ..registerLazySingleton<AccountRepository>(
      () => AccountRepositoryImpl(
        dao: c<AccountDao>(),
        clock: c<GPClock>(),
        uuidGenerator: c<GPUuidGenerator>(),
        logger: c<GPAppLogger>(),
        // The W10 seam, stated rather than defaulted so it is greppable. Auth turns this into a session lookup; until then every row is owned by the
        // sentinel — see `core/database/owner_id.dart` for why it is not a nullable column.
        ownerId: localOwnerId,
      ),
    );
}

/// Registers the `categories` feature (W3 T5–T6).
///
/// Same rules as the accounts module: one DAO instance in the process, the repository registered against its interface, and the module separate so a test
/// can register it alone. The seeder is the one addition accounts has no equivalent of — see `bootstrap()` for why it runs on every launch.
void configureCategoriesDependencies({GetIt? container}) {
  final c = container ?? getIt;

  c
    ..registerLazySingleton<CategoryDao>(() => CategoryDao(c<GPAppDatabase>()))
    // Registered rather than constructed at the call site, because `bootstrap` should not be the place that knows a seeder needs a clock and a uuid
    // generator. `ownerId` is the same W10 seam as the accounts repository — stated, not defaulted, so it is greppable when auth lands.
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

/// Registers the `transactions` feature (W4 T6).
///
/// Same rules as the accounts module: one DAO instance in the process, the repository registered against its interface, the module separate so a test can
/// register it alone. Registered although nothing on screen reads it before W5 — as `CategoryRepository` was at W3 T6 — so the first BLoC finds the graph
/// already wired rather than being the change that grows it.
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
        // The same W10 seam as the other two repositories — stated, not defaulted, so it is greppable when auth lands.
        ownerId: localOwnerId,
      ),
    );
}
