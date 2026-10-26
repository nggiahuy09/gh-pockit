import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:meta/meta.dart';

import '../../../../app/di/injector.dart';
import '../../../../core/bloc/transformers.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/money/currency_code.dart';
import '../../../../core/money/money.dart';
import '../../../../core/utils/value_wrapper.dart';
import '../../domain/entities/account_entity.dart';
import '../../domain/entities/account_type.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/usecases/create_account_use_case.dart';
import '../../domain/usecases/update_account_use_case.dart';
import '../../domain/usecases/watch_account_use_case.dart';
import '../account_form_field_enum.dart';

part 'account_form_event.dart';

part 'account_form_state.dart';

/// Creates an account, or edits the one [_accountId] names. The currency is chosen on create only (ADR-0010).
final class AccountFormBloc extends Bloc<AccountFormEvent, AccountFormState> {
  AccountFormBloc({String? accountId}) : _accountId = accountId, super(AccountFormState.initial(accountId != null)) {
    on<AccountFormEvent>(_eventHandler, transformer: sequential());

    if (accountId != null) add(const _AccountFormLoadEvent());
  }

  final _createAccount = CreateAccountUseCase(getIt.get<AccountRepository>());
  final _updateAccount = UpdateAccountUseCase(getIt.get<AccountRepository>());
  final _watchAccount = WatchAccountUseCase(getIt.get<AccountRepository>());

  final String? _accountId;

  var _isSubmitting = false;

  Future<void> _eventHandler(AccountFormEvent event, Emitter<AccountFormState> emit) async {
    switch (event) {
      case _AccountFormLoadEvent():
        await _loadHandler(emit);
      case AccountFormNameChangeEvent(:final name):
        _nameChangeHandler(name, emit);
      case AccountFormTypeChangeEvent(:final type):
        _typeChangeHandler(type, emit);
      case AccountFormCurrencyChangeEvent(:final currency):
        _currencyChangeHandler(currency, emit);
      case AccountFormInitialBalanceChangeEvent(:final minorUnits):
        _initialBalanceChangeHandler(minorUnits, emit);
      case AccountFormOwedChangeEvent(:final isOwed):
        _owedChangeHandler(isOwed, emit);
      case AccountFormSubmitEvent():
        await _submitHandler(emit);
    }
  }

  /// Reads the account once: a form keeps what the user is typing, and a change made elsewhere meanwhile surfaces as a conflict on save.
  Future<void> _loadHandler(Emitter<AccountFormState> emit) async {
    final accountId = _accountId;
    if (accountId == null) return;

    try {
      final account = await _watchAccount.execute(WatchAccountInput(accountId)).first;
      if (isClosed) return;

      if (account == null) {
        emit(state._copyWith(failure: const GPValueWrapper(GPNotFoundFailure()), status: AccountFormStatus.editing));
        return;
      }

      final balance = account.initialBalance;
      emit(
        state._copyWith(
          original: account,
          status: AccountFormStatus.editing,
          type: account.type,
          currencyCode: balance.currencyCode,
          name: account.name,
          initialMinorUnits: GPValueWrapper(balance.minorUnits.abs()),
          isOwed: balance.isNegative,
        ),
      );
    } on GPFailure catch (failure) {
      if (!isClosed) emit(state._copyWith(failure: GPValueWrapper(failure), status: AccountFormStatus.editing));
    }
  }

  void _nameChangeHandler(String name, Emitter<AccountFormState> emit) => emit(state._copyWith(failure: _failureAfterEdit(AccountFormField.name), name: name));

  void _typeChangeHandler(AccountType type, Emitter<AccountFormState> emit) => emit(state._copyWith(failure: _failureAfterEdit(null), type: type));

  void _currencyChangeHandler(CurrencyCode currency, Emitter<AccountFormState> emit) {
    if (state.isEditing) return;

    emit(state._copyWith(failure: _failureAfterEdit(null), currencyCode: currency.code));
  }

  void _initialBalanceChangeHandler(int? minorUnits, Emitter<AccountFormState> emit) =>
      emit(state._copyWith(failure: _failureAfterEdit(null), initialMinorUnits: GPValueWrapper(minorUnits)));

  void _owedChangeHandler(bool isOwed, Emitter<AccountFormState> emit) => emit(state._copyWith(failure: _failureAfterEdit(null), isOwed: isOwed));

  Future<void> _submitHandler(Emitter<AccountFormState> emit) async {
    final original = state.original;
    // Editing with nothing loaded: there is nothing to update, and creating would be a second account.
    if (_isSubmitting || state.isLoading || state.isSaved || (state.isEditing && original == null)) return;

    _isSubmitting = true;
    emit(state._copyWith(failure: const GPValueWrapper(null), status: AccountFormStatus.saving));

    final magnitude = state.initialMinorUnits ?? 0;
    final initialBalance = Money(state.isOwed ? -magnitude : magnitude, state.currencyCode);
    final result = original == null ? await _createAccount.execute(CreateAccountInput(initialBalance, state.type, state.name)) : await _update(original, initialBalance.minorUnits);
    _isSubmitting = false;
    if (isClosed) return;

    emit(switch (result) {
      GPOk() => state._copyWith(status: AccountFormStatus.saved),
      GPErr(:final failure) => state._copyWith(failure: GPValueWrapper(failure), status: AccountFormStatus.editing),
    });
  }

  Future<GPResult<AccountEntity>> _update(AccountEntity original, int initialBalanceMinorUnits) async =>
      switch (original.update(type: state.type, name: state.name, initialBalanceMinorUnits: initialBalanceMinorUnits)) {
        GPOk(:final value) => await _updateAccount.execute(UpdateAccountInput(value)),
        final GPErr<AccountEntity> refused => refused,
      };

  /// An edit clears the failure it can fix: one about the edited field, or one about no field (ADR-0016).
  GPValueWrapper<GPFailure?>? _failureAfterEdit(AccountFormField? edited) {
    final failure = state.failure;
    if (failure == null) return null;

    final about = AccountFormField.fromFailure(failure);
    return about == null || about == edited ? const GPValueWrapper(null) : null;
  }
}
