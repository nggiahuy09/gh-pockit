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
      final result = mapper.toEntity(row()) as MappedAccount;

      expect(result.account.id, 'a1');
      expect(result.account.name, 'Ví tiền mặt');
      expect(result.account.type, AccountType.cash);
      expect(result.account.initialBalance, Money(1500000, 'VND'));
      expect(result.account.isArchived, isFalse);
      expect(result.account.version, 1);
    });

    test('turns epoch millis into UTC DateTimes', () {
      final result = mapper.toEntity(row()) as MappedAccount;

      expect(result.account.createdAt, DateTime.fromMillisecondsSinceEpoch(t0, isUtc: true));
      expect(result.account.updatedAt, DateTime.fromMillisecondsSinceEpoch(t1, isUtc: true));
      expect(result.account.createdAt.isUtc, isTrue);
      expect(result.account.updatedAt.isUtc, isTrue);
    });

    test('drops owner_id and deleted_at, which the entity does not carry', () {
      // Asserted by construction: the entity has no field to carry them.
      final result = mapper.toEntity(row(deletedAt: t1)) as MappedAccount;

      expect(result.account.id, 'a1');
    });

    test('maps a tombstone rather than refusing it', () {
      expect(mapper.toEntity(row(deletedAt: t1)), isA<MappedAccount>());
    });

    test('reports an unknown type as a database failure, not as an "other" account', () {
      expect((mapper.toEntity(row(type: 'savings')) as UnmappableAccountRow).reason, AccountMapperReason.unknownType);
    });

    test('reports a malformed currency code as a database failure', () {
      expect((mapper.toEntity(row(currencyCode: 'vnd')) as UnmappableAccountRow).reason, AccountMapperReason.malformedCurrencyCode);
      expect((mapper.toEntity(row(currencyCode: '')) as UnmappableAccountRow).reason, AccountMapperReason.malformedCurrencyCode);
    });

    test('re-labels a broken domain rule as a database failure, not a validation failure', () {
      expect((mapper.toEntity(row(name: '   ')) as UnmappableAccountRow).reason, AccountMapperReason.brokenDomainRule);
      expect((mapper.toEntity(row(name: 'a' * (AccountEntity.nameMaxLength + 1))) as UnmappableAccountRow).reason, AccountMapperReason.brokenDomainRule);
    });
  });

  test('every rejection reads the same to the user, whatever the reason', () {
    for (final reason in AccountMapperReason.values) {
      expect(UnmappableAccountRow(reason).failure, const GPDatabaseFailure(), reason: '${reason.name} should not invent its own message');
    }
  });

  test('every reason is reachable from a real row', () {
    final produced = {
      (mapper.toEntity(row(type: 'savings')) as UnmappableAccountRow).reason,
      (mapper.toEntity(row(currencyCode: 'vnd')) as UnmappableAccountRow).reason,
      (mapper.toEntity(row(name: '  ')) as UnmappableAccountRow).reason,
    };

    expect(produced, AccountMapperReason.values.toSet());
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
      // The one column left absent: a fresh row is alive.
      expect(companion.deletedAt, const Value<int?>.absent());
    });

    test('splits Money back into its two columns', () {
      final companion = mapper.toInsert(entity(initialBalance: Money(1234, 'USD')), ownerId: localOwnerId);

      expect(companion.initialBalance, const Value(1234));
      expect(companion.currencyCode, const Value('USD'));
    });

    test('writes the enum through storageValue, not through its Dart name', () {
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
    final original = row(type: 'credit_card', currencyCode: 'USD', initialBalance: -4500, isArchived: true, version: 7);
    final mapped = (mapper.toEntity(original) as MappedAccount).account;
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
