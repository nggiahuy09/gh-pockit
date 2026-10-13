import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ghpockit/app/di/injector.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/result.dart';
import 'package:ghpockit/core/money/money.dart';
import 'package:ghpockit/core/utils/clock.dart';
import 'package:ghpockit/features/accounts/domain/entities/account_entity.dart';
import 'package:ghpockit/features/accounts/domain/repositories/account_repository.dart';
import 'package:ghpockit/features/accounts/domain/usecases/watch_accounts_use_case.dart';
import 'package:ghpockit/features/categories/domain/entities/category_entity.dart';
import 'package:ghpockit/features/categories/domain/repositories/category_repository.dart';
import 'package:ghpockit/features/categories/domain/usecases/watch_categories_use_case.dart';
import 'package:ghpockit/features/categories/presentation/category_display_order.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_type.dart';
import 'package:ghpockit/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:ghpockit/features/transactions/domain/usecases/create_transaction_use_case.dart';
import 'package:ghpockit/features/transactions/domain/usecases/delete_transaction_use_case.dart';
import 'package:ghpockit/features/transactions/domain/usecases/update_transaction_use_case.dart';
import 'package:ghpockit/features/transactions/domain/usecases/watch_transaction_use_case.dart';
import 'package:ghpockit/features/transactions/presentation/transaction_form_field.dart';

part 'transaction_form_state.dart';

/// Creates an expense or an income, or edits the transaction [transactionId] names. Validation is the entity's and the use cases': the form only refuses
/// to submit with no account to write to.
class TransactionFormCubit extends Cubit<TransactionFormState> {
  TransactionFormCubit({this.transactionId}) : super(TransactionFormState(isLoadingOriginal: transactionId != null));

  final String? transactionId;

  final GPClock _clock = getIt<GPClock>();

  final WatchAccountsUseCase _watchAccounts = WatchAccountsUseCase(accountRepository: getIt<AccountRepository>());
  final WatchCategoriesUseCase _watchCategories = WatchCategoriesUseCase(categoryRepository: getIt<CategoryRepository>());
  final WatchTransactionUseCase _watchTransaction = WatchTransactionUseCase(transactionRepository: getIt<TransactionRepository>());
  final CreateTransactionUseCase _createTransaction = CreateTransactionUseCase(
    transactionRepository: getIt<TransactionRepository>(),
    categoryRepository: getIt<CategoryRepository>(),
  );
  final UpdateTransactionUseCase _updateTransaction = UpdateTransactionUseCase(
    transactionRepository: getIt<TransactionRepository>(),
    categoryRepository: getIt<CategoryRepository>(),
  );
  final DeleteTransactionUseCase _deleteTransaction = DeleteTransactionUseCase(transactionRepository: getIt<TransactionRepository>());

  StreamSubscription<List<AccountEntity>>? _accountsSubscription;
  StreamSubscription<List<CategoryEntity>>? _categoriesSubscription;

  bool get isEditing => transactionId != null;

  /// Live, so an account added from the form's empty state shows up the moment the account form pops.
  void start() {
    if (_accountsSubscription != null) return;

    _accountsSubscription = _watchAccounts().listen(_onAccounts, onError: _onStreamError);
    _categoriesSubscription = _watchCategories().listen(_onCategories, onError: _onStreamError);
  }

  /// Reads the transaction once, as the account form does: what the user types stays put, and a change made elsewhere meanwhile is a conflict on save.
  Future<void> load() async {
    final id = transactionId;
    if (id == null) return;

    try {
      final transaction = await _watchTransaction(id).first;
      if (isClosed) return;

      if (transaction == null) {
        emit(state.copyWith(isLoadingOriginal: false, failure: const GPNotFoundFailure()));
        return;
      }

      emit(
        state.copyWith(
          original: transaction,
          isLoadingOriginal: false,
          type: transaction.type,
          accountId: transaction.accountId,
          categoryId: transaction.categoryId,
          clearCategoryId: transaction.categoryId == null,
          amountMinorUnits: transaction.amount.minorUnits,
          note: transaction.note ?? '',
        ),
      );
    } on GPFailure catch (failure) {
      if (!isClosed) emit(state.copyWith(isLoadingOriginal: false, failure: failure));
    }
  }

  void _onAccounts(List<AccountEntity> accounts) {
    final selected = state.accountId;
    // An edit keeps its own account once archived or deleted elsewhere: moving the transaction is the user's call, and the save says what is wrong.
    final keeps = selected != null && (selected == state.original?.accountId || accounts.any((AccountEntity account) => account.id == selected));

    // The oldest account is the default; a selection archived or deleted elsewhere falls back to it rather than to nothing.
    emit(state.copyWith(accounts: accounts, accountId: keeps ? selected : accounts.firstOrNull?.id, clearAccountId: !keeps && accounts.isEmpty));
  }

  void _onCategories(List<CategoryEntity> categories) {
    final selected = state.categoryId;
    // An edit keeps the category it is filed under once deleted: re-filing is the user's call, not a side effect of fixing the note (ADR-0010).
    final keeps = selected == null || selected == state.original?.categoryId || categories.any((CategoryEntity category) => category.id == selected);

    emit(state.copyWith(categories: categories, clearCategoryId: !keeps));
  }

