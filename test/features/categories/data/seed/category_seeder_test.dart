import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/owner_id.dart';
import 'package:ghpockit/core/utils/uuid_generator.dart';
import 'package:ghpockit/features/categories/data/daos/category_dao.dart';
import 'package:ghpockit/features/categories/data/seed/category_seeder.dart';
import 'package:ghpockit/features/categories/data/seed/default_categories.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';

import '../../../../helpers/fake_clock.dart';
import '../../../../helpers/fake_uuid_generator.dart';

void main() {
  late GPAppDatabase db;
  late CategoryDao dao;
  late FakeClock clock;

  setUp(() {
    db = GPAppDatabase.forTesting(NativeDatabase.memory());
    dao = CategoryDao(db);
    clock = FakeClock();
  });

  tearDown(() async {
    await db.close();
  });

  /// The real generator, not `FakeUuidGenerator`: deterministic ids are a claim about the production one.
  CategorySeeder seeder({String ownerId = localOwnerId, GPUuidGenerator? uuidGenerator}) => CategorySeeder(
    dao: dao,
    clock: clock,
    uuidGenerator: uuidGenerator ?? GPUuidGeneratorImpl(clock: clock),
    ownerId: ownerId,
  );

  test('writes one row per default category, all of them system rows', () async {
    expect(await seeder().seedDefaults(), DefaultCategory.values.length);

    final rows = await db.select(db.categoriesTable).get();
    expect(rows, hasLength(DefaultCategory.values.length));
    expect(rows.every((r) => r.isSystem), isTrue);
    expect(rows.every((r) => r.ownerId == localOwnerId), isTrue);
    expect(rows.every((r) => r.version == 1), isTrue);
    expect(rows.every((r) => r.createdAt == clock.nowEpochMillis()), isTrue);
  });

  test('stores the translation key and leaves name null', () async {
    await seeder().seedDefaults();

    final rows = await db.select(db.categoriesTable).get();
    expect(rows.map((r) => r.nameKey).toSet(), DefaultCategory.values.map((c) => c.nameKey).toSet());
    expect(rows.every((r) => r.name == null), isTrue);
    expect(rows.every((r) => r.iconKey != null), isTrue);
    expect(rows.every((r) => r.colorKey == null), isTrue);
  });

  test('carries each category type through to the row', () async {
    await seeder().seedDefaults();

    for (final category in DefaultCategory.values) {
      final row = (await db.select(db.categoriesTable).get()).firstWhere((r) => r.nameKey == category.nameKey);
      expect(CategoryType.fromStorage(row.type), category.type, reason: '${category.nameKey} should be ${category.type.name}');
    }
  });

  test('is idempotent: a second run writes nothing', () async {
    await seeder().seedDefaults();

    expect(await seeder().seedDefaults(), 0);
    expect(await db.select(db.categoriesTable).get(), hasLength(DefaultCategory.values.length));
  });

  test('two devices of the same user derive identical ids', () async {
    await seeder().seedDefaults();
    final first = (await db.select(db.categoriesTable).get()).map((r) => r.id).toSet();

    final secondDevice = GPAppDatabase.forTesting(NativeDatabase.memory());
    final secondDao = CategoryDao(secondDevice);
    await CategorySeeder(
      dao: secondDao,
      clock: FakeClock(),
      uuidGenerator: GPUuidGeneratorImpl(clock: FakeClock()),
      ownerId: localOwnerId,
    ).seedDefaults();
    final second = (await secondDevice.select(secondDevice.categoriesTable).get()).map((r) => r.id).toSet();

    expect(second, first);

    await secondDevice.close();
  });

  test('gives two owners different ids for the same category', () async {
    await seeder().seedDefaults();
    await seeder(ownerId: 'someone-else').seedDefaults();

    final rows = await db.select(db.categoriesTable).get();
    expect(rows, hasLength(DefaultCategory.values.length * 2));
    expect(rows.map((r) => r.id).toSet(), hasLength(DefaultCategory.values.length * 2));
  });

  test('does not bring back a category the user deleted', () async {
    await seeder().seedDefaults();
    final food = (await db.select(db.categoriesTable).get()).firstWhere((r) => r.nameKey == 'category.food');
    await dao.softDelete(food.id, now: clock.nowEpochMillis());

    expect(await seeder().seedDefaults(), 0);
    expect((await dao.watchCategories(localOwnerId).first).map((r) => r.nameKey), isNot(contains('category.food')));
  });

  test('stamps every row with one instant, read once from the clock', () async {
    final fake = FakeUuidGenerator();
    await CategorySeeder(dao: dao, clock: clock, uuidGenerator: fake, ownerId: localOwnerId).seedDefaults();

    final stamps = (await db.select(db.categoriesTable).get()).map((r) => r.createdAt).toSet();
    expect(stamps, hasLength(1));
  });

  test('every default category has a distinct key', () async {
    expect(DefaultCategory.values.map((c) => c.nameKey).toSet(), hasLength(DefaultCategory.values.length));
  });

  test('fromNameKey is the inverse of nameKey, and null for anything else', () {
    for (final category in DefaultCategory.values) {
      expect(DefaultCategory.fromNameKey(category.nameKey), category);
    }

    expect(DefaultCategory.fromNameKey('category.pets'), isNull);
    expect(DefaultCategory.fromNameKey(''), isNull);
  });
}
