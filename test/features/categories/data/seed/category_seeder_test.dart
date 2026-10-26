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

late GPAppDatabase _db;
late CategoryDao _dao;
late FakeClock _clock;

/// The real generator, not `FakeUuidGenerator`: deterministic ids are a claim about the production one.
CategorySeeder _seeder([String ownerId = localOwnerId]) => CategorySeeder(
  clock: _clock,
  dao: _dao,
  uuidGenerator: GPUuidGeneratorImpl(clock: _clock),
  ownerId: ownerId,
);

void main() {
  setUp(() {
    _db = GPAppDatabase.forTesting(NativeDatabase.memory());
    _dao = CategoryDao(_db);
    _clock = FakeClock();
  });

  tearDown(() => _db.close());

  test('writes one row per default category, all of them system rows', () async {
    expect(await _seeder().seedDefaults(), DefaultCategory.values.length);

    final rows = await _db.select(_db.categoriesTable).get();
    expect(rows, hasLength(DefaultCategory.values.length));
    expect(rows.every((row) => row.isSystem), isTrue);
    expect(rows.every((row) => row.ownerId == localOwnerId), isTrue);
    expect(rows.every((row) => row.version == 1), isTrue);
    expect(rows.every((row) => row.createdAt == _clock.nowEpochMillis()), isTrue);
  });

  test('stores the translation key and leaves name null', () async {
    await _seeder().seedDefaults();

    final rows = await _db.select(_db.categoriesTable).get();
    expect(rows.map((row) => row.nameKey).toSet(), DefaultCategory.values.map((category) => category.nameKey).toSet());
    expect(rows.every((row) => row.name == null), isTrue);
    expect(rows.every((row) => row.iconKey != null), isTrue);
    expect(rows.every((row) => row.colorKey == null), isTrue);
  });

  test('carries each category type through to the row', () async {
    await _seeder().seedDefaults();

    for (final category in DefaultCategory.values) {
      final row = (await _db.select(_db.categoriesTable).get()).firstWhere((row) => row.nameKey == category.nameKey);
      expect(CategoryType.fromStorage(row.type), category.type, reason: '${category.nameKey} should be ${category.type.name}');
    }
  });

  test('is idempotent: a second run writes nothing', () async {
    await _seeder().seedDefaults();

    expect(await _seeder().seedDefaults(), 0);
    expect(await _db.select(_db.categoriesTable).get(), hasLength(DefaultCategory.values.length));
  });

  test('two devices of the same user derive identical ids', () async {
    await _seeder().seedDefaults();
    final first = (await _db.select(_db.categoriesTable).get()).map((row) => row.id).toSet();

    final secondDevice = GPAppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(secondDevice.close);
    final secondDao = CategoryDao(secondDevice);
    await CategorySeeder(
      clock: FakeClock(),
      dao: secondDao,
      uuidGenerator: GPUuidGeneratorImpl(clock: FakeClock()),
      ownerId: localOwnerId,
    ).seedDefaults();
    final second = (await secondDevice.select(secondDevice.categoriesTable).get()).map((row) => row.id).toSet();

    expect(second, first);
  });

  test('gives two owners different ids for the same category', () async {
    await _seeder().seedDefaults();
    await _seeder('someone-else').seedDefaults();

    final rows = await _db.select(_db.categoriesTable).get();
    expect(rows, hasLength(DefaultCategory.values.length * 2));
    expect(rows.map((row) => row.id).toSet(), hasLength(DefaultCategory.values.length * 2));
  });

  test('does not bring back a category the user deleted', () async {
    await _seeder().seedDefaults();
    final food = (await _db.select(_db.categoriesTable).get()).firstWhere((row) => row.nameKey == 'category.food');
    await _dao.softDelete(food.id, now: _clock.nowEpochMillis());

    expect(await _seeder().seedDefaults(), 0);
    expect((await _dao.watchCategories(ownerId: localOwnerId).first).map((row) => row.nameKey), isNot(contains('category.food')));
  });

  test('stamps every row with one instant, read once from the clock', () async {
    await CategorySeeder(clock: _clock, dao: _dao, uuidGenerator: FakeUuidGenerator(), ownerId: localOwnerId).seedDefaults();

    final stamps = (await _db.select(_db.categoriesTable).get()).map((row) => row.createdAt).toSet();
    expect(stamps, hasLength(1));
  });

  test('every default category has a distinct key', () {
    expect(DefaultCategory.values.map((category) => category.nameKey).toSet(), hasLength(DefaultCategory.values.length));
  });

  test('fromNameKey is the inverse of nameKey, and null for anything else', () {
    for (final category in DefaultCategory.values) {
      expect(DefaultCategory.fromNameKey(category.nameKey), category);
    }

    expect(DefaultCategory.fromNameKey('category.pets'), isNull);
    expect(DefaultCategory.fromNameKey(''), isNull);
  });
}
