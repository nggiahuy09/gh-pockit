import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:meta/meta.dart';

/// What the transaction list asks for: which rows, and how many of them (W4 T4, ADR-0011).
///
/// A value object, so it lives beside the entities with no suffix (§3) — `AccountType` is its precedent. It is the whole vocabulary a screen has for
/// narrowing the list, and three things are deliberately missing from it:
///
/// - **The owner.** The repository scopes every query to it, exactly as `AccountRepository` does; a query that could name an owner is one a `BLoC` could
///   name wrongly.
/// - **Tombstones.** The DAO filters `deleted_at IS NULL` on every read, so there is no "include deleted" switch to forget to turn off.
/// - **The order.** It is always `occurred_at DESC, id DESC` — a total order, so rows cannot swap places between emissions (ADR-0011). An order that could
///   be changed would need an index per order, and the list has one reader.
///
/// **Every filter is optional and they all AND together.** `null` means "do not filter on this", and an empty set means the same: [TransactionQuery.new]
/// normalises one into the other, because "nothing selected" in a filter bar means "everything", and a set that silently matches no row would be the one
/// filter bug nobody reports — the list is merely empty.
///
/// **Paging is [limit] and nothing else.** There is no offset: "load more" is [withLimit] with a larger number, re-subscribed on one stream, so the rows
/// always form a consistent prefix of the list however much it changes underneath (ADR-0011).
@immutable
final class TransactionQuery {
  /// Builds a query, normalising as it goes — sets are copied and an empty one becomes `null`, instants become UTC.
  ///
  /// Throws [ArgumentError] on a [limit] that is not positive and on a [from] after [to]. Both are mistakes in the caller, never something a user typed —
  /// a date picker cannot produce an inverted range, the code that turns its dates into instants can — so they throw rather than return a result
  /// (ADR-0006). `from == to` is not an error: it is an empty range, and it returns nothing.
  factory TransactionQuery({
    required int limit,
    Set<String>? accountIds,
    Set<String>? categoryIds,
    Set<TransactionType>? types,
    DateTime? from,
    DateTime? to,
  }) {
    if (limit <= 0) throw ArgumentError.value(limit, 'limit', 'must be positive');

    final fromUtc = from?.toUtc();
    final toUtc = to?.toUtc();

    if (fromUtc != null && toUtc != null && fromUtc.isAfter(toUtc)) throw ArgumentError.value(to, 'to', 'must not be before from ($from)');

    return TransactionQuery._(
      limit: limit,
      accountIds: _normalized(accountIds),
      categoryIds: _normalized(categoryIds),
      types: _normalized(types),
      from: fromUtc,
      to: toUtc,
    );
  }

  const TransactionQuery._({required this.limit, required this.accountIds, required this.categoryIds, required this.types, required this.from, required this.to});

  /// How many rows the query may return — the size of the window, not of a page.
  ///
  /// Required, with no default: how many rows a screen shows at a time is the screen's decision (W5), and a number chosen here would be a presentation
  /// constant living in the domain.
  final int limit;

  /// Transactions touching any of these accounts, on **either side of a transfer** — `account_id` or `destination_account_id` (ADR-0011). Matching only the
  /// source would give an account a history with every transfer into it missing. `null` for every account.
  ///
  /// Unmodifiable, and a copy: a caller that goes on editing the set it passed in cannot change a query that already exists.
  final Set<String>? accountIds;

  /// Transactions filed under any of these categories. `null` for every category, uncategorised ones included.
  ///
  /// There is no way to ask for "uncategorised only" yet. It is not a `category_id IS NULL` filter: a transaction under a category that was deleted reads as
  /// uncategorised too (ADR-0010), so the filter needs a join, and that is W26's.
  final Set<String>? categoryIds;

  /// Transactions of any of these types, so "everything but transfers" is `{expense, income}`. `null` for every type.
  final Set<TransactionType>? types;

  /// The start of the range, **inclusive** — an instant in UTC. `null` for no lower bound.
  ///
  /// Presentation turns a local date into this instant; the domain never sees a calendar date (ADR-0009).
  final DateTime? from;

  /// The end of the range, **exclusive** — so one month's `to` is the next month's [from], and a transaction at exactly midnight belongs to one of them.
  /// `null` for no upper bound.
  final DateTime? to;

  /// The same query with a different [limit] — what "load more" sends. Every filter is kept as it is, and the new limit is validated like the first one.
  TransactionQuery withLimit(int limit) => TransactionQuery(limit: limit, accountIds: accountIds, categoryIds: categoryIds, types: types, from: from, to: to);

  static Set<T>? _normalized<T>(Set<T>? values) => (values == null || values.isEmpty) ? null : Set<T>.unmodifiable(values);

  static bool _sameSet<T>(Set<T>? a, Set<T>? b) => a == null || b == null ? a == b : a.length == b.length && a.containsAll(b);

  /// Value equality, with sets compared regardless of their order — `{a, b}` and `{b, a}` are one filter. This is what lets W5 skip re-subscribing when a
  /// filter bar re-emits the query it already had.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionQuery &&
          other.limit == limit &&
          _sameSet(other.accountIds, accountIds) &&
          _sameSet(other.categoryIds, categoryIds) &&
          _sameSet(other.types, types) &&
          other.from == from &&
          other.to == to;

  @override
  int get hashCode => Object.hash(
    limit,
    accountIds == null ? null : Object.hashAllUnordered(accountIds!),
    categoryIds == null ? null : Object.hashAllUnordered(categoryIds!),
    types == null ? null : Object.hashAllUnordered(types!),
    from,
    to,
  );

  /// Ids, types and instants only — none of which golden rule 9 restricts. A query carries no amount and no note to leak.
  @override
  String toString() => 'TransactionQuery(limit: $limit, accountIds: $accountIds, categoryIds: $categoryIds, types: ${types?.map((t) => t.name).toSet()}, from: $from, to: $to)';
}
