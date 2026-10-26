part of 'account_form_bloc.dart';

@immutable
sealed class AccountFormEvent {
  const AccountFormEvent();
}

@immutable
final class _AccountFormLoadEvent extends AccountFormEvent {
  const _AccountFormLoadEvent();
}

@immutable
final class AccountFormNameChangeEvent extends AccountFormEvent {
  const AccountFormNameChangeEvent(this.name);

  final String name;
}

@immutable
final class AccountFormTypeChangeEvent extends AccountFormEvent {
  const AccountFormTypeChangeEvent(this.type);

  final AccountType type;
}

@immutable
final class AccountFormCurrencyChangeEvent extends AccountFormEvent {
  const AccountFormCurrencyChangeEvent(this.currency);

  final CurrencyCode currency;
}

@immutable
final class AccountFormInitialBalanceChangeEvent extends AccountFormEvent {
  const AccountFormInitialBalanceChangeEvent(this.minorUnits);

  /// Null while the field is empty.
  final int? minorUnits;
}

@immutable
final class AccountFormOwedChangeEvent extends AccountFormEvent {
  const AccountFormOwedChangeEvent(this.isOwed);

  final bool isOwed;
}

@immutable
final class AccountFormSubmitEvent extends AccountFormEvent {
  const AccountFormSubmitEvent();
}
