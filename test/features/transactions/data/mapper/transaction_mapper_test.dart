import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/owner_id.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/transactions/data/daos/transaction_dao.dart';
import 'package:ghpockit/features/transactions/data/mapper/transaction_mapper.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';

import '../../../../helpers/results.dart';

const _occurredAt = 1790573400000; // 2026-09-28 05:30 UTC
const _createdAt = 1790575200000; // 2026-09-28 06:00 UTC

void main() {
  group('toDomain', () {
    test('reads every column into the entity', () {
      final transaction = _mapped(_row());

      expect(transaction.id, 'tx-1');
      expect(transaction.type, TransactionType.expense);
      expect(transaction.accountId, 'acc-cash');
      expect(transaction.destinationAccountId, isNull);
      expect(transaction.categoryId, 'cat-food');
      expect(transaction.amount, Money(125000, 'VND'));
      expect(transaction.note, 'Phở bò');
      expect(transaction.version, 3);
    });

    test('reads every timestamp as a UTC instant', () {
      final transaction = _mapped(_row());

      expect(transaction.occurredAt, DateTime.fromMillisecondsSinceEpoch(_occurredAt, isUtc: true));
      expect(transaction.occurredAt.isUtc, isTrue);
      expect(transaction.createdAt.isUtc, isTrue);
      expect(transaction.updatedAt.isUtc, isTrue);
    });

    test('reads a transfer, with its destination and no category', () {
      final transaction = _mapped(_row(categoryId: null, destinationAccountId: 'acc-bank', note: null, type: 'transfer'));

      expect(transaction.type, TransactionType.transfer);
      expect(transaction.destinationAccountId, 'acc-bank');
      expect(transaction.categoryId, isNull);
    });

    test('does not filter a tombstone — the DAO does, except where it deliberately does not', () {
      expect(_row(deletedAt: _createdAt).toDomain(), isA<MappedTransaction>());
    });

    test('refuses a type this build does not know, rather than guessing', () {
      // No vocabulary CHECK on the column (ADR-0009), so a `refund` from a newer build can reach the mapper.
      expect(_refusal(_row(type: 'refund')), TransactionMapperReason.unknownType);
    });

    test('refuses a currency code that is three characters but not three letters', () {
      // The table checks the length; `Money` checks the alphabet.
      expect(_refusal(_row(currencyCode: 'vn1')), TransactionMapperReason.malformedCurrencyCode);
    });

    test('refuses a row that breaks a rule of the entity', () {
      // The table has no length CHECK, so a note from a build with a larger limit is the one entity rule a stored row can break.
      expect(_refusal(_row(note: 'a' * (TransactionEntity.noteMaxLength + 1))), TransactionMapperReason.brokenDomainRule);
    });

    test('flattens every refusal to the same user-facing failure', () {
      for (final unreadable in [_row(type: 'refund'), _row(currencyCode: 'vn1'), _row(note: 'a' * 501)]) {
        expect(unreadable.toDomain(), isA<UnmappableTransactionRow>().having((mapping) => mapping.failure, 'failure', const GPDatabaseFailure()));
      }
    });
  });

  group('toInsert', () {
    test('states every column, with the owner the repository passes and a pending sync state', () {
      final companion = _entity(note: 'Phở bò').toInsert(localOwnerId);

      expect(companion.id, const Value('tx-1'));
      expect(companion.ownerId, const Value(localOwnerId));
      expect(companion.type, const Value('expense'));
      expect(companion.accountId, const Value('acc-cash'));
      expect(companion.destinationAccountId, const Value<String?>(null));
      expect(companion.categoryId, const Value<String?>('cat-food'));
      expect(companion.amountMinor, const Value(125000));
      expect(companion.currencyCode, const Value('VND'));
      expect(companion.occurredAt, const Value(_occurredAt));
      expect(companion.note, const Value<String?>('Phở bò'));
      expect(companion.createdAt, const Value(_createdAt));
      expect(companion.updatedAt, const Value(_createdAt));
      expect(companion.version, const Value(3));
      expect(companion.syncStatus, const Value(TransactionDao.pendingSyncStatus));
      // Absent, so the row is born live.
      expect(companion.deletedAt.present, isFalse);
    });
  });

  group('toPatch', () {
    test('carries only the columns an edit may move', () {
      final patch = _entity().toPatch();

      for (final present in [patch.type, patch.accountId, patch.destinationAccountId, patch.categoryId, patch.amountMinor, patch.currencyCode, patch.occurredAt, patch.note]) {
        expect(present.present, isTrue);
      }
      // `updatedAt` and `syncStatus` too: the DAO stamps both on every write.
      for (final absent in [patch.id, patch.ownerId, patch.createdAt, patch.version, patch.deletedAt, patch.updatedAt, patch.syncStatus]) {
        expect(absent.present, isFalse);
      }
    });

    test('writes a missing reference as null rather than leaving the old one in place', () {
      final expensePatch = _entity(categoryId: null).toPatch();
      final transferPatch = _entity(type: TransactionType.transfer, destinationAccountId: 'acc-bank').toPatch();

      expect(expensePatch.destinationAccountId, const Value<String?>(null));
      expect(expensePatch.categoryId, const Value<String?>(null));
      expect(transferPatch.categoryId, const Value<String?>(null));
      expect(transferPatch.destinationAccountId, const Value<String?>('acc-bank'));
    });
  });
}

TransactionRow _row({
  String? categoryId = 'cat-food',
  String currencyCode = 'VND',
  String? destinationAccountId,
  String? note = 'Phở bò',
  String type = 'expense',
  int amountMinor = 125000,
  int? deletedAt,
}) => TransactionRow(
  id: 'tx-1',
  ownerId: localOwnerId,
  type: type,
  accountId: 'acc-cash',
  destinationAccountId: destinationAccountId,
  categoryId: categoryId,
  amountMinor: amountMinor,
  currencyCode: currencyCode,
  occurredAt: _occurredAt,
  note: note,
  createdAt: _createdAt,
  updatedAt: _createdAt,
  version: 3,
  deletedAt: deletedAt,
  syncStatus: 'synced',
);

TransactionEntity _mapped(TransactionRow row) => switch (row.toDomain()) {
  MappedTransaction(:final transaction) => transaction,
  UnmappableTransactionRow(:final reason) => throw TestFailure('Expected a mapped row, got ${reason.name}'),
};

TransactionMapperReason _refusal(TransactionRow row) => switch (row.toDomain()) {
  MappedTransaction() => throw TestFailure('Expected a refused row'),
  UnmappableTransactionRow(:final reason) => reason,
};

TransactionEntity _entity({TransactionType type = TransactionType.expense, String? categoryId = 'cat-food', String? destinationAccountId, String? note}) => okValue(
  TransactionEntity.create(
    amount: Money(125000, 'VND'),
    type: type,
    createdAt: DateTime.fromMillisecondsSinceEpoch(_createdAt, isUtc: true),
    occurredAt: DateTime.fromMillisecondsSinceEpoch(_occurredAt, isUtc: true),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(_createdAt, isUtc: true),
    accountId: 'acc-cash',
    categoryId: categoryId,
    destinationAccountId: destinationAccountId,
    id: 'tx-1',
    note: note,
    version: 3,
  ),
);
