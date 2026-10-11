import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';

void main() {
  final occurredAt = DateTime.utc(2026, 9, 28, 5, 30);
  final createdAt = DateTime.utc(2026, 9, 28, 6);
  final updatedAt = DateTime.utc(2026, 9, 28, 6);

  GPResult<TransactionEntity> build({
    TransactionType type = TransactionType.expense,
    String accountId = 'acc-cash',
    String? destinationAccountId,
    String? categoryId = 'cat-food',
    Money? amount,
    String? note = 'Phở bò',
    int version = 1,
  }) => TransactionEntity.create(
    id: 'tx-1',
    type: type,
    accountId: accountId,
    destinationAccountId: destinationAccountId,
    categoryId: categoryId,
    amount: amount ?? Money(125000, 'VND'),
    occurredAt: occurredAt,
    note: note,
    createdAt: createdAt,
    updatedAt: updatedAt,
    version: version,
  );

  GPResult<TransactionEntity> transfer({String? destinationAccountId = 'acc-bank', String? categoryId}) =>
      build(type: TransactionType.transfer, destinationAccountId: destinationAccountId, categoryId: categoryId, note: null);

  TransactionEntity ok(GPResult<TransactionEntity> result) => (result as GPOk<TransactionEntity>).value;

  GPErr<TransactionEntity> refused(GPValidationCode code) => GPErr<TransactionEntity>(GPValidationFailure(code));

  group('create', () {
    test('keeps every field it was given', () {
      final transaction = ok(build());

      expect(transaction.id, 'tx-1');
      expect(transaction.type, TransactionType.expense);
      expect(transaction.accountId, 'acc-cash');
      expect(transaction.destinationAccountId, isNull);
      expect(transaction.categoryId, 'cat-food');
      expect(transaction.amount, Money(125000, 'VND'));
      expect(transaction.occurredAt, occurredAt);
      expect(transaction.note, 'Phở bò');
      expect(transaction.createdAt, createdAt);
      expect(transaction.updatedAt, updatedAt);
      expect(transaction.version, 1);
    });

    test('defaults a new transaction to version 1', () {
      final transaction = ok(
        TransactionEntity.create(
          id: 'tx-2',
          type: TransactionType.income,
          accountId: 'acc-bank',
          amount: Money(15000000, 'VND'),
          occurredAt: occurredAt,
          createdAt: createdAt,
          updatedAt: updatedAt,
        ),
      );

      expect(transaction.version, 1);
    });

    test('accepts an uncategorised expense or income', () {
      expect(ok(build(categoryId: null)).categoryId, isNull);
      expect(ok(build(type: TransactionType.income, categoryId: null)).categoryId, isNull);
    });

    test('rejects an amount of zero or less, naming the rule', () {
      expect(build(amount: Money.zero('VND')), refused(GPValidationCode.transactionAmountNotPositive));
      expect(build(amount: Money(-125000, 'VND')), refused(GPValidationCode.transactionAmountNotPositive));
    });

    test('accepts the smallest positive amount', () {
      expect(ok(build(amount: Money(1, 'USD'))).amount, Money(1, 'USD'));
    });

    test('normalises every timestamp to UTC', () {
      final local = DateTime(2026, 9, 28, 12, 30);
      final transaction = ok(
        TransactionEntity.create(
          id: 'tx-3',
          type: TransactionType.expense,
          accountId: 'acc-cash',
          amount: Money(35000, 'VND'),
          occurredAt: local,
          createdAt: local,
          updatedAt: local,
        ),
      );

      expect(transaction.occurredAt.isUtc, isTrue);
      expect(transaction.occurredAt, local.toUtc());
      expect(transaction.createdAt.isUtc, isTrue);
      expect(transaction.updatedAt.isUtc, isTrue);
    });
  });

  group('create — transfer', () {
    test('keeps its destination and carries no category', () {
      final transaction = ok(transfer());

      expect(transaction.type, TransactionType.transfer);
      expect(transaction.accountId, 'acc-cash');
      expect(transaction.destinationAccountId, 'acc-bank');
      expect(transaction.categoryId, isNull);
    });

    test('requires a destination', () {
      expect(transfer(destinationAccountId: null), refused(GPValidationCode.transactionDestinationMissing));
    });

    test('rejects a destination that is its own source', () {
      expect(transfer(destinationAccountId: 'acc-cash'), refused(GPValidationCode.transactionDestinationSameAsSource));
    });

    test('drops a category rather than refusing it', () {
      expect(ok(transfer(categoryId: 'cat-food')).categoryId, isNull);
    });
  });

  group('create — not a transfer', () {
    test('drops a destination rather than refusing it', () {
      expect(ok(build(destinationAccountId: 'acc-bank')).destinationAccountId, isNull);
      expect(ok(build(type: TransactionType.income, destinationAccountId: 'acc-bank')).destinationAccountId, isNull);
    });
  });

  group('create — note', () {
    test('trims it', () {
      expect(ok(build(note: '  Phở bò  ')).note, 'Phở bò');
    });

    test('treats an empty or whitespace-only note as no note', () {
      expect(ok(build(note: '')).note, isNull);
      expect(ok(build(note: '   ')).note, isNull);
      expect(ok(build(note: null)).note, isNull);
    });

    test('accepts a note exactly at the limit and rejects one past it', () {
      expect(ok(build(note: 'a' * TransactionEntity.noteMaxLength)).note!.length, TransactionEntity.noteMaxLength);
      expect(build(note: 'a' * (TransactionEntity.noteMaxLength + 1)), refused(GPValidationCode.transactionNoteTooLong));
    });

    test('measures the limit after trimming', () {
      expect(build(note: '${'a' * TransactionEntity.noteMaxLength}   '), isA<GPOk<TransactionEntity>>());
    });
  });

  group('update', () {
    test('changes only what it is given', () {
      final transaction = ok(ok(build()).update(amount: Money(95000, 'VND')));

      expect(transaction.amount, Money(95000, 'VND'));
      expect(transaction.id, 'tx-1');
      expect(transaction.createdAt, createdAt);
      expect(transaction.type, TransactionType.expense);
      expect(transaction.categoryId, 'cat-food');
      expect(transaction.note, 'Phở bò');
      expect(transaction.version, 1);
    });

    test("does not move updatedAt — that is the repository's job", () {
      expect(ok(ok(build()).update(note: 'Bún chả')).updatedAt, updatedAt);
    });

    test('re-validates what changed', () {
      expect(ok(build()).update(amount: Money.zero('VND')), refused(GPValidationCode.transactionAmountNotPositive));
    });

    test('switches an expense to a transfer in one call, dropping its category', () {
      final switched = ok(ok(build()).update(type: TransactionType.transfer, destinationAccountId: 'acc-bank'));

      expect(switched.type, TransactionType.transfer);
      expect(switched.destinationAccountId, 'acc-bank');
      expect(switched.categoryId, isNull);
    });

    test('refuses a switch to transfer that names no destination', () {
      expect(ok(build()).update(type: TransactionType.transfer), refused(GPValidationCode.transactionDestinationMissing));
    });

    test('switches a transfer back to an expense, dropping its destination', () {
      final switched = ok(ok(transfer()).update(type: TransactionType.expense));

      expect(switched.type, TransactionType.expense);
      expect(switched.destinationAccountId, isNull);
      expect(switched.categoryId, isNull);
    });

    test('clearCategory removes the category; a null categoryId leaves it alone', () {
      expect(ok(ok(build()).update(clearCategory: true)).categoryId, isNull);
      expect(ok(ok(build()).update(note: 'Bún chả')).categoryId, 'cat-food');
    });

    test('an empty note clears it; a null note leaves it alone', () {
      expect(ok(ok(build()).update(note: '')).note, isNull);
      expect(ok(ok(build()).update(amount: Money(95000, 'VND'))).note, 'Phở bò');
    });

    test('leaves the original untouched', () {
      final original = ok(build());

      ok(original.update(amount: Money(1, 'VND')));

      expect(original.amount, Money(125000, 'VND'));
    });
  });

  group('stampedAt', () {
    test('moves updatedAt and nothing else', () {
      final later = DateTime.utc(2026, 9, 29, 8);
      final transaction = ok(build()).stampedAt(later);

      expect(transaction.updatedAt, later);
      expect(transaction.createdAt, createdAt);
      expect(transaction.occurredAt, occurredAt);
      expect(transaction.amount, Money(125000, 'VND'));
      expect(transaction.version, 1);
    });

    test('normalises to UTC', () {
      final local = DateTime(2026, 9, 29, 15);

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

      expect(base, isNot(ok(build(type: TransactionType.income))));
      expect(base, isNot(ok(build(accountId: 'acc-bank'))));
      expect(base, isNot(ok(build(categoryId: 'cat-coffee'))));
      expect(base, isNot(ok(build(amount: Money(125001, 'VND')))));
      expect(base, isNot(ok(build(amount: Money(125000, 'USD')))));
      expect(base, isNot(ok(build(note: 'Bún chả'))));
      expect(base, isNot(ok(build(version: 2))));
      expect(ok(transfer()), isNot(ok(transfer(destinationAccountId: 'acc-momo'))));
      expect(base, isNot(ok(base.update(occurredAt: DateTime.utc(2026, 9, 27)))));
      expect(base, isNot(base.stampedAt(DateTime.utc(2026, 9, 29))));
    });
  });

  group('what it deliberately does not check (ADR-0010)', () {
    test('does not compare the currency with the account — it has no account to compare with', () {
      expect(build(amount: Money(1234, 'USD')), isA<GPOk<TransactionEntity>>());
    });

    test('does not check that the category is of the right kind', () {
      expect(build(type: TransactionType.income, categoryId: 'cat-rent'), isA<GPOk<TransactionEntity>>());
    });
  });

  test('toString carries no amount and no note', () {
    final transaction = ok(build(note: 'Tiền nhà tháng 10', amount: Money(7500000, 'VND')));

    expect(transaction.toString(), 'TransactionEntity(id: tx-1, type: expense, version: 1)');
    expect(transaction.toString(), isNot(contains('7500000')));
    expect(transaction.toString(), isNot(contains('Tiền nhà')));
  });
}
