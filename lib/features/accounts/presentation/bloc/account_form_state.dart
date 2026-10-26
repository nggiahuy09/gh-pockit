part of 'account_form_bloc.dart';

@immutable
final class AccountFormState with Equatable {
  const AccountFormState({
    required this.failure,
    required this.original,
    required this.status,
    required this.type,
    required this.currencyCode,
    required this.name,
    required this.initialMinorUnits,
    required this.isEditing,
    required this.isOwed,
  });

  const AccountFormState.initial(this.isEditing)
    : failure = null,
      original = null,
      status = isEditing ? AccountFormStatus.loading : AccountFormStatus.editing,
      type = AccountType.cash,
      currencyCode = defaultCurrencyCode,
      name = '',
      initialMinorUnits = null,
      isOwed = false;

  final GPFailure? failure;

  /// The account being edited, as loaded. Null on create.
  final AccountEntity? original;

  final AccountFormStatus status;
  final AccountType type;
  final String currencyCode;
  final String name;

  /// The magnitude typed; [isOwed] gives the sign. Null while the field is empty, saved as zero.
  final int? initialMinorUnits;

  final bool isEditing;

  /// A credit card or a loan starts below zero.
  final bool isOwed;

  static const defaultCurrencyCode = 'VND';

  bool get isLoading => status == AccountFormStatus.loading;

  bool get isSaving => status == AccountFormStatus.saving;

  bool get isSaved => status == AccountFormStatus.saved;

  AccountFormField? get failedField {
    final failure = this.failure;
    return failure == null ? null : AccountFormField.fromFailure(failure);
  }

  @override
  List<Object?> get props => [failure, original, status, type, currencyCode, name, initialMinorUnits, isEditing, isOwed];

  AccountFormState _copyWith({
    GPValueWrapper<GPFailure?>? failure,
    AccountEntity? original,
    AccountFormStatus? status,
    AccountType? type,
    String? currencyCode,
    String? name,
    GPValueWrapper<int?>? initialMinorUnits,
    bool? isOwed,
  }) => AccountFormState(
    failure: failure == null ? this.failure : failure.value,
    original: original ?? this.original,
    status: status ?? this.status,
    type: type ?? this.type,
    currencyCode: currencyCode ?? this.currencyCode,
    name: name ?? this.name,
    initialMinorUnits: initialMinorUnits == null ? this.initialMinorUnits : initialMinorUnits.value,
    isEditing: isEditing,
    isOwed: isOwed ?? this.isOwed,
  );

  /// No name or balance: states can end up in logs (golden rule 9).
  @override
  String toString() => 'AccountFormState(status: ${status.name}, isEditing: $isEditing, failure: $failure)';
}

/// `saved` is terminal: the view pops on it.
enum AccountFormStatus { loading, editing, saving, saved }
