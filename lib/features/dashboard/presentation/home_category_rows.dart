import 'package:meta/meta.dart';

import '../../../core/money/money.dart';
import '../../transactions/domain/entities/category_spending.dart';

/// What Home shows of a month's breakdown (canvas `W8Home`): the [shownCategories] largest, then "Uncategorised" whatever its size, then one line
/// for the rest, so the rows always add up to the month's spending. Empty only for a month with no expense.
@immutable
final class HomeCategoryRows {
  /// [breakdown] comes largest first, as the query sorts it.
  factory HomeCategoryRows.of(List<CategorySpending> breakdown) {
    if (breakdown.isEmpty) return const HomeCategoryRows._(largestMinor: 0, rest: null, restCount: 0, rows: [], totalMinor: 0);

    final named = [
      for (final spending in breakdown)
        if (spending.category != null) spending,
    ];
    final uncategorised = breakdown.where((spending) => spending.category == null).firstOrNull;
    final hidden = named.skip(shownCategories).toList();

    return HomeCategoryRows._(
      largestMinor: breakdown.map((spending) => spending.amount.minorUnits).reduce((a, b) => a > b ? a : b),
      rest: hidden.isEmpty ? null : hidden.map((spending) => spending.amount).reduce((a, b) => a + b),
      restCount: hidden.length,
      rows: [...named.take(shownCategories), ?uncategorised],
      totalMinor: breakdown.fold(0, (sum, spending) => sum + spending.amount.minorUnits),
    );
  }

  const HomeCategoryRows._({required this.largestMinor, required this.rest, required this.restCount, required this.rows, required this.totalMinor});

  /// More pushes "Accounts" under the dock on a 844-tall phone.
  static const shownCategories = 3;

  /// The bar scale: the largest group fills its track.
  final int largestMinor;

  /// Null when every category is listed.
  final Money? rest;

  final int restCount;
  final List<CategorySpending> rows;
  final int totalMinor;

  bool get isEmpty => rows.isEmpty;

  /// Of the month's spending, rounded half up in integers: the shares are display, never money.
  int percentOf(Money amount) => (amount.minorUnits * 200 + totalMinor) ~/ (totalMinor * 2);

  double barOf(Money amount) => amount.minorUnits / largestMinor;
}
