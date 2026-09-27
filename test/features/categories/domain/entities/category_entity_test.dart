import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/features/categories/domain/entities/category_entity.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';

/// `CategoryEntity` (W3 T6) — and specifically the two-name invariant, which is the only thing here that `AccountEntity` does not already cover.
void main() {
  final t0 = DateTime.utc(2026, 9, 22, 10);
  final t1 = DateTime.utc(2026, 9, 22, 11);

  GPResult<CategoryEntity> build({String? nameKey, String? name, bool isSystem = false, CategoryType type = CategoryType.expense, int version = 1}) =>
      CategoryEntity.create(id: 'c1', nameKey: nameKey, name: name, type: type, isSystem: isSystem, createdAt: t0, updatedAt: t0, version: version);

  CategoryEntity ok(GPResult<CategoryEntity> result) => (result as GPOk<CategoryEntity>).value;

  group('create', () {
    test('accepts a seeded category: a key and no name', () {
      final category = ok(build(nameKey: 'category.food', isSystem: true));

      expect(category.nameKey, 'category.food');
      expect(category.name, isNull);
      expect(category.isSystem, isTrue);
    });

    test('accepts a user-created category: a name and no key', () {
      final category = ok(build(name: 'Cà phê'));

      expect(category.nameKey, isNull);
      expect(category.name, 'Cà phê');
      expect(category.isSystem, isFalse);
    });

    test('accepts a renamed seeded category: both', () {
      final category = ok(build(nameKey: 'category.food', name: 'Cà phê sáng', isSystem: true));

      expect(category.nameKey, 'category.food');
      expect(category.name, 'Cà phê sáng');
    });

    test('refuses a category with neither', () {
      // The same invariant as the table's CHECK, stated where a user can be told about it: for a user-created category this is "you left the name blank".
      expect(build(), const GPErr<CategoryEntity>(GPValidationFailure(GPValidationCode.categoryNameEmpty)));
    });

    test('treats a blank typed name as no name at all', () {
      // Trim, then decide. `'   '` is not a three-character name, and collapsing it to null means "empty" and "absent" are one state rather than two that
      // render identically and compare differently.
      expect(build(name: '   '), const GPErr<CategoryEntity>(GPValidationFailure(GPValidationCode.categoryNameEmpty)));
      expect(build(name: ''), const GPErr<CategoryEntity>(GPValidationFailure(GPValidationCode.categoryNameEmpty)));
      // With a key present, a blank name is not an error — it is a seeded category nobody has renamed.
      expect(ok(build(nameKey: 'category.food', name: '   ')).name, isNull);
    });

    test('trims a name it keeps', () {
      expect(ok(build(name: '  Cà phê  ')).name, 'Cà phê');
    });

    test('refuses a name past the limit, and accepts one exactly at it', () {
      expect(ok(build(name: 'a' * CategoryEntity.nameMaxLength)).name, hasLength(CategoryEntity.nameMaxLength));
      expect(
        build(name: 'a' * (CategoryEntity.nameMaxLength + 1)),
        const GPErr<CategoryEntity>(GPValidationFailure(GPValidationCode.categoryNameTooLong)),
      );
    });

    test('normalises timestamps to UTC', () {
      final local = DateTime(2026, 9, 22, 10);
      final category = ok(CategoryEntity.create(id: 'c1', name: 'Cà phê', type: CategoryType.expense, createdAt: local, updatedAt: local));

      expect(category.createdAt.isUtc, isTrue);
      expect(category.createdAt, local.toUtc());
    });
  });

  group('update', () {
    test('keeps the key when the user renames a seeded category', () {
      // The rule T5 established, enforced here by the signature rather than by a check: `update` has no `nameKey` parameter, so there is no way to lose it.
      final renamed = ok(ok(build(nameKey: 'category.food', isSystem: true)).update(name: 'Cà phê sáng'));

      expect(renamed.nameKey, 'category.food');
      expect(renamed.name, 'Cà phê sáng');
      // Provenance survives an edit too: renaming a default does not make it user-made.
      expect(renamed.isSystem, isTrue);
    });

    test('clears a custom name back to the default, which null alone cannot express', () {
      // `name: null` means "leave it alone" for every other optional parameter, so resetting needs its own flag. This is the "use the default name again"
      // edit a settings screen offers.
      final renamed = ok(ok(build(nameKey: 'category.food', name: 'Cà phê sáng', isSystem: true)).update(clearName: true));

      expect(renamed.name, isNull);
      expect(renamed.nameKey, 'category.food');
    });

    test('refuses to clear the name of a category that has no key', () {
      // A user-created category with its name cleared would be a row no screen can render — the same state the table's CHECK refuses.
      expect(ok(build(name: 'Cà phê')).update(clearName: true), const GPErr<CategoryEntity>(GPValidationFailure(GPValidationCode.categoryNameEmpty)));
    });

    test('re-validates the new name', () {
      expect(ok(build(name: 'Cà phê')).update(name: '  '), const GPErr<CategoryEntity>(GPValidationFailure(GPValidationCode.categoryNameEmpty)));
      expect(
        ok(build(name: 'Cà phê')).update(name: 'a' * (CategoryEntity.nameMaxLength + 1)),
        const GPErr<CategoryEntity>(GPValidationFailure(GPValidationCode.categoryNameTooLong)),
      );
    });

    test('leaves updatedAt alone, because only the repository owns the clock', () {
      expect(ok(ok(build(name: 'Cà phê')).update(type: CategoryType.income)).updatedAt, t0);
    });
  });

  test('stampedAt moves only updatedAt', () {
    final stamped = ok(build(name: 'Cà phê')).stampedAt(t1);

    expect(stamped.updatedAt, t1);
    expect(stamped.createdAt, t0);
    expect(stamped.name, 'Cà phê');
  });

  group('equality', () {
    test('is by value over every field', () {
      expect(ok(build(name: 'Cà phê')), ok(build(name: 'Cà phê')));
      expect(ok(build(name: 'Cà phê')).hashCode, ok(build(name: 'Cà phê')).hashCode);
    });

    test('separates a seeded category from a user-created one with the same text', () {
      // Two rows that render identically and are not the same thing. Without `nameKey` in equality, a Drift re-emission could swap one for the other and no
      // widget would rebuild.
      expect(ok(build(nameKey: 'category.food', isSystem: true)), isNot(ok(build(name: 'Food'))));
    });
  });

  test('toString carries the key but never the typed name', () {
    // Golden rule 9. The key is our own constant and identifies the row; the name is user data the moment they rename it.
    final text = ok(build(nameKey: 'category.food', name: 'Cà phê sáng', isSystem: true)).toString();

    expect(text, contains('category.food'));
    expect(text, isNot(contains('Cà phê sáng')));
  });
}
