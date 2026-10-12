part of 'transaction_form_cubit.dart';

@immutable
final class TransactionFormState {
  const TransactionFormState({
    this.type = TransactionType.expense,
    this.accountId,
    this.categoryId,
    this.amountMinorUnits,
    this.pickedDay,
    this.note = '',
    this.accounts,
    this.categories,
    this.isSaving = false,
    this.isSaved = false,
    this.failure,
  });

  final TransactionType type;
  final String? accountId;

  /// Null is "uncategorised", a valid choice.
  final String? categoryId;

  /// In the selected account's currency. Null while the field is empty.
  final int? amountMinorUnits;

  /// A local calendar day at midnight, once the user picks one. Null dates the transaction at the moment it is saved.
  final DateTime? pickedDay;

  final String note;

  /// Null until the first emission: loading, not empty.
  final List<AccountEntity>? accounts;

  /// Both kinds, in the repository's order; [categoriesForType] narrows and orders them for display.
  final List<CategoryEntity>? categories;

  final bool isSaving;

  /// Terminal: the page pops on it.
  final bool isSaved;

  final GPFailure? failure;

  bool get isLoading => accounts == null || categories == null;

  AccountEntity? get selectedAccount {
    final id = accountId;
    if (id == null) return null;

    return accounts?.where((AccountEntity account) => account.id == id).firstOrNull;
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
    bool? isSaving,
    bool? isSaved,
    GPFailure? failure,
    bool clearFailure = false,
  }) => TransactionFormState(
    type: type ?? this.type,
    accountId: clearAccountId ? null : (accountId ?? this.accountId),
    categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
    amountMinorUnits: clearAmount ? null : (amountMinorUnits ?? this.amountMinorUnits),
    pickedDay: pickedDay ?? this.pickedDay,
    note: note ?? this.note,
    accounts: accounts ?? this.accounts,
    categories: categories ?? this.categories,
    isSaving: isSaving ?? this.isSaving,
    isSaved: isSaved ?? this.isSaved,
    failure: clearFailure ? null : (failure ?? this.failure),
  );
}
