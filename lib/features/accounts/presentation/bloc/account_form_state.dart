part of 'account_form_cubit.dart';

@immutable
final class AccountFormState {
  const AccountFormState({
    this.original,
    this.name = '',
    this.type = AccountType.cash,
    this.currencyCode = defaultCurrencyCode,
    this.initialMinorUnits,
    this.isOwed = false,
    this.isLoading = false,
    this.isSaving = false,
    this.isSaved = false,
    this.failure,
  });

  /// The app's home market; the picker offers every `CurrencyCode`.
  static const String defaultCurrencyCode = 'VND';

  /// The account being edited, as loaded. Null on create.
  final AccountEntity? original;

  final String name;
  final AccountType type;
  final String currencyCode;

  /// The magnitude typed; [isOwed] gives the sign. Null while the field is empty, saved as zero.
  final int? initialMinorUnits;

  /// A credit card or a loan starts below zero.
  final bool isOwed;

  final bool isLoading;
  final bool isSaving;

  /// Terminal: the page pops on it.
  final bool isSaved;

  final GPFailure? failure;

  AccountFormState copyWith({
    String? name,
    AccountType? type,
    String? currencyCode,
    int? initialMinorUnits,
    bool clearInitialMinorUnits = false,
    bool? isOwed,
    bool? isLoading,
    bool? isSaving,
    bool? isSaved,
    GPFailure? failure,
    bool clearFailure = false,
  }) => AccountFormState(
    original: original,
    name: name ?? this.name,
    type: type ?? this.type,
    currencyCode: currencyCode ?? this.currencyCode,
    initialMinorUnits: clearInitialMinorUnits ? null : (initialMinorUnits ?? this.initialMinorUnits),
    isOwed: isOwed ?? this.isOwed,
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    isSaved: isSaved ?? this.isSaved,
    failure: clearFailure ? null : (failure ?? this.failure),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountFormState &&
          other.original == original &&
          other.name == name &&
          other.type == type &&
          other.currencyCode == currencyCode &&
          other.initialMinorUnits == initialMinorUnits &&
          other.isOwed == isOwed &&
          other.isLoading == isLoading &&
          other.isSaving == isSaving &&
          other.isSaved == isSaved &&
          other.failure == failure;

  @override
  int get hashCode => Object.hash(original, name, type, currencyCode, initialMinorUnits, isOwed, isLoading, isSaving, isSaved, failure);
}
