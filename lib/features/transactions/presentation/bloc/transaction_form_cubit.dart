import 'dart:async';

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
import 'package:ghpockit/features/transactions/presentation/transaction_form_field.dart';
import 'package:meta/meta.dart';

part 'transaction_form_state.dart';

/// Creates an expense or an income. Validation is the entity's and the use case's: the form only refuses to submit with no account to write to.
class TransactionFormCubit extends Cubit<TransactionFormState> {
  TransactionFormCubit() : super(const TransactionFormState());

  final GPClock _clock = getIt<GPClock>();

  final WatchAccountsUseCase _watchAccounts = WatchAccountsUseCase(accountRepository: getIt<AccountRepository>());
  final WatchCategoriesUseCase _watchCategories = WatchCategoriesUseCase(categoryRepository: getIt<CategoryRepository>());
  final CreateTransactionUseCase _createTransaction = CreateTransactionUseCase(
    transactionRepository: getIt<TransactionRepository>(),
    categoryRepository: getIt<CategoryRepository>(),
  );

  StreamSubscription<List<AccountEntity>>? _accountsSubscription;
  StreamSubscription<List<CategoryEntity>>? _categoriesSubscription;

  /// Live, so an account added from the form's empty state shows up the moment the account form pops.
  void start() {
    if (_accountsSubscription != null) return;

    _accountsSubscription = _watchAccounts().listen(_onAccounts, onError: _onStreamError);
    _categoriesSubscription = _watchCategories().listen(_onCategories, onError: _onStreamError);
  }

  void _onAccounts(List<AccountEntity> accounts) {
    final selected = state.accountId;
    final stillThere = selected != null && accounts.any((AccountEntity account) => account.id == selected);

    // The oldest account is the default; a selection archived or deleted elsewhere falls back to it rather than to nothing.
    emit(state.copyWith(accounts: accounts, accountId: stillThere ? selected : accounts.firstOrNull?.id, clearAccountId: !stillThere && accounts.isEmpty));
  }

  void _onCategories(List<CategoryEntity> categories) {
    final selected = state.categoryId;
    final stillThere = selected == null || categories.any((CategoryEntity category) => category.id == selected);

    emit(state.copyWith(categories: categories, clearCategoryId: !stillThere));
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

  Future<void> submit() async {
    final account = state.selectedAccount;
    if (account == null || state.isSaving || state.isSaved) return;

    emit(state.copyWith(isSaving: true, clearFailure: true));

    final result = await _createTransaction(
      type: state.type,
      accountId: account.id,
      // Zero when nothing was typed: the entity's "amount must be positive" is the message, not a disabled button.
      amount: Money(state.amountMinorUnits ?? 0, account.initialBalance.currencyCode),
      occurredAt: _occurredAt(state.pickedDay),
      categoryId: state.categoryId,
      note: state.note,
    );

    if (isClosed) return;

    emit(switch (result) {
      GPOk<TransactionEntity>() => state.copyWith(isSaving: false, isSaved: true),
      GPErr<TransactionEntity>(:final failure) => state.copyWith(isSaving: false, failure: failure),
    });
  }

  /// No day picked is "now", read at the save rather than when the form opened, so a form left open past midnight does not date it the day before. A
  /// picked day takes the current time of day, so several entries backdated to one day keep the order they were typed in.
  DateTime _occurredAt(DateTime? day) {
    final now = _clock.nowUtc();
    if (day == null) return now;

    final local = now.toLocal();
    return DateTime(day.year, day.month, day.day, local.hour, local.minute, local.second, local.millisecond).toUtc();
  }

  @override
  Future<void> close() async {
    await _accountsSubscription?.cancel();
    await _categoriesSubscription?.cancel();
    return super.close();
  }
}
