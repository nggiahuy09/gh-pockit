part of 'transaction_form_bloc.dart';

@immutable
sealed class TransactionFormEvent {
  const TransactionFormEvent();
}

@immutable
sealed class TransactionFormRequestEvent extends TransactionFormEvent {
  const TransactionFormRequestEvent();
}

@immutable
final class _TransactionFormLoadEvent extends TransactionFormRequestEvent {
  const _TransactionFormLoadEvent();
}

@immutable
final class TransactionFormTypeChangeEvent extends TransactionFormRequestEvent {
  const TransactionFormTypeChangeEvent(this.type);

  final TransactionType type;
}

@immutable
final class TransactionFormAccountChangeEvent extends TransactionFormRequestEvent {
  const TransactionFormAccountChangeEvent(this.accountId);

  final String accountId;
}

@immutable
final class TransactionFormDestinationChangeEvent extends TransactionFormRequestEvent {
  const TransactionFormDestinationChangeEvent(this.accountId);

  final String accountId;
}

@immutable
final class TransactionFormCategoryChangeEvent extends TransactionFormRequestEvent {
  const TransactionFormCategoryChangeEvent(this.categoryId);

  final String? categoryId;
}

@immutable
final class TransactionFormAmountChangeEvent extends TransactionFormRequestEvent {
  const TransactionFormAmountChangeEvent(this.minorUnits);

  final int? minorUnits;
}

@immutable
final class TransactionFormDateChangeEvent extends TransactionFormRequestEvent {
  const TransactionFormDateChangeEvent(this.day);

  final DateTime day;
}

@immutable
final class TransactionFormNoteChangeEvent extends TransactionFormRequestEvent {
  const TransactionFormNoteChangeEvent(this.note);

  final String note;
}

@immutable
final class TransactionFormSubmitEvent extends TransactionFormRequestEvent {
  const TransactionFormSubmitEvent();
}

@immutable
final class TransactionFormDeleteEvent extends TransactionFormRequestEvent {
  const TransactionFormDeleteEvent();
}

@immutable
final class _TransactionFormWatchEvent extends TransactionFormEvent {
  const _TransactionFormWatchEvent();
}
