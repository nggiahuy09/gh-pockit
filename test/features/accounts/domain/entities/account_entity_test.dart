import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';

import '../../../../helpers/results.dart';

final _createdAt = DateTime.utc(2026, 9, 14, 10);
final _updatedAt = DateTime.utc(2026, 9, 14, 10);

GPResult<AccountEntity> _build({Money? initialBalance, AccountType type = AccountType.cash, String name = 'Ví tiền mặt', int version = 1, bool isArchived = false}) =>
    AccountEntity.create(
      initialBalance: initialBalance ?? Money(1500000, 'VND'),
      type: type,
      createdAt: _createdAt,
      updatedAt: _updatedAt,
      id: 'acc-1',
      name: name,
      version: version,
      isArchived: isArchived,
    );

void main() {
  group('create', () {
    test('keeps every field it was given', () {
      final account = okValue(_build());

      expect(account.id, 'acc-1');
      expect(account.name, 'Ví tiền mặt');
      expect(account.type, AccountType.cash);
      expect(account.initialBalance, Money(1500000, 'VND'));
      expect(account.isArchived, isFalse);
      expect(account.createdAt, _createdAt);
      expect(account.updatedAt, _updatedAt);
      expect(account.version, 1);
    });

    test('defaults a new account to live and version 1', () {
      final account = okValue(
        AccountEntity.create(initialBalance: Money.zero('VND'), type: AccountType.bank, createdAt: _createdAt, updatedAt: _updatedAt, id: 'acc-2', name: 'Vietcombank'),
      );

      expect(account.isArchived, isFalse);
      expect(account.version, 1);
    });

    test('trims the name', () {
      expect(okValue(_build(name: '  Ví tiền mặt  ')).name, 'Ví tiền mặt');
    });

    test('rejects a blank name with a code naming the field', () {
      expect(_build(name: ''), const GPErr<AccountEntity>(GPValidationFailure(GPValidationCode.accountNameEmpty)));
    });

    test('treats a whitespace-only name as blank, not as three characters', () {
      expect(_build(name: '   '), const GPErr<AccountEntity>(GPValidationFailure(GPValidationCode.accountNameEmpty)));
    });

    test('accepts a name exactly at the limit and rejects one past it', () {
      expect(okValue(_build(name: 'a' * AccountEntity.nameMaxLength)).name.length, AccountEntity.nameMaxLength);
      expect(_build(name: 'a' * (AccountEntity.nameMaxLength + 1)), const GPErr<AccountEntity>(GPValidationFailure(GPValidationCode.accountNameTooLong)));
    });

    test('measures the limit after trimming', () {
      expect(_build(name: '${'a' * AccountEntity.nameMaxLength}   '), isA<GPOk<AccountEntity>>());
    });

    test('normalises timestamps to UTC', () {
      final local = DateTime(2026, 9, 14, 17);
      final account = okValue(
        AccountEntity.create(initialBalance: Money.zero('VND'), type: AccountType.eWallet, createdAt: local, updatedAt: local, id: 'acc-3', name: 'Momo'),
      );

      expect(account.createdAt.isUtc, isTrue);
      expect(account.updatedAt.isUtc, isTrue);
      expect(account.createdAt, local.toUtc());
    });
  });

  group('update', () {
    test('changes only what it is given', () {
      final account = okValue(okValue(_build()).update(name: 'Ví mới'));

      expect(account.name, 'Ví mới');
      expect(account.id, 'acc-1');
      expect(account.createdAt, _createdAt);
      expect(account.type, AccountType.cash);
      expect(account.initialBalance, Money(1500000, 'VND'));
      expect(account.version, 1);
    });

    test("does not move updatedAt — that is the repository's job", () {
      expect(okValue(okValue(_build()).update(name: 'Ví mới')).updatedAt, _updatedAt);
    });

    test('re-validates the new name', () {
      expect(okValue(_build()).update(name: ''), const GPErr<AccountEntity>(GPValidationFailure(GPValidationCode.accountNameEmpty)));
    });

    test('moves the opening balance in the currency the account was created with', () {
      final account = okValue(okValue(_build()).update(initialBalanceMinorUnits: -250000));

      expect(account.initialBalance, Money(-250000, 'VND'));
    });

    test('toggles isArchived without touching anything else', () {
      final archived = okValue(okValue(_build()).update(isArchived: true));

      expect(archived.isArchived, isTrue);
      expect(archived.version, 1);
      expect(archived.name, 'Ví tiền mặt');
    });

    test('leaves the original untouched', () {
      final original = okValue(_build());

      okValue(original.update(name: 'Something else'));

      expect(original.name, 'Ví tiền mặt');
    });
  });

  group('withUpdatedAt', () {
    test('moves updatedAt and nothing else', () {
      final later = DateTime.utc(2026, 9, 15, 8);
      final account = okValue(_build()).withUpdatedAt(later);

      expect(account.updatedAt, later);
      expect(account.createdAt, _createdAt);
      expect(account.name, 'Ví tiền mặt');
      expect(account.version, 1);
    });

    test('normalises to UTC', () {
      final local = DateTime(2026, 9, 15, 17);

      expect(okValue(_build()).withUpdatedAt(local).updatedAt, local.toUtc());
      expect(okValue(_build()).withUpdatedAt(local).updatedAt.isUtc, isTrue);
    });
  });

  group('equality', () {
    test('is by value over every field', () {
      expect(okValue(_build()), okValue(_build()));
      expect(okValue(_build()).hashCode, okValue(_build()).hashCode);
    });

    test('differs when any single field differs', () {
      final base = okValue(_build());

      expect(base, isNot(okValue(_build(name: 'Khác'))));
      expect(base, isNot(okValue(_build(type: AccountType.bank))));
      expect(base, isNot(okValue(_build(initialBalance: Money(1, 'VND')))));
      expect(base, isNot(okValue(_build(initialBalance: Money(1500000, 'USD')))));
      expect(base, isNot(okValue(_build(isArchived: true))));
      expect(base, isNot(okValue(_build(version: 2))));
    });
  });

  test('toString carries no name and no balance', () {
    final account = okValue(_build(name: 'Lương tháng 9'));

    expect(account.toString(), 'AccountEntity(id: acc-1, type: cash, isArchived: false, version: 1)');
    expect(account.toString(), isNot(contains('Lương')));
    expect(account.toString(), isNot(contains('1500000')));
  });
}
