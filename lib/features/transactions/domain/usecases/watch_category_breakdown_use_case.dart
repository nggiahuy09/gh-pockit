import 'package:meta/meta.dart';

import '../../../../core/domain/loggable.dart';
import '../../../../core/domain/use_case.dart';
import '../../../../core/utils/calendar_month.dart';
import '../entities/category_spending.dart';
import '../repositories/transaction_repository.dart';
import 'watch_monthly_summary_use_case.dart';

/// In the month card's currency, so the rows add up to its expense figure.
final class WatchCategoryBreakdownUseCase with GPStreamUseCase<WatchCategoryBreakdownInput, List<CategorySpending>> {
  const WatchCategoryBreakdownUseCase(this._repository);

  final TransactionRepository _repository;

  @override
  Stream<List<CategorySpending>> execute(WatchCategoryBreakdownInput input) =>
      _repository.watchSpendingByCategory(currencyCode: WatchMonthlySummaryUseCase.currency.code, from: input.month.start, to: input.month.end);
}

@immutable
final class WatchCategoryBreakdownInput implements GPLoggable {
  const WatchCategoryBreakdownInput(this.month);

  final GPCalendarMonth month;

  @override
  Map<String, Object?> toLog() => {'year': month.year, 'month': month.month};
}
