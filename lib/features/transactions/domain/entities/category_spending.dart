import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import '../../../../core/money/money.dart';
import '../../../categories/domain/entities/category_entity.dart';

/// What one category's expenses add up to over a range.
@immutable
final class CategorySpending with Equatable {
  const CategorySpending({required this.category, required this.amount});

  /// Null for the uncategorised group, which also holds a deleted category's spending (ADR-0010).
  final CategoryEntity? category;

  final Money amount;

  @override
  List<Object?> get props => [category, amount];

  @override
  String toString() => 'CategorySpending(${category?.id ?? 'uncategorised'})';
}
