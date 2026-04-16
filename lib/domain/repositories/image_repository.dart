import '../entities/gallery_image.dart';
import '../entities/gallery_scan_progress.dart';

abstract class ImageRepository {
  Future<bool> requestGalleryPermission();

  Future<List<GalleryImage>> loadCachedBabyImages();

  Future<DateTime?> loadLastScanAt();

  Future<List<GalleryImage>> scanBabyImages({
    required void Function(GalleryScanProgress progress) onProgress,
    void Function(List<GalleryImage> partial)? onBabyFound,
    bool forceRescan,
    bool startupFastScan,
  });

  Future<void> excludeAsset(String assetId);

  /// Tell the repository whether the current user has premium so it can
  /// apply larger batch sizes for faster scanning.
  void setPremium(bool isPremium);

  void dispose();
}
