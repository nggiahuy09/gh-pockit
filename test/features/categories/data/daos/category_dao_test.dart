import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/owner_id.dart';
import 'package:ghpockit/features/categories/data/daos/category_dao.dart';

const _t0 = 1757800000000;
const _t1 = 1757800060000;
const _otherOwner = 'someone-else';

CategoriesTableCompanion _row({
  String id = 'c1',
  String? name,
  String? nameKey = 'category.food',
  String ownerId = localOwnerId,
  String type = 'expense',
  int createdAt = _t0,
  int version = 1,
  bool isSystem = true,
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

void main() {
  late GPAppDatabase db;
  late CategoryDao dao;

  setUp(() {
    db = GPAppDatabase.forTesting(NativeDatabase.memory());
    dao = CategoryDao(db);
  });

  tearDown(() => db.close());

  group('watchCategories', () {
    test('emits a newly inserted category', () async {
      final emissions = dao.watchCategories(ownerId: localOwnerId);

      await dao.insertCategory(_row());

      await expectLater(emissions, emitsThrough(predicate<List<CategoryRow>>((rows) => rows.length == 1 && rows.single.nameKey == 'category.food')));
    });

    test('shows only the asked-for owner', () async {
      await dao.insertCategory(_row(id: 'mine'));
      await dao.insertCategory(_row(id: 'theirs', ownerId: _otherOwner));

      expect((await dao.watchCategories(ownerId: localOwnerId).first).map((r) => r.id), ['mine']);
    });

    test('hides soft-deleted rows', () async {
      await dao.insertCategory(_row(id: 'alive'));
      await dao.insertCategory(_row(id: 'gone', nameKey: 'category.bills'));
      await dao.softDelete('gone', now: _t1);

      expect((await dao.watchCategories(ownerId: localOwnerId).first).map((r) => r.id), ['alive']);
    });

    test('narrows to one type when asked', () async {
      await dao.insertCategory(_row(id: 'spend'));
      await dao.insertCategory(_row(id: 'earn', nameKey: 'category.salary', type: 'income'));

      expect((await dao.watchCategories(ownerId: localOwnerId, type: 'income').first).map((r) => r.id), ['earn']);
      expect(await dao.watchCategories(ownerId: localOwnerId).first, hasLength(2));
    });

    test('orders by creation, then by id', () async {
      // `a` is inserted second but created first; `b` and `c` share a timestamp, so the id breaks their tie.
      await dao.insertCategory(_row(id: 'b', nameKey: 'category.bills', createdAt: _t1));
      await dao.insertCategory(_row(id: 'a'));
      await dao.insertCategory(_row(id: 'c', nameKey: 'category.health', createdAt: _t1));

      expect((await dao.watchCategories(ownerId: localOwnerId).first).map((r) => r.id), ['a', 'b', 'c']);
    });
  });

  group('watchCategory', () {
    test('emits null once the row is soft-deleted', () async {
      await dao.insertCategory(_row());

      final emissions = dao.watchCategory(id: 'c1', ownerId: localOwnerId);
      expect(await emissions.first, isNotNull);

      await dao.softDelete('c1', now: _t1);

      await expectLater(dao.watchCategory(id: 'c1', ownerId: localOwnerId), emitsThrough(isNull));
    });
  });

  group('findById', () {
    test('finds a tombstoned row, unlike every other read', () async {
      await dao.insertCategory(_row());
      await dao.softDelete('c1', now: _t1);

      expect((await dao.findById('c1'))?.deletedAt, _t1);
    });
  });

  group('insertMissing', () {
    test('inserts everything on the first run and nothing on the second', () async {
      final rows = [_row(), _row(id: 'c2', nameKey: 'category.bills')];

      expect(await dao.insertMissing(rows), 2);
      expect(await dao.insertMissing(rows), 0);
      expect(await db.select(db.categoriesTable).get(), hasLength(2));
    });

    test('leaves an existing row exactly as it is, renames included', () async {
      await dao.insertCategory(_row(name: 'Ăn uống của tôi'));

      expect(await dao.insertMissing([_row()]), 0);
      expect((await dao.findById('c1'))?.name, 'Ăn uống của tôi');
    });

    test('does not resurrect a category the user deleted', () async {
      await dao.insertMissing([_row()]);
      await dao.softDelete('c1', now: _t1);

      expect(await dao.insertMissing([_row()]), 0);
      expect((await dao.findById('c1'))?.deletedAt, _t1);
      expect(await dao.watchCategories(ownerId: localOwnerId).first, isEmpty);
    });

    test('inserts only the rows that are missing', () async {
      await dao.insertMissing([_row()]);

      expect(await dao.insertMissing([_row(), _row(id: 'c2', nameKey: 'category.bills')]), 1);
    });

    test('writes nothing and counts nothing for an empty list', () async {
      expect(await dao.insertMissing([]), 0);
    });
  });

  group('updateCategory', () {
    test('writes the patch and moves updated_at, leaving version alone', () async {
      await dao.insertCategory(_row());

      final written = await dao.updateCategory(
        'c1',
        patch: const CategoriesTableCompanion(name: Value('Ăn uống')),
        baseVersion: 1,
        now: _t1,
      );

      final updated = await dao.findById('c1');
      expect(written, 1);
      expect(updated?.name, 'Ăn uống');
      expect(updated?.nameKey, 'category.food');
      expect(updated?.updatedAt, _t1);
      expect(updated?.version, 1);
    });

    test('writes nothing when the base version is stale', () async {
      await dao.insertCategory(_row(version: 2));

      expect(
        await dao.updateCategory(
          'c1',
          patch: const CategoriesTableCompanion(name: Value('Ăn uống')),
          baseVersion: 1,
          now: _t1,
        ),
        0,
      );
    });

    test('refuses to edit a tombstone', () async {
      await dao.insertCategory(_row());
      await dao.softDelete('c1', now: _t1);

      expect(
        await dao.updateCategory(
          'c1',
          patch: const CategoriesTableCompanion(name: Value('Ăn uống')),
          baseVersion: 1,
          now: _t1,
        ),
        0,
      );
    });
  });

  group('softDelete', () {
    test('stamps both deleted_at and updated_at', () async {
      await dao.insertCategory(_row());

      expect(await dao.softDelete('c1', now: _t1), 1);

      final deleted = await dao.findById('c1');
      expect(deleted?.deletedAt, _t1);
      expect(deleted?.updatedAt, _t1);
    });

    test('deletes a system category, because is_system is provenance and not a lock', () async {
      await dao.insertCategory(_row());

      expect(await dao.softDelete('c1', now: _t1), 1);
    });

    test('reports 0 on a row that is already gone', () async {
      await dao.insertCategory(_row());
      await dao.softDelete('c1', now: _t1);

      expect(await dao.softDelete('c1', now: _t1), 0);
    });
  });
}
