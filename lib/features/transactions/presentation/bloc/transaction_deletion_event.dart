part of 'transaction_deletion_bloc.dart';

@immutable
sealed class TransactionDeletionEvent {
  const TransactionDeletionEvent();
}

@immutable
final class TransactionDeletionDeleteEvent extends TransactionDeletionEvent {
  const TransactionDeletionDeleteEvent(this.transactionId);

  final String transactionId;
}

/// A delete written elsewhere (the form), whose undo the list offers.
@immutable
final class TransactionDeletionUndoOfferEvent extends TransactionDeletionEvent {
  const TransactionDeletionUndoOfferEvent(this.transactionId);

  final String transactionId;
}

@immutable
final class TransactionDeletionRestoreEvent extends TransactionDeletionEvent {
  const TransactionDeletionRestoreEvent(this.transactionId);

  final String transactionId;
}
