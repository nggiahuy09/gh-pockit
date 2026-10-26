import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/features/categories/data/mapper/category_mapper.dart';
import 'package:ghpockit/features/categories/domain/entities/category_entity.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';

const _t0 = 1757800000000;

CategoryRow _row({String? name, String? nameKey = 'category.food', String type = 'expense', int version = 1, bool isSystem = true}) => CategoryRow(
  id: 'c1',
  ownerId: 'local',
  nameKey: nameKey,
  name: name,
  type: type,
  iconKey: 'food',
  isSystem: isSystem,
  createdAt: _t0,
  updatedAt: _t0,
  version: version,
);

CategoryEntity _mapped(CategoryRow row) => switch (row.toDomain()) {
  MappedCategory(:final category) => category,
  UnmappableCategoryRow(:final reason) => throw TestFailure('Expected a mapped category, got ${reason.name}'),
};

CategoryMapperReason? _rejection(CategoryRow row) => switch (row.toDomain()) {
  MappedCategory() => null,
  UnmappableCategoryRow(:final reason) => reason,
};

void main() {
  group('toDomain', () {
    test('converts every column, epoch millis into UTC DateTimes', () {
      final entity = _mapped(_row(name: 'Cà phê sáng'));

      expect(entity.id, 'c1');
      expect(entity.nameKey, 'category.food');
      expect(entity.name, 'Cà phê sáng');
      expect(entity.type, CategoryType.expense);
      expect(entity.iconKey, 'food');
      expect(entity.colorKey, isNull);
      expect(entity.isSystem, isTrue);
      expect(entity.createdAt, DateTime.fromMillisecondsSinceEpoch(_t0, isUtc: true));
      expect(entity.createdAt.isUtc, isTrue);
      expect(entity.version, 1);
    });

    test('drops no information for a user-created row', () {
      final entity = _mapped(_row(name: 'Cà phê', nameKey: null, isSystem: false));

      expect(entity.nameKey, isNull);
      expect(entity.name, 'Cà phê');
      expect(entity.isSystem, isFalse);
    });

    test('refuses a type this build does not know, instead of guessing', () {
      expect(_rejection(_row(type: 'transfer')), CategoryMapperReason.unknownType);
    });

    test('refuses a row with neither name column, and calls it a broken rule', () {
      // The table's CHECK forbids this row, but a backup from a build before the constraint can still hold one.
      expect(_rejection(_row(nameKey: null)), CategoryMapperReason.brokenDomainRule);
    });

    test('shows the user one sentence whatever the reason', () {
      for (final reason in CategoryMapperReason.values) {
        expect(UnmappableCategoryRow(reason).failure, const GPDatabaseFailure());
      }
    });

    test("maps a tombstoned row like any other, because filtering is the DAO's job", () {
      expect(_rejection(_row()), isNull);
    });
  });

  group('toInsert', () {
    test('states every column, with the owner coming from the caller', () {
      final companion = _mapped(_row(name: 'Cà phê sáng')).toInsert('someone-else');

      expect(companion.id.value, 'c1');
      expect(companion.ownerId.value, 'someone-else');
      expect(companion.nameKey.value, 'category.food');
      expect(companion.name.value, 'Cà phê sáng');
      expect(companion.type.value, 'expense');
      expect(companion.isSystem.value, true);
      expect(companion.createdAt.value, _t0);
      expect(companion.version.value, 1);
    });
  });

  group('toPatch', () {
    test('moves only the columns a user edit may move', () {
      final patch = _mapped(_row(name: 'Cà phê sáng')).toPatch();

      expect(patch.name.value, 'Cà phê sáng');
      expect(patch.iconKey.value, 'food');
    });

    test('leaves out name_key, is_system and type, so neither provenance nor the filing of past transactions can be edited away', () {
      final patch = _mapped(_row(name: 'Cà phê sáng')).toPatch();

      expect(patch.nameKey.present, isFalse);
      expect(patch.isSystem.present, isFalse);
      expect(patch.type.present, isFalse);
      expect(patch.id.present, isFalse);
      expect(patch.ownerId.present, isFalse);
      expect(patch.createdAt.present, isFalse);
      expect(patch.updatedAt.present, isFalse);
      expect(patch.version.present, isFalse);
    });

    test('writes a null name when the user cleared it back to the default', () {
      final patch = _mapped(_row()).toPatch();

      expect(patch.name.present, isTrue);
      expect(patch.name.value, isNull);
    });
  });
}
