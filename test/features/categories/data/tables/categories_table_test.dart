// `isNull` is both a drift SQL predicate and a matcher; this file wants the matcher.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/owner_id.dart';

/// The constraints on `categories` that are decisions rather than drift defaults (W3 T5).
///
/// The §6 column set is the same as `accounts` and is not re-asserted here. What is: the two-name rule, and the uniqueness that makes seeding idempotent.
void main() {
  late GPAppDatabase db;

  setUp(() {
    db = GPAppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  CategoriesTableCompanion category({
    String id = 'c1',
    String ownerId = localOwnerId,
    String? nameKey = 'category.food',
    String? name,
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

  test('round-trips every column, with both name columns independent', () async {
    await db.into(db.categoriesTable).insert(category(name: 'Ăn uống của tôi'));

    final row = await db.select(db.categoriesTable).getSingle();

    expect(row.ownerId, localOwnerId);
    // Both present: a seeded category the user renamed keeps its provenance. Losing the key here is the thing the two-column design exists to prevent.
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
    // The two ordinary shapes: a seeded category nobody has touched, and one the user created.
    await db.into(db.categoriesTable).insert(category(id: 'seeded'));
    await db.into(db.categoriesTable).insert(category(id: 'mine', nameKey: null, name: 'Cà phê', isSystem: false));

    expect(await db.select(db.categoriesTable).get(), hasLength(2));
  });

  test('refuses a row with neither a key nor a name', () async {
    // The CHECK, at the only level that holds for every write path. Without it the table can hold a row no screen can render, and the symptom is a blank
    // line in a picker rather than a rejected insert — the same argument the currency CHECK on `accounts` makes.
    await expectLater(
      db.into(db.categoriesTable).insert(category(nameKey: null)),
      throwsA(isA<SqliteException>()),
    );
  });

  test('refuses two rows claiming the same key for one owner', () async {
    // What makes re-seeding safe even if a row arrives by some route other than the seeder — a pull at W14, or a future "restore defaults".
    await db.into(db.categoriesTable).insert(category(id: 'first'));

    await expectLater(
      db.into(db.categoriesTable).insert(category(id: 'second')),
      throwsA(isA<SqliteException>()),
    );
  });

  test('allows the same key under two different owners', () async {
    // The index is on the pair, not on the key. Two users both have a Food category, and after W10 they are two rows.
    await db.into(db.categoriesTable).insert(category(id: 'mine'));
    await db.into(db.categoriesTable).insert(category(id: 'theirs', ownerId: 'someone-else'));

    expect(await db.select(db.categoriesTable).get(), hasLength(2));
  });

  test('allows any number of user-created rows, because NULL keys are distinct', () async {
    // The reason a plain UNIQUE index is enough and no partial index is needed: SQLite treats NULLs in a unique index as distinct from each other, so the
    // constraint binds seeded rows and ignores user-created ones. If that ever stopped being true, creating a second custom category would start failing.
    await db.into(db.categoriesTable).insert(category(id: 'u1', nameKey: null, name: 'Cà phê', isSystem: false));
    await db.into(db.categoriesTable).insert(category(id: 'u2', nameKey: null, name: 'Sách', isSystem: false));
    await db.into(db.categoriesTable).insert(category(id: 'u3', nameKey: null, name: 'Sách', isSystem: false));

    expect(await db.select(db.categoriesTable).get(), hasLength(3));
  });
}
