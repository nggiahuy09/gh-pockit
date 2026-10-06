import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_list_snapshot.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';

void main() {
  TransactionEntity transaction(String id, {String note = 'Phở bò'}) {
    final created = TransactionEntity.create(
      id: id,
      type: TransactionType.expense,
      accountId: 'acc-cash',
      amount: Money(125000, 'VND'),
      occurredAt: DateTime.utc(2026, 9, 28, 5, 30),
      createdAt: DateTime.utc(2026, 9, 28, 6),
      updatedAt: DateTime.utc(2026, 9, 28, 6),
      note: note,
    );

    return (created as GPOk<TransactionEntity>).value;
  }

  TransactionListSnapshot snapshot({List<String> ids = const ['tx-2', 'tx-1'], int unreadableCount = 0, bool hasMore = false}) =>
      TransactionListSnapshot(transactions: [for (final id in ids) transaction(id)], unreadableCount: unreadableCount, hasMore: hasMore);

  test('counts every row the query returned: the ones that mapped and the ones that did not', () {
    final withOneUnreadable = snapshot(unreadableCount: 1);

    expect(withOneUnreadable.transactions, hasLength(2));
    expect(withOneUnreadable.rowCount, 3);
  });

  test('holds a copy of the list, and one that cannot be changed', () {
    final rows = [transaction('tx-1')];
    final built = TransactionListSnapshot(transactions: rows, unreadableCount: 0, hasMore: false);

    rows.add(transaction('tx-2'));

    expect(built.transactions, hasLength(1));
    expect(() => built.transactions.add(transaction('tx-3')), throwsUnsupportedError);
  });

  test('refuses a negative unreadable count, which only a bug can produce', () {
    expect(() => snapshot(unreadableCount: -1), throwsArgumentError);
  });

  group('equality', () {
    test('is by value, element by element', () {
      expect(snapshot(), snapshot());
      expect(snapshot().hashCode, snapshot().hashCode);
    });

    test('differs when the rows, their order, or either count differs', () {
      final base = snapshot();

      expect(base, isNot(snapshot(ids: ['tx-1', 'tx-2'])));
      expect(base, isNot(snapshot(ids: ['tx-2'])));
      expect(base, isNot(snapshot(unreadableCount: 1)));
      expect(base, isNot(snapshot(hasMore: true)));
      expect(
        base,
        isNot(
          TransactionListSnapshot(
            transactions: [
              transaction('tx-2', note: 'Bún chả'),
              transaction('tx-1'),
            ],
            unreadableCount: 0,
            hasMore: false,
          ),
        ),
      );
    });
  });

  test('toString carries counts only — no amount and no note', () {
    final text = snapshot(unreadableCount: 1, hasMore: true).toString();

    expect(text, 'TransactionListSnapshot(transactions: 2, unreadableCount: 1, hasMore: true)');
    expect(text, isNot(contains('125000')));
    expect(text, isNot(contains('Phở')));
  });
}
