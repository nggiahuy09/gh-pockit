import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';

import '../../../../helpers/results.dart';

final _occurredAt = DateTime.utc(2026, 9, 28, 5, 30);
final _createdAt = DateTime.utc(2026, 9, 28, 6);
final _updatedAt = DateTime.utc(2026, 9, 28, 6);

void main() {
  group('create', () {
    test('keeps every field it was given', () {
      final transaction = okValue(_build());

      expect(transaction.id, 'tx-1');
      expect(transaction.type, TransactionType.expense);
      expect(transaction.accountId, 'acc-cash');
      expect(transaction.destinationAccountId, isNull);
      expect(transaction.categoryId, 'cat-food');
      expect(transaction.amount, Money(125000, 'VND'));
      expect(transaction.occurredAt, _occurredAt);
      expect(transaction.note, 'Phở bò');
      expect(transaction.createdAt, _createdAt);
      expect(transaction.updatedAt, _updatedAt);
      expect(transaction.version, 1);
    });

    test('defaults a new transaction to version 1', () {
      final transaction = okValue(
        TransactionEntity.create(
          amount: Money(15000000, 'VND'),
          type: TransactionType.income,
          createdAt: _createdAt,
          occurredAt: _occurredAt,
          updatedAt: _updatedAt,
          accountId: 'acc-bank',
          id: 'tx-2',
        ),
      );

      expect(transaction.version, 1);
    });

    test('accepts an uncategorised expense or income', () {
      expect(okValue(_build(categoryId: null)).categoryId, isNull);
      expect(okValue(_build(type: TransactionType.income, categoryId: null)).categoryId, isNull);
    });

    test('rejects an amount of zero or less, naming the rule', () {
      expect(_build(amount: Money.zero('VND')), _refused(GPValidationCode.transactionAmountNotPositive));
      expect(_build(amount: Money(-125000, 'VND')), _refused(GPValidationCode.transactionAmountNotPositive));
    });

    test('accepts the smallest positive amount', () {
      expect(okValue(_build(amount: Money(1, 'USD'))).amount, Money(1, 'USD'));
    });

    test('normalises every timestamp to UTC', () {
      final local = DateTime(2026, 9, 28, 12, 30);
      final transaction = okValue(
        TransactionEntity.create(
          amount: Money(35000, 'VND'),
          type: TransactionType.expense,
          createdAt: local,
          occurredAt: local,
          updatedAt: local,
          accountId: 'acc-cash',
          id: 'tx-3',
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
      final transaction = okValue(_transfer());

      expect(transaction.type, TransactionType.transfer);
      expect(transaction.accountId, 'acc-cash');
      expect(transaction.destinationAccountId, 'acc-bank');
      expect(transaction.categoryId, isNull);
    });

    test('requires a destination', () {
      expect(_transfer(destinationAccountId: null), _refused(GPValidationCode.transactionDestinationMissing));
    });

    test('rejects a destination that is its own source', () {
      expect(_transfer(destinationAccountId: 'acc-cash'), _refused(GPValidationCode.transactionDestinationSameAsSource));
    });

    test('drops a category rather than refusing it', () {
      expect(okValue(_transfer(categoryId: 'cat-food')).categoryId, isNull);
    });
  });

  group('create — not a transfer', () {
    test('drops a destination rather than refusing it', () {
      expect(okValue(_build(destinationAccountId: 'acc-bank')).destinationAccountId, isNull);
      expect(okValue(_build(type: TransactionType.income, destinationAccountId: 'acc-bank')).destinationAccountId, isNull);
    });
  });

  group('create — note', () {
    test('trims it', () {
      expect(okValue(_build(note: '  Phở bò  ')).note, 'Phở bò');
    });

    test('treats an empty or whitespace-only note as no note', () {
      expect(okValue(_build(note: '')).note, isNull);
      expect(okValue(_build(note: '   ')).note, isNull);
      expect(okValue(_build(note: null)).note, isNull);
    });

    test('accepts a note exactly at the limit and rejects one past it', () {
      expect(okValue(_build(note: 'a' * TransactionEntity.noteMaxLength)).note?.length, TransactionEntity.noteMaxLength);
      expect(_build(note: 'a' * (TransactionEntity.noteMaxLength + 1)), _refused(GPValidationCode.transactionNoteTooLong));
    });

    test('measures the limit after trimming', () {
      expect(_build(note: '${'a' * TransactionEntity.noteMaxLength}   '), isA<GPOk<TransactionEntity>>());
    });
  });

  group('update', () {
    test('changes only what it is given', () {
      final transaction = okValue(okValue(_build()).update(amount: Money(95000, 'VND')));

      expect(transaction.amount, Money(95000, 'VND'));
      expect(transaction.id, 'tx-1');
      expect(transaction.createdAt, _createdAt);
      expect(transaction.type, TransactionType.expense);
      expect(transaction.categoryId, 'cat-food');
      expect(transaction.note, 'Phở bò');
      expect(transaction.version, 1);
    });

    test("does not move updatedAt — that is the repository's job", () {
      expect(okValue(okValue(_build()).update(note: 'Bún chả')).updatedAt, _updatedAt);
    });

    test('re-validates what changed', () {
      expect(okValue(_build()).update(amount: Money.zero('VND')), _refused(GPValidationCode.transactionAmountNotPositive));
    });

    test('switches an expense to a transfer in one call, dropping its category', () {
      final switched = okValue(okValue(_build()).update(type: TransactionType.transfer, destinationAccountId: 'acc-bank'));

      expect(switched.type, TransactionType.transfer);
      expect(switched.destinationAccountId, 'acc-bank');
      expect(switched.categoryId, isNull);
    });

    test('refuses a switch to transfer that names no destination', () {
      expect(okValue(_build()).update(type: TransactionType.transfer), _refused(GPValidationCode.transactionDestinationMissing));
    });

    test('switches a transfer back to an expense, dropping its destination', () {
      final switched = okValue(okValue(_transfer()).update(type: TransactionType.expense));

      expect(switched.type, TransactionType.expense);
      expect(switched.destinationAccountId, isNull);
      expect(switched.categoryId, isNull);
    });

    test('clearCategory removes the category; a null categoryId leaves it alone', () {
      expect(okValue(okValue(_build()).update(clearCategory: true)).categoryId, isNull);
      expect(okValue(okValue(_build()).update(note: 'Bún chả')).categoryId, 'cat-food');
    });

    test("clearDestination removes a transfer's destination, which it then refuses as missing; a null one leaves it alone", () {
      expect(okValue(_transfer()).update(clearDestination: true), const GPErr<TransactionEntity>(GPValidationFailure(GPValidationCode.transactionDestinationMissing)));
      expect(okValue(okValue(_transfer()).update(note: 'Tiền nhà')).destinationAccountId, isNotNull);
    });

    test('an empty note clears it; a null note leaves it alone', () {
      expect(okValue(okValue(_build()).update(note: '')).note, isNull);
      expect(okValue(okValue(_build()).update(amount: Money(95000, 'VND'))).note, 'Phở bò');
    });

    test('leaves the original untouched', () {
      final original = okValue(_build());

      okValue(original.update(amount: Money(1, 'VND')));

      expect(original.amount, Money(125000, 'VND'));
    });
  });

  group('withUpdatedAt', () {
    test('moves updatedAt and nothing else', () {
      final later = DateTime.utc(2026, 9, 29, 8);
      final transaction = okValue(_build()).withUpdatedAt(later);

      expect(transaction.updatedAt, later);
      expect(transaction.createdAt, _createdAt);
      expect(transaction.occurredAt, _occurredAt);
      expect(transaction.amount, Money(125000, 'VND'));
      expect(transaction.version, 1);
    });

    test('normalises to UTC', () {
      final local = DateTime(2026, 9, 29, 15);

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

      expect(base, isNot(okValue(_build(type: TransactionType.income))));
      expect(base, isNot(okValue(_build(accountId: 'acc-bank'))));
      expect(base, isNot(okValue(_build(categoryId: 'cat-coffee'))));
      expect(base, isNot(okValue(_build(amount: Money(125001, 'VND')))));
      expect(base, isNot(okValue(_build(amount: Money(125000, 'USD')))));
      expect(base, isNot(okValue(_build(note: 'Bún chả'))));
      expect(base, isNot(okValue(_build(version: 2))));
      expect(okValue(_transfer()), isNot(okValue(_transfer(destinationAccountId: 'acc-momo'))));
      expect(base, isNot(okValue(base.update(occurredAt: DateTime.utc(2026, 9, 27)))));
      expect(base, isNot(base.withUpdatedAt(DateTime.utc(2026, 9, 29))));
    });
  });

  group('what it deliberately does not check (ADR-0010)', () {
    test('does not compare the currency with the account — it has no account to compare with', () {
      expect(_build(amount: Money(1234, 'USD')), isA<GPOk<TransactionEntity>>());
    });

    test('does not check that the category is of the right kind', () {
      expect(_build(type: TransactionType.income, categoryId: 'cat-rent'), isA<GPOk<TransactionEntity>>());
    });
  });

  test('toString carries no amount and no note', () {
    final transaction = okValue(_build(amount: Money(7500000, 'VND'), note: 'Tiền nhà tháng 10'));

    expect(transaction.toString(), 'TransactionEntity(id: tx-1, type: expense, version: 1)');
    expect(transaction.toString(), isNot(contains('7500000')));
    expect(transaction.toString(), isNot(contains('Tiền nhà')));
  });
}

GPResult<TransactionEntity> _build({
  Money? amount,
  TransactionType type = TransactionType.expense,
  String accountId = 'acc-cash',
  String? categoryId = 'cat-food',
  String? destinationAccountId,
  String? note = 'Phở bò',
  int version = 1,
}) => TransactionEntity.create(
  amount: amount ?? Money(125000, 'VND'),
  type: type,
  createdAt: _createdAt,
  occurredAt: _occurredAt,
  updatedAt: _updatedAt,
  accountId: accountId,
  categoryId: categoryId,
  destinationAccountId: destinationAccountId,
  id: 'tx-1',
  note: note,
  version: version,
);

GPResult<TransactionEntity> _transfer({String? categoryId, String? destinationAccountId = 'acc-bank'}) =>
    _build(type: TransactionType.transfer, categoryId: categoryId, destinationAccountId: destinationAccountId, note: null);

GPErr<TransactionEntity> _refused(GPValidationCode code) => GPErr(GPValidationFailure(code));
