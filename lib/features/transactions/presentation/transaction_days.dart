import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

import '../../../core/localization/locale_base/locale_base.dart';
import '../domain/entities/transaction_entity.dart';

@immutable
final class TransactionDay {
  const TransactionDay(this._transactions, this.date);

  final List<TransactionEntity> _transactions;

  /// Local midnight.
  final DateTime date;

  List<TransactionEntity> get transactions => List.unmodifiable(_transactions);
}

List<TransactionDay> groupByLocalDay(Iterable<TransactionEntity> transactions) {
  final days = <DateTime, List<TransactionEntity>>{};
  for (final transaction in transactions) {
    final local = transaction.occurredAt.toLocal();
    days.putIfAbsent(DateTime(local.year, local.month, local.day), () => []).add(transaction);
  }

  return [for (final MapEntry(key: date, value: rows) in days.entries) TransactionDay(rows, date)];
}

/// [today] is local. Needs the date symbols `bootstrap()` loads.
String getDayLabel({required GPLocaleBase locale, required DateTime date, required DateTime today}) {
  if (date == DateTime(today.year, today.month, today.day)) return locale.transactions.today;
  // Through the constructor, not `subtract`: across a DST change a day is 23 or 25 hours long.
  if (date == DateTime(today.year, today.month, today.day - 1)) return locale.transactions.yesterday;

  final language = locale.locale.languageCode;
  return (date.year == today.year ? DateFormat.MMMMEEEEd(language) : DateFormat.yMMMMEEEEd(language)).format(date);
}
