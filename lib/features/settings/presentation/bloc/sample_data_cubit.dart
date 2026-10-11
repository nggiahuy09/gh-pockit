import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/utils/clock.dart';
import 'package:ghpockit/features/accounts/domain/repositories/account_repository.dart';
import 'package:ghpockit/features/settings/presentation/debug/sample_data.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:ghpockit/features/transactions/domain/usecases/create_sample_transaction_use_case.dart';
import 'package:ghpockit/features/transactions/domain/usecases/seed_sample_data_use_case.dart';

/// Debug builds only. The state is "a write is in flight".
class SampleDataCubit extends Cubit<bool> {
  SampleDataCubit() : super(false);

  // `late`: resolved on the first tap, so the settings page still pumps without DI.
  late final CreateSampleTransactionUseCase _createSample = CreateSampleTransactionUseCase(
    accountRepository: getIt<AccountRepository>(),
    transactionRepository: getIt<TransactionRepository>(),
    clock: getIt<GPClock>(),
  );

  late final SeedSampleDataUseCase _seed = SeedSampleDataUseCase(
    accountRepository: getIt<AccountRepository>(),
    transactionRepository: getIt<TransactionRepository>(),
    clock: getIt<GPClock>(),
  );

  /// Returns how many transactions it wrote.
  Future<GPResult<int>> seedDataset() => _busyWhile(() => _seed(accounts: sampleAccounts, transactions: sampleTransactions));

  Future<GPResult<TransactionEntity>> addSample({required String accountName, required String note}) async {
    return _busyWhile(() => _createSample(accountName: accountName, note: note));
  }

  Future<T> _busyWhile<T>(Future<T> Function() write) async {
    emit(true);
    try {
      return await write();
    } finally {
      if (!isClosed) emit(false);
    }
  }
}
