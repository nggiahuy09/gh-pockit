import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';

void main() {
  final createdAt = DateTime.utc(2026, 9, 14, 10);
  final updatedAt = DateTime.utc(2026, 9, 14, 10);

  GPResult<AccountEntity> build({String name = 'Ví tiền mặt', AccountType type = AccountType.cash, Money? initialBalance, bool isArchived = false, int version = 1}) =>
      AccountEntity.create(
        id: 'acc-1',
        name: name,
        type: type,
        initialBalance: initialBalance ?? Money(1500000, 'VND'),
        createdAt: createdAt,
        updatedAt: updatedAt,
        isArchived: isArchived,
        version: version,
      );

  AccountEntity ok(GPResult<AccountEntity> result) => (result as GPOk<AccountEntity>).value;

  group('create', () {
    test('keeps every field it was given', () {
      final account = ok(build());

      expect(account.id, 'acc-1');
      expect(account.name, 'Ví tiền mặt');
      expect(account.type, AccountType.cash);
      expect(account.initialBalance, Money(1500000, 'VND'));
      expect(account.isArchived, isFalse);
      expect(account.createdAt, createdAt);
      expect(account.updatedAt, updatedAt);
      expect(account.version, 1);
    });

    test('defaults a new account to live and version 1', () {
      final account = ok(
        AccountEntity.create(id: 'acc-2', name: 'Vietcombank', type: AccountType.bank, initialBalance: Money.zero('VND'), createdAt: createdAt, updatedAt: updatedAt),
      );

      expect(account.isArchived, isFalse);
      expect(account.version, 1);
    });

    test('trims the name', () {
      expect(ok(build(name: '  Ví tiền mặt  ')).name, 'Ví tiền mặt');
    });

    test('rejects a blank name with a code naming the field', () {
      expect(build(name: ''), const GPErr<AccountEntity>(GPValidationFailure(GPValidationCode.accountNameEmpty)));
    });

    test('treats a whitespace-only name as blank, not as three characters', () {
      expect(build(name: '   '), const GPErr<AccountEntity>(GPValidationFailure(GPValidationCode.accountNameEmpty)));
    });

    test('accepts a name exactly at the limit and rejects one past it', () {
      expect(ok(build(name: 'a' * AccountEntity.nameMaxLength)).name.length, AccountEntity.nameMaxLength);
      expect(build(name: 'a' * (AccountEntity.nameMaxLength + 1)), const GPErr<AccountEntity>(GPValidationFailure(GPValidationCode.accountNameTooLong)));
    });

    test('measures the limit after trimming', () {
      expect(build(name: '${'a' * AccountEntity.nameMaxLength}   '), isA<GPOk<AccountEntity>>());
    });

    test('normalises timestamps to UTC', () {
      final local = DateTime(2026, 9, 14, 17);
      final account = ok(
        AccountEntity.create(id: 'acc-3', name: 'Momo', type: AccountType.eWallet, initialBalance: Money.zero('VND'), createdAt: local, updatedAt: local),
      );

      expect(account.createdAt.isUtc, isTrue);
      expect(account.updatedAt.isUtc, isTrue);
      expect(account.createdAt, local.toUtc());
    });
  });

  group('update', () {
    test('changes only what it is given', () {
      final account = ok(ok(build()).update(name: 'Ví mới'));

      expect(account.name, 'Ví mới');
      expect(account.id, 'acc-1');
      expect(account.createdAt, createdAt);
      expect(account.type, AccountType.cash);
      expect(account.initialBalance, Money(1500000, 'VND'));
      expect(account.version, 1);
    });

    test("does not move updatedAt — that is the repository's job", () {
      expect(ok(ok(build()).update(name: 'Ví mới')).updatedAt, updatedAt);
    });

    test('re-validates the new name', () {
      expect(ok(build()).update(name: ''), const GPErr<AccountEntity>(GPValidationFailure(GPValidationCode.accountNameEmpty)));
    });

    test('toggles isArchived without touching anything else', () {
      final archived = ok(ok(build()).update(isArchived: true));

      expect(archived.isArchived, isTrue);
      expect(archived.version, 1);
      expect(archived.name, 'Ví tiền mặt');
    });

    test('leaves the original untouched', () {
      final original = ok(build());

      ok(original.update(name: 'Something else'));

      expect(original.name, 'Ví tiền mặt');
    });
  });

  group('stampedAt', () {
    test('moves updatedAt and nothing else', () {
      final later = DateTime.utc(2026, 9, 15, 8);
      final account = ok(build()).stampedAt(later);

      expect(account.updatedAt, later);
      expect(account.createdAt, createdAt);
      expect(account.name, 'Ví tiền mặt');
      expect(account.version, 1);
    });

    test('normalises to UTC', () {
      final local = DateTime(2026, 9, 15, 17);

      expect(ok(build()).stampedAt(local).updatedAt, local.toUtc());
      expect(ok(build()).stampedAt(local).updatedAt.isUtc, isTrue);
    });
  });

  group('equality', () {
    test('is by value over every field', () {
      expect(ok(build()), ok(build()));
      expect(ok(build()).hashCode, ok(build()).hashCode);
    });

    test('differs when any single field differs', () {
      final base = ok(build());

      expect(base, isNot(ok(build(name: 'Khác'))));
      expect(base, isNot(ok(build(type: AccountType.bank))));
      expect(base, isNot(ok(build(initialBalance: Money(1, 'VND')))));
      expect(base, isNot(ok(build(initialBalance: Money(1500000, 'USD')))));
      expect(base, isNot(ok(build(isArchived: true))));
      expect(base, isNot(ok(build(version: 2))));
    });
  });

  test('toString carries no name and no balance', () {
    final account = ok(build(name: 'Lương tháng 9'));

    expect(account.toString(), 'AccountEntity(id: acc-1, type: cash, isArchived: false, version: 1)');
    expect(account.toString(), isNot(contains('Lương')));
    expect(account.toString(), isNot(contains('1500000')));
  });
}
