import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import 'transaction_type.dart';

/// Filters AND together; null or an empty set means no filter on that field. The order is fixed: `occurred_at DESC, id DESC` (ADR-0011).
@immutable
final class TransactionQuery with Equatable {
  /// Throws [ArgumentError] on a non-positive [limit] or a [from] after [to]: caller bugs, not user input (ADR-0006).
  factory TransactionQuery({Set<String>? accountIds, Set<String>? categoryIds, Set<TransactionType>? types, DateTime? from, DateTime? to, required int limit}) {
    if (limit <= 0) throw ArgumentError.value(limit, 'limit', 'must be positive');

    final fromUtc = from?.toUtc();
    final toUtc = to?.toUtc();
    if (fromUtc != null && toUtc != null && fromUtc.isAfter(toUtc)) throw ArgumentError.value(to, 'to', 'must not be before from ($from)');

    return TransactionQuery._(
      accountIds: _normalized(accountIds),
      categoryIds: _normalized(categoryIds),
      types: _normalized(types),
      from: fromUtc,
      to: toUtc,
      limit: limit,
    );
  }

  const TransactionQuery._({
    required Set<String>? accountIds,
    required Set<String>? categoryIds,
    required Set<TransactionType>? types,
    required this.from,
    required this.to,
    required this.limit,
  }) : _accountIds = accountIds,
       _categoryIds = categoryIds,
       _types = types;

  /// Matches either side of a transfer.
  final Set<String>? _accountIds;

  final Set<String>? _categoryIds;
  final Set<TransactionType>? _types;

  /// Inclusive. An instant: presentation converts local dates (ADR-0009).
  final DateTime? from;

  /// Exclusive, so one month's [to] is the next month's [from].
  final DateTime? to;

  /// The size of the whole window, not of a page (ADR-0011).
  final int limit;

  static Set<T>? _normalized<T>(Set<T>? values) => (values == null || values.isEmpty) ? null : Set.of(values);

  Set<String>? get accountIds => _accountIds == null ? null : Set.unmodifiable(_accountIds);

  Set<String>? get categoryIds => _categoryIds == null ? null : Set.unmodifiable(_categoryIds);

  Set<TransactionType>? get types => _types == null ? null : Set.unmodifiable(_types);

  @override
  List<Object?> get props => [_accountIds, _categoryIds, _types, from, to, limit];

  TransactionQuery withLimit(int limit) => TransactionQuery(accountIds: _accountIds, categoryIds: _categoryIds, types: _types, from: from, to: to, limit: limit);

  @override
  String toString() =>
      'TransactionQuery(accountIds: $_accountIds, categoryIds: $_categoryIds, types: ${_types?.map((type) => type.name).toSet()}, from: $from, to: $to, limit: $limit)';
}
