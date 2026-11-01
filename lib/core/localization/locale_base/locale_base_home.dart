part of 'locale_base.dart';

abstract class GPLocaleBaseHome {
  const GPLocaleBaseHome();

  String get title;

  String get seeAllAccounts;

  /// "Income − spending", the month card's main figure.
  String get netThisMonth;

  String get loadingMonth;

  String get spendingByCategory;

  String get loadingSpending;

  String get noSpendingTitle;

  String get noSpendingBody;

  /// Under a section that failed while the rest of Home still shows.
  String get sectionErrorBody;

  /// The line that sums the categories Home does not list.
  String otherCategories(int count);

  /// [percent] is of the month's spending, already rounded.
  String categoryShare({required String amount, required String name, required int percent});
}
