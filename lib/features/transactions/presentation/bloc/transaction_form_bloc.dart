import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:meta/meta.dart';

import '../../../../app/di/injector.dart';
import '../../../../core/bloc/transformers.dart';
import '../../../../core/domain/use_case.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/money/money.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/value_wrapper.dart';
import '../../../accounts/domain/entities/account_entity.dart';
import '../../../accounts/domain/repositories/account_repository.dart';
import '../../../accounts/domain/usecases/watch_accounts_use_case.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../categories/domain/repositories/category_repository.dart';
import '../../../categories/domain/usecases/watch_categories_use_case.dart';
import '../../../categories/presentation/category_display_order.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/entities/transaction_type.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/usecases/create_transaction_use_case.dart';
import '../../domain/usecases/delete_transaction_use_case.dart';
import '../../domain/usecases/update_transaction_use_case.dart';
import '../../domain/usecases/watch_transaction_use_case.dart';
import '../transaction_form_field_enum.dart';

part 'transaction_form_event.dart';

part 'transaction_form_state.dart';

/// Creates an expense, an income or a transfer, or edits the transaction [_transactionId] names. Validation is the entity's and the use cases': the form
/// only refuses to submit with no account to write to.
final class TransactionFormBloc extends Bloc<TransactionFormEvent, TransactionFormState> {
  TransactionFormBloc({String? transactionId}) : _transactionId = transactionId, super(TransactionFormState.initial(transactionId != null)) {
    on<TransactionFormRequestEvent>(_eventHandler, transformer: sequential());
    on<_TransactionFormWatchEvent>(_watchHandler, transformer: restartable());

    add(const _TransactionFormWatchEvent());
    if (transactionId != null) add(const _TransactionFormLoadEvent());
  }

  final GPClock _clock = getIt.get<GPClock>();
  final _createTransaction = CreateTransactionUseCase(getIt.get<CategoryRepository>(), getIt.get<TransactionRepository>());
  final _deleteTransaction = DeleteTransactionUseCase(getIt.get<TransactionRepository>());
  final _updateTransaction = UpdateTransactionUseCase(getIt.get<CategoryRepository>(), getIt.get<TransactionRepository>());
  final _watchAccounts = WatchAccountsUseCase(getIt.get<AccountRepository>());
  final _watchCategories = WatchCategoriesUseCase(getIt.get<CategoryRepository>());
  final _watchTransaction = WatchTransactionUseCase(getIt.get<TransactionRepository>());

  final String? _transactionId;

  var _isSubmitting = false;

  Future<void> _eventHandler(TransactionFormRequestEvent event, Emitter<TransactionFormState> emit) async {
    switch (event) {
      case _TransactionFormLoadEvent():
        await _loadHandler(emit);
      case TransactionFormTypeChangeEvent(:final type):
        _typeChangeHandler(type, emit);
      case TransactionFormAccountChangeEvent(:final accountId):
        _accountChangeHandler(accountId, emit);
      case TransactionFormDestinationChangeEvent(:final accountId):
        _destinationChangeHandler(accountId, emit);
      case TransactionFormCategoryChangeEvent(:final categoryId):
        _categoryChangeHandler(categoryId, emit);
      case TransactionFormAmountChangeEvent(:final minorUnits):
        _amountChangeHandler(minorUnits, emit);
      case TransactionFormDateChangeEvent(:final day):
        _dateChangeHandler(day, emit);
      case TransactionFormNoteChangeEvent(:final note):
        _noteChangeHandler(note, emit);
      case TransactionFormSubmitEvent():
        await _submitHandler(emit);
      case TransactionFormDeleteEvent():
        await _deleteHandler(emit);
    }
  }

  /// Live, so an account added from the form's empty state shows up the moment the account form pops.
  Future<void> _watchHandler(_TransactionFormWatchEvent event, Emitter<TransactionFormState> emit) => Future.wait([
    emit.forEach(_watchAccounts.execute(const GPNoInput()), onData: _withAccounts, onError: _withStreamFailure),
    emit.forEach(_watchCategories.execute(const GPNoInput()), onData: _withCategories, onError: _withStreamFailure),
  ]);

