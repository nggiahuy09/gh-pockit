import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:meta/meta.dart';

/// One emission of the transaction list: the rows that could be read, and how many could not (W4 T4, ADR-0011).
///
/// A *snapshot* rather than a page, because there are no pages — the list is one window that grows (`TransactionQuery.withLimit`), and this is what the
/// window held at one moment. The next write to the table produces the next one.
///
/// **Why not a plain `List<TransactionEntity>`, as accounts have.** Because a row the mapper refuses must neither take the whole list down with it — at
/// fifty thousand rows that hides a year of history — nor vanish without a word, since the balance is a SQL `SUM` that still counts it. [unreadableCount]
/// is how the list stays honest about the difference, and it has to travel *with* the rows: a count on a separate stream could describe a different
/// emission than the one on screen.
@immutable
final class TransactionListSnapshot {
  /// [transactions] is copied into an unmodifiable list, so the repository that built it cannot change a snapshot a screen is already showing.
  ///
  /// Throws [ArgumentError] on a negative [unreadableCount] — only a bug in the repository can produce one.
  TransactionListSnapshot({required List<TransactionEntity> transactions, required this.unreadableCount, required this.hasMore})
    : transactions = List<TransactionEntity>.unmodifiable(transactions) {
    if (unreadableCount < 0) throw ArgumentError.value(unreadableCount, 'unreadableCount', 'must not be negative');
  }

  /// The rows that mapped, in the query's order: `occurred_at DESC, id DESC`.
  final List<TransactionEntity> transactions;

  /// How many rows the query returned that the mapper refused — each logged with its id and reason, none shown. When it is not zero, the screen says so
  /// without blocking the rest.
  final int unreadableCount;

  /// Whether the window came back full, so a larger one may hold more rows.
  ///
  /// Decided by the repository on the **raw** row count, refused rows included, never on [transactions] alone: one unreadable row would otherwise make a
  /// full window look short, and the list would stop loading a history that goes on. "May", because a window that is exactly full looks the same as one
  /// with more behind it — the next, larger window settles it for the price of one query.
  final bool hasMore;

  /// Every row the query returned: the ones that mapped plus the ones that did not.
  int get rowCount => transactions.length + unreadableCount;

  /// Value equality, element by element, so `flutter_bloc` skips a rebuild when a write elsewhere in the table re-runs the query and nothing on screen moved.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TransactionListSnapshot || other.unreadableCount != unreadableCount || other.hasMore != hasMore) return false;
    if (other.transactions.length != transactions.length) return false;

    for (var i = 0; i < transactions.length; i++) {
      if (other.transactions[i] != transactions[i]) return false;
    }

    return true;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(transactions), unreadableCount, hasMore);

  /// Counts only. The entities' own `toString` carries no amount and no note, but a snapshot of fifty of them in one log line is noise, not information.
  @override
  String toString() => 'TransactionListSnapshot(transactions: ${transactions.length}, unreadableCount: $unreadableCount, hasMore: $hasMore)';
}
