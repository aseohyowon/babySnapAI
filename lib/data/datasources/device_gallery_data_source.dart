import 'dart:io';

import 'package:photo_manager/photo_manager.dart';

import '../../core/services/gallery_access_service.dart';
import '../models/gallery_asset_meta.dart';
import '../models/gallery_asset_model.dart';

class DeviceGalleryDataSource {
  DeviceGalleryDataSource(this._galleryAccessService);

  final GalleryAccessService _galleryAccessService;

  Future<bool> requestPermission() {
    return _galleryAccessService.requestPermission();
  }

  Future<List<GalleryAssetModel>> fetchGalleryAssets() async {
    final assets = await _galleryAccessService.fetchImageAssets();
    if (assets.isEmpty) return [];

    // Resolving AssetEntity → File is an async OS call per asset.
    // Do it in parallel batches of 20 to eliminate the sequential I/O stall
    // that was the primary bottleneck for large galleries.
    const fileBatchSize = 20;
    final results = <GalleryAssetModel>[];
    for (var i = 0; i < assets.length; i += fileBatchSize) {
      final end = (i + fileBatchSize).clamp(0, assets.length);
      final batch = assets.sublist(i, end);
      final resolved = await Future.wait(batch.map(_resolveAsset));
      for (final model in resolved) {
        if (model != null) results.add(model);
      }
    }

    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
  }

  Future<GalleryAssetModel?> _resolveAsset(AssetEntity asset) async {
    final file = await asset.file;
    if (file == null) return null;
    if (_isLikelyScreenshotPath(file.path)) return null;
    if (_isLikelyIllustrationFormat(file.path)) return null;
    return GalleryAssetModel(
      id: asset.id,
      path: file.path,
      createdAt: asset.createDateTime.toLocal(),
      modifiedAt: asset.modifiedDateTime.toLocal(),
    );
  }

  /// Returns lightweight metadata for all gallery images without calling
  /// [asset.file] on any asset. Screenshots and non-photo formats are
  /// filtered out using synchronously available [AssetEntity] fields
  /// ([relativePath] and [title]).  
  ///
  /// Use [resolveMetaToModel] to get the actual file path for a specific asset.
  Future<List<GalleryAssetMeta>> fetchAssetsMetaFiltered({
    int? limit,
    DateTime? newerThan,
  }) async {
    final assets = await _galleryAccessService.fetchImageAssets(
      limit: limit,
      newerThan: newerThan,
    );
    if (assets.isEmpty) return const [];

    final metas = <GalleryAssetMeta>[];
    for (final asset in assets) {
      final relPath =
          (asset.relativePath ?? '').toLowerCase().replaceAll('\\', '/');
      if (relPath.contains('screenshot') ||
          relPath.contains('screen_shot') ||
          relPath.contains('screen-shot')) {
        continue;
      }
      final title = (asset.title ?? '').toLowerCase();
      if (title.endsWith('.png') ||
          title.endsWith('.webp') ||
          title.endsWith('.gif') ||
          title.endsWith('.bmp')) {
        continue;
      }
      metas.add(GalleryAssetMeta(
        id: asset.id,
        createdAt: asset.createDateTime.toLocal(),
        modifiedAt: asset.modifiedDateTime.toLocal(),
        entity: asset,
      ));
    }
    metas.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return metas;
  }

  /// Resolves a single [GalleryAssetMeta] to a [GalleryAssetModel] by calling
  /// [asset.file]. Returns null if the file cannot be resolved or exists on a
  /// path that should be excluded.
  Future<GalleryAssetModel?> resolveMetaToModel(GalleryAssetMeta meta) async {
    final file = await meta.entity.file;
    if (file == null) return null;
    // Double-check path-based filters for any assets that slipped through
    // the title/relativePath pre-filter (e.g. files with no extension in title).
    if (_isLikelyScreenshotPath(file.path)) return null;
    if (_isLikelyIllustrationFormat(file.path)) return null;
    return GalleryAssetModel(
      id: meta.id,
      path: file.path,
      createdAt: meta.createdAt,
      modifiedAt: meta.modifiedAt,
    );
  }

  /// Returns a temporary [File] containing a JPEG thumbnail of the asset at
  /// the given [size] (pixels on the longest side). The caller is responsible
  /// for deleting the file when done.
  ///
  /// Using a small thumbnail instead of the full-resolution file drastically
  /// reduces the iOS IOSurface allocation that ML Kit triggers via
  /// [InputImage.fromFile], cutting per-image memory from ~22 MB to ~1 MB.
  /// Returns a path to a SINGLE shared temp file (reused each call).
  /// Safe because images are processed sequentially (workerCount = 1).
  /// Maximum disk usage: ONE thumbnail file (~50-100 KB) at any time.
  Future<File?> getThumbnailTempFile(
    GalleryAssetMeta meta, {
    int size = 512,
  }) async {
    try {
      final bytes = await meta.entity.thumbnailDataWithSize(
        ThumbnailSize(size, size),
        quality: 70,
      );
      if (bytes == null || bytes.isEmpty) {
        // ignore: avoid_print
        print('[THUMB] null/empty bytes for ${meta.id}');
        return null;
      }
      // Use a single fixed file name — overwritten for each image.
      // This prevents temp files from accumulating on the device.
      final tempPath = '${Directory.systemTemp.path}/babyscan_thumb.jpg';
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(bytes, flush: true);
      return tempFile;
    } catch (e, st) {
      // ignore: avoid_print
      print('[THUMB] ERROR for ${meta.id}: $e\n$st');
      return null;
    }
  }

  bool _isLikelyScreenshotPath(String path) {
    final normalized = path.toLowerCase().replaceAll('\\', '/');
    return normalized.contains('/screenshots/') ||
        normalized.contains('/screen_shots/') ||
        normalized.contains('/screen-shots/') ||
        normalized.contains('/screenshot/');
  }

  bool _isLikelyIllustrationFormat(String path) {
    final normalized = path.toLowerCase();
    return normalized.endsWith('.png') ||
        normalized.endsWith('.webp') ||
        normalized.endsWith('.gif') ||
        normalized.endsWith('.bmp');
  }
}
