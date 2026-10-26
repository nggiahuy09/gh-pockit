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
import 'package:ghpockit/features/categories/data/daos/category_dao.dart';
import 'package:ghpockit/features/categories/data/repositories/category_repository_impl.dart';
import 'package:ghpockit/features/categories/data/seed/category_seeder.dart';
import 'package:ghpockit/features/categories/domain/repositories/category_repository.dart';
import 'package:ghpockit/features/transactions/data/daos/transaction_dao.dart';
import 'package:ghpockit/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';

void main() {
  group('configureCoreDependencies', () {
    late GetIt container;

    setUp(() {
      container = GetIt.asNewInstance();
      configureCoreDependencies(container);
    });

    tearDown(() => container.reset());

    test('registers the three core abstractions', () {
      expect(container.get<GPClock>(), isA<GPSystemClock>());
      expect(container.get<GPUuidGenerator>(), isA<GPUuidGeneratorImpl>());
      expect(container.get<GPAppLogger>(), isA<GPDeveloperLogger>());
    });

    test('resolves each one as a singleton', () {
      expect(container.get<GPClock>(), same(container.get<GPClock>()));
      expect(container.get<GPUuidGenerator>(), same(container.get<GPUuidGenerator>()));
      expect(container.get<GPAppLogger>(), same(container.get<GPAppLogger>()));
    });

    test('registers against the interface, not the implementation', () {
      expect(container.isRegistered<GPClock>(), isTrue);
      expect(container.isRegistered<GPSystemClock>(), isFalse);
      expect(container.isRegistered<GPUuidGenerator>(), isTrue);
      expect(container.isRegistered<GPUuidGeneratorImpl>(), isFalse);
    });

    test('wires the logger to the registered GPClock', () {
      container.get<GPAppLogger>().info('probe');

      expect(container.get<GPClock>(), isA<GPSystemClock>());
    });

    test('binds the locale store to Drift, not to the in-memory one', () async {
      await _useMemoryDatabase(container);

      expect(container.get<GPLocaleStore>(), isA<GPDriftLocaleStore>());
      expect(container.isRegistered<GPLocaleStore>(), isTrue);
      expect(container.isRegistered<GPDriftLocaleStore>(), isFalse);
    });

    test('a reset container can be configured again', () async {
      // get_it throws on a duplicate registration, so a hot restart relies on the reset alone.
      await container.reset();

      expect(() => configureCoreDependencies(container), returnsNormally);
      expect(container.get<GPClock>(), isA<GPSystemClock>());
    });

    test('defaults to the global locator when no container is given', () {
      configureCoreDependencies();
      addTearDown(getIt.reset);

      expect(getIt.get<GPClock>(), isA<GPSystemClock>());
    });
  });

  group('configureAccountsDependencies', () {
    late GetIt container;

    setUp(() async {
      container = GetIt.asNewInstance();
      configureCoreDependencies(container);
      await _useMemoryDatabase(container);
      configureAccountsDependencies(container);
    });

    tearDown(() => container.reset());

    test('registers the repository against its interface, not the impl', () {
      expect(container.get<AccountRepository>(), isA<AccountRepositoryImpl>());
      expect(container.isRegistered<AccountRepository>(), isTrue);
      expect(container.isRegistered<AccountRepositoryImpl>(), isFalse);
    });

    test('hands out one AccountDao, shared with the repository', () {
      expect(container.get<AccountDao>(), same(container.get<AccountDao>()));
      expect(container.get<AccountRepository>(), same(container.get<AccountRepository>()));
    });

    test('binds the DAO to the same database the core module registered', () {
      expect(container.get<AccountDao>().attachedDatabase, same(container.get<GPAppDatabase>()));
    });
  });

  group('configureCategoriesDependencies', () {
    late GetIt container;

    setUp(() async {
      container = GetIt.asNewInstance();
      configureCoreDependencies(container);
      await _useMemoryDatabase(container);
      configureCategoriesDependencies(container);
    });

    tearDown(() => container.reset());

    test('registers the repository against its interface, not the impl', () {
      expect(container.get<CategoryRepository>(), isA<CategoryRepositoryImpl>());
      expect(container.isRegistered<CategoryRepositoryImpl>(), isFalse);
    });

    test('hands out one CategoryDao, bound to the database the core module registered, and the seeder', () {
      expect(container.get<CategoryDao>(), same(container.get<CategoryDao>()));
      expect(container.get<CategoryDao>().attachedDatabase, same(container.get<GPAppDatabase>()));
      expect(container.get<CategorySeeder>(), isA<CategorySeeder>());
    });
  });

  group('configureTransactionsDependencies', () {
    late GetIt container;

    setUp(() async {
      container = GetIt.asNewInstance();
      configureCoreDependencies(container);
      await _useMemoryDatabase(container);
      configureTransactionsDependencies(container);
    });

    tearDown(() => container.reset());

    test('registers the repository against its interface, not the impl', () {
      expect(container.get<TransactionRepository>(), isA<TransactionRepositoryImpl>());
      expect(container.isRegistered<TransactionRepositoryImpl>(), isFalse);
    });

    test('hands out one TransactionDao, bound to the database the core module registered', () {
      expect(container.get<TransactionDao>(), same(container.get<TransactionDao>()));
      expect(container.get<TransactionDao>().attachedDatabase, same(container.get<GPAppDatabase>()));
    });
  });
}

/// The production database asks `path_provider` for a path, which a unit test cannot answer. Lazy registration allows the swap.
Future<void> _useMemoryDatabase(GetIt container) async {
  await container.unregister<GPAppDatabase>();
  container.registerLazySingleton<GPAppDatabase>(() => GPAppDatabase.forTesting(NativeDatabase.memory()), dispose: (db) => db.close());
}
