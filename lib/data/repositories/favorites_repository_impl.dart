import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/favorite_image.dart';
import '../../domain/repositories/favorites_repository.dart';

class FavoritesRepositoryImpl implements FavoritesRepository {
  FavoritesRepositoryImpl();

  static const String _favoritesKey = 'baby_gallery_favorites';

  @override
  Future<List<FavoriteImage>> getFavorites() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getStringList(_favoritesKey) ?? <String>[];
    
    return raw.map((item) {
      final parts = item.split('|');
      if (parts.length != 3) return null;
      return FavoriteImage(
        assetId: parts[0],
        path: parts[1],
        addedAt: DateTime.parse(parts[2]),
      );
    }).whereType<FavoriteImage>().toList();
  }

  @override
  Future<bool> isFavorite(String assetId) async {
    final favorites = await getFavorites();
    return favorites.any((fav) => fav.assetId == assetId);
  }

  @override
  Future<void> addFavorite(FavoriteImage favoriteImage) async {
    final preferences = await SharedPreferences.getInstance();
    final favorites = await getFavorites();
    
    if (!favorites.any((fav) => fav.assetId == favoriteImage.assetId)) {
      final serialized = _serialize(favoriteImage);
      final current = preferences.getStringList(_favoritesKey) ?? <String>[];
      current.add(serialized);
      await preferences.setStringList(_favoritesKey, current);
    }
  }

  @override
  Future<void> removeFavorite(String assetId) async {
    final preferences = await SharedPreferences.getInstance();
    final current = preferences.getStringList(_favoritesKey) ?? <String>[];
    current.removeWhere((item) => item.startsWith('$assetId|'));
    await preferences.setStringList(_favoritesKey, current);
  }

  @override
  Future<void> clearFavorites() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_favoritesKey);
  }

  String _serialize(FavoriteImage image) {
    return '${image.assetId}|${image.path}|${image.addedAt.toIso8601String()}';
  }
}