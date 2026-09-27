import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/owner_id.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/logging/app_logger.dart';
import 'package:ghpockit/features/categories/data/daos/category_dao.dart';
import 'package:ghpockit/features/categories/data/repositories/category_repository_impl.dart';
import 'package:ghpockit/features/categories/data/seed/category_seeder.dart';
import 'package:ghpockit/features/categories/data/seed/default_categories.dart';
import 'package:ghpockit/features/categories/domain/entities/category_entity.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';

import '../../../../helpers/fake_clock.dart';
import '../../../../helpers/fake_uuid_generator.dart';
import '../../../../helpers/recording_logger.dart';

/// `CategoryRepositoryImpl` on a real in-memory Drift database (W3 T6), for the reason `account_repository_impl_test.dart` gives: a mocked DAO would assert
/// that the repository calls the methods the test expects, which is a restatement of the implementation rather than a check on it.
///
/// What this file adds over the accounts one is the second writer. Categories are written by the user *and* by `CategorySeeder`, so the cases worth having
/// here are the ones where the two meet: renaming a seeded row, deleting one, and what the seeder does afterwards.
void main() {
  late GPAppDatabase db;
  late CategoryDao dao;
  late FakeClock clock;
  late FakeUuidGenerator uuid;
  late RecordingLogger logger;
  late CategoryRepositoryImpl repository;

  final startedAt = DateTime.utc(2026, 9, 22, 9);

  setUp(() {
    db = GPAppDatabase.forTesting(NativeDatabase.memory());
    dao = CategoryDao(db);
    clock = FakeClock(startedAt);
    uuid = FakeUuidGenerator();
    logger = RecordingLogger(clock: clock);
    repository = CategoryRepositoryImpl(dao: dao, clock: clock, uuidGenerator: uuid, logger: logger, ownerId: localOwnerId);
  });

  tearDown(() async {
    await db.close();
  });

  CategoryEntity ok(GPResult<CategoryEntity> result) => (result as GPOk<CategoryEntity>).value;

  Future<CategoryEntity> create({String name = 'Cà phê', CategoryType type = CategoryType.expense}) async => ok(await repository.createCategory(name: name, type: type));

  group('createCategory', () {
    test('writes a row the stream then emits', () async {
      final created = await create();

      expect(created.name, 'Cà phê');
      expect(created.isSystem, isFalse);
      // No key: a category created through the repository is user-made by definition, and there is no parameter through which a caller could claim
      // otherwise.
      expect(created.nameKey, isNull);
      expect((await repository.watchCategories().first).map((c) => c.id), [created.id]);
    });

    test('mints a v7 id and stamps one instant on both timestamps', () async {
      final created = await create();

      // `v7`, not the seeder's derived `v5`: nothing about a category the user invented is reproducible on another device.
      expect(created.id, uuid.issuedV7.single);
      expect(created.createdAt, startedAt);
      expect(created.updatedAt, startedAt);
    });

    test('refuses a blank name without touching storage', () async {
      final result = await repository.createCategory(name: '   ', type: CategoryType.expense);

      expect(result, const GPErr<CategoryEntity>(GPValidationFailure(GPValidationCode.categoryNameEmpty)));
      expect(await db.select(db.categoriesTable).get(), isEmpty);
    });
  });

  group('watchCategories', () {
    test('narrows to one type in SQL, not in Dart', () async {
      await create();
      final salary = await create(name: 'Lương', type: CategoryType.income);

      expect((await repository.watchCategories(type: CategoryType.income).first).map((c) => c.id), [salary.id]);
      expect(await repository.watchCategories().first, hasLength(2));
    });

    test('hides rows belonging to another owner', () async {
      await create();
      final otherRepository = CategoryRepositoryImpl(dao: dao, clock: clock, uuidGenerator: uuid, logger: logger, ownerId: 'someone-else');

      expect(await otherRepository.watchCategories().first, isEmpty);
    });

    test('fails the whole list on one unreadable row, and logs the reason without the name', () async {
      // The policy W2 T6 chose for accounts, re-decided at the same scale rather than copied. A picker quietly missing one category is worse than a screen
      // that says it could not read local data.
      await create();
      await db.customStatement("UPDATE categories SET type = 'transfer'");

      await expectLater(repository.watchCategories(), emitsError(const GPDatabaseFailure()));

      expect(logger.last.fields['entity'], 'category');
      expect(logger.last.fields['reason'], 'unknownType');
      // Golden rule 9: an id, an entity type and a reason code — never the row's name.
      expect(logger.last.fields.values, isNot(contains('Cà phê')));
    });
  });

  group('watchCategory', () {
    test('emits null once the category is deleted, so a detail screen can pop itself', () async {
      final created = await create();

      expect(await repository.watchCategory(created.id).first, created);

      await repository.deleteCategory(created.id);

      await expectLater(repository.watchCategory(created.id), emitsThrough(isNull));
    });
  });

  group('updateCategory', () {
    test('renames a seeded category and keeps its key', () async {
      // The T5 rule, end to end through the repository: the user's name lands in `name`, `name_key` is untouched, and the row is still recognisably the
      // default it came from.
      await CategorySeeder(dao: dao, clock: clock, uuidGenerator: uuid, ownerId: localOwnerId).seedDefaults();
      final food = (await repository.watchCategories().first).firstWhere((c) => c.nameKey == DefaultCategory.food.nameKey);

      clock.advance(const Duration(minutes: 5));
      final renamed = ok(await repository.updateCategory(ok(food.update(name: 'Cà phê sáng'))));

      expect(renamed.name, 'Cà phê sáng');
      expect(renamed.nameKey, DefaultCategory.food.nameKey);
      expect(renamed.isSystem, isTrue);
      // Stamped by the repository, which is the only holder of a clock.
      expect(renamed.updatedAt, startedAt.add(const Duration(minutes: 5)));
      expect((await dao.findById(food.id))?.nameKey, DefaultCategory.food.nameKey);
    });

    test('clears a custom name back to the default', () async {
      await CategorySeeder(dao: dao, clock: clock, uuidGenerator: uuid, ownerId: localOwnerId).seedDefaults();
      final food = (await repository.watchCategories().first).firstWhere((c) => c.nameKey == DefaultCategory.food.nameKey);
      final renamed = ok(await repository.updateCategory(ok(food.update(name: 'Cà phê sáng'))));

      final reset = ok(await repository.updateCategory(ok(renamed.update(clearName: true))));

      expect(reset.name, isNull);
      // The column really is NULL, not merely absent from the patch — otherwise "use the default again" would silently do nothing.
      expect((await dao.findById(food.id))?.name, isNull);
    });

    test('reports a conflict, with both versions, when the row moved on', () async {
      final created = await create();
      await db.customStatement('UPDATE categories SET version = 4');

      final result = await repository.updateCategory(ok(created.update(name: 'Trà')));

      expect(result, GPErr<CategoryEntity>(GPConflictFailure(entityId: created.id, localVersion: 1, remoteVersion: 4)));
    });

    test('reports not-found for a tombstoned row rather than a conflict', () async {
      final created = await create();
      await repository.deleteCategory(created.id);

      expect(await repository.updateCategory(ok(created.update(name: 'Trà'))), const GPErr<CategoryEntity>(GPNotFoundFailure()));
    });

    test('reports not-found for an id that never existed', () async {
      final created = await create();
      await db.customStatement('DELETE FROM categories');

      expect(await repository.updateCategory(ok(created.update(name: 'Trà'))), const GPErr<CategoryEntity>(GPNotFoundFailure()));
    });
  });

  group('deleteCategory', () {
    test('soft-deletes: the row stays, the list does not show it', () async {
      final created = await create();

      expect(await repository.deleteCategory(created.id), const GPOk<void>(null));
      expect(await repository.watchCategories().first, isEmpty);
      // Golden rule 5: the row survives so the server can be told it is gone.
      expect((await dao.findById(created.id))?.deletedAt, startedAt.millisecondsSinceEpoch);
    });

    test('deletes a system category, and the seeder does not bring it back', () async {
      // `is_system` is provenance, not a lock — and the seeder's derived id still belongs to the tombstone, so the next launch's `INSERT OR IGNORE` is
      // ignored. With random seed ids this test would fail on the second line.
      final seeder = CategorySeeder(dao: dao, clock: clock, uuidGenerator: uuid, ownerId: localOwnerId);
      await seeder.seedDefaults();
      final food = (await repository.watchCategories().first).firstWhere((c) => c.nameKey == DefaultCategory.food.nameKey);

      expect(await repository.deleteCategory(food.id), const GPOk<void>(null));
      expect(await seeder.seedDefaults(), 0);
      expect((await repository.watchCategories().first).map((c) => c.nameKey), isNot(contains(DefaultCategory.food.nameKey)));
    });

    test('reports not-found when there is no live row', () async {
      final created = await create();
      await repository.deleteCategory(created.id);

      expect(await repository.deleteCategory(created.id), const GPErr<void>(GPNotFoundFailure()));
    });
  });

  test('every seeded category survives a round trip through the repository', () async {
    // The two halves of the week meeting: T5 writes eleven rows, T6 reads them back as entities. A mapper that lost the key, the type or the provenance
    // would show up here rather than in W6.
    await CategorySeeder(dao: dao, clock: clock, uuidGenerator: uuid, ownerId: localOwnerId).seedDefaults();

    final categories = await repository.watchCategories().first;

    expect(categories, hasLength(DefaultCategory.values.length));
    expect(categories.every((c) => c.isSystem), isTrue);
    expect(categories.every((c) => c.name == null), isTrue);
    expect(categories.map((c) => c.nameKey).toSet(), DefaultCategory.values.map((c) => c.nameKey).toSet());
    expect(
      categories.where((c) => c.type == CategoryType.income).map((c) => c.nameKey).toSet(),
      DefaultCategory.values.where((c) => c.type == CategoryType.income).map((c) => c.nameKey).toSet(),
    );
  });

  group('a read the database refuses', () {
    /// Builds a repository whose DAO streams fail with [error] instead of emitting rows.
    ///
    /// The one double in this file, for the reason the accounts file's read group gives: real SQL fails a read only wholesale and never with an [Error].
    /// That group also shows, against a real dropped table, that Drift delivers a failed query as an error event — a fact about Drift rather than about
    /// this repository, so it is not proved twice.
    CategoryRepositoryImpl repositoryReadingFrom(Object error) => CategoryRepositoryImpl(
      dao: FailingStreamCategoryDao(db, error),
      clock: clock,
      uuidGenerator: uuid,
      logger: logger,
      ownerId: localOwnerId,
    );

    test('watchCategories reports an exception and logs an entity type, nothing else', () async {
      await expectLater(repositoryReadingFrom(SqliteException(10, 'disk I/O error')).watchCategories(), emitsError(const GPDatabaseFailure()));

      expect(logger.last.level, GPLogLevel.error);
      expect(logger.last.fields, {'entity': 'category'});
    });

    test('watchCategory reports it too, and logs the id', () async {
      await expectLater(repositoryReadingFrom(SqliteException(10, 'disk I/O error')).watchCategory('c1'), emitsError(const GPDatabaseFailure()));

      expect(logger.last.fields, {'entity': 'category', 'id': 'c1'});
    });

    test('an Error is forwarded unchanged — it is a bug, not a sentence', () async {
      final bug = StateError('broken invariant');
      final failing = repositoryReadingFrom(bug);

      await expectLater(failing.watchCategories(), emitsError(same(bug)));
      await expectLater(failing.watchCategory('c1'), emitsError(same(bug)));
      expect(logger.records, isEmpty);
    });
  });
}

/// A [CategoryDao] whose two watch streams fail with a given object instead of emitting rows — `FailingStreamAccountDao`'s counterpart, and a subclass
/// of the real DAO for the same reason: everything it does not override still runs against the in-memory database.
class FailingStreamCategoryDao extends CategoryDao {
  FailingStreamCategoryDao(super.attachedDatabase, this.error);

  final Object error;

  @override
  Stream<List<CategoryRow>> watchCategories(String ownerId, {String? type}) => Stream<List<CategoryRow>>.error(error);

  @override
  Stream<CategoryRow?> watchCategory(String ownerId, String id) => Stream<CategoryRow?>.error(error);
}
