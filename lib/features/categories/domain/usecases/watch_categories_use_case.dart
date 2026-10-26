import '../../../../core/domain/use_case.dart';
import '../entities/category_entity.dart';
import '../repositories/category_repository.dart';

final class WatchCategoriesUseCase with GPStreamUseCase<GPNoInput, List<CategoryEntity>> {
  const WatchCategoriesUseCase(this._repository);

  final CategoryRepository _repository;

  @override
  Stream<List<CategoryEntity>> execute(GPNoInput input) => _repository.watchCategories();
}
