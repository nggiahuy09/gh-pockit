import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

import '../../../core/localization/locale_base/locale_base.dart';
import '../domain/entities/transaction_list_item.dart';

@immutable
final class TransactionDay {
  const TransactionDay(this._items, this.date);

  final List<TransactionListItem> _items;

  /// Local midnight.
  final DateTime date;

  List<TransactionListItem> get items => List.unmodifiable(_items);
}

List<TransactionDay> groupByLocalDay(Iterable<TransactionListItem> items) {
  final days = <DateTime, List<TransactionListItem>>{};
  for (final item in items) {
    final local = item.transaction.occurredAt.toLocal();
    days.putIfAbsent(DateTime(local.year, local.month, local.day), () => []).add(item);
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
