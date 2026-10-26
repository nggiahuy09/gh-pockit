import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:meta/meta.dart';

import '../../../../app/di/injector.dart';
import '../../../../core/bloc/transformers.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/utils/clock.dart';
import '../../../accounts/domain/repositories/account_repository.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../../../transactions/domain/usecases/create_sample_transaction_use_case.dart';
import '../../../transactions/domain/usecases/seed_sample_data_use_case.dart';
import '../debug/sample_data.dart';

part 'sample_data_event.dart';

part 'sample_data_state.dart';

/// Debug builds only.
final class SampleDataBloc extends Bloc<SampleDataEvent, SampleDataState> {
  SampleDataBloc() : super(const SampleDataInitState()) {
    on<SampleDataEvent>(_eventHandler, transformer: sequential());
  }

  // `late`: resolved on the first tap, so the settings page still pumps without DI.
  late final _createSampleTransaction = CreateSampleTransactionUseCase(getIt.get<AccountRepository>(), getIt.get<GPClock>(), getIt.get<TransactionRepository>());
  late final _seedSampleData = SeedSampleDataUseCase(getIt.get<AccountRepository>(), getIt.get<GPClock>(), getIt.get<TransactionRepository>());

  Future<void> _eventHandler(SampleDataEvent event, Emitter<SampleDataState> emit) async {
    switch (event) {
      case SampleDataAddEvent(:final accountName, :final note):
        await _addHandler(accountName: accountName, note: note, emit: emit);
      case SampleDataSeedEvent():
        await _seedHandler(emit);
    }
  }

  Future<void> _addHandler({required String accountName, required String note, required Emitter<SampleDataState> emit}) async {
    emit(const SampleDataAddLoadingState());

    final result = await _createSampleTransaction.execute(CreateSampleTransactionInput(accountName: accountName, note: note));
    if (isClosed) return;

    emit(switch (result) {
      GPOk() => const SampleDataAddedState(),
      GPErr(:final failure) => SampleDataAddErrorState(failure),
    });
  }

  Future<void> _seedHandler(Emitter<SampleDataState> emit) async {
    emit(const SampleDataSeedLoadingState());

    final result = await _seedSampleData.execute(const SeedSampleDataInput(accounts: sampleAccounts, transactions: sampleTransactions));
    if (isClosed) return;

    emit(switch (result) {
      GPOk(:final value) => SampleDataSeededState(value),
      GPErr(:final failure) => SampleDataSeedErrorState(failure),
    });
  }
}
