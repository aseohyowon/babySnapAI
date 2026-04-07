import '../entities/favorite_image.dart';
import '../repositories/favorites_repository.dart';

class GetFavoritesUseCase {
  GetFavoritesUseCase(this._repository);

  final FavoritesRepository _repository;

  Future<List<FavoriteImage>> execute() {
    return _repository.getFavorites();
  }

  Future<void> addFavorite(FavoriteImage image) {
    return _repository.addFavorite(image);
  }

  Future<void> removeFavorite(String assetId) {
    return _repository.removeFavorite(assetId);
  }

  Future<bool> isFavorite(String assetId) {
    return _repository.isFavorite(assetId);
  }
}
