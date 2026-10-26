import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/owner_id.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/data/mapper/account_mapper.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';

import '../../../../helpers/results.dart';

const _t0 = 1757800000000;
const _t1 = 1757800060000;

AccountRow _row({
  String currencyCode = 'VND',
  String id = 'a1',
  String name = 'Ví tiền mặt',
  String type = 'cash',
  int? deletedAt,
  int initialBalance = 1500000,
  int version = 1,
  bool isArchived = false,
}) => AccountRow(
  id: id,
  ownerId: localOwnerId,
  name: name,
  type: type,
  currencyCode: currencyCode,
  initialBalance: initialBalance,
  isArchived: isArchived,
  createdAt: _t0,
  updatedAt: _t1,
  version: version,
  deletedAt: deletedAt,
);

AccountEntity _entity({Money? initialBalance, AccountType type = AccountType.cash, String name = 'Ví tiền mặt', int version = 1, bool isArchived = false}) => okValue(
  AccountEntity.create(
    initialBalance: initialBalance ?? Money(1500000, 'VND'),
    type: type,
    createdAt: DateTime.fromMillisecondsSinceEpoch(_t0, isUtc: true),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(_t1, isUtc: true),
    id: 'a1',
    name: name,
    version: version,
    isArchived: isArchived,
  ),
);

AccountEntity _mapped(AccountRow row) => switch (row.toDomain()) {
  MappedAccount(:final account) => account,
  UnmappableAccountRow(:final reason) => throw TestFailure('Expected a mapped account, got ${reason.name}'),
};

AccountMapperReason? _rejection(AccountRow row) => switch (row.toDomain()) {
  MappedAccount() => null,
  UnmappableAccountRow(:final reason) => reason,
};

void main() {
  group('toDomain', () {
    test('maps every column, joining the two money columns into one Money', () {
      final account = _mapped(_row());

      expect(account.id, 'a1');
      expect(account.name, 'Ví tiền mặt');
      expect(account.type, AccountType.cash);
      expect(account.initialBalance, Money(1500000, 'VND'));
      expect(account.isArchived, isFalse);
      expect(account.version, 1);
    });

    test('turns epoch millis into UTC DateTimes', () {
      final account = _mapped(_row());

      expect(account.createdAt, DateTime.fromMillisecondsSinceEpoch(_t0, isUtc: true));
      expect(account.updatedAt, DateTime.fromMillisecondsSinceEpoch(_t1, isUtc: true));
      expect(account.createdAt.isUtc, isTrue);
      expect(account.updatedAt.isUtc, isTrue);
    });

    test('maps a tombstone rather than refusing it', () {
      expect(_mapped(_row(deletedAt: _t1)).id, 'a1');
    });

    test('reports an unknown type as a database failure, not as an "other" account', () {
      expect(_rejection(_row(type: 'savings')), AccountMapperReason.unknownType);
    });

    test('reports a malformed currency code as a database failure', () {
      expect(_rejection(_row(currencyCode: 'vnd')), AccountMapperReason.malformedCurrencyCode);
      expect(_rejection(_row(currencyCode: '')), AccountMapperReason.malformedCurrencyCode);
    });

    test('re-labels a broken domain rule as a database failure, not a validation failure', () {
      expect(_rejection(_row(name: '   ')), AccountMapperReason.brokenDomainRule);
      expect(_rejection(_row(name: 'a' * (AccountEntity.nameMaxLength + 1))), AccountMapperReason.brokenDomainRule);
    });
  });

  test('every rejection reads the same to the user, whatever the reason', () {
    for (final reason in AccountMapperReason.values) {
      expect(UnmappableAccountRow(reason).failure, const GPDatabaseFailure(), reason: '${reason.name} should not invent its own message');
    }
  });

  test('every reason is reachable from a real row', () {
    final produced = {_rejection(_row(type: 'savings')), _rejection(_row(currencyCode: 'vnd')), _rejection(_row(name: '  '))};

    expect(produced, AccountMapperReason.values.toSet());
  });

  group('toInsert', () {
    test('states every column, so nothing is left to a SQL default', () {
      final companion = _entity().toInsert(localOwnerId);

      expect(companion.id, const Value('a1'));
      expect(companion.ownerId, const Value(localOwnerId));
      expect(companion.name, const Value('Ví tiền mặt'));
      expect(companion.type, const Value('cash'));
      expect(companion.currencyCode, const Value('VND'));
      expect(companion.initialBalance, const Value(1500000));
      expect(companion.isArchived, const Value(false));
      expect(companion.createdAt, const Value(_t0));
      expect(companion.updatedAt, const Value(_t1));
      expect(companion.version, const Value(1));
      expect(companion.deletedAt, const Value<int?>.absent());
    });

    test('splits Money back into its two columns', () {
      final companion = _entity(initialBalance: Money(1234, 'USD')).toInsert(localOwnerId);

      expect(companion.initialBalance, const Value(1234));
      expect(companion.currencyCode, const Value('USD'));
    });

    test('writes the enum through storageValue, not through its Dart name', () {
      expect(_entity(type: AccountType.eWallet).toInsert(localOwnerId).type, const Value('e_wallet'));
      expect(_entity(type: AccountType.creditCard).toInsert(localOwnerId).type, const Value('credit_card'));
    });

    test('takes the owner from its argument, since the entity has none', () {
      expect(_entity().toInsert('user-42').ownerId, const Value('user-42'));
    });
  });

  group('toPatch', () {
    test('carries only the columns a user edit may move', () {
      final patch = _entity(name: 'Ví mới', isArchived: true).toPatch();

      expect(patch.name, const Value('Ví mới'));
      expect(patch.type, const Value('cash'));
      expect(patch.initialBalance, const Value(1500000));
      expect(patch.isArchived, const Value(true));
    });

    test('leaves identity, ownership, currency, version and updated_at absent', () {
      final patch = _entity(version: 9).toPatch();

      expect(patch.currencyCode, const Value<String>.absent());
      expect(patch.id, const Value<String>.absent());
      expect(patch.ownerId, const Value<String>.absent());
      expect(patch.createdAt, const Value<int>.absent());
      expect(patch.updatedAt, const Value<int>.absent());
      expect(patch.version, const Value<int>.absent());
      expect(patch.deletedAt, const Value<int?>.absent());
    });
  });

  test('a row survives a round trip through the entity and back', () {
    final original = _row(currencyCode: 'USD', type: 'credit_card', initialBalance: -4500, version: 7, isArchived: true);
    final companion = _mapped(original).toInsert(localOwnerId);

    expect(companion.type, Value(original.type));
    expect(companion.currencyCode, Value(original.currencyCode));
    expect(companion.initialBalance, Value(original.initialBalance));
    expect(companion.isArchived, Value(original.isArchived));
    expect(companion.createdAt, Value(original.createdAt));
    expect(companion.updatedAt, Value(original.updatedAt));
    expect(companion.version, Value(original.version));
  });
}
