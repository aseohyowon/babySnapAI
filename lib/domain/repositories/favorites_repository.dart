import '../entities/favorite_image.dart';

abstract class FavoritesRepository {
  Future<List<FavoriteImage>> getFavorites();

  Future<bool> isFavorite(String assetId);

  Future<void> addFavorite(FavoriteImage favoriteImage);

  Future<void> removeFavorite(String assetId);

  Future<void> clearFavorites();
}
