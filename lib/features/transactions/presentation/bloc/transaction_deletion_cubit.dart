import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:ghpockit/features/transactions/domain/usecases/delete_transaction_use_case.dart';
import 'package:ghpockit/features/transactions/domain/usecases/restore_transaction_use_case.dart';

/// The list's delete and its undo (ADR-0017). Both write at once: the list follows the database, so a row deleted is gone from it and a row restored is
/// back, with nothing held here. The state is "a write is in flight", as in `SampleDataCubit`.
class TransactionDeletionCubit extends Cubit<bool> {
  TransactionDeletionCubit() : super(false);

  final DeleteTransactionUseCase _delete = DeleteTransactionUseCase(transactionRepository: getIt<TransactionRepository>());
  final RestoreTransactionUseCase _restore = RestoreTransactionUseCase(transactionRepository: getIt<TransactionRepository>());

  Future<GPResult<void>> delete(String id) => _busyWhile(() => _delete(id));

  Future<GPResult<void>> restore(String id) => _busyWhile(() => _restore(id));

  Future<T> _busyWhile<T>(Future<T> Function() write) async {
    emit(true);
    try {
      return await write();
    } finally {
      if (!isClosed) emit(false);
    }
  }
}
