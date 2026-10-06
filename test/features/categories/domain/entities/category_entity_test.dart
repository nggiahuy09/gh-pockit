import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/features/categories/domain/entities/category_entity.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';

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
      expect(build(), const GPErr<CategoryEntity>(GPValidationFailure(GPValidationCode.categoryNameEmpty)));
    });

    test('treats a blank typed name as no name at all', () {
      expect(build(name: '   '), const GPErr<CategoryEntity>(GPValidationFailure(GPValidationCode.categoryNameEmpty)));
      expect(build(name: ''), const GPErr<CategoryEntity>(GPValidationFailure(GPValidationCode.categoryNameEmpty)));
      // With a key, a blank name is no error: a seeded category nobody has renamed.
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
      final renamed = ok(ok(build(nameKey: 'category.food', isSystem: true)).update(name: 'Cà phê sáng'));

      expect(renamed.nameKey, 'category.food');
      expect(renamed.name, 'Cà phê sáng');
      expect(renamed.isSystem, isTrue);
    });

    test('clears a custom name back to the default, which null alone cannot express', () {
      final renamed = ok(ok(build(nameKey: 'category.food', name: 'Cà phê sáng', isSystem: true)).update(clearName: true));

      expect(renamed.name, isNull);
      expect(renamed.nameKey, 'category.food');
    });

    test('refuses to clear the name of a category that has no key', () {
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
      expect(ok(build(nameKey: 'category.food', isSystem: true)), isNot(ok(build(name: 'Food'))));
    });
  });

  test('toString carries the key but never the typed name', () {
    final text = ok(build(nameKey: 'category.food', name: 'Cà phê sáng', isSystem: true)).toString();

    expect(text, contains('category.food'));
    expect(text, isNot(contains('Cà phê sáng')));
  });
}
