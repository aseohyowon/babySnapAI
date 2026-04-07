import 'dart:io';

class GalleryImage {
  const GalleryImage({
    required this.assetId,
    required this.path,
    required this.createdAt,
    required this.faceCount,
    required this.isBaby,
    this.faceVector,
  });

  final String assetId;
  final String path;
  final DateTime createdAt;
  final int faceCount;
  final bool isBaby;
  final List<double>? faceVector;

  File get file => File(path);
}
