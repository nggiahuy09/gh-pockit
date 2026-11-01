import 'package:meta/meta.dart';

import '../../../../core/domain/loggable.dart';
import '../../../../core/domain/use_case.dart';
import '../../../../core/money/currency_code.dart';
import '../../../../core/utils/calendar_month.dart';
import '../entities/income_expense_totals.dart';
import '../repositories/transaction_repository.dart';

/// Home's month card. Another currency's transactions are left out, not converted (ADR-0021).
final class WatchMonthlySummaryUseCase with GPStreamUseCase<WatchMonthlySummaryInput, IncomeExpenseTotals> {
  const WatchMonthlySummaryUseCase(this._repository);

  /// The one currency the month's figures are in, until the app handles more than one (ADR-0021). The breakdown reads it from here.
  static const CurrencyCode currency = CurrencyCode.vnd;

  final TransactionRepository _repository;

  @override
  Stream<IncomeExpenseTotals> execute(WatchMonthlySummaryInput input) =>
      _repository.watchIncomeExpenseTotals(currencyCode: currency.code, from: input.month.start, to: input.month.end);
}

@immutable
final class WatchMonthlySummaryInput implements GPLoggable {
  const WatchMonthlySummaryInput(this.month);

  final GPCalendarMonth month;

  @override
  Map<String, Object?> toLog() => {'year': month.year, 'month': month.month};
}
