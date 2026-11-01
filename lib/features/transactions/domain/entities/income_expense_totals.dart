import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import '../../../../core/money/money.dart';

/// Both in one currency. A transfer is neither (ADR-0009).
@immutable
final class IncomeExpenseTotals with Equatable {
  const IncomeExpenseTotals({required this.income, required this.expense});

  final Money income;
  final Money expense;

  /// Negative when more went out than came in.
  Money get net => income - expense;

  @override
  List<Object?> get props => [income, expense];

  @override
  String toString() => 'IncomeExpenseTotals(${income.currencyCode})';
}
