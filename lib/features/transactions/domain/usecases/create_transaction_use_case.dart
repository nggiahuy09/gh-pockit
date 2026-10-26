import 'package:meta/meta.dart';

import '../../../../core/domain/loggable.dart';
import '../../../../core/domain/use_case.dart';
import '../../../../core/error/result.dart';
import '../../../../core/money/money.dart';
import '../../../categories/domain/repositories/category_repository.dart';
import '../entities/transaction_entity.dart';
import '../entities/transaction_type.dart';
import '../repositories/transaction_repository.dart';
import 'refusal_from_category.dart';

final class CreateTransactionUseCase with GPUseCase<CreateTransactionInput, TransactionEntity> {
  const CreateTransactionUseCase(this._categoryRepository, this._transactionRepository);

  final CategoryRepository _categoryRepository;
  final TransactionRepository _transactionRepository;

  @override
  Future<GPResult<TransactionEntity>> execute(CreateTransactionInput input) async {
    final categoryId = input.categoryId;
    if (categoryId != null) {
      final refused = await refusalFromCategory(_categoryRepository, type: input.type, categoryId: categoryId);
      if (refused != null) return GPErr(refused);
    }

    return _transactionRepository.createTransaction(
      amount: input.amount,
      type: input.type,
      occurredAt: input.occurredAt,
      accountId: input.accountId,
      categoryId: categoryId,
      destinationAccountId: input.destinationAccountId,
      note: input.note,
    );
  }
}

@immutable
final class CreateTransactionInput implements GPLoggable {
  const CreateTransactionInput({
    required this.amount,
    required this.type,
    required this.occurredAt,
    required this.accountId,
    this.categoryId,
    this.destinationAccountId,
    this.note,
  });

  final Money amount;
  final TransactionType type;
  final DateTime occurredAt;
  final String accountId;
  final String? categoryId;
  final String? destinationAccountId;
  final String? note;

  @override
  Map<String, Object?> toLog() => {
    'type': type.storageValue,
    'account_id': accountId,
    'category_id': ?categoryId,
    'destination_account_id': ?destinationAccountId,
  };
}
