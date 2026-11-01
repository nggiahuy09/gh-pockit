import 'package:flutter/material.dart';

import '../../../../core/theme/theme_context.dart';
import '../../domain/entities/category_entity.dart';

/// The neutral 40 px disc of the canvas's `GPCategoryIcon` (W7). A null category is "Uncategorised": an empty ring, so it never reads as a category.
final class CategoryIconWidget extends StatelessWidget {
  const CategoryIconWidget({super.key, required this.category});

  final CategoryEntity? category;

  static const size = 40.0;

  /// By `icon_key`, never a stored code point (`categories_table.dart`). An unknown key, a newer build's or a user's, falls back to the generic one.
  static IconData iconOf(CategoryEntity? category) {
    if (category == null) return Icons.question_mark;

    return switch (category.iconKey) {
      'food' => Icons.restaurant,
      'transport' => Icons.directions_bus_outlined,
      'shopping' => Icons.shopping_bag_outlined,
      'bills' => Icons.receipt_long_outlined,
      'housing' => Icons.house_outlined,
      'health' => Icons.medical_services_outlined,
      'entertainment' => Icons.movie_outlined,
      'education' => Icons.school_outlined,
      'salary' => Icons.payments_outlined,
      _ => Icons.category_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isUncategorised = category == null;

    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isUncategorised ? null : colors.surfaceVariant,
          shape: BoxShape.circle,
          border: isUncategorised ? Border.all(color: colors.onSurfaceVariant, width: 1.5) : null,
        ),
        child: Icon(iconOf(category), size: 20.0, color: colors.onSurfaceVariant),
      ),
    );
  }
}
