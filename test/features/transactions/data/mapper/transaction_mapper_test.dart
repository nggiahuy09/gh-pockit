import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/database/database.dart';
import 'package:ghpockit/core/database/owner_id.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/transactions/data/daos/transaction_dao.dart';
import 'package:ghpockit/features/transactions/data/mapper/transaction_mapper.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';

void main() {
  const mapper = TransactionMapper();

  const occurredAt = 1790573400000; // 2026-09-28 05:30 UTC
  const createdAt = 1790575200000; // 2026-09-28 06:00 UTC

  TransactionRow row({
    String type = 'expense',
    String? destinationAccountId,
    String? categoryId = 'cat-food',
    int amountMinor = 125000,
    String currencyCode = 'VND',
    String? note = 'Phở bò',
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
    occurredAt: occurredAt,
    note: note,
    createdAt: createdAt,
    updatedAt: createdAt,
    version: 3,
    deletedAt: deletedAt,
    syncStatus: 'synced',
  );

  TransactionEntity mapped(TransactionRow row) => (mapper.toEntity(row) as MappedTransaction).transaction;

  TransactionMapperReason refusal(TransactionRow row) => (mapper.toEntity(row) as UnmappableTransactionRow).reason;

  TransactionEntity entity({TransactionType type = TransactionType.expense, String? destinationAccountId, String? categoryId = 'cat-food', String? note}) {
    final created = TransactionEntity.create(
      id: 'tx-1',
      type: type,
      accountId: 'acc-cash',
      destinationAccountId: destinationAccountId,
      categoryId: categoryId,
      amount: Money(125000, 'VND'),
      occurredAt: DateTime.fromMillisecondsSinceEpoch(occurredAt, isUtc: true),
      note: note,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(createdAt, isUtc: true),
      version: 3,
    );

    return (created as GPOk<TransactionEntity>).value;
  }

  group('toEntity', () {
    test('reads every column into the entity', () {
      final transaction = mapped(row());

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
      final transaction = mapped(row());

      expect(transaction.occurredAt, DateTime.fromMillisecondsSinceEpoch(occurredAt, isUtc: true));
      expect(transaction.occurredAt.isUtc, isTrue);
      expect(transaction.createdAt.isUtc, isTrue);
      expect(transaction.updatedAt.isUtc, isTrue);
    });

    test('reads a transfer, with its destination and no category', () {
      final transaction = mapped(row(type: 'transfer', destinationAccountId: 'acc-bank', categoryId: null, note: null));

      expect(transaction.type, TransactionType.transfer);
      expect(transaction.destinationAccountId, 'acc-bank');
      expect(transaction.categoryId, isNull);
    });

    test('does not filter a tombstone — the DAO does, except where it deliberately does not', () {
      expect(mapper.toEntity(row(deletedAt: createdAt)), isA<MappedTransaction>());
    });

    test('refuses a type this build does not know, rather than guessing', () {
      // No vocabulary CHECK on the column (ADR-0009), so a `refund` from a newer build can reach the mapper.
      expect(refusal(row(type: 'refund')), TransactionMapperReason.unknownType);
    });

    test('refuses a currency code that is three characters but not three letters', () {
      // The table checks the length; `Money` checks the alphabet — `vn1` passes the first and not the second.
      expect(refusal(row(currencyCode: 'vn1')), TransactionMapperReason.malformedCurrencyCode);
    });

    test('refuses a row that breaks a rule of the entity', () {
      // The table has no length CHECK, so a note from a build with a larger limit is the one entity rule a stored row can break.
      expect(refusal(row(note: 'a' * (TransactionEntity.noteMaxLength + 1))), TransactionMapperReason.brokenDomainRule);
    });

    test('flattens every refusal to the same user-facing failure', () {
      for (final unreadable in [row(type: 'refund'), row(currencyCode: 'vn1'), row(note: 'a' * 501)]) {
        expect((mapper.toEntity(unreadable) as UnmappableTransactionRow).failure, const GPDatabaseFailure());
      }
    });
  });

  group('toInsert', () {
    test('states every column, with the owner the repository passes and a pending sync state', () {
      final companion = mapper.toInsert(entity(note: 'Phở bò'), ownerId: localOwnerId);

      expect(companion.id, const Value('tx-1'));
      expect(companion.ownerId, const Value(localOwnerId));
      expect(companion.type, const Value('expense'));
      expect(companion.accountId, const Value('acc-cash'));
      expect(companion.destinationAccountId, const Value<String?>(null));
      expect(companion.categoryId, const Value<String?>('cat-food'));
      expect(companion.amountMinor, const Value(125000));
      expect(companion.currencyCode, const Value('VND'));
      expect(companion.occurredAt, const Value(occurredAt));
      expect(companion.note, const Value<String?>('Phở bò'));
      expect(companion.createdAt, const Value(createdAt));
      expect(companion.updatedAt, const Value(createdAt));
      expect(companion.version, const Value(3));
      expect(companion.syncStatus, const Value(TransactionDao.pendingSyncStatus));
      // Absent, so the row is born live.
      expect(companion.deletedAt.present, isFalse);
    });
  });

  group('toPatch', () {
    test('carries only the columns an edit may move', () {
      final patch = mapper.toPatch(entity());

      for (final present in [patch.type, patch.accountId, patch.destinationAccountId, patch.categoryId, patch.amountMinor, patch.currencyCode, patch.occurredAt, patch.note]) {
        expect(present.present, isTrue);
      }
      // `updatedAt` and `syncStatus` too: the DAO stamps both on every write.
      for (final absent in [patch.id, patch.ownerId, patch.createdAt, patch.version, patch.deletedAt, patch.updatedAt, patch.syncStatus]) {
        expect(absent.present, isFalse);
      }
    });

    test('writes a missing reference as null rather than leaving the old one in place', () {
      final expensePatch = mapper.toPatch(entity(categoryId: null));
      final transferPatch = mapper.toPatch(entity(type: TransactionType.transfer, destinationAccountId: 'acc-bank'));

      expect(expensePatch.destinationAccountId, const Value<String?>(null));
      expect(expensePatch.categoryId, const Value<String?>(null));
      expect(transferPatch.categoryId, const Value<String?>(null));
      expect(transferPatch.destinationAccountId, const Value<String?>('acc-bank'));
    });
  });
}
