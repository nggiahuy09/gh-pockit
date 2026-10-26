import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:meta/meta.dart';

import '../../../../app/di/injector.dart';
import '../../../../core/bloc/transformers.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/usecases/delete_transaction_use_case.dart';
import '../../domain/usecases/restore_transaction_use_case.dart';

part 'transaction_deletion_event.dart';

part 'transaction_deletion_state.dart';

/// The list's delete and its undo (ADR-0017). Both write at once: the list follows the database, so nothing is held here.
final class TransactionDeletionBloc extends Bloc<TransactionDeletionEvent, TransactionDeletionState> {
  TransactionDeletionBloc() : super(const TransactionDeletionInitState()) {
    on<TransactionDeletionEvent>(_eventHandler, transformer: sequential());
  }

  final _deleteTransaction = DeleteTransactionUseCase(getIt.get<TransactionRepository>());
  final _restoreTransaction = RestoreTransactionUseCase(getIt.get<TransactionRepository>());

  Future<void> _eventHandler(TransactionDeletionEvent event, Emitter<TransactionDeletionState> emit) async {
    switch (event) {
      case TransactionDeletionDeleteEvent(:final transactionId):
        await _deleteHandler(transactionId, emit);
      case TransactionDeletionUndoOfferEvent(:final transactionId):
        _undoOfferHandler(transactionId, emit);
      case TransactionDeletionRestoreEvent(:final transactionId):
        await _restoreHandler(transactionId, emit);
    }
  }

  Future<void> _deleteHandler(String transactionId, Emitter<TransactionDeletionState> emit) async {
    emit(const TransactionDeletionDeleteLoadingState());

    final result = await _deleteTransaction.execute(DeleteTransactionInput(transactionId));
    if (isClosed) return;

    emit(switch (result) {
      GPOk() => TransactionDeletionDeletedState(transactionId),
      GPErr(:final failure) => TransactionDeletionDeleteErrorState(failure),
    });
  }

  void _undoOfferHandler(String transactionId, Emitter<TransactionDeletionState> emit) => emit(TransactionDeletionDeletedState(transactionId));

  Future<void> _restoreHandler(String transactionId, Emitter<TransactionDeletionState> emit) async {
    emit(const TransactionDeletionRestoreLoadingState());

    final result = await _restoreTransaction.execute(RestoreTransactionInput(transactionId));
    if (isClosed) return;

    emit(switch (result) {
      GPOk() => const TransactionDeletionRestoredState(),
      GPErr(:final failure) => TransactionDeletionRestoreErrorState(failure),
    });
  }
}