  /// Reads the transaction once: what the user types stays put, and a change made elsewhere meanwhile is a conflict on save.
  Future<void> _loadHandler(Emitter<TransactionFormState> emit) async {
    final transactionId = _transactionId;
    if (transactionId == null) return;

    try {
      final transaction = await _watchTransaction.execute(WatchTransactionInput(transactionId)).first;
      if (isClosed) return;

      if (transaction == null) {
        emit(state._copyWith(failure: const GPValueWrapper(GPNotFoundFailure()), status: TransactionFormStatus.editing));
        return;
      }

      emit(
        state._copyWith(
          original: transaction,
          status: TransactionFormStatus.editing,
          type: transaction.type,
          accountId: GPValueWrapper(transaction.accountId),
          categoryId: GPValueWrapper(transaction.categoryId),
          destinationAccountId: GPValueWrapper(transaction.destinationAccountId),
          note: transaction.note ?? '',
          amountMinorUnits: GPValueWrapper(transaction.amount.minorUnits),
        ),
      );
    } on GPFailure catch (failure) {
      if (!isClosed) emit(state._copyWith(failure: GPValueWrapper(failure), status: TransactionFormStatus.editing));
    }
  }

  /// A category of the other kind, or a destination once it is no longer a transfer, is dropped rather than refused later.
  void _typeChangeHandler(TransactionType type, Emitter<TransactionFormState> emit) {
    final category = state.selectedCategory;
    final keepsCategory = category != null && category.type == type.categoryType;

    emit(
      state._copyWith(
        failure: _failureAfterEdit(TransactionFormField.category) ?? _failureAfterEdit(TransactionFormField.destination),
        type: type,
        categoryId: keepsCategory ? null : const GPValueWrapper(null),
        destinationAccountId: type.isTransfer ? null : const GPValueWrapper(null),
      ),
    );
  }

  /// An id no longer offered is ignored: an open menu still offers what the stream has since dropped. A destination the new source cannot pair with is
  /// dropped.
  void _accountChangeHandler(String accountId, Emitter<TransactionFormState> emit) {
    if (!(state.accounts?.any((account) => account.id == accountId) ?? false)) return;

    final next = state._copyWith(accountId: GPValueWrapper(accountId));
    final destination = next.destinationAccountId;
    final keepsDestination = destination == null || next.destinationsForSource.any((account) => account.id == destination);

    emit(
      next._copyWith(
        failure: _failureAfterEdit(TransactionFormField.account) ?? _failureAfterEdit(TransactionFormField.destination),
        destinationAccountId: keepsDestination ? null : const GPValueWrapper(null),
      ),
    );
  }

  void _destinationChangeHandler(String accountId, Emitter<TransactionFormState> emit) {
    if (!state.destinationsForSource.any((account) => account.id == accountId)) return;

    emit(state._copyWith(failure: _failureAfterEdit(TransactionFormField.destination), destinationAccountId: GPValueWrapper(accountId)));
  }

  void _categoryChangeHandler(String? categoryId, Emitter<TransactionFormState> emit) {
    if (categoryId != null && !state.categoriesForType.any((category) => category.id == categoryId)) return;

    emit(state._copyWith(failure: _failureAfterEdit(TransactionFormField.category), categoryId: GPValueWrapper(categoryId)));
  }

  void _amountChangeHandler(int? minorUnits, Emitter<TransactionFormState> emit) =>
      emit(state._copyWith(failure: _failureAfterEdit(TransactionFormField.amount), amountMinorUnits: GPValueWrapper(minorUnits)));

  void _dateChangeHandler(DateTime day, Emitter<TransactionFormState> emit) =>
      emit(state._copyWith(failure: _failureAfterEdit(null), pickedDay: DateTime(day.year, day.month, day.day)));

  void _noteChangeHandler(String note, Emitter<TransactionFormState> emit) => emit(state._copyWith(failure: _failureAfterEdit(TransactionFormField.note), note: note));

  Future<void> _submitHandler(Emitter<TransactionFormState> emit) async {
    final original = state.original;
    final accountId = state.accountId;
    final currencyCode = state.currencyCode;
    // Editing with nothing loaded: there is nothing to update, and creating would be a second transaction.
    if (_isSubmitting || state.isFinishedOrBusy || (state.isEditing && original == null) || accountId == null || currencyCode == null) return;

    _isSubmitting = true;
    emit(state._copyWith(failure: const GPValueWrapper(null), status: TransactionFormStatus.saving));

    // Zero when nothing was typed: the entity's "amount must be positive" is the message, not a disabled button.
    final amount = Money(state.amountMinorUnits ?? 0, currencyCode);
    final occurredAt = _occurredAt(state.pickedDay);
    final result = original == null
        ? await _createTransaction.execute(
            CreateTransactionInput(
              amount: amount,
              type: state.type,
              occurredAt: occurredAt,
              accountId: accountId,
              categoryId: state.categoryId,
              destinationAccountId: state.destinationAccountId,
              note: state.note,
            ),
          )
        : await _update(original, amount: amount, occurredAt: occurredAt, accountId: accountId);
    _isSubmitting = false;
    if (isClosed) return;

    emit(switch (result) {
      GPOk() => state._copyWith(status: TransactionFormStatus.saved),
      GPErr(:final failure) => state._copyWith(failure: GPValueWrapper(failure), status: TransactionFormStatus.editing),
    });
  }

