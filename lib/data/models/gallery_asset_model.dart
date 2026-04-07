import 'dart:io';

class GalleryAssetModel {
  const GalleryAssetModel({
    required this.id,
    required this.path,
    required this.createdAt,
    required this.modifiedAt,
  });

  final String id;
  final String path;
  final DateTime createdAt;
  final DateTime modifiedAt;

  File get file => File(path);
}
