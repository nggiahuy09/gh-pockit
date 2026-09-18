import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';

/// The first domain entity under test (W2 T5).
///
/// The rules asserted here are the ones `accounts_table.dart` deliberately refused to put in SQL: "a name may not be blank" is a business rule, and the
/// table's doc comment says so in as many words. If they are not enforced here they are enforced nowhere, because the DB path was chosen not to.
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

  /// Unwraps a result the test knows is ok, so the assertions below read as assertions rather than as switch statements.
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
      // `version` starts at 1 rather than 0 because §7 makes it the token the server matches on, and `accounts_table.dart` deliberately gives the column
      // no SQL default — a value nobody wrote is indistinguishable from a value the server confirmed.
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
      // The code, not just "invalid", is the UX point: the form puts this message under the name input instead of showing "check your input" and letting
      // the user hunt.
      expect(build(name: ''), const GPErr<AccountEntity>(GPValidationFailure(GPValidationCode.accountNameEmpty)));
    });

    test('treats a whitespace-only name as blank, not as three characters', () {
      // Trim happens before the check, so `'   '` cannot slip through and be stored as a name that renders as nothing.
      expect(build(name: '   '), const GPErr<AccountEntity>(GPValidationFailure(GPValidationCode.accountNameEmpty)));
    });

    test('accepts a name exactly at the limit and rejects one past it', () {
      expect(ok(build(name: 'a' * AccountEntity.nameMaxLength)).name.length, AccountEntity.nameMaxLength);
      expect(build(name: 'a' * (AccountEntity.nameMaxLength + 1)), const GPErr<AccountEntity>(GPValidationFailure(GPValidationCode.accountNameTooLong)));
    });

    test('measures the limit after trimming', () {
      // Otherwise a pasted name with trailing spaces is rejected for a length the user cannot see.
      expect(build(name: '${'a' * AccountEntity.nameMaxLength}   '), isA<GPOk<AccountEntity>>());
    });

    test('normalises timestamps to UTC', () {
      // §6 keeps timezones out of storage entirely. Normalising rather than asserting means a caller holding a local DateTime gets the right instant
      // instead of a failed test three layers away.
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
    test('changes only what it is given, and always the timestamp', () {
      final later = DateTime.utc(2026, 9, 15, 8);
      final account = ok(ok(build()).update(name: 'Ví mới', updatedAt: later));

      expect(account.name, 'Ví mới');
      expect(account.updatedAt, later);
      // Untouched: identity, birth date, and everything not named in the call.
      expect(account.id, 'acc-1');
      expect(account.createdAt, createdAt);
      expect(account.type, AccountType.cash);
      expect(account.initialBalance, Money(1500000, 'VND'));
      expect(account.version, 1);
    });

    test('re-validates the new name', () {
      // A rename is user input like any other, so it fails the same way rather than throwing.
      expect(ok(build()).update(name: '', updatedAt: updatedAt), const GPErr<AccountEntity>(GPValidationFailure(GPValidationCode.accountNameEmpty)));
    });

    test('toggles isArchived without touching anything else', () {
      final later = DateTime.utc(2026, 9, 15, 8);
      final archived = ok(ok(build()).update(isArchived: true, updatedAt: later));

      expect(archived.isArchived, isTrue);
      // Archived is not deleted and not a new version: as far as sync is concerned it is an ordinary field change (§7, `AccountDao.archive`).
      expect(archived.version, 1);
      expect(archived.name, 'Ví tiền mặt');
    });

    test('leaves the original untouched', () {
      final original = ok(build());

      ok(original.update(name: 'Something else', updatedAt: DateTime.utc(2026, 9, 15, 8)));

      expect(original.name, 'Ví tiền mặt');
    });
  });

  group('equality', () {
    test('is by value over every field', () {
      // Load bearing for `flutter_bloc`: a Drift stream re-emits freshly mapped instances after any write to the table, and without this every write
      // would rebuild every account widget on screen.
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
    // Golden rule 9. This entity gets interpolated into repository and sync logs, and `redactSensitiveFields` only sees maps — by the time a string
    // exists it is too late. Same guard as `failure_test.dart` keeps on GPConflictFailure.
    final account = ok(build(name: 'Lương tháng 9'));

    expect(account.toString(), 'AccountEntity(id: acc-1, type: cash, isArchived: false, version: 1)');
    expect(account.toString(), isNot(contains('Lương')));
    expect(account.toString(), isNot(contains('1500000')));
  });
}
