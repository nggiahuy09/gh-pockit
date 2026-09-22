// `isNull`/`isNotNull` are both drift SQL predicates and matcher expectations; this file wants the matchers.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/owner_id.dart';
import 'package:ghpockit/features/categories/data/daos/category_dao.dart';

/// `CategoryDao` (W3 T5).
///
/// The reads and writes it shares with `AccountDao` are asserted here too rather than assumed — owner scoping and the soft-delete filter are one forgotten
/// `where` away from being wrong per DAO, and "the other DAO does it right" is not a test. What is genuinely new is [CategoryDao.insertMissing]: the first
/// write in this app that happens without a user asking for it, which makes "runs twice, changes nothing the second time" a property worth pinning.
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

  /// Stands in for `CategoryMapper` until T6 builds it — the DAO takes a companion, never a field list.
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
      // `a` keeps the helper's default `createdAt` of t0; the other two are explicitly later, so the expected order is not the insertion order.
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
      // The W13 reconciliation read: the applier has to find a row it already deleted, or it re-inserts the server's copy as a duplicate.
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
      // The reason it is `insertOrIgnore` and not an upsert: re-seeding must never undo the user's edits. An `insertOrReplace` here would silently reset
      // every renamed category on the next launch.
      await dao.insertCategory(row(name: 'Ăn uống của tôi'));

      expect(await dao.insertMissing([row()]), 0);
      expect((await dao.findById('c1'))?.name, 'Ăn uống của tôi');
    });

    test('does not resurrect a category the user deleted', () async {
      // The tombstoned row still holds the id, so the ignore hits it. This only works because seeded ids are derived rather than random — with `v7()` the
      // next run would mint a new id and the deleted category would come back.
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
      // Still there: renaming a seeded category keeps its provenance.
      expect(updated?.nameKey, 'category.food');
      expect(updated?.updatedAt, t1);
      // The server's number, never the client's (§7).
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
      // Editing a deleted row would move its `updated_at` and push a resurrected row at the next sync.
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
      // `deleted_at` is what reads filter on; `updated_at` is what makes the deletion visible to W12's delta pull. Writing only the first produces a row
      // that is locally gone and permanently invisible to sync.
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
