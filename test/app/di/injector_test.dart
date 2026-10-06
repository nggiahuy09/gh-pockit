import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/localization/drift_locale_store.dart';
import 'package:ghpockit/core/localization/locale_store.dart';
import 'package:ghpockit/core/logging/app_logger.dart';
import 'package:ghpockit/core/logging/developer_logger.dart';
import 'package:ghpockit/core/utils/clock.dart';
import 'package:ghpockit/core/utils/uuid_generator.dart';
import 'package:ghpockit/features/accounts/data/daos/account_dao.dart';
import 'package:ghpockit/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:ghpockit/features/accounts/domain/repositories/account_repository.dart';
import 'package:ghpockit/features/accounts/domain/usecases/delete_account_use_case.dart';
import 'package:ghpockit/features/transactions/data/daos/transaction_dao.dart';
import 'package:ghpockit/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:ghpockit/features/transactions/domain/usecases/create_transaction_use_case.dart';
import 'package:ghpockit/features/transactions/domain/usecases/update_transaction_use_case.dart';

void main() {
  group('configureCoreDependencies', () {
    late GetIt container;

    setUp(() {
      // A private container, never `GetIt.instance`: registrations in the global locator would leak into the next test.
      container = GetIt.asNewInstance();
      configureCoreDependencies(container: container);
    });

    tearDown(() => container.reset());

    test('registers the three core abstractions', () {
      expect(container<GPClock>(), isA<GPSystemClock>());
      expect(container<GPUuidGenerator>(), isA<GPUuidGeneratorImpl>());
      expect(container<GPAppLogger>(), isA<GPDeveloperLogger>());
    });

    test('resolves each one as a singleton', () {
      expect(container<GPClock>(), same(container<GPClock>()));
      expect(container<GPUuidGenerator>(), same(container<GPUuidGenerator>()));
      expect(container<GPAppLogger>(), same(container<GPAppLogger>()));
    });

    test('registers against the interface, not the implementation', () {
      expect(container.isRegistered<GPClock>(), isTrue);
      expect(container.isRegistered<GPSystemClock>(), isFalse);
      expect(container.isRegistered<GPUuidGenerator>(), isTrue);
      expect(container.isRegistered<GPUuidGeneratorImpl>(), isFalse);
    });

    test('wires the logger to the registered GPClock', () {
      // Resolving the logger runs its factory, which resolves `GPClock` from this same container.
      container<GPAppLogger>().info('probe');

      expect(container<GPClock>(), isA<GPSystemClock>());
    });

    test('binds the locale store to Drift, not to the in-memory one', () async {
      // In-memory database first: the production one asks `path_provider` for a path, which a unit test cannot answer. Lazy registration allows the swap.
      await container.unregister<GPAppDatabase>();
      container.registerLazySingleton<GPAppDatabase>(() => GPAppDatabase.forTesting(NativeDatabase.memory()), dispose: (db) => db.close());

      expect(container<GPLocaleStore>(), isA<GPDriftLocaleStore>());
      expect(container.isRegistered<GPLocaleStore>(), isTrue);
      expect(container.isRegistered<GPDriftLocaleStore>(), isFalse);
    });

    test('a reset container can be configured again', () async {
      // get_it throws on a duplicate registration, so a reboot (hot restart, an integration test) relies on the reset alone.
      await container.reset();

      expect(() => configureCoreDependencies(container: container), returnsNormally);
      expect(container<GPClock>(), isA<GPSystemClock>());
    });

    test('defaults to the global locator when no container is given', () {
      configureCoreDependencies();
      addTearDown(() async {
        await getIt.reset();
      });

      expect(getIt<GPClock>(), isA<GPSystemClock>());
    });
  });

  group('configureAccountsDependencies', () {
    late GetIt container;

    setUp(() async {
      container = GetIt.asNewInstance();
      configureCoreDependencies(container: container);
      await container.unregister<GPAppDatabase>();
      container.registerLazySingleton<GPAppDatabase>(() => GPAppDatabase.forTesting(NativeDatabase.memory()), dispose: (db) => db.close());
      configureAccountsDependencies(container: container);
    });

    tearDown(() => container.reset());

    test('registers the repository against its interface, not the impl', () {
      expect(container<AccountRepository>(), isA<AccountRepositoryImpl>());
      expect(container.isRegistered<AccountRepository>(), isTrue);
      expect(container.isRegistered<AccountRepositoryImpl>(), isFalse);
    });

    test('hands out one AccountDao, shared with the repository', () {
      expect(container<AccountDao>(), same(container<AccountDao>()));
      expect(container<AccountRepository>(), same(container<AccountRepository>()));
    });

    test('binds the DAO to the same database the core module registered', () {
      expect(container<AccountDao>().attachedDatabase, same(container<GPAppDatabase>()));
    });
  });

  group('configureTransactionsDependencies', () {
    late GetIt container;

    setUp(() async {
      container = GetIt.asNewInstance();
      configureCoreDependencies(container: container);
      await container.unregister<GPAppDatabase>();
      container.registerLazySingleton<GPAppDatabase>(() => GPAppDatabase.forTesting(NativeDatabase.memory()), dispose: (db) => db.close());
      configureTransactionsDependencies(container: container);
    });

    tearDown(() => container.reset());

    test('registers the repository against its interface, not the impl', () {
      expect(container<TransactionRepository>(), isA<TransactionRepositoryImpl>());
      expect(container.isRegistered<TransactionRepositoryImpl>(), isFalse);
    });

    test('hands out one TransactionDao, bound to the database the core module registered', () {
      expect(container<TransactionDao>(), same(container<TransactionDao>()));
      expect(container<TransactionDao>().attachedDatabase, same(container<GPAppDatabase>()));
    });
  });

  group('the use cases, which reach across modules', () {
    late GetIt container;

    setUp(() async {
      container = GetIt.asNewInstance();
      configureCoreDependencies(container: container);
      await container.unregister<GPAppDatabase>();
      container.registerLazySingleton<GPAppDatabase>(() => GPAppDatabase.forTesting(NativeDatabase.memory()), dispose: (db) => db.close());
    });

    tearDown(() => container.reset());

    test("each is registered by its own feature's module", () {
      // `DeleteAccountUseCase` reads transactions but is an accounts operation (ADR-0010).
      configureAccountsDependencies(container: container);

      expect(container.isRegistered<DeleteAccountUseCase>(), isTrue);
      expect(container.isRegistered<CreateTransactionUseCase>(), isFalse);

      configureTransactionsDependencies(container: container);

      expect(container.isRegistered<CreateTransactionUseCase>(), isTrue);
      expect(container.isRegistered<UpdateTransactionUseCase>(), isTrue);
    });

    test('each resolves once every module it reads is configured — in any order, since every registration is lazy', () {
      // The reverse of the order `bootstrap()` uses, on purpose.
      configureTransactionsDependencies(container: container);
      configureCategoriesDependencies(container: container);
      configureAccountsDependencies(container: container);

      expect(container<DeleteAccountUseCase>(), same(container<DeleteAccountUseCase>()));
      expect(container<CreateTransactionUseCase>(), isA<CreateTransactionUseCase>());
      expect(container<UpdateTransactionUseCase>(), isA<UpdateTransactionUseCase>());
    });
  });
}
