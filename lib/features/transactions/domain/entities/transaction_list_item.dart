import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import '../../../categories/domain/entities/category_entity.dart';
import 'transaction_entity.dart';

/// A list row with the names it shows, read in the same statement as the transaction (ADR-0024).
@immutable
final class TransactionListItem with Equatable {
  const TransactionListItem({required this.transaction, required this.category, required this.accountName, this.destinationAccountName});

  final TransactionEntity transaction;

  /// Null reads "Uncategorised": no category, a soft-deleted one, or one whose row will not map (ADR-0010).
  final CategoryEntity? category;

  /// A soft-deleted account still has its name (ADR-0010).
  final String accountName;

  /// Set for a transfer only.
  final String? destinationAccountName;

  @override
  List<Object?> get props => [transaction, category, accountName, destinationAccountName];

  /// Names are user text: never printed (golden rule 9).
  @override
  String toString() => 'TransactionListItem(${transaction.id})';
}
