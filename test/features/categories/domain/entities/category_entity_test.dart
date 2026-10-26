import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/features/categories/domain/entities/category_entity.dart';
import 'package:ghpockit/features/categories/domain/entities/category_type.dart';

import '../../../../helpers/results.dart';

final _t0 = DateTime.utc(2026, 9, 22, 10);
final _t1 = DateTime.utc(2026, 9, 22, 11);

GPResult<CategoryEntity> _build({CategoryType type = CategoryType.expense, String? name, String? nameKey, int version = 1, bool isSystem = false}) =>
    CategoryEntity.create(type: type, createdAt: _t0, updatedAt: _t0, id: 'c1', name: name, nameKey: nameKey, version: version, isSystem: isSystem);

void main() {
  group('create', () {
    test('accepts a seeded category: a key and no name', () {
      final category = okValue(_build(nameKey: 'category.food', isSystem: true));

      expect(category.nameKey, 'category.food');
      expect(category.name, isNull);
      expect(category.isSystem, isTrue);
    });

    test('accepts a user-created category: a name and no key', () {
      final category = okValue(_build(name: 'Cà phê'));

      expect(category.nameKey, isNull);
      expect(category.name, 'Cà phê');
      expect(category.isSystem, isFalse);
    });

    test('accepts a renamed seeded category: both', () {
      final category = okValue(_build(name: 'Cà phê sáng', nameKey: 'category.food', isSystem: true));

      expect(category.nameKey, 'category.food');
      expect(category.name, 'Cà phê sáng');
    });

    test('refuses a category with neither', () {
      expect(_build(), const GPErr<CategoryEntity>(GPValidationFailure(GPValidationCode.categoryNameEmpty)));
    });

    test('treats a blank typed name as no name at all', () {
      expect(_build(name: '   '), const GPErr<CategoryEntity>(GPValidationFailure(GPValidationCode.categoryNameEmpty)));
      expect(_build(name: ''), const GPErr<CategoryEntity>(GPValidationFailure(GPValidationCode.categoryNameEmpty)));
      // With a key, a blank name is no error: a seeded category nobody has renamed.
      expect(okValue(_build(name: '   ', nameKey: 'category.food')).name, isNull);
    });

    test('trims a name it keeps', () {
      expect(okValue(_build(name: '  Cà phê  ')).name, 'Cà phê');
    });

    test('refuses a name past the limit, and accepts one exactly at it', () {
      expect(okValue(_build(name: 'a' * CategoryEntity.nameMaxLength)).name, hasLength(CategoryEntity.nameMaxLength));
      expect(_build(name: 'a' * (CategoryEntity.nameMaxLength + 1)), const GPErr<CategoryEntity>(GPValidationFailure(GPValidationCode.categoryNameTooLong)));
    });

    test('normalises timestamps to UTC', () {
      final local = DateTime(2026, 9, 22, 10);
      final category = okValue(CategoryEntity.create(type: CategoryType.expense, createdAt: local, updatedAt: local, id: 'c1', name: 'Cà phê'));

      expect(category.createdAt.isUtc, isTrue);
      expect(category.createdAt, local.toUtc());
    });
  });

  group('update', () {
    test('keeps the key when the user renames a seeded category', () {
      final renamed = okValue(okValue(_build(nameKey: 'category.food', isSystem: true)).update(name: 'Cà phê sáng'));

      expect(renamed.nameKey, 'category.food');
      expect(renamed.name, 'Cà phê sáng');
      expect(renamed.isSystem, isTrue);
    });

    test('clears a custom name back to the default, which null alone cannot express', () {
      final renamed = okValue(okValue(_build(name: 'Cà phê sáng', nameKey: 'category.food', isSystem: true)).update(clearName: true));

      expect(renamed.name, isNull);
      expect(renamed.nameKey, 'category.food');
    });

    test('refuses to clear the name of a category that has no key', () {
      expect(okValue(_build(name: 'Cà phê')).update(clearName: true), const GPErr<CategoryEntity>(GPValidationFailure(GPValidationCode.categoryNameEmpty)));
    });

    test('re-validates the new name', () {
      expect(okValue(_build(name: 'Cà phê')).update(name: '  '), const GPErr<CategoryEntity>(GPValidationFailure(GPValidationCode.categoryNameEmpty)));
      expect(
        okValue(_build(name: 'Cà phê')).update(name: 'a' * (CategoryEntity.nameMaxLength + 1)),
        const GPErr<CategoryEntity>(GPValidationFailure(GPValidationCode.categoryNameTooLong)),
      );
    });

    test('leaves updatedAt alone, because only the repository owns the clock', () {
      expect(okValue(okValue(_build(name: 'Cà phê')).update(name: 'Trà')).updatedAt, _t0);
    });
  });

  test('withUpdatedAt moves only updatedAt', () {
    final stamped = okValue(_build(name: 'Cà phê')).withUpdatedAt(_t1);

    expect(stamped.updatedAt, _t1);
    expect(stamped.createdAt, _t0);
    expect(stamped.name, 'Cà phê');
  });

  group('equality', () {
    test('is by value over every field', () {
      expect(okValue(_build(name: 'Cà phê')), okValue(_build(name: 'Cà phê')));
      expect(okValue(_build(name: 'Cà phê')).hashCode, okValue(_build(name: 'Cà phê')).hashCode);
    });

    test('separates a seeded category from a user-created one with the same text', () {
      expect(okValue(_build(nameKey: 'category.food', isSystem: true)), isNot(okValue(_build(name: 'Food'))));
    });
  });

  test('toString carries the key but never the typed name', () {
    final text = okValue(_build(name: 'Cà phê sáng', nameKey: 'category.food', isSystem: true)).toString();

    expect(text, contains('category.food'));
    expect(text, isNot(contains('Cà phê sáng')));
  });
}
