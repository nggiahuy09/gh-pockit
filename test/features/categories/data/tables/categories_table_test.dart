import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/owner_id.dart';

CategoriesTableCompanion _category({
  String id = 'c1',
  String? name,
  String? nameKey = 'category.food',
  String ownerId = localOwnerId,
  String type = 'expense',
  bool isSystem = true,
}) => CategoriesTableCompanion.insert(
  id: id,
  ownerId: ownerId,
  nameKey: Value(nameKey),
  name: Value(name),
  type: type,
  iconKey: const Value('food'),
  isSystem: isSystem,
  createdAt: 1757800000000,
  updatedAt: 1757800000000,
  version: 1,
);

void main() {
  late GPAppDatabase db;

  setUp(() => db = GPAppDatabase.forTesting(NativeDatabase.memory()));

  tearDown(() => db.close());

  test('round-trips every column, with both name columns independent', () async {
    await db.into(db.categoriesTable).insert(_category(name: 'Ăn uống của tôi'));

    final row = await db.select(db.categoriesTable).getSingle();

    expect(row.ownerId, localOwnerId);
    expect(row.nameKey, 'category.food');
    expect(row.name, 'Ăn uống của tôi');
    expect(row.type, 'expense');
    expect(row.iconKey, 'food');
    expect(row.colorKey, isNull);
    expect(row.isSystem, true);
    expect(row.version, 1);
    expect(row.deletedAt, isNull);
  });

  test('accepts a row with only a key, and one with only a name', () async {
    await db.into(db.categoriesTable).insert(_category(id: 'seeded'));
    await db.into(db.categoriesTable).insert(_category(id: 'mine', name: 'Cà phê', nameKey: null, isSystem: false));

    expect(await db.select(db.categoriesTable).get(), hasLength(2));
  });

  test('refuses a row with neither a key nor a name', () async {
    await expectLater(
      db.into(db.categoriesTable).insert(_category(nameKey: null)),
      throwsA(isA<SqliteException>()),
    );
  });

  test('refuses two rows claiming the same key for one owner', () async {
    await db.into(db.categoriesTable).insert(_category(id: 'first'));

    await expectLater(
      db.into(db.categoriesTable).insert(_category(id: 'second')),
      throwsA(isA<SqliteException>()),
    );
  });

  test('allows the same key under two different owners', () async {
    await db.into(db.categoriesTable).insert(_category(id: 'mine'));
    await db.into(db.categoriesTable).insert(_category(id: 'theirs', ownerId: 'someone-else'));

    expect(await db.select(db.categoriesTable).get(), hasLength(2));
  });

  test('allows any number of user-created rows, because NULL keys are distinct', () async {
    await db.into(db.categoriesTable).insert(_category(id: 'u1', name: 'Cà phê', nameKey: null, isSystem: false));
    await db.into(db.categoriesTable).insert(_category(id: 'u2', name: 'Sách', nameKey: null, isSystem: false));
    await db.into(db.categoriesTable).insert(_category(id: 'u3', name: 'Sách', nameKey: null, isSystem: false));

    expect(await db.select(db.categoriesTable).get(), hasLength(3));
  });
}
