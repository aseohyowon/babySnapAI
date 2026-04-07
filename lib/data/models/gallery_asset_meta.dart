import 'package:photo_manager/photo_manager.dart';

/// Lightweight asset descriptor returned by [DeviceGalleryDataSource.fetchAssetsMetaFiltered].
///
/// Contains only the metadata that is available synchronously from [AssetEntity]
/// (no [asset.file] call). The underlying [entity] is kept so callers can lazily
/// resolve the actual file path only when a full [GalleryAssetModel] is needed.
class GalleryAssetMeta {
  const GalleryAssetMeta({
    required this.id,
    required this.createdAt,
    required this.modifiedAt,
    required this.entity,
  });

  final String id;
  final DateTime createdAt;
  final DateTime modifiedAt;

  /// The underlying platform asset. Call [entity.file] to get the [File].
  final AssetEntity entity;
}
