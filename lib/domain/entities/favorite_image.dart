class FavoriteImage {
  const FavoriteImage({
    required this.assetId,
    required this.path,
    required this.addedAt,
  });

  final String assetId;
  final String path;
  final DateTime addedAt;
}
