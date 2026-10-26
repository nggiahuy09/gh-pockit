import 'package:meta/meta.dart';

import '../../../../core/domain/loggable.dart';
import '../../../../core/domain/use_case.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../categories/domain/repositories/category_repository.dart';
import '../entities/transaction_entity.dart';
import '../repositories/transaction_repository.dart';
import 'refusal_from_category.dart';

/// ADR-0010 rule 3, judged only when the edit changes the filing: a transaction under a category deleted since must stay editable.
final class UpdateTransactionUseCase with GPUseCase<UpdateTransactionInput, TransactionEntity> {
  const UpdateTransactionUseCase(this._categoryRepository, this._transactionRepository);

  final CategoryRepository _categoryRepository;
  final TransactionRepository _transactionRepository;

  @override
  Future<GPResult<TransactionEntity>> execute(UpdateTransactionInput input) async {
    final transaction = input.transaction;
    final categoryId = transaction.categoryId;
    if (categoryId == null) return _transactionRepository.updateTransaction(transaction);

    final TransactionEntity? stored;
    try {
      stored = await _transactionRepository.watchTransaction(transaction.id).first;
    } on GPFailure catch (failure) {
      return GPErr(failure);
    }

    if (stored == null) return const GPErr(GPNotFoundFailure());

    // A stale edit skips the rule: the version guard reports it as a conflict instead.
    final filingChanged = stored.categoryId != categoryId || stored.type != transaction.type;
    if (stored.version == transaction.version && filingChanged) {
      final refused = await refusalFromCategory(_categoryRepository, type: transaction.type, categoryId: categoryId);
      if (refused != null) return GPErr(refused);
    }

    return _transactionRepository.updateTransaction(transaction);
  }
}

@immutable
final class UpdateTransactionInput implements GPLoggable {
  const UpdateTransactionInput(this.transaction);

  final TransactionEntity transaction;

  @override
  Map<String, Object?> toLog() => {'transaction_id': transaction.id, 'version': transaction.version};
}
