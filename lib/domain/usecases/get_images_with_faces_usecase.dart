import '../entities/gallery_image.dart';
import '../entities/gallery_scan_progress.dart';
import '../repositories/image_repository.dart';

class GetImagesWithFacesUseCase {
  GetImagesWithFacesUseCase(this._repository);

  final ImageRepository _repository;

  Future<bool> requestGalleryPermission() {
    return _repository.requestGalleryPermission();
  }

  Future<List<GalleryImage>> loadCachedBabyImages() {
    return _repository.loadCachedBabyImages();
  }

  Future<DateTime?> loadLastScanAt() {
    return _repository.loadLastScanAt();
  }

  Future<List<GalleryImage>> execute({
    required void Function(GalleryScanProgress progress) onProgress,
    void Function(List<GalleryImage> partial)? onBabyFound,
    bool forceRescan = false,
  }) {
    return _repository.scanBabyImages(
      onProgress: onProgress,
      onBabyFound: onBabyFound,
      forceRescan: forceRescan,
    );
  }

  Future<void> excludeAsset(String assetId) {
    return _repository.excludeAsset(assetId);
  }

  void setPremium(bool isPremium) {
    _repository.setPremium(isPremium);
  }

  void dispose() {
    _repository.dispose();
  }
}
