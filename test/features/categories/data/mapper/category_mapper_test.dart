import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/features/categories/data/mapper/category_mapper.dart';
import 'package:ghpockit/features/categories/domain/entities/category_entity.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';

/// `CategoryMapper` (W3 T6): the one place a row and an entity are allowed to disagree, and the place that decides what an unreadable row is.
void main() {
  const mapper = CategoryMapper();
  const t0 = 1757800000000;

  CategoryRow row({String? nameKey = 'category.food', String? name, String type = 'expense', bool isSystem = true, int version = 1}) => CategoryRow(
    id: 'c1',
    ownerId: 'local',
    nameKey: nameKey,
    name: name,
    type: type,
    iconKey: 'food',
    isSystem: isSystem,
    createdAt: t0,
    updatedAt: t0,
    version: version,
  );

  CategoryEntity mapped(CategoryRow input) => (mapper.toEntity(input) as MappedCategory).category;

  group('toEntity', () {
    test('converts every column, epoch millis into UTC DateTimes', () {
      final entity = mapped(row(name: 'Cà phê sáng'));

      expect(entity.id, 'c1');
      expect(entity.nameKey, 'category.food');
      expect(entity.name, 'Cà phê sáng');
      expect(entity.type, CategoryType.expense);
      expect(entity.iconKey, 'food');
      expect(entity.colorKey, isNull);
      expect(entity.isSystem, isTrue);
      expect(entity.createdAt, DateTime.fromMillisecondsSinceEpoch(t0, isUtc: true));
      expect(entity.createdAt.isUtc, isTrue);
      expect(entity.version, 1);
    });

    test('drops no information for a user-created row', () {
      final entity = mapped(row(nameKey: null, name: 'Cà phê', isSystem: false));

      expect(entity.nameKey, isNull);
      expect(entity.name, 'Cà phê');
      expect(entity.isSystem, isFalse);
    });

    test('refuses a type this build does not know, instead of guessing', () {
      // A row from a newer build or a corrupted one. Coercing it to `expense` would file income under spending and then write the guess back on the next
      // edit, destroying the original value.
      expect(mapper.toEntity(row(type: 'transfer')), isA<UnmappableCategoryRow>().having((r) => r.reason, 'reason', CategoryMapperReason.unknownType));
    });

    test('refuses a row with neither name column, and calls it a broken rule', () {
      // The table's CHECK makes this unreachable through SQL, so a row in this state arrived some other way — a backup restored from a build before the
      // constraint. The mapper is the last place it can be stopped before it reaches a picker as a blank entry.
      expect(
        mapper.toEntity(row(nameKey: null)),
        isA<UnmappableCategoryRow>().having((r) => r.reason, 'reason', CategoryMapperReason.brokenDomainRule),
      );
    });

    test('shows the user one sentence whatever the reason', () {
      // The flattening happens once, here, not at each call site: the user is looking at a list, so "could not read local data" is the only true sentence.
      // The reason stays distinct for the log.
      for (final reason in CategoryMapperReason.values) {
        expect(UnmappableCategoryRow(reason).failure, const GPDatabaseFailure());
      }
    });

    test("maps a tombstoned row like any other, because filtering is the DAO's job", () {
      // `CategoryEntity` has no `deletedAt`, and `findById` deliberately returns tombstones for W14's applier. A filter here would make the applier unable
      // to use the mapper at all.
      expect(mapper.toEntity(row()), isA<MappedCategory>());
    });
  });

  group('toInsert', () {
    test('states every column, with the owner coming from the caller', () {
      final companion = mapper.toInsert(mapped(row(name: 'Cà phê sáng')), ownerId: 'someone-else');

      expect(companion.id.value, 'c1');
      // Not on the entity by design, so only the repository can supply it.
      expect(companion.ownerId.value, 'someone-else');
      expect(companion.nameKey.value, 'category.food');
      expect(companion.name.value, 'Cà phê sáng');
      expect(companion.type.value, 'expense');
      expect(companion.isSystem.value, true);
      expect(companion.createdAt.value, t0);
      expect(companion.version.value, 1);
    });
  });

  group('toPatch', () {
    test('moves only the columns a user edit may move', () {
      final patch = mapper.toPatch(mapped(row(name: 'Cà phê sáng')));

      expect(patch.name.value, 'Cà phê sáng');
      expect(patch.type.value, 'expense');
      expect(patch.iconKey.value, 'food');
    });

    test('leaves out name_key and is_system, so provenance cannot be edited away', () {
      // The omission is the mechanism. `name_key` absent from every patch is what makes "a rename keeps the key" hold even for a caller that builds a patch
      // by hand, and `is_system` absent is what stops an edit from laundering a seeded row into a user-made one.
      final patch = mapper.toPatch(mapped(row(name: 'Cà phê sáng')));

      expect(patch.nameKey.present, isFalse);
      expect(patch.isSystem.present, isFalse);
      // Identity and the server's fields, absent for the reasons `AccountMapper.toPatch` gives.
      expect(patch.id.present, isFalse);
      expect(patch.ownerId.present, isFalse);
      expect(patch.createdAt.present, isFalse);
      expect(patch.updatedAt.present, isFalse);
      expect(patch.version.present, isFalse);
    });

    test('writes a null name when the user cleared it back to the default', () {
      // `present` with a null value, not absent: the column must actually be set to NULL, or "use the default again" would silently do nothing.
      final patch = mapper.toPatch(mapped(row()));

      expect(patch.name.present, isTrue);
      expect(patch.name.value, isNull);
    });
  });
}
