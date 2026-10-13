part of 'transaction_form_cubit.dart';

@immutable
final class TransactionFormState {
  const TransactionFormState({
    this.original,
    this.type = TransactionType.expense,
    this.accountId,
    this.categoryId,
    this.amountMinorUnits,
    this.pickedDay,
    this.note = '',
    this.accounts,
    this.categories,
    this.isLoadingOriginal = false,
    this.isSaving = false,
    this.isSaved = false,
    this.failure,
  });

  /// The transaction being edited, as loaded. Null on create.
  final TransactionEntity? original;

  final TransactionType type;

  /// On an edit, may name an account no longer in [accounts] (archived or deleted since): the form keeps it rather than move the transaction.
  final String? accountId;

  /// Null is "uncategorised", a valid choice. On an edit, may name a category deleted since, which the form shows as uncategorised (ADR-0010).
  final String? categoryId;

  /// In the selected account's currency. Null while the field is empty.
  final int? amountMinorUnits;

  /// A local calendar day at midnight, once the user picks one. Null keeps the edited transaction's date, or dates a new one at the moment it is saved.
  final DateTime? pickedDay;

  final String note;

  /// Null until the first emission: loading, not empty.
  final List<AccountEntity>? accounts;

  /// Both kinds, in the repository's order; [categoriesForType] narrows and orders them for display.
  final List<CategoryEntity>? categories;

  final bool isLoadingOriginal;
  final bool isSaving;

  /// Terminal: the page pops on it.
  final bool isSaved;

  final GPFailure? failure;

  bool get isLoading => accounts == null || categories == null || isLoadingOriginal;

  AccountEntity? get selectedAccount {
    final id = accountId;
    if (id == null) return null;

    return accounts?.where((AccountEntity account) => account.id == id).firstOrNull;
  }

  /// The amount's currency: the selected account's, or the edited transaction's while its account is not in [accounts].
  String? get currencyCode {
    final account = selectedAccount;
    if (account != null) return account.initialBalance.currencyCode;

    final original = this.original;
    return original != null && original.accountId == accountId ? original.amount.currencyCode : null;
  }

  CategoryEntity? get selectedCategory {
    final id = categoryId;
    if (id == null) return null;

    return categories?.where((CategoryEntity category) => category.id == id).firstOrNull;
  }

  List<CategoryEntity> get categoriesForType {
    final kind = type.categoryType;
    return inDisplayOrder(categories?.where((CategoryEntity category) => category.type == kind) ?? const <CategoryEntity>[]);
  }

  TransactionFormState copyWith({
    TransactionEntity? original,
    TransactionType? type,
    String? accountId,
    bool clearAccountId = false,
    String? categoryId,
    bool clearCategoryId = false,
    int? amountMinorUnits,
    bool clearAmount = false,
    DateTime? pickedDay,
    String? note,
    List<AccountEntity>? accounts,
    List<CategoryEntity>? categories,
    bool? isLoadingOriginal,
    bool? isSaving,
    bool? isSaved,
    GPFailure? failure,
    bool clearFailure = false,
  }) => TransactionFormState(
    original: original ?? this.original,
    type: type ?? this.type,
    accountId: clearAccountId ? null : (accountId ?? this.accountId),
    categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
    amountMinorUnits: clearAmount ? null : (amountMinorUnits ?? this.amountMinorUnits),
    pickedDay: pickedDay ?? this.pickedDay,
    note: note ?? this.note,
    accounts: accounts ?? this.accounts,
    categories: categories ?? this.categories,
    isLoadingOriginal: isLoadingOriginal ?? this.isLoadingOriginal,
    isSaving: isSaving ?? this.isSaving,
    isSaved: isSaved ?? this.isSaved,
    failure: clearFailure ? null : (failure ?? this.failure),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionFormState &&
          other.original == original &&
          other.type == type &&
          other.accountId == accountId &&
          other.categoryId == categoryId &&
          other.amountMinorUnits == amountMinorUnits &&
          other.pickedDay == pickedDay &&
          other.note == note &&
          listEquals(other.accounts, accounts) &&
          listEquals(other.categories, categories) &&
          other.isLoadingOriginal == isLoadingOriginal &&
          other.isSaving == isSaving &&
          other.isSaved == isSaved &&
          other.failure == failure;

  @override
  int get hashCode => Object.hash(
    original,
    type,
    accountId,
    categoryId,
    amountMinorUnits,
    pickedDay,
    note,
    accounts == null ? null : Object.hashAll(accounts!),
    categories == null ? null : Object.hashAll(categories!),
    isLoadingOriginal,
    isSaving,
    isSaved,
    failure,
  );
}
