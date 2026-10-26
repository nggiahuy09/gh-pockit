import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_list_snapshot.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';

import '../../../../helpers/results.dart';

void main() {
  test('counts every row the query returned: the ones that mapped and the ones that did not', () {
    final withOneUnreadable = _snapshot(unreadableCount: 1);

    expect(withOneUnreadable.transactions, hasLength(2));
    expect(withOneUnreadable.rowCount, 3);
  });

  test('hands out a list that cannot be changed', () {
    final built = TransactionListSnapshot(transactions: [_transaction('tx-1')], unreadableCount: 0, hasMore: false);

    expect(() => built.transactions.add(_transaction('tx-3')), throwsUnsupportedError);
    expect(built.transactions, hasLength(1));
  });

  test('refuses a negative unreadable count, which only a bug can produce', () {
    expect(() => _snapshot(unreadableCount: -1), throwsArgumentError);
  });

  group('equality', () {
    test('is by value, element by element', () {
      expect(_snapshot(), _snapshot());
      expect(_snapshot().hashCode, _snapshot().hashCode);
    });

    test('differs when the rows, their order, or either count differs', () {
      final base = _snapshot();

      expect(base, isNot(_snapshot(ids: const ['tx-1', 'tx-2'])));
      expect(base, isNot(_snapshot(ids: const ['tx-2'])));
      expect(base, isNot(_snapshot(unreadableCount: 1)));
      expect(base, isNot(_snapshot(hasMore: true)));
      expect(base, isNot(TransactionListSnapshot(transactions: [_transaction('tx-2', 'Bún chả'), _transaction('tx-1')], unreadableCount: 0, hasMore: false)));
    });
  });

  test('toString carries counts only — no amount and no note', () {
    final text = _snapshot(unreadableCount: 1, hasMore: true).toString();

    expect(text, 'TransactionListSnapshot(transactions: 2, unreadableCount: 1, hasMore: true)');
    expect(text, isNot(contains('125000')));
    expect(text, isNot(contains('Phở')));
  });
}

TransactionEntity _transaction(String id, [String note = 'Phở bò']) => okValue(
  TransactionEntity.create(
    amount: Money(125000, 'VND'),
    type: TransactionType.expense,
    createdAt: DateTime.utc(2026, 9, 28, 6),
    occurredAt: DateTime.utc(2026, 9, 28, 5, 30),
    updatedAt: DateTime.utc(2026, 9, 28, 6),
    accountId: 'acc-cash',
    id: id,
    note: note,
  ),
);

TransactionListSnapshot _snapshot({List<String> ids = const ['tx-2', 'tx-1'], int unreadableCount = 0, bool hasMore = false}) =>
    TransactionListSnapshot(transactions: [for (final id in ids) _transaction(id)], unreadableCount: unreadableCount, hasMore: hasMore);
