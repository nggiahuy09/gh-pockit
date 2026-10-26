part of 'transaction_form_bloc.dart';

@immutable
final class TransactionFormState with Equatable {
  const TransactionFormState({
    required List<AccountEntity>? accounts,
    required List<CategoryEntity>? categories,
    required this.failure,
    required this.original,
    required this.status,
    required this.type,
    required this.pickedDay,
    required this.accountId,
    required this.categoryId,
    required this.destinationAccountId,
    required this.note,
    required this.amountMinorUnits,
    required this.isEditing,
  }) : _accounts = accounts,
       _categories = categories;

  const TransactionFormState.initial(this.isEditing)
    : _accounts = null,
      _categories = null,
      failure = null,
      original = null,
      status = isEditing ? TransactionFormStatus.loading : TransactionFormStatus.editing,
      type = TransactionType.expense,
      pickedDay = null,
      accountId = null,
      categoryId = null,
      destinationAccountId = null,
      note = '',
      amountMinorUnits = null;

  final List<AccountEntity>? _accounts;

  /// Both kinds, in the repository's order; [categoriesForType] narrows and orders them for display.
  final List<CategoryEntity>? _categories;

  final GPFailure? failure;

  final TransactionEntity? original;

  final TransactionFormStatus status;
  final TransactionType type;

  /// A local calendar day at midnight, once the user picks one. Null keeps the edited transaction's date, or dates a new one at the moment it is saved.
  final DateTime? pickedDay;

  /// On an edit, may name an account no longer in [accounts]: the form keeps it rather than move the transaction.
  final String? accountId;

  /// On an edit, may name a category deleted since, which the form shows as uncategorised (ADR-0010).
  final String? categoryId;

  final String? destinationAccountId;

  final String note;

  /// In the selected account's currency. Null while the field is empty.
  final int? amountMinorUnits;

  final bool isEditing;

  /// Null until the first emission: loading, not empty.
  List<AccountEntity>? get accounts {
    final accounts = _accounts;
    return accounts == null ? null : List.unmodifiable(accounts);
  }

  List<CategoryEntity>? get categories {
    final categories = _categories;
    return categories == null ? null : List.unmodifiable(categories);
  }

  bool get isLoading => status == TransactionFormStatus.loading || _accounts == null || _categories == null;

  bool get isSaving => status == TransactionFormStatus.saving;

  bool get isSaved => status == TransactionFormStatus.saved;

  bool get isDeleting => status == TransactionFormStatus.deleting;

  bool get isDeleted => status == TransactionFormStatus.deleted;

  bool get isFinishedOrBusy => isLoading || isSaving || isSaved || isDeleting || isDeleted;

  TransactionFormField? get failedField {
    final failure = this.failure;
    return failure == null ? null : TransactionFormField.fromFailure(failure);
  }

  AccountEntity? get selectedAccount {
    final accountId = this.accountId;
    return accountId == null ? null : _accounts?.where((account) => account.id == accountId).firstOrNull;
  }

  /// The selected account's, or the edited transaction's while its account is not in [accounts].
  String? get currencyCode {
    final account = selectedAccount;
    if (account != null) return account.initialBalance.currencyCode;

    final original = this.original;
    return original != null && original.accountId == accountId ? original.amount.currencyCode : null;
  }

  /// Another account in the same currency: no transfer between currencies (ADR-0009).
  List<AccountEntity> get destinationsForSource {
    final currency = currencyCode;
    return [
      for (final account in _accounts ?? const <AccountEntity>[])
        if (account.id != accountId && account.initialBalance.currencyCode == currency) account,
    ];
  }

  CategoryEntity? get selectedCategory {
    final categoryId = this.categoryId;
    return categoryId == null ? null : _categories?.where((category) => category.id == categoryId).firstOrNull;
  }

  List<CategoryEntity> get categoriesForType {
    final categoryType = type.categoryType;
    return inDisplayOrder((_categories ?? const <CategoryEntity>[]).where((category) => category.type == categoryType));
  }

  @override
  List<Object?> get props => [_accounts, _categories, failure, original, status, type, pickedDay, accountId, categoryId, destinationAccountId, note, amountMinorUnits, isEditing];

  TransactionFormState _copyWith({
    List<AccountEntity>? accounts,
    List<CategoryEntity>? categories,
    GPValueWrapper<GPFailure?>? failure,
    TransactionEntity? original,
    TransactionFormStatus? status,
    TransactionType? type,
    DateTime? pickedDay,
    GPValueWrapper<String?>? accountId,
    GPValueWrapper<String?>? categoryId,
    GPValueWrapper<String?>? destinationAccountId,
    String? note,
    GPValueWrapper<int?>? amountMinorUnits,
  }) => TransactionFormState(
    accounts: accounts ?? _accounts,
    categories: categories ?? _categories,
    failure: failure == null ? this.failure : failure.value,
    original: original ?? this.original,
    status: status ?? this.status,
    type: type ?? this.type,
    pickedDay: pickedDay ?? this.pickedDay,
    accountId: accountId == null ? this.accountId : accountId.value,
    categoryId: categoryId == null ? this.categoryId : categoryId.value,
    destinationAccountId: destinationAccountId == null ? this.destinationAccountId : destinationAccountId.value,
    note: note ?? this.note,
    amountMinorUnits: amountMinorUnits == null ? this.amountMinorUnits : amountMinorUnits.value,
    isEditing: isEditing,
  );

  /// No amount or note: states can end up in logs (golden rule 9).
  @override
  String toString() => 'TransactionFormState(status: ${status.name}, type: ${type.name}, isEditing: $isEditing, failure: $failure)';
}

/// `saved` and `deleted` are terminal: the view pops on them.
enum TransactionFormStatus { loading, editing, saving, saved, deleting, deleted }
