import '../entities/menu_item.dart';
import '../repositories/menu_repository.dart';
import '../../../../core/utils/result.dart';

/// Use-case: fetch the full menu, optionally filtered by category.
class GetMenuItems {
  final MenuRepository _repository;

  const GetMenuItems(this._repository);

  Future<Result<List<MenuItem>>> call({String? category}) {
    return _repository.getMenuItems(category: category);
  }
}
