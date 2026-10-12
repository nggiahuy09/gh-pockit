import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/currency_code.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_type.dart';
import 'package:ghpockit/features/accounts/domain/repositories/account_repository.dart';
import 'package:ghpockit/features/accounts/domain/usecases/create_account_use_case.dart';
import 'package:ghpockit/features/accounts/domain/usecases/update_account_use_case.dart';
import 'package:ghpockit/features/accounts/domain/usecases/watch_account_use_case.dart';
import 'package:meta/meta.dart';

part 'account_form_state.dart';

/// Creates an account, or edits the one [accountId] names. The currency is chosen on create only (ADR-0010).
class AccountFormCubit extends Cubit<AccountFormState> {
  AccountFormCubit({this.accountId}) : super(AccountFormState(isLoading: accountId != null));

  final String? accountId;

  final WatchAccountUseCase _watchAccount = WatchAccountUseCase(accountRepository: getIt<AccountRepository>());
  final CreateAccountUseCase _createAccount = CreateAccountUseCase(accountRepository: getIt<AccountRepository>());
  final UpdateAccountUseCase _updateAccount = UpdateAccountUseCase(accountRepository: getIt<AccountRepository>());

  bool get isEditing => accountId != null;

  /// Reads the account once: a form keeps what the user is typing, and a change made elsewhere meanwhile surfaces as a conflict on save.
  Future<void> load() async {
    final id = accountId;
    if (id == null) return;

    try {
      final account = await _watchAccount(id).first;
      if (isClosed) return;

      if (account == null) {
        emit(state.copyWith(isLoading: false, failure: const GPNotFoundFailure()));
        return;
      }

      final balance = account.initialBalance;
      emit(
        AccountFormState(
          original: account,
          name: account.name,
          type: account.type,
          currencyCode: balance.currencyCode,
          initialMinorUnits: balance.minorUnits.abs(),
          isOwed: balance.isNegative,
        ),
      );
    } on GPFailure catch (failure) {
      if (!isClosed) emit(state.copyWith(isLoading: false, failure: failure));
    }
  }

  void nameChanged(String name) => emit(state.copyWith(name: name, clearFailure: true));

  void typeChanged(AccountType type) => emit(state.copyWith(type: type, clearFailure: true));

  void currencyChanged(CurrencyCode currency) {
    if (isEditing) return;
    emit(state.copyWith(currencyCode: currency.code, clearFailure: true));
  }

  void initialBalanceChanged(int? minorUnits) => emit(state.copyWith(initialMinorUnits: minorUnits, clearInitialMinorUnits: minorUnits == null, clearFailure: true));

  void owedChanged({required bool isOwed}) => emit(state.copyWith(isOwed: isOwed, clearFailure: true));

  Future<void> submit() async {
    if (state.isSaving || state.isLoading || state.isSaved) return;
    // Editing with nothing loaded (gone, or unreadable): without the original there is nothing to update, and creating would be a second account.
    if (isEditing && state.original == null) return;

    final magnitude = state.initialMinorUnits ?? 0;
    final signed = state.isOwed ? -magnitude : magnitude;

    emit(state.copyWith(isSaving: true, clearFailure: true));

    final original = state.original;
    final GPResult<AccountEntity> result;
    if (original == null) {
      result = await _createAccount(name: state.name, type: state.type, initialBalance: Money(signed, state.currencyCode));
    } else {
      result = switch (original.update(name: state.name, type: state.type, initialBalanceMinorUnits: signed)) {
        GPOk<AccountEntity>(:final value) => await _updateAccount(value),
        final GPErr<AccountEntity> refused => refused,
      };
    }

    if (isClosed) return;

    emit(switch (result) {
      GPOk<AccountEntity>() => state.copyWith(isSaving: false, isSaved: true),
      GPErr<AccountEntity>(:final failure) => state.copyWith(isSaving: false, failure: failure),
    });
  }
}
