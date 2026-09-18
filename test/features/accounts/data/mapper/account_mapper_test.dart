import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/owner_id.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/data/mapper/account_mapper.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';

/// The three-model rule under test (W2 T6).
///
/// The mapper is the only place the row and the entity are allowed to disagree, so this file is where each disagreement is checked in both directions.
/// The asymmetry is the theme: entity → row is a rename of fields and cannot fail, row → entity is *parsing* and can.
///
/// Rows are built through `AccountRow` directly rather than by inserting and reading back. The DAO and the table have their own test files; what this one
/// needs is a row with an exact, and sometimes deliberately invalid, shape.
void main() {
  const mapper = AccountMapper();
  const t0 = 1757800000000;
  const t1 = 1757800060000;

  AccountRow row({
    String id = 'a1',
    String name = 'Ví tiền mặt',
    String type = 'cash',
    String currencyCode = 'VND',
    int initialBalance = 1500000,
    bool isArchived = false,
    int version = 1,
    int? deletedAt,
  }) => AccountRow(
    id: id,
    ownerId: localOwnerId,
    name: name,
    type: type,
    currencyCode: currencyCode,
    initialBalance: initialBalance,
    isArchived: isArchived,
    createdAt: t0,
    updatedAt: t1,
    version: version,
    deletedAt: deletedAt,
  );

  AccountEntity entity({String name = 'Ví tiền mặt', AccountType type = AccountType.cash, Money? initialBalance, bool isArchived = false, int version = 1}) =>
      (AccountEntity.create(
                id: 'a1',
                name: name,
                type: type,
                initialBalance: initialBalance ?? Money(1500000, 'VND'),
                createdAt: DateTime.fromMillisecondsSinceEpoch(t0, isUtc: true),
                updatedAt: DateTime.fromMillisecondsSinceEpoch(t1, isUtc: true),
                isArchived: isArchived,
                version: version,
              )
              as GPOk<AccountEntity>)
          .value;

  group('toEntity', () {
    test('maps every column, joining the two money columns into one Money', () {
      final result = mapper.toEntity(row()) as GPOk<AccountEntity>;

      expect(result.value.id, 'a1');
      expect(result.value.name, 'Ví tiền mặt');
      expect(result.value.type, AccountType.cash);
      // The disagreement that matters most: two columns in SQLite, one indivisible value above it.
      expect(result.value.initialBalance, Money(1500000, 'VND'));
      expect(result.value.isArchived, isFalse);
      expect(result.value.version, 1);
    });

    test('turns epoch millis into UTC DateTimes', () {
      final result = mapper.toEntity(row()) as GPOk<AccountEntity>;

      expect(result.value.createdAt, DateTime.fromMillisecondsSinceEpoch(t0, isUtc: true));
      expect(result.value.updatedAt, DateTime.fromMillisecondsSinceEpoch(t1, isUtc: true));
      // §6 keeps timezones out of storage; a non-UTC DateTime reaching the domain would make `createdAt == createdAt` depend on the device.
      expect(result.value.createdAt.isUtc, isTrue);
      expect(result.value.updatedAt.isUtc, isTrue);
    });

    test('drops owner_id and deleted_at, which the entity does not carry', () {
      // Asserted by construction: there is no field to read them from. What this pins is that a tombstone still maps — see below.
      final result = mapper.toEntity(row(deletedAt: t1)) as GPOk<AccountEntity>;

      expect(result.value.id, 'a1');
    });

    test('maps a tombstone rather than refusing it', () {
      // Deliberate: `AccountDao.findById` is the one read that sees tombstones, and W13's applier needs to map one in order to reconcile it. Every read a
      // user reaches already filters `deleted_at IS NULL` in SQL, so filtering here too would only break the applier.
      expect(mapper.toEntity(row(deletedAt: t1)), isA<GPOk<AccountEntity>>());
    });

    test('reports an unknown type as a database failure, not as an "other" account', () {
      // Coercing to `AccountType.other` would hide the corruption and then write the coerced value back on the next edit, destroying the original.
      expect(mapper.toEntity(row(type: 'savings')), const GPErr<AccountEntity>(GPDatabaseFailure()));
    });

    test('reports a malformed currency code as a database failure', () {
      // Reached through `Money.fromStorage`, so no `Error` is caught on this path — the code is data here, not a programmer mistake.
      expect(mapper.toEntity(row(currencyCode: 'vnd')), const GPErr<AccountEntity>(GPDatabaseFailure()));
      expect(mapper.toEntity(row(currencyCode: '')), const GPErr<AccountEntity>(GPDatabaseFailure()));
    });

    test('re-labels a broken domain rule as a database failure, not a validation failure', () {
      // The UX decision in this file: the user is looking at a list, not typing. "Account name can't be empty" would be a sentence about an input that is
      // not on screen; what actually happened is that local data cannot be read.
      expect(mapper.toEntity(row(name: '   ')), const GPErr<AccountEntity>(GPDatabaseFailure()));
      expect(mapper.toEntity(row(name: 'a' * (AccountEntity.nameMaxLength + 1))), const GPErr<AccountEntity>(GPDatabaseFailure()));
    });
  });

  group('toInsert', () {
    test('states every column, so nothing is left to a SQL default', () {
      final companion = mapper.toInsert(entity(), ownerId: localOwnerId);

      expect(companion.id, const Value('a1'));
      expect(companion.ownerId, const Value(localOwnerId));
      expect(companion.name, const Value('Ví tiền mặt'));
      expect(companion.type, const Value('cash'));
      expect(companion.currencyCode, const Value('VND'));
      expect(companion.initialBalance, const Value(1500000));
      expect(companion.isArchived, const Value(false));
      expect(companion.createdAt, const Value(t0));
      expect(companion.updatedAt, const Value(t1));
      expect(companion.version, const Value(1));
      // Absent is the correct state for the one nullable column: a fresh row is alive.
      expect(companion.deletedAt, const Value<int?>.absent());
    });

    test('splits Money back into its two columns', () {
      final companion = mapper.toInsert(entity(initialBalance: Money(1234, 'USD')), ownerId: localOwnerId);

      expect(companion.initialBalance, const Value(1234));
      expect(companion.currencyCode, const Value('USD'));
    });

    test('writes the enum through storageValue, not through its Dart name', () {
      // `AccountType.eWallet` must reach SQLite as `e_wallet`. If this ever prints `eWallet`, the table's refusal of drift's `textEnum` has been undone
      // somewhere and a rename has become a silent data migration.
      expect(mapper.toInsert(entity(type: AccountType.eWallet), ownerId: localOwnerId).type, const Value('e_wallet'));
      expect(mapper.toInsert(entity(type: AccountType.creditCard), ownerId: localOwnerId).type, const Value('credit_card'));
    });

    test('takes the owner from its argument, since the entity has none', () {
      expect(mapper.toInsert(entity(), ownerId: 'user-42').ownerId, const Value('user-42'));
    });
  });

  group('toPatch', () {
    test('carries only the columns a user edit may move', () {
      final patch = mapper.toPatch(entity(name: 'Ví mới', isArchived: true));

      expect(patch.name, const Value('Ví mới'));
      expect(patch.type, const Value('cash'));
      expect(patch.currencyCode, const Value('VND'));
      expect(patch.initialBalance, const Value(1500000));
      expect(patch.isArchived, const Value(true));
    });

    test('leaves identity, ownership, version and updated_at absent', () {
      // Each absence is load bearing and each has its own reason — identity cannot move or sync loses the row, `owner_id` is not the entity's to state,
      // `version` is the server's (§7), and `updated_at` is stamped by the DAO so a patch cannot skip the pull cursor.
      final patch = mapper.toPatch(entity(version: 9));

      expect(patch.id, const Value<String>.absent());
      expect(patch.ownerId, const Value<String>.absent());
      expect(patch.createdAt, const Value<int>.absent());
      expect(patch.updatedAt, const Value<int>.absent());
      expect(patch.version, const Value<int>.absent());
      expect(patch.deletedAt, const Value<int?>.absent());
    });
  });

  test('a row survives a round trip through the entity and back', () {
    // The property the three-model rule is actually for: three shapes, no information lost between them.
    final original = row(type: 'credit_card', currencyCode: 'USD', initialBalance: -4500, isArchived: true, version: 7);
    final mapped = (mapper.toEntity(original) as GPOk<AccountEntity>).value;
    final companion = mapper.toInsert(mapped, ownerId: localOwnerId);

    expect(companion.type, Value(original.type));
    expect(companion.currencyCode, Value(original.currencyCode));
    expect(companion.initialBalance, Value(original.initialBalance));
    expect(companion.isArchived, Value(original.isArchived));
    expect(companion.createdAt, Value(original.createdAt));
    expect(companion.updatedAt, Value(original.updatedAt));
    expect(companion.version, Value(original.version));
  });
}
