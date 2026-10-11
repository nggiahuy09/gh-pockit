import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/owner_id.dart';
import 'package:ghpockit/features/categories/data/daos/category_dao.dart';

void main() {
  const t0 = 1757800000000;
  const t1 = 1757800060000;
  const otherOwner = 'someone-else';

  late GPAppDatabase db;
  late CategoryDao dao;

  setUp(() {
    db = GPAppDatabase.forTesting(NativeDatabase.memory());
    dao = CategoryDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  CategoriesTableCompanion row({
    String id = 'c1',
    String ownerId = localOwnerId,
    String? nameKey = 'category.food',
    String? name,
    String type = 'expense',
    bool isSystem = true,
    int createdAt = t0,
    int version = 1,
  }) => CategoriesTableCompanion.insert(
    id: id,
    ownerId: ownerId,
    nameKey: Value(nameKey),
    name: Value(name),
    type: type,
    isSystem: isSystem,
    createdAt: createdAt,
    updatedAt: createdAt,
    version: version,
  );

  group('watchCategories', () {
    test('emits a newly inserted category', () async {
      final emissions = dao.watchCategories(localOwnerId);

      await dao.insertCategory(row());

      await expectLater(emissions, emitsThrough(predicate<List<CategoryRow>>((rows) => rows.length == 1 && rows.single.nameKey == 'category.food')));
    });

    test('shows only the asked-for owner', () async {
      await dao.insertCategory(row(id: 'mine'));
      await dao.insertCategory(row(id: 'theirs', ownerId: otherOwner));

      expect((await dao.watchCategories(localOwnerId).first).map((r) => r.id), ['mine']);
    });

    test('hides soft-deleted rows', () async {
      await dao.insertCategory(row(id: 'alive'));
      await dao.insertCategory(row(id: 'gone', nameKey: 'category.bills'));
      await dao.softDelete('gone', now: t1);

      expect((await dao.watchCategories(localOwnerId).first).map((r) => r.id), ['alive']);
    });

    test('narrows to one type when asked', () async {
      await dao.insertCategory(row(id: 'spend'));
      await dao.insertCategory(row(id: 'earn', nameKey: 'category.salary', type: 'income'));

      expect((await dao.watchCategories(localOwnerId, type: 'income').first).map((r) => r.id), ['earn']);
      expect(await dao.watchCategories(localOwnerId).first, hasLength(2));
    });

    test('orders by creation, then by id', () async {
      // `a` takes the default t0 but is inserted second; `b` and `c` share t1, so the id breaks their tie.
      await dao.insertCategory(row(id: 'b', nameKey: 'category.bills', createdAt: t1));
      await dao.insertCategory(row(id: 'a'));
      await dao.insertCategory(row(id: 'c', nameKey: 'category.health', createdAt: t1));

      expect((await dao.watchCategories(localOwnerId).first).map((r) => r.id), ['a', 'b', 'c']);
    });
  });

  group('watchCategory', () {
    test('emits null once the row is soft-deleted', () async {
      await dao.insertCategory(row());

      final emissions = dao.watchCategory(localOwnerId, 'c1');
      expect(await emissions.first, isNotNull);

      await dao.softDelete('c1', now: t1);

      await expectLater(dao.watchCategory(localOwnerId, 'c1'), emitsThrough(isNull));
    });
  });

  group('findById', () {
    test('finds a tombstoned row, unlike every other read', () async {
      await dao.insertCategory(row());
      await dao.softDelete('c1', now: t1);

      expect((await dao.findById('c1'))?.deletedAt, t1);
    });
  });

  group('insertMissing', () {
    test('inserts everything on the first run and nothing on the second', () async {
      final rows = [row(), row(id: 'c2', nameKey: 'category.bills')];

      expect(await dao.insertMissing(rows), 2);
      expect(await dao.insertMissing(rows), 0);
      expect(await db.select(db.categoriesTable).get(), hasLength(2));
    });

    test('leaves an existing row exactly as it is, renames included', () async {
      await dao.insertCategory(row(name: 'Ăn uống của tôi'));

      expect(await dao.insertMissing([row()]), 0);
      expect((await dao.findById('c1'))?.name, 'Ăn uống của tôi');
    });

    test('does not resurrect a category the user deleted', () async {
      await dao.insertMissing([row()]);
      await dao.softDelete('c1', now: t1);

      expect(await dao.insertMissing([row()]), 0);
      expect((await dao.findById('c1'))?.deletedAt, t1);
      expect(await dao.watchCategories(localOwnerId).first, isEmpty);
    });

    test('inserts only the rows that are missing', () async {
      await dao.insertMissing([row()]);

      expect(await dao.insertMissing([row(), row(id: 'c2', nameKey: 'category.bills')]), 1);
    });

    test('writes nothing and counts nothing for an empty list', () async {
      expect(await dao.insertMissing([]), 0);
    });
  });

  group('updateCategory', () {
    test('writes the patch and moves updated_at, leaving version alone', () async {
      await dao.insertCategory(row());

      final written = await dao.updateCategory(
        'c1',
        baseVersion: 1,
        patch: const CategoriesTableCompanion(name: Value('Ăn uống')),
        now: t1,
      );

      final updated = await dao.findById('c1');
      expect(written, 1);
      expect(updated?.name, 'Ăn uống');
      expect(updated?.nameKey, 'category.food');
      expect(updated?.updatedAt, t1);
      expect(updated?.version, 1);
    });

    test('writes nothing when the base version is stale', () async {
      await dao.insertCategory(row(version: 2));

      expect(
        await dao.updateCategory(
          'c1',
          baseVersion: 1,
          patch: const CategoriesTableCompanion(name: Value('Ăn uống')),
          now: t1,
        ),
        0,
      );
    });

    test('refuses to edit a tombstone', () async {
      await dao.insertCategory(row());
      await dao.softDelete('c1', now: t1);

      expect(
        await dao.updateCategory(
          'c1',
          baseVersion: 1,
          patch: const CategoriesTableCompanion(name: Value('Ăn uống')),
          now: t1,
        ),
        0,
      );
    });
  });

  group('softDelete', () {
    test('stamps both deleted_at and updated_at', () async {
      await dao.insertCategory(row());

      expect(await dao.softDelete('c1', now: t1), 1);

      final deleted = await dao.findById('c1');
      expect(deleted?.deletedAt, t1);
      expect(deleted?.updatedAt, t1);
    });

    test('deletes a system category, because is_system is provenance and not a lock', () async {
      await dao.insertCategory(row());

      expect(await dao.softDelete('c1', now: t1), 1);
    });

    test('reports 0 on a row that is already gone', () async {
      await dao.insertCategory(row());
      await dao.softDelete('c1', now: t1);

      expect(await dao.softDelete('c1', now: t1), 0);
    });
  });
}