  Future<GPResult<TransactionEntity>> _update(TransactionEntity original, {required Money amount, required DateTime occurredAt, required String accountId}) async {
    final edited = original.update(
      amount: amount,
      type: state.type,
      occurredAt: occurredAt,
      accountId: accountId,
      categoryId: state.categoryId,
      destinationAccountId: state.destinationAccountId,
      note: state.note,
      clearCategory: state.categoryId == null,
      clearDestination: state.destinationAccountId == null,
    );

    return switch (edited) {
      GPOk(:final value) => await _updateTransaction.execute(UpdateTransactionInput(value)),
      GPErr() => edited,
    };
  }

  /// No confirmation: the list offers the undo once the page pops (ADR-0017).
  Future<void> _deleteHandler(Emitter<TransactionFormState> emit) async {
    final original = state.original;
    if (original == null || state.isFinishedOrBusy) return;

    emit(state._copyWith(failure: const GPValueWrapper(null), status: TransactionFormStatus.deleting));

    final result = await _deleteTransaction.execute(DeleteTransactionInput(original.id));
    if (isClosed) return;

    emit(switch (result) {
      GPOk() => state._copyWith(status: TransactionFormStatus.deleted),
      GPErr(:final failure) => state._copyWith(failure: GPValueWrapper(failure), status: TransactionFormStatus.editing),
    });
  }

  /// The oldest account is the default; a selection gone elsewhere falls back to it. An edit keeps its own account and destination once archived or
  /// deleted elsewhere: moving the transaction is the user's call, and the save says what is wrong. No destination is ever picked for the user.
  TransactionFormState _withAccounts(List<AccountEntity> accounts) {
    final original = state.original;
    final selected = state.accountId;
    final keepsAccount = selected != null && (selected == original?.accountId || accounts.any((account) => account.id == selected));
    final destination = state.destinationAccountId;
    final keepsDestination = destination == null || destination == original?.destinationAccountId || accounts.any((account) => account.id == destination);

    return state._copyWith(
      accounts: accounts,
      accountId: keepsAccount ? null : GPValueWrapper(accounts.firstOrNull?.id),
      destinationAccountId: keepsDestination ? null : const GPValueWrapper(null),
    );
  }

  /// An edit keeps the category it is filed under once deleted: re-filing is the user's call (ADR-0010).
  TransactionFormState _withCategories(List<CategoryEntity> categories) {
    final selected = state.categoryId;
    final keepsCategory = selected == null || selected == state.original?.categoryId || categories.any((category) => category.id == selected);

    return state._copyWith(categories: categories, categoryId: keepsCategory ? null : const GPValueWrapper(null));
  }

  /// Anything but a `GPFailure` is a bug and must not read as a sentence (ADR-0006).
  TransactionFormState _withStreamFailure(Object error, StackTrace stackTrace) {
    if (error is! GPFailure) Error.throwWithStackTrace(error, stackTrace);

    return state._copyWith(failure: GPValueWrapper(error));
  }

  /// An edit clears the failure it can fix: one about the edited field, or one about no field (ADR-0016). An amount error stays while the note is typed.
  GPValueWrapper<GPFailure?>? _failureAfterEdit(TransactionFormField? edited) {
    final failure = state.failure;
    if (failure == null) return null;

    final about = TransactionFormField.fromFailure(failure);
    return about == null || about == edited ? const GPValueWrapper(null) : null;
  }

  /// A new transaction with no day picked is "now", read at the save, so a form left open past midnight does not date it the day before. A picked day
  /// takes the current time of day, so entries backdated to one day keep the order they were typed in. An edit keeps its time of day.
  DateTime _occurredAt(DateTime? day) {
    final time = state.original?.occurredAt.toLocal() ?? _clock.nowUtc().toLocal();
    if (day == null) return time.toUtc();

    return DateTime(day.year, day.month, day.day, time.hour, time.minute, time.second, time.millisecond).toUtc();
  }
}
