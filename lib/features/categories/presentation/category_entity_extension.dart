import '../../../core/localization/locale_base/locale_base.dart';
import '../data/seed/default_categories.dart';
import '../domain/entities/category_entity.dart';
import 'default_category_extension.dart';

extension CategoryEntityExtension on CategoryEntity {
  /// A typed name wins; otherwise the key is translated, or shown raw when this build does not know it (a newer build's seed).
  String getTitle(GPLocaleBase locale) {
    final name = this.name;
    if (name != null) return name;

    final nameKey = this.nameKey;
    if (nameKey == null) return '';

    return DefaultCategory.fromNameKey(nameKey)?.getTitle(locale) ?? nameKey;
  }
}
