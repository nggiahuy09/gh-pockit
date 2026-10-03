import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_query.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';

/// `TransactionQuery` (W4 T4, ADR-0011).
void main() {
  final from = DateTime.utc(2026, 9);
  final to = DateTime.utc(2026, 10);

  TransactionQuery everything({int limit = 50}) => TransactionQuery(limit: limit);

  TransactionQuery filtered({int limit = 50}) => TransactionQuery(
    limit: limit,
    accountIds: const {'acc-cash', 'acc-bank'},
    categoryIds: const {'cat-food'},
    types: const {TransactionType.expense, TransactionType.income},
    from: from,
    to: to,
  );

  group('builds', () {
    test('keeps every filter it was given', () {
      final query = filtered();

      expect(query.limit, 50);
      expect(query.accountIds, {'acc-cash', 'acc-bank'});
      expect(query.categoryIds, {'cat-food'});
      expect(query.types, {TransactionType.expense, TransactionType.income});
      expect(query.from, from);
      expect(query.to, to);
    });

    test('filters on nothing unless asked', () {
      final query = everything();

      expect(query.accountIds, isNull);
      expect(query.categoryIds, isNull);
      expect(query.types, isNull);
      expect(query.from, isNull);
      expect(query.to, isNull);
    });

    test('reads an empty set as no filter, not as a filter that matches nothing', () {
      // "Nothing selected" in a filter bar means everything. A set that matched no row would be the filter bug nobody reports: the list is merely empty.
      final query = TransactionQuery(limit: 50, accountIds: const {}, categoryIds: const {}, types: const {});

      expect(query.accountIds, isNull);
      expect(query.categoryIds, isNull);
      expect(query.types, isNull);
      expect(query, everything());
    });

    test('copies the sets it is given, and hands out ones that cannot be changed', () {
      final accountIds = {'acc-cash'};
      final query = TransactionQuery(limit: 50, accountIds: accountIds);

      // The caller keeps editing its own set; the query does not follow.
      accountIds.add('acc-bank');

      expect(query.accountIds, {'acc-cash'});
      expect(() => query.accountIds!.add('acc-momo'), throwsUnsupportedError);
    });

    test('normalises the range to UTC', () {
      // Presentation computes these from local dates in the device zone (ADR-0009); the query holds instants, whatever zone they arrived in.
      final localFrom = DateTime(2026, 9);
      final query = TransactionQuery(limit: 50, from: localFrom);

      expect(query.from!.isUtc, isTrue);
      expect(query.from, localFrom.toUtc());
    });

    test('accepts an empty range — from equal to to', () {
      // Half-open: `[t, t)` holds no instant, so it returns nothing. That is an answer, not a mistake.
      expect(TransactionQuery(limit: 50, from: from, to: from).to, from);
    });

    test('accepts a range open at either end', () {
      expect(TransactionQuery(limit: 50, from: from).to, isNull);
      expect(TransactionQuery(limit: 50, to: to).from, isNull);
    });
  });

  group('refuses, as a bug in the caller (ADR-0006)', () {
    test('a limit of zero or less', () {
      expect(() => TransactionQuery(limit: 0), throwsArgumentError);
      expect(() => TransactionQuery(limit: -1), throwsArgumentError);
    });

    test('a range that ends before it starts', () {
      // A date picker cannot produce this; the code that turns its dates into instants can. So it throws instead of returning a result.
      expect(() => TransactionQuery(limit: 50, from: to, to: from), throwsArgumentError);
    });
  });

  group('withLimit', () {
    test('keeps every filter and changes only the limit — what "load more" sends', () {
      final grown = filtered().withLimit(100);

      expect(grown.limit, 100);
      expect(grown, filtered(limit: 100));
    });

    test('validates the new limit like the first one', () {
      expect(() => filtered().withLimit(0), throwsArgumentError);
    });
  });

  group('equality', () {
    test('is by value, with sets compared regardless of order', () {
      // W5 skips re-subscribing when a filter bar re-emits the query it already had; that only works if `{a, b}` equals `{b, a}`.
      final first = TransactionQuery(limit: 50, accountIds: const {'acc-cash', 'acc-bank'}, types: const {TransactionType.expense, TransactionType.income});
      final second = TransactionQuery(limit: 50, accountIds: const {'acc-bank', 'acc-cash'}, types: const {TransactionType.income, TransactionType.expense});

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('differs when any single part differs', () {
      final base = filtered();

      expect(base, isNot(filtered(limit: 100)));
      expect(base, isNot(everything()));
      expect(base, isNot(TransactionQuery(limit: 50, accountIds: const {'acc-cash'}, categoryIds: const {'cat-food'}, types: base.types, from: from, to: to)));
      expect(base, isNot(TransactionQuery(limit: 50, accountIds: base.accountIds, categoryIds: const {'cat-rent'}, types: base.types, from: from, to: to)));
      expect(base, isNot(TransactionQuery(limit: 50, accountIds: base.accountIds, categoryIds: base.categoryIds, types: const {TransactionType.transfer}, from: from, to: to)));
      expect(base, isNot(TransactionQuery(limit: 50, accountIds: base.accountIds, categoryIds: base.categoryIds, types: base.types, to: to)));
      expect(base, isNot(TransactionQuery(limit: 50, accountIds: base.accountIds, categoryIds: base.categoryIds, types: base.types, from: from)));
    });

    test('a filter on every type is not the same query as no filter', () {
      // They return the same rows today. They stop doing so the day a fourth type is added, and a query must not compare equal to one that will diverge.
      expect(TransactionQuery(limit: 50, types: TransactionType.values.toSet()), isNot(everything()));
    });
  });
}
