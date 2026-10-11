import 'package:ghpockit/core/localization/locale_base/locale_base.dart';
import 'package:ghpockit/features/transactions/domain/entities/transaction_entity.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

@immutable
final class TransactionDay {
  TransactionDay(this.date, List<TransactionEntity> transactions) : transactions = List<TransactionEntity>.unmodifiable(transactions);

  /// Local midnight.
  final DateTime date;
  final List<TransactionEntity> transactions;
}

List<TransactionDay> groupByLocalDay(Iterable<TransactionEntity> transactions) {
  final days = <DateTime, List<TransactionEntity>>{};
  for (final transaction in transactions) {
    final local = transaction.occurredAt.toLocal();
    days.putIfAbsent(DateTime(local.year, local.month, local.day), () => <TransactionEntity>[]).add(transaction);
  }

  return [for (final MapEntry(key: date, value: rows) in days.entries) TransactionDay(date, rows)];
}

/// [today] is local. Needs the date symbols `bootstrap()` loads.
String dayLabel(DateTime date, {required DateTime today, required GPLocaleBase l10n}) {
  if (date == DateTime(today.year, today.month, today.day)) return l10n.transactions.today;
  // Through the constructor, not `subtract(Duration(days: 1))`: across a DST change a day is 23 or 25 hours long.
  if (date == DateTime(today.year, today.month, today.day - 1)) return l10n.transactions.yesterday;

  final language = l10n.locale.languageCode;
  return (date.year == today.year ? DateFormat.MMMMEEEEd(language) : DateFormat.yMMMMEEEEd(language)).format(date);
}
