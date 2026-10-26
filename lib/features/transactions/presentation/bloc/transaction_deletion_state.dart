part of 'transaction_deletion_bloc.dart';

@immutable
sealed class TransactionDeletionState with Equatable {
  const TransactionDeletionState();

  @override
  List<Object?> get props => const [];
}

final class TransactionDeletionInitState extends TransactionDeletionState {
  const TransactionDeletionInitState();
}

final class TransactionDeletionDeleteLoadingState extends TransactionDeletionState {
  const TransactionDeletionDeleteLoadingState();
}

final class TransactionDeletionDeletedState extends TransactionDeletionState {
  const TransactionDeletionDeletedState(this.transactionId);

  final String transactionId;

  @override
  List<Object?> get props => [transactionId];
}

final class TransactionDeletionRestoreLoadingState extends TransactionDeletionState {
  const TransactionDeletionRestoreLoadingState();
}

final class TransactionDeletionRestoredState extends TransactionDeletionState {
  const TransactionDeletionRestoredState();
}

sealed class TransactionDeletionErrorState extends TransactionDeletionState {
  const TransactionDeletionErrorState(this.failure);

  final GPFailure failure;

  @override
  List<Object?> get props => [failure];
}

final class TransactionDeletionDeleteErrorState extends TransactionDeletionErrorState {
  const TransactionDeletionDeleteErrorState(super.failure);
}

final class TransactionDeletionRestoreErrorState extends TransactionDeletionErrorState {
  const TransactionDeletionRestoreErrorState(super.failure);
}
