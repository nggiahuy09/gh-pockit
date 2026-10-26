import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_query.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';

final _from = DateTime.utc(2026, 9);
final _to = DateTime.utc(2026, 10);

void main() {
  group('builds', () {
    test('keeps every filter it was given', () {
      final query = _filtered();

      expect(query.limit, 50);
      expect(query.accountIds, {'acc-cash', 'acc-bank'});
      expect(query.categoryIds, {'cat-food'});
      expect(query.types, {TransactionType.expense, TransactionType.income});
      expect(query.from, _from);
      expect(query.to, _to);
    });

    test('filters on nothing unless asked', () {
      final query = _everything();

      expect(query.accountIds, isNull);
      expect(query.categoryIds, isNull);
      expect(query.types, isNull);
      expect(query.from, isNull);
      expect(query.to, isNull);
    });

    test('reads an empty set as no filter, not as a filter that matches nothing', () {
      final query = TransactionQuery(accountIds: const {}, categoryIds: const {}, types: const {}, limit: 50);

      expect(query.accountIds, isNull);
      expect(query.categoryIds, isNull);
      expect(query.types, isNull);
      expect(query, _everything());
    });

    test('copies the sets it is given, and hands out ones that cannot be changed', () {
      final accountIds = {'acc-cash'};
      final query = TransactionQuery(accountIds: accountIds, limit: 50);

      accountIds.add('acc-bank');

      expect(query.accountIds, {'acc-cash'});
      expect(() => query.accountIds?.add('acc-momo'), throwsUnsupportedError);
    });

    test('normalises the range to UTC', () {
      final localFrom = DateTime(2026, 9);
      final query = TransactionQuery(from: localFrom, limit: 50);

      expect(query.from?.isUtc, isTrue);
      expect(query.from, localFrom.toUtc());
    });

    test('accepts an empty range — from equal to to', () {
      expect(TransactionQuery(from: _from, to: _from, limit: 50).to, _from);
    });

    test('accepts a range open at either end', () {
      expect(TransactionQuery(from: _from, limit: 50).to, isNull);
      expect(TransactionQuery(to: _to, limit: 50).from, isNull);
    });
  });

  group('refuses, as a bug in the caller (ADR-0006)', () {
    test('a limit of zero or less', () {
      expect(() => TransactionQuery(limit: 0), throwsArgumentError);
      expect(() => TransactionQuery(limit: -1), throwsArgumentError);
    });

    test('a range that ends before it starts', () {
      expect(() => TransactionQuery(from: _to, to: _from, limit: 50), throwsArgumentError);
    });
  });

  group('withLimit', () {
    test('keeps every filter and changes only the limit — what "load more" sends', () {
      final grown = _filtered().withLimit(100);

      expect(grown.limit, 100);
      expect(grown, _filtered(limit: 100));
    });

    test('validates the new limit like the first one', () {
      expect(() => _filtered().withLimit(0), throwsArgumentError);
    });
  });

  group('equality', () {
    test('is by value, with sets compared regardless of order', () {
      final first = TransactionQuery(accountIds: const {'acc-cash', 'acc-bank'}, types: const {TransactionType.expense, TransactionType.income}, limit: 50);
      final second = TransactionQuery(accountIds: const {'acc-bank', 'acc-cash'}, types: const {TransactionType.income, TransactionType.expense}, limit: 50);

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('differs when any single part differs', () {
      final base = _filtered();

      expect(base, isNot(_filtered(limit: 100)));
      expect(base, isNot(_everything()));
      expect(base, isNot(TransactionQuery(accountIds: const {'acc-cash'}, categoryIds: const {'cat-food'}, types: base.types, from: _from, to: _to, limit: 50)));
      expect(base, isNot(TransactionQuery(accountIds: base.accountIds, categoryIds: const {'cat-rent'}, types: base.types, from: _from, to: _to, limit: 50)));
      expect(base, isNot(TransactionQuery(accountIds: base.accountIds, categoryIds: base.categoryIds, types: const {TransactionType.transfer}, from: _from, to: _to, limit: 50)));
      expect(base, isNot(TransactionQuery(accountIds: base.accountIds, categoryIds: base.categoryIds, types: base.types, to: _to, limit: 50)));
      expect(base, isNot(TransactionQuery(accountIds: base.accountIds, categoryIds: base.categoryIds, types: base.types, from: _from, limit: 50)));
    });

    test('a filter on every type is not the same query as no filter', () {
      // Same rows today, but not once a fourth type exists.
      expect(TransactionQuery(types: TransactionType.values.toSet(), limit: 50), isNot(_everything()));
    });
  });
}

TransactionQuery _everything({int limit = 50}) => TransactionQuery(limit: limit);

TransactionQuery _filtered({int limit = 50}) => TransactionQuery(
  accountIds: const {'acc-cash', 'acc-bank'},
  categoryIds: const {'cat-food'},
  types: const {TransactionType.expense, TransactionType.income},
  from: _from,
  to: _to,
  limit: limit,
);
