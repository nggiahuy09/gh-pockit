// `isNull` is both a drift SQL predicate and a matcher; this file wants the matcher.
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

/// `TransactionMapper` (W4 T6) — rows built by hand, no database: the mapper is a pure translation, and what it refuses is the point of the file.
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
      // Two columns, one value — the amount never travels without its currency.
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
      // `findById` returns tombstones on purpose; a mapper that refused them would make that read useless.
      expect(mapper.toEntity(row(deletedAt: createdAt)), isA<MappedTransaction>());
    });

    test('refuses a type this build does not know, rather than guessing', () {
      // No vocabulary CHECK on the column (ADR-0009), so a `refund` from a newer build reaches the mapper, and it must not become an expense.
      expect(refusal(row(type: 'refund')), TransactionMapperReason.unknownType);
    });

    test('refuses a currency code that is three characters but not three letters', () {
      // The table checks the length; `Money` checks the alphabet — `vn1` passes the first and not the second.
      expect(refusal(row(currencyCode: 'vn1')), TransactionMapperReason.malformedCurrencyCode);
    });

    test('refuses a row that breaks a rule of the entity', () {
      // A note written by a build with a larger limit. The table has no length CHECK on purpose (§3), so this is the one rule a stored row can still break.
      expect(refusal(row(note: 'a' * (TransactionEntity.noteMaxLength + 1))), TransactionMapperReason.brokenDomainRule);
    });

    test('flattens every refusal to the same user-facing failure', () {
      // The user is reading a list, not typing: "Note is too long" would be a sentence about an input that is not on screen.
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
      // Identity, birth, the server's version, the tombstone — and the two the DAO stamps itself on every write.
      for (final absent in [patch.id, patch.ownerId, patch.createdAt, patch.version, patch.deletedAt, patch.updatedAt, patch.syncStatus]) {
        expect(absent.present, isFalse);
      }
    });

    test('writes a missing reference as null rather than leaving the old one in place', () {
      // Switching a transfer back to an expense must clear its destination, and the reverse must clear the category — or the table's CHECK refuses the row.
      final expensePatch = mapper.toPatch(entity(categoryId: null));
      final transferPatch = mapper.toPatch(entity(type: TransactionType.transfer, destinationAccountId: 'acc-bank'));

      expect(expensePatch.destinationAccountId, const Value<String?>(null));
      expect(expensePatch.categoryId, const Value<String?>(null));
      expect(transferPatch.categoryId, const Value<String?>(null));
      expect(transferPatch.destinationAccountId, const Value<String?>('acc-bank'));
    });
  });
}
