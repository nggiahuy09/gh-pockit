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
import '../../../../helpers/results.dart';

final _startedAt = DateTime.utc(2026, 9, 22, 9);

Future<CategoryEntity> _create(CategoryRepositoryImpl repository, {CategoryType type = CategoryType.expense, String name = 'Cà phê'}) async =>
    okValue(await repository.createCategory(type: type, name: name));

Future<CategoryEntity> _seededFood(CategoryRepositoryImpl repository) async =>
    (await repository.watchCategories().first).firstWhere((category) => category.nameKey == DefaultCategory.food.nameKey);

/// Real in-memory SQL, not a mocked DAO: a mock would only restate which DAO methods the repository calls.
void main() {
  late GPAppDatabase db;
  late CategoryDao dao;
  late FakeClock clock;
  late FakeUuidGenerator uuid;
  late RecordingLogger logger;
  late CategoryRepositoryImpl repository;
  late CategorySeeder seeder;

  setUp(() {
    db = GPAppDatabase.forTesting(NativeDatabase.memory());
    dao = CategoryDao(db);
    clock = FakeClock(_startedAt);
    uuid = FakeUuidGenerator();
    logger = RecordingLogger(clock);
    repository = CategoryRepositoryImpl(clock: clock, dao: dao, logger: logger, uuidGenerator: uuid, ownerId: localOwnerId);
    seeder = CategorySeeder(clock: clock, dao: dao, uuidGenerator: uuid, ownerId: localOwnerId);
  });

  tearDown(() => db.close());

  group('createCategory', () {
    test('writes a row the stream then emits', () async {
      final created = await _create(repository);

      expect(created.name, 'Cà phê');
      expect(created.isSystem, isFalse);
      expect(created.nameKey, isNull);
      expect((await repository.watchCategories().first).map((category) => category.id), [created.id]);
    });

    test('mints a v7 id and stamps one instant on both timestamps', () async {
      final created = await _create(repository);

      expect(created.id, uuid.issuedV7.single);
      expect(created.createdAt, _startedAt);
      expect(created.updatedAt, _startedAt);
    });

    test('refuses a blank name without touching storage', () async {
      final result = await repository.createCategory(type: CategoryType.expense, name: '   ');

      expect(result, const GPErr<CategoryEntity>(GPValidationFailure(GPValidationCode.categoryNameEmpty)));
      expect(await db.select(db.categoriesTable).get(), isEmpty);
    });
  });

  group('watchCategories', () {
    test('narrows to one type in SQL, not in Dart', () async {
      await _create(repository);
      final salary = await _create(repository, type: CategoryType.income, name: 'Lương');

      expect((await repository.watchCategories(CategoryType.income).first).map((category) => category.id), [salary.id]);
      expect(await repository.watchCategories().first, hasLength(2));
    });

    test('hides rows belonging to another owner', () async {
      await _create(repository);
      final otherRepository = CategoryRepositoryImpl(clock: clock, dao: dao, logger: logger, uuidGenerator: uuid, ownerId: 'someone-else');

      expect(await otherRepository.watchCategories().first, isEmpty);
    });

    test('fails the whole list on one unreadable row, and logs the reason without the name', () async {
      await _create(repository);
      await db.customStatement("UPDATE categories SET type = 'transfer'");

      await expectLater(repository.watchCategories(), emitsError(const GPDatabaseFailure()));

      expect(logger.last.fields['entity'], 'category');
      expect(logger.last.fields['reason'], 'unknownType');
      expect(logger.last.fields.values, isNot(contains('Cà phê')));
    });
  });

  group('watchCategory', () {
    test('emits null once the category is deleted, so a detail screen can pop itself', () async {
      final created = await _create(repository);

      expect(await repository.watchCategory(created.id).first, created);

      await repository.deleteCategory(created.id);

      await expectLater(repository.watchCategory(created.id), emitsThrough(isNull));
    });
  });

  group('updateCategory', () {
    test('renames a seeded category and keeps its key', () async {
      await seeder.seedDefaults();
      final food = await _seededFood(repository);

      clock.advance(const Duration(minutes: 5));
      final renamed = okValue(await repository.updateCategory(okValue(food.update(name: 'Cà phê sáng'))));

      expect(renamed.name, 'Cà phê sáng');
      expect(renamed.nameKey, DefaultCategory.food.nameKey);
      expect(renamed.isSystem, isTrue);
      expect(renamed.updatedAt, _startedAt.add(const Duration(minutes: 5)));
      expect((await dao.findById(food.id))?.nameKey, DefaultCategory.food.nameKey);
    });

    test('clears a custom name back to the default', () async {
      await seeder.seedDefaults();
      final food = await _seededFood(repository);
      final renamed = okValue(await repository.updateCategory(okValue(food.update(name: 'Cà phê sáng'))));

      final reset = okValue(await repository.updateCategory(okValue(renamed.update(clearName: true))));

      expect(reset.name, isNull);
      // Read off the row: had the patch left `name` absent, the returned entity would still say null.
      expect((await dao.findById(food.id))?.name, isNull);
    });

    test('reports a conflict, with both versions, when the row moved on', () async {
      final created = await _create(repository);
      await db.customStatement('UPDATE categories SET version = 4');

      final result = await repository.updateCategory(okValue(created.update(name: 'Trà')));

      expect(result, GPErr<CategoryEntity>(GPConflictFailure(entityId: created.id, localVersion: 1, remoteVersion: 4)));
    });

    test('reports not-found for a tombstoned row rather than a conflict', () async {
      final created = await _create(repository);
      await repository.deleteCategory(created.id);

      expect(await repository.updateCategory(okValue(created.update(name: 'Trà'))), const GPErr<CategoryEntity>(GPNotFoundFailure()));
    });

    test('reports not-found for an id that never existed', () async {
      final created = await _create(repository);
      await db.customStatement('DELETE FROM categories');

      expect(await repository.updateCategory(okValue(created.update(name: 'Trà'))), const GPErr<CategoryEntity>(GPNotFoundFailure()));
    });
  });

  group('deleteCategory', () {
    test('soft-deletes: the row stays, the list does not show it', () async {
      final created = await _create(repository);

      expect(await repository.deleteCategory(created.id), const GPOk<void>(null));
      expect(await repository.watchCategories().first, isEmpty);
      expect((await dao.findById(created.id))?.deletedAt, _startedAt.millisecondsSinceEpoch);
    });

    test('deletes a system category, and the seeder does not bring it back', () async {
      await seeder.seedDefaults();
      final food = await _seededFood(repository);

      expect(await repository.deleteCategory(food.id), const GPOk<void>(null));
      expect(await seeder.seedDefaults(), 0);
      expect((await repository.watchCategories().first).map((category) => category.nameKey), isNot(contains(DefaultCategory.food.nameKey)));
    });

    test('reports not-found when there is no live row', () async {
      final created = await _create(repository);
      await repository.deleteCategory(created.id);

      expect(await repository.deleteCategory(created.id), const GPErr<void>(GPNotFoundFailure()));
    });
  });

  test('every seeded category survives a round trip through the repository', () async {
    await seeder.seedDefaults();

    final categories = await repository.watchCategories().first;

    expect(categories, hasLength(DefaultCategory.values.length));
    expect(categories.every((category) => category.isSystem), isTrue);
    expect(categories.every((category) => category.name == null), isTrue);
    expect(categories.map((category) => category.nameKey).toSet(), DefaultCategory.values.map((category) => category.nameKey).toSet());
    expect(
      categories.where((category) => category.type == CategoryType.income).map((category) => category.nameKey).toSet(),
      DefaultCategory.values.where((category) => category.type == CategoryType.income).map((category) => category.nameKey).toSet(),
    );
  });

  group('a read the database refuses', () {
    // Real SQL fails a read only wholesale, and never with an `Error`.
    late Object error;
    late CategoryRepositoryImpl failing;

    setUp(() {
      error = SqliteException(10, 'disk I/O error');
      failing = CategoryRepositoryImpl(clock: clock, dao: _FailingStreamCategoryDao(db, () => error), logger: logger, uuidGenerator: uuid, ownerId: localOwnerId);
    });

    test('watchCategories reports an exception and logs an entity type, nothing else', () async {
      await expectLater(failing.watchCategories(), emitsError(const GPDatabaseFailure()));

      expect(logger.last.level, GPLogLevel.error);
      expect(logger.last.fields, {'entity': 'category'});
    });

    test('watchCategory reports it too, and logs the id', () async {
      await expectLater(failing.watchCategory('c1'), emitsError(const GPDatabaseFailure()));

      expect(logger.last.fields, {'entity': 'category', 'id': 'c1'});
    });

    test('an Error is forwarded unchanged — it is a bug, not a sentence', () async {
      final bug = StateError('broken invariant');
      error = bug;

      await expectLater(failing.watchCategories(), emitsError(same(bug)));
      await expectLater(failing.watchCategory('c1'), emitsError(same(bug)));
      expect(logger.records, isEmpty);
    });
  });
}

final class _FailingStreamCategoryDao extends CategoryDao {
  _FailingStreamCategoryDao(super.attachedDatabase, this._error);

  final Object Function() _error;

  @override
  Stream<List<CategoryRow>> watchCategories({required String ownerId, String? type}) => Stream.error(_error.call());

  @override
  Stream<CategoryRow?> watchCategory({required String id, required String ownerId}) => Stream.error(_error.call());
}
