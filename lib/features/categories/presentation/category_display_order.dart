import 'package:ghpockit/features/categories/data/seed/default_categories.dart';
import 'package:ghpockit/features/categories/domain/entities/category_entity.dart';

/// Seeded categories in seed order, then the user's own in the order they arrive. Seeds share one `created_at`, so the repository's tie-break on id
/// (a v5 hash) would show them in an order that reads as random.
List<CategoryEntity> inDisplayOrder(Iterable<CategoryEntity> categories) {
  final afterSeeds = DefaultCategory.values.length;
  var arrival = 0;
  // Arrival breaks ties, so the sort is stable even though `List.sort` is not.
  final ranked = <(int, int, CategoryEntity)>[
    for (final category in categories) (_seedOf(category)?.index ?? afterSeeds, arrival++, category),
  ]..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));

  return <CategoryEntity>[for (final (_, _, category) in ranked) category];
}

DefaultCategory? _seedOf(CategoryEntity category) {
  final key = category.nameKey;
  return key == null ? null : DefaultCategory.fromNameKey(key);
}
