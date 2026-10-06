import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:meta/meta.dart';

/// Filters AND together, and `null` or an empty set means no filter on that field. The order is fixed: `occurred_at DESC, id DESC` (ADR-0011).
@immutable
final class TransactionQuery {
  /// Throws [ArgumentError] on a non-positive [limit] or a [from] after [to]: caller bugs, not user input (ADR-0006).
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

  /// The size of the whole window, not of a page: "load more" is [withLimit] with a larger one (ADR-0011).
  final int limit;

  /// Matches either side of a transfer: `account_id` or `destination_account_id`.
  final Set<String>? accountIds;

  /// No "uncategorised only" filter yet: it is not `category_id IS NULL`, since a deleted category reads as uncategorised too (ADR-0010).
  final Set<String>? categoryIds;

  final Set<TransactionType>? types;

  /// Inclusive. An instant: presentation converts local dates (ADR-0009).
  final DateTime? from;

  /// Exclusive, so one month's [to] is the next month's [from].
  final DateTime? to;

  TransactionQuery withLimit(int limit) => TransactionQuery(limit: limit, accountIds: accountIds, categoryIds: categoryIds, types: types, from: from, to: to);

  static Set<T>? _normalized<T>(Set<T>? values) => (values == null || values.isEmpty) ? null : Set<T>.unmodifiable(values);

  static bool _sameSet<T>(Set<T>? a, Set<T>? b) => a == null || b == null ? a == b : a.length == b.length && a.containsAll(b);

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

  @override
  String toString() => 'TransactionQuery(limit: $limit, accountIds: $accountIds, categoryIds: $categoryIds, types: ${types?.map((t) => t.name).toSet()}, from: $from, to: $to)';
}