  void _onStreamError(Object error, StackTrace stackTrace) {
    // Anything but a `GPFailure` is a bug and must not read as a sentence (ADR-0006).
    if (error is! GPFailure) Error.throwWithStackTrace(error, stackTrace);
    if (!isClosed) emit(state.copyWith(failure: error));
  }

  /// A category of the other kind is dropped rather than refused later: it is what switching the type leaves behind.
  void typeChanged(TransactionType type) {
    final category = state.selectedCategory;
    final keepsCategory = category != null && category.type == type.categoryType;

    emit(state.copyWith(type: type, clearCategoryId: !keepsCategory, clearFailure: _fixes(TransactionFormField.category)));
  }

  /// An id no longer in the list is ignored: an open dropdown menu still offers what the stream has since dropped.
  void accountChanged(String accountId) {
    if (state.accounts?.any((AccountEntity account) => account.id == accountId) != true) return;

    emit(state.copyWith(accountId: accountId, clearFailure: _fixes(TransactionFormField.account)));
  }

  /// Null is "uncategorised". An id the current type cannot use is ignored, as in [accountChanged].
  void categoryChanged(String? categoryId) {
    if (categoryId != null && !state.categoriesForType.any((CategoryEntity category) => category.id == categoryId)) return;

    emit(state.copyWith(categoryId: categoryId, clearCategoryId: categoryId == null, clearFailure: _fixes(TransactionFormField.category)));
  }

  void amountChanged(int? minorUnits) => emit(state.copyWith(amountMinorUnits: minorUnits, clearAmount: minorUnits == null, clearFailure: _fixes(TransactionFormField.amount)));

  void dateChanged(DateTime day) => emit(state.copyWith(pickedDay: DateTime(day.year, day.month, day.day), clearFailure: _fixes(null)));

  void noteChanged(String note) => emit(state.copyWith(note: note, clearFailure: _fixes(TransactionFormField.note)));

  /// An edit clears the failure it can fix: one about the edited field, or one about no field (ADR-0016). An amount error stays while the note is typed.
  bool _fixes(TransactionFormField? edited) {
    final failure = state.failure;
    if (failure == null) return false;

    final about = transactionFormFieldOf(failure);
    return about == null || about == edited;
  }

  bool get _isFinishedOrBusy => state.isLoading || state.isSaving || state.isSaved || state.isDeleting || state.isDeleted;

  Future<void> submit() async {
    if (_isFinishedOrBusy) return;
    // Editing with nothing loaded (gone, or unreadable): without the original there is nothing to update, and creating would be a second transaction.
    if (isEditing && state.original == null) return;

    final accountId = state.accountId;
    final currencyCode = state.currencyCode;
    if (accountId == null || currencyCode == null) return;

    emit(state.copyWith(isSaving: true, clearFailure: true));

    // Zero when nothing was typed: the entity's "amount must be positive" is the message, not a disabled button.
    final amount = Money(state.amountMinorUnits ?? 0, currencyCode);
    final occurredAt = _occurredAt(state.pickedDay);
    final original = state.original;
    final GPResult<TransactionEntity> result;

    if (original == null) {
      result = await _createTransaction(type: state.type, accountId: accountId, amount: amount, occurredAt: occurredAt, categoryId: state.categoryId, note: state.note);
    } else {
      final edited = original.update(
        type: state.type,
        accountId: accountId,
        categoryId: state.categoryId,
        clearCategory: state.categoryId == null,
        amount: amount,
        occurredAt: occurredAt,
        note: state.note,
      );
      result = switch (edited) {
        GPOk<TransactionEntity>(:final value) => await _updateTransaction(value),
        final GPErr<TransactionEntity> refused => refused,
      };
    }

    if (isClosed) return;

    emit(switch (result) {
      GPOk<TransactionEntity>() => state.copyWith(isSaving: false, isSaved: true),
      GPErr<TransactionEntity>(:final failure) => state.copyWith(isSaving: false, failure: failure),
    });
  }

  /// No confirmation: the list offers the undo once the page pops (ADR-0017).
  Future<void> delete() async {
    final original = state.original;
    if (original == null || _isFinishedOrBusy) return;

    emit(state.copyWith(isDeleting: true, clearFailure: true));

    final result = await _deleteTransaction(original.id);
    if (isClosed) return;

    emit(switch (result) {
      GPOk<void>() => state.copyWith(isDeleting: false, isDeleted: true),
      GPErr<void>(:final failure) => state.copyWith(isDeleting: false, failure: failure),
    });
  }

  /// A new transaction with no day picked is "now", read at the save rather than when the form opened, so a form left open past midnight does not date
  /// it the day before; a picked day takes the current time of day, so several entries backdated to one day keep the order they were typed in. An edit
  /// keeps its date, or its time of day on the day picked: only the day was asked for.
  DateTime _occurredAt(DateTime? day) {
    final time = state.original?.occurredAt.toLocal() ?? _clock.nowUtc().toLocal();
    if (day == null) return time.toUtc();

    return DateTime(day.year, day.month, day.day, time.hour, time.minute, time.second, time.millisecond).toUtc();
  }

  @override
  Future<void> close() async {
    await _accountsSubscription?.cancel();
    await _categoriesSubscription?.cancel();
    return super.close();
  }
}
