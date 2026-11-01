part of 'locale_en.dart';

final class GPLocaleEnHome implements GPLocaleBaseHome {
  const GPLocaleEnHome();

  @override
  String get title => 'Home';

  @override
  String get seeAllAccounts => 'See all';

  @override
  String get netThisMonth => 'Income − spending this month';

  @override
  String get loadingMonth => "Loading this month's totals";

  @override
  String get spendingByCategory => 'Spending by category';

  @override
  String get loadingSpending => 'Loading spending by category';

  @override
  String get noSpendingTitle => 'No spending this month yet';

  @override
  String get noSpendingBody => 'Each expense adds up under its category here.';

  @override
  String get sectionErrorBody => 'This part comes back by itself the next time data is saved.';

  @override
  String otherCategories(int count) => count == 1 ? '1 more category' : '$count more categories';

  @override
  String categoryShare({required String amount, required String name, required int percent}) => "$name, $amount, $percent% of this month's spending";
}
